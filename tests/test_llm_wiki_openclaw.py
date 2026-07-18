import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins" / "llm-wiki"
POST_COMMIT_TEMPLATE = PLUGIN_ROOT / "templates" / "post-commit-refresh.sh"


class LlmWikiOpenClawTests(unittest.TestCase):
    def test_canonical_skills_define_openclaw_context_ownership_and_lifecycle(self):
        bootstrap = (PLUGIN_ROOT / "skills" / "bootstrap" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        status = (PLUGIN_ROOT / "skills" / "status" / "SKILL.md").read_text(
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

    def test_generated_openclaw_skills_keep_native_maintenance_behavior(self):
        bootstrap = (
            PLUGIN_ROOT / "openclaw" / "skills" / "wiki-bootstrap" / "SKILL.md"
        ).read_text(encoding="utf-8")
        status = (
            PLUGIN_ROOT / "openclaw" / "skills" / "wiki-status" / "SKILL.md"
        ).read_text(encoding="utf-8")

        self.assertIn("generated-from: skills/bootstrap/SKILL.md", bootstrap)
        self.assertIn("[skills/bootstrap/SKILL.md](../../../skills/bootstrap/SKILL.md)", bootstrap)
        self.assertIn("OpenClaw", bootstrap)
        self.assertIn("generated-from: skills/status/SKILL.md", status)
        self.assertIn("[skills/status/SKILL.md](../../../skills/status/SKILL.md)", status)
        self.assertIn("OpenClaw", status)

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
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], arguments)
        self.assertIn("unsupported headless_agent 'other-agent'", log)

    def test_post_commit_template_requires_explicit_openclaw_agent_id(self):
        result, arguments, log = self.run_template("openclaw", openclaw_agent_id=None)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], arguments)
        self.assertIn("requires openclaw_agent_id", log)

    def test_post_commit_template_rejects_flag_shaped_openclaw_agent_id(self):
        result, arguments, log = self.run_template(
            "openclaw", openclaw_agent_id="--deliver"
        )
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], arguments)
        self.assertIn("invalid openclaw_agent_id", log)

    def run_template(self, headless_agent, openclaw_agent_id="main"):
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
            log_path = root / ".llm-wiki" / "post-commit-refresh.log"
            log = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
            return result, arguments, log

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
