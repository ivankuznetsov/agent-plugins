import json
import os
import shutil
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins" / "llm-wiki"
POST_COMMIT_TEMPLATE = PLUGIN_ROOT / "templates" / "post-commit-refresh.sh"
SCHEDULER_TEMPLATE = PLUGIN_ROOT / "templates" / "install-systemd-scheduler.sh"
UPGRADE_SCRIPT = PLUGIN_ROOT / "skills" / "upgrade" / "scripts" / "upgrade-project.sh"


class LlmWikiOpenClawTests(unittest.TestCase):
    def test_canonical_skills_define_openclaw_context_ownership_and_lifecycle(self):
        bootstrap = (PLUGIN_ROOT / "skills" / "bootstrap" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        status = (PLUGIN_ROOT / "skills" / "wiki-status" / "SKILL.md").read_text(
            encoding="utf-8"
        )

        self.assertIn('"context_agents": ["claude", "codex", "pi", "openclaw"]', bootstrap)
        self.assertIn('"openclaw_agent_id": "<configured-agent-id-or-null>"', bootstrap)
        self.assertIn('headless_agent: "openclaw"', bootstrap)
        self.assertIn("OpenClaw auto-injects", bootstrap)
        self.assertIn("openclaw agent --local --agent", bootstrap)
        self.assertIn("Omit `--deliver`", bootstrap)

        self.assertIn("openclaw plugins list --json", status)
        self.assertIn("openclaw plugins inspect llm-wiki --json", status)
        self.assertIn("openclaw plugins update llm-wiki --dry-run", status)
        self.assertIn("openclaw plugins update llm-wiki", status)
        self.assertIn("openclaw gateway restart --safe", status)
        upgrade = (PLUGIN_ROOT / "skills" / "upgrade" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Codex, Claude Code, Pi, or OpenClaw", upgrade)
        self.assertIn("openclaw_agent_id", upgrade)

    def test_generated_openclaw_skills_keep_native_maintenance_behavior(self):
        bootstrap = (
            PLUGIN_ROOT / "openclaw" / "skills" / "wiki-bootstrap" / "SKILL.md"
        ).read_text(encoding="utf-8")
        status = (
            PLUGIN_ROOT / "openclaw" / "skills" / "wiki-status" / "SKILL.md"
        ).read_text(encoding="utf-8")

        self.assertIn("generated-from: skills/bootstrap/SKILL.md", bootstrap)
        self.assertIn("# Bootstrap LLM Wiki", bootstrap)
        self.assertIn("OpenClaw", bootstrap)
        self.assertIn("generated-from: skills/wiki-status/SKILL.md", status)
        self.assertIn("Installed source:", status)
        self.assertIn("OpenClaw", status)
        upgrade = (
            PLUGIN_ROOT / "openclaw" / "skills" / "wiki-upgrade" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertIn("generated-from: skills/upgrade/SKILL.md", upgrade)
        self.assertIn("upgrade-project.sh --project", upgrade)

    def test_post_commit_template_dispatches_non_delivering_openclaw_turn(self):
        result, arguments, _ = self.run_template("openclaw")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(
            ["openclaw", "agent", "--local", "--agent", "main"],
            arguments[:5],
        )
        self.assertIn("--message", arguments)
        self.assertIn("--json", arguments)
        timeout_index = arguments.index("--timeout")
        self.assertEqual("1800", arguments[timeout_index + 1])
        for forbidden in (
            "--deliver",
            "--channel",
            "--reply-channel",
            "--reply-to",
            "--to",
        ):
            self.assertNotIn(forbidden, arguments)

    def test_post_commit_template_dispatches_every_supported_owner(self):
        prefixes = {
            "claude": ["claude", "-p"],
            "codex": ["codex", "exec"],
            "pi": ["pi", "-p", "--no-session"],
            "openclaw": ["openclaw", "agent", "--local", "--agent", "main"],
        }
        for owner, prefix in prefixes.items():
            with self.subTest(owner=owner):
                result, arguments, _ = self.run_template(owner)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertEqual(prefix, arguments[: len(prefix)])

    def test_post_commit_template_rejects_unknown_headless_agent(self):
        result, arguments, log = self.run_template("other-agent")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual([], arguments)
        self.assertIn("unsupported or missing headless_agent", log)
        self.assertIn("queue retained", log)

    def test_post_commit_template_requires_explicit_automation_consent(self):
        result, arguments, _ = self.run_template("codex", consent=False)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual([], arguments)
        self.assertIn("automatic refresh disabled", result.stderr)

    def test_post_commit_runtime_bounds_recovery_and_publishes_only_refresh_branch(self):
        template = POST_COMMIT_TEMPLATE.read_text(encoding="utf-8")

        self.assertIn("LLM_WIKI_MAX_SOURCE_PIN_BATCH", template)
        self.assertIn("reconstructed interrupted queue write", template)
        self.assertIn('refresh_branch="${LLM_WIKI_REFRESH_BRANCH:-llm-wiki/refresh}"', template)
        self.assertIn('push "$refresh_remote" "HEAD:refs/heads/$refresh_branch"', template)
        self.assertNotIn('push "$refresh_remote" "HEAD:refs/heads/$base_branch"', template)

    def test_compiled_log_only_commit_does_not_queue_or_launch_refresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.initialize_hook_project(directory)
            (root / "wiki" / "log.md").write_text(
                "# Compiled projection\n\nsecond render\n", encoding="utf-8"
            )
            self.run_git(root, "add", "wiki/log.md")
            self.run_git(root, "commit", "-m", "compile wiki log")
            source_sha = self.git_output(root, "rev-parse", "HEAD")

            environment = os.environ.copy()
            environment.update(
                {
                    "HOME": str(Path(directory) / "home"),
                    "PATH": "/usr/bin:/bin",
                    "LLM_WIKI_SKIP_SYSTEMCTL": "1",
                }
            )
            result = subprocess.run(
                [str(root / ".llm-wiki" / "post-commit-refresh.sh")],
                cwd=root,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            pending = root / ".git" / "llm-wiki" / "pending"
            self.assertEqual([], list(pending.iterdir()))
            source_ref = subprocess.run(
                ["git", "show-ref", "--verify", "--quiet", f"refs/llm-wiki/sources/{source_sha}"],
                cwd=root,
                check=False,
            )
            self.assertNotEqual(0, source_ref.returncode)

    def test_headless_hook_recovers_user_bus_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.initialize_hook_project(directory)
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            self.run_git(root, "add", "README.md")
            self.run_git(root, "commit", "-m", "change docs")

            bin_dir = Path(directory) / "bin"
            runtime_dir = Path(directory) / "runtime"
            systemctl_log = Path(directory) / "systemctl.log"
            bin_dir.mkdir()
            runtime_dir.mkdir()
            fake_systemctl = bin_dir / "systemctl"
            fake_systemctl.write_text(
                '#!/usr/bin/env bash\nprintf "%s|%s|%s\\n" '
                '"$XDG_RUNTIME_DIR" "$DBUS_SESSION_BUS_ADDRESS" "$*" '
                '>"$LLM_WIKI_SYSTEMCTL_LOG"\n',
                encoding="utf-8",
            )
            fake_systemctl.chmod(0o755)
            state_dir = root / ".git" / "llm-wiki"
            state_dir.mkdir(parents=True)
            marker = state_dir / "scheduler-service"
            marker.write_text("llm-wiki-project-deadbeef.service\n", encoding="utf-8")

            bus_path = runtime_dir / "bus"
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as bus:
                bus.bind(str(bus_path))
                environment = os.environ.copy()
                environment.update(
                    {
                        "HOME": str(Path(directory) / "home"),
                        "PATH": f"{bin_dir}:/usr/bin:/bin",
                        "XDG_RUNTIME_DIR": str(runtime_dir),
                        "DBUS_SESSION_BUS_ADDRESS": "",
                        "LLM_WIKI_SYSTEMCTL_LOG": str(systemctl_log),
                    }
                )
                result = subprocess.run(
                    [str(root / ".llm-wiki" / "post-commit-refresh.sh")],
                    cwd=root,
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )

            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertEqual(
                f"{runtime_dir}|unix:path={bus_path}|--user start --no-block "
                "llm-wiki-project-deadbeef.service\n",
                systemctl_log.read_text(encoding="utf-8"),
            )
            self.assertEqual(
                "llm-wiki-project-deadbeef.service\n",
                marker.read_text(encoding="utf-8"),
            )

    def test_failed_headless_signal_keeps_scheduler_marker_and_falls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.initialize_hook_project(directory)
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            self.run_git(root, "add", "README.md")
            self.run_git(root, "commit", "-m", "change docs")

            bin_dir = Path(directory) / "bin"
            bin_dir.mkdir()
            fake_systemctl = bin_dir / "systemctl"
            fake_systemctl.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
            fake_systemctl.chmod(0o755)
            state_dir = root / ".git" / "llm-wiki"
            state_dir.mkdir(parents=True)
            marker = state_dir / "scheduler-service"
            marker.write_text("llm-wiki-project-deadbeef.service\n", encoding="utf-8")

            environment = os.environ.copy()
            environment.update(
                {
                    "HOME": str(Path(directory) / "home"),
                    "PATH": f"{bin_dir}:/usr/bin:/bin",
                    "LLM_WIKI_REFRESH_CMD": "/bin/true",
                    "LLM_WIKI_SKIP_PUSH": "1",
                }
            )
            result = subprocess.run(
                [str(root / ".llm-wiki" / "post-commit-refresh.sh")],
                cwd=root,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertEqual(
                "llm-wiki-project-deadbeef.service\n",
                marker.read_text(encoding="utf-8"),
            )
            log = (state_dir / "post-commit-refresh.log").read_text(encoding="utf-8")
            self.assertIn("keeping its configured marker", log)

    def test_scheduler_recovers_user_bus_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.initialize_hook_project(directory)
            unit_dir = Path(directory) / "systemd"
            bin_dir = Path(directory) / "bin"
            runtime_dir = Path(directory) / "runtime"
            systemctl_log = Path(directory) / "systemctl.log"
            unit_dir.mkdir()
            bin_dir.mkdir()
            runtime_dir.mkdir()
            fake_systemctl = bin_dir / "systemctl"
            fake_systemctl.write_text(
                '#!/usr/bin/env bash\nprintf "%s|%s|%s\\n" '
                '"$XDG_RUNTIME_DIR" "$DBUS_SESSION_BUS_ADDRESS" "$*" '
                '>>"$LLM_WIKI_SYSTEMCTL_LOG"\n',
                encoding="utf-8",
            )
            fake_systemctl.chmod(0o755)

            bus_path = runtime_dir / "bus"
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as bus:
                bus.bind(str(bus_path))
                environment = os.environ.copy()
                environment.update(
                    {
                        "PATH": f"{bin_dir}:/usr/bin:/bin",
                        "XDG_RUNTIME_DIR": str(runtime_dir),
                        "DBUS_SESSION_BUS_ADDRESS": "",
                        "LLM_WIKI_SYSTEMD_USER_DIR": str(unit_dir),
                        "LLM_WIKI_FLOCK_PATH": shutil.which("flock") or "/usr/bin/flock",
                        "LLM_WIKI_SYSTEMCTL_LOG": str(systemctl_log),
                    }
                )
                result = subprocess.run(
                    [str(SCHEDULER_TEMPLATE), "--project", str(root)],
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )

            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            calls = systemctl_log.read_text(encoding="utf-8")
            self.assertIn(
                f"{runtime_dir}|unix:path={bus_path}|--user daemon-reload",
                calls,
            )

    def test_scheduler_reconciles_linked_worktrees_and_stops_disabled_units(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "project"
            linked = Path(directory) / "linked"
            unit_dir = Path(directory) / "systemd"
            bin_dir = Path(directory) / "bin"
            systemctl_log = Path(directory) / "systemctl.log"
            root.mkdir()
            unit_dir.mkdir()
            bin_dir.mkdir()
            (root / ".llm-wiki").mkdir()
            (root / "wiki").mkdir()
            (root / ".llm-wiki" / "config.json").write_text("{}\n", encoding="utf-8")
            (root / "wiki" / "index.md").write_text("# Wiki\n", encoding="utf-8")
            self.run_git(root, "init", "-b", "main")
            self.run_git(root, "config", "user.email", "llm-wiki-test@example.com")
            self.run_git(root, "config", "user.name", "LLM Wiki Test")
            self.run_git(root, "add", ".")
            self.run_git(root, "commit", "-m", "initial")
            self.run_git(root, "worktree", "add", "-b", "feature", str(linked))

            common_dir = Path(
                subprocess.run(
                    ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                    cwd=root,
                    text=True,
                    capture_output=True,
                    check=True,
                ).stdout.strip()
            )
            shared_dir = common_dir / "llm-wiki"
            shared_dir.mkdir()
            shutil.copy2(POST_COMMIT_TEMPLATE, shared_dir / "post-commit-refresh.sh")
            (shared_dir / "post-commit-refresh.sh").chmod(0o755)

            fake_systemctl = bin_dir / "systemctl"
            fake_systemctl.write_text(
                '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >>"$LLM_WIKI_SYSTEMCTL_LOG"\n',
                encoding="utf-8",
            )
            fake_systemctl.chmod(0o755)
            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": f"{bin_dir}:/usr/bin:/bin",
                    "LLM_WIKI_SYSTEMD_USER_DIR": str(unit_dir),
                    "LLM_WIKI_FLOCK_PATH": shutil.which("flock") or "/usr/bin/flock",
                    "LLM_WIKI_SYSTEMCTL_LOG": str(systemctl_log),
                }
            )

            for project in (root, linked):
                result = subprocess.run(
                    [str(SCHEDULER_TEMPLATE), "--project", str(project)],
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)

            services = list(unit_dir.glob("llm-wiki-*.service"))
            timers = list(unit_dir.glob("llm-wiki-*.timer"))
            self.assertEqual(1, len(services))
            self.assertEqual(1, len(timers))
            service = services[0]
            timer = timers[0]
            service_text = service.read_text(encoding="utf-8")
            timer_text = timer.read_text(encoding="utf-8")
            self.assertIn("MemoryMax=4G", service_text)
            self.assertIn("MemorySwapMax=0", service_text)
            self.assertIn("TimeoutStartSec=4h", service_text)
            self.assertIn("%t/llm-wiki-refresh.lock", service_text)
            self.assertNotIn("Persistent=", timer_text)

            legacy_service = unit_dir / "llm-wiki-linked-legacy.service"
            legacy_timer = unit_dir / "llm-wiki-linked-legacy.timer"
            legacy_service.write_text(
                "[Unit]\nDescription=Refresh LLM wiki for llm-wiki-linked-legacy\n"
                f"[Service]\nWorkingDirectory={linked}\n",
                encoding="utf-8",
            )
            legacy_timer.write_text("[Timer]\nPersistent=true\n", encoding="utf-8")

            result = subprocess.run(
                [str(SCHEDULER_TEMPLATE), "--disabled", "--project", str(linked)],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertFalse(legacy_service.exists())
            self.assertFalse(legacy_timer.exists())
            self.assertFalse((unit_dir / "timers.target.wants" / timer.name).exists())
            systemctl_calls = systemctl_log.read_text(encoding="utf-8")
            self.assertIn("stop llm-wiki-linked-legacy.service", systemctl_calls)
            self.assertIn("stop llm-wiki-linked-legacy.timer", systemctl_calls)
            self.assertIn(f"stop {timer.name}", systemctl_calls)

    def test_post_commit_template_requires_explicit_openclaw_agent_id(self):
        result, arguments, log = self.run_template("openclaw", openclaw_agent_id=None)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual([], arguments)
        self.assertIn("requires a valid openclaw_agent_id", log)
        self.assertIn("queue retained", log)

    def test_post_commit_template_rejects_flag_shaped_openclaw_agent_id(self):
        result, arguments, log = self.run_template(
            "openclaw", openclaw_agent_id="--deliver"
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual([], arguments)
        self.assertIn("requires a valid openclaw_agent_id", log)
        self.assertIn("queue retained", log)

    def test_project_upgrade_accepts_preserved_openclaw_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "project"
            root.mkdir()
            (root / ".llm-wiki").mkdir()
            (root / "wiki").mkdir()
            (root / ".llm-wiki" / "config.json").write_text(
                json.dumps(
                    {
                        "headless_agent": "openclaw",
                        "context_agents": ["claude", "codex", "pi", "openclaw"],
                        "openclaw_agent_id": "project-agent",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            (root / "wiki" / "index.md").write_text("# Wiki\n", encoding="utf-8")
            self.run_git(root, "init", "-b", "main")
            self.run_git(root, "config", "user.email", "llm-wiki-test@example.com")
            self.run_git(root, "config", "user.name", "LLM Wiki Test")
            self.run_git(root, "add", ".")
            self.run_git(root, "commit", "-m", "initial")

            result = subprocess.run(
                [str(UPGRADE_SCRIPT), "--check", "--project", str(root)],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(10, result.returncode, result.stdout + result.stderr)
            self.assertIn("upgrade available", result.stdout)

    def test_project_upgrade_installs_all_runtime_files_without_enabling_unapproved_timer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "project"
            unit_dir = Path(directory) / "systemd"
            root.mkdir()
            unit_dir.mkdir()
            (root / ".llm-wiki").mkdir()
            (root / "wiki").mkdir()
            (root / ".llm-wiki" / "config.json").write_text(
                json.dumps(
                    {
                        "headless_agent": "codex",
                        "automation_enabled": False,
                        "external_provider_access_approved": False,
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            (root / "wiki" / "index.md").write_text("# Wiki\n", encoding="utf-8")
            self.run_git(root, "init", "-b", "main")
            self.run_git(root, "config", "user.email", "llm-wiki-test@example.com")
            self.run_git(root, "config", "user.name", "LLM Wiki Test")
            self.run_git(root, "add", ".")
            self.run_git(root, "commit", "-m", "initial")

            environment = os.environ.copy()
            environment.update(
                {
                    "LLM_WIKI_SYSTEMD_USER_DIR": str(unit_dir),
                    "LLM_WIKI_SKIP_SYSTEMCTL": "1",
                    "LLM_WIKI_FLOCK_PATH": shutil.which("flock") or "/usr/bin/flock",
                }
            )
            result = subprocess.run(
                [str(UPGRADE_SCRIPT), "--project", str(root)],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            for name in (
                "post-commit-refresh.sh",
                "refresh-wiki.sh",
                "compile-log.sh",
                "install-systemd-scheduler.sh",
            ):
                self.assertTrue((root / ".llm-wiki" / name).is_file(), name)
            self.assertEqual(1, len(list(unit_dir.glob("llm-wiki-*.service"))))
            self.assertEqual(1, len(list(unit_dir.glob("llm-wiki-*.timer"))))
            self.assertEqual(
                [],
                list((unit_dir / "timers.target.wants").glob("llm-wiki-*.timer")),
            )

            check_result = subprocess.run(
                [str(UPGRADE_SCRIPT), "--check", "--project", str(root)],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(
                0,
                check_result.returncode,
                check_result.stdout + check_result.stderr,
            )
            self.assertIn("project structure is current", check_result.stdout)

    def run_template(self, headless_agent, openclaw_agent_id="main", consent=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "project"
            bin_dir = Path(directory) / "bin"
            home = Path(directory) / "home"
            capture = Path(directory) / "openclaw-arguments"
            root.mkdir()
            bin_dir.mkdir()
            home.mkdir()
            (root / ".llm-wiki").mkdir()
            (root / "wiki").mkdir()

            shutil.copy2(POST_COMMIT_TEMPLATE, root / ".llm-wiki" / "post-commit-refresh.sh")
            (root / ".llm-wiki" / "post-commit-refresh.sh").chmod(0o755)
            config = {
                "headless_agent": headless_agent,
                "context_agents": ["claude", "codex", "pi", "openclaw"],
                "automation_enabled": consent,
                "external_provider_access_approved": consent,
            }
            if openclaw_agent_id is not None:
                config["openclaw_agent_id"] = openclaw_agent_id
            (root / ".llm-wiki" / "config.json").write_text(
                json.dumps(config)
                + "\n",
                encoding="utf-8",
            )
            (root / "README.md").write_text("initial\n", encoding="utf-8")
            (root / "wiki" / "index.md").write_text("# Wiki\n", encoding="utf-8")

            for executable in ("claude", "codex", "pi", "openclaw"):
                fake_executable = bin_dir / executable
                fake_executable.write_text(
                    "#!/usr/bin/env bash\nprintf '%s\\0' "
                    f'"{executable}" "$@" >"$LLM_WIKI_CAPTURE"\n',
                    encoding="utf-8",
                )
                fake_executable.chmod(0o755)

            self.run_git(root, "init", "-b", "main")
            self.run_git(root, "config", "user.email", "llm-wiki-test@example.com")
            self.run_git(root, "config", "user.name", "LLM Wiki Test")
            self.run_git(root, "add", ".")
            self.run_git(root, "commit", "-m", "initial")
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            self.run_git(root, "add", "README.md")
            self.run_git(root, "commit", "-m", "change docs")

            environment = os.environ.copy()
            environment.update(
                {
                    "HOME": str(home),
                    "PATH": f"{bin_dir}:/usr/bin:/bin",
                    "LLM_WIKI_CAPTURE": str(capture),
                }
            )
            result = subprocess.run(
                [str(root / ".llm-wiki" / "post-commit-refresh.sh")],
                cwd=root,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            arguments = []
            if capture.exists():
                arguments = [
                    item.decode()
                    for item in capture.read_bytes().split(b"\0")
                    if item
                ]
            log_path = root / ".git" / "llm-wiki" / "post-commit-refresh.log"
            log = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
            return result, arguments, log

    def initialize_hook_project(self, directory):
        root = Path(directory) / "project"
        home = Path(directory) / "home"
        root.mkdir()
        home.mkdir()
        (root / ".llm-wiki").mkdir()
        (root / "wiki").mkdir()
        shutil.copy2(POST_COMMIT_TEMPLATE, root / ".llm-wiki" / "post-commit-refresh.sh")
        (root / ".llm-wiki" / "post-commit-refresh.sh").chmod(0o755)
        (root / ".llm-wiki" / "config.json").write_text(
            json.dumps(
                {
                    "headless_agent": "codex",
                    "automation_enabled": True,
                    "external_provider_access_approved": True,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "README.md").write_text("initial\n", encoding="utf-8")
        (root / "wiki" / "index.md").write_text("# Wiki\n", encoding="utf-8")
        (root / "wiki" / "log.md").write_text("# Compiled projection\n", encoding="utf-8")
        self.run_git(root, "init", "-b", "main")
        self.run_git(root, "config", "user.email", "llm-wiki-test@example.com")
        self.run_git(root, "config", "user.name", "LLM Wiki Test")
        self.run_git(root, "add", ".")
        self.run_git(root, "commit", "-m", "initial")
        return root

    def git_output(self, root, *arguments):
        result = subprocess.run(
            ["git", *arguments],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        return result.stdout.strip()

    def run_git(self, root, *arguments):
        result = subprocess.run(
            ["git", *arguments],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
