import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.screenote_flow import (
    CaptureSafetyError,
    ProjectResolutionError,
    create_private_directory,
    create_private_file,
    resolve_project,
    run_flow,
    validate_http_url,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins/screenote"
LAUNCHER = PLUGIN_ROOT / "scripts/screenote-cli.sh"
FIXTURE_ROOT = REPO_ROOT / "tests/fixtures/screenote-cli"
SCENARIOS = FIXTURE_ROOT / "scenarios"
APPROVED = {
    ("project", "list"),
    ("page", "list"),
    ("screenshot", "list"),
    ("screenshot", "create"),
    ("annotation", "list"),
    ("annotation", "get"),
    ("comment", "add"),
}


class ScreenoteCliContractTests(unittest.TestCase):
    def _run(self, arguments):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        binary = root / "screenote"
        binary.write_text(
            "#!/bin/sh\n"
            ": \"${SCREENOTE_MOCK_ARGV:?}\"\n"
            "printf '%s\\n' \"$@\" > \"$SCREENOTE_MOCK_ARGV\"\n"
            "printf '%s\\n' '{\"ok\":true}'\n",
            encoding="utf-8",
        )
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
        argv_path = root / "argv"
        env = {
            **os.environ,
            "PATH": f"{root}:{os.environ.get('PATH', '')}",
            "SCREENOTE_MOCK_ARGV": str(argv_path),
        }
        result = subprocess.run(
            [str(LAUNCHER), *arguments],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
        argv = argv_path.read_text().splitlines() if argv_path.exists() else []
        return result, argv

    def _run_flow(self, scenario, workflow="screenote", **options):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        argv_path = root / "argv.jsonl"
        env = {
            **os.environ,
            "PATH": f"{FIXTURE_ROOT}:{os.environ.get('PATH', '')}",
            "SCREENOTE_MOCK_SCENARIO": str(SCENARIOS / scenario),
            "SCREENOTE_MOCK_ARGV": str(argv_path),
            "SCREENOTE_TOKEN": "test-token-kept-only-in-env",
        }
        report = run_flow(workflow, launcher=LAUNCHER, workspace=root / "captures", env=env, **options)
        records = [json.loads(line) for line in argv_path.read_text().splitlines()] if argv_path.exists() else []
        return root, report, records

    def test_launcher_allows_only_approved_tuples_and_preserves_argv(self):
        hostile = "Fixed user's $(layout); still data"
        for noun, verb in APPROVED:
            with self.subTest(command=f"{noun} {verb}"):
                result, argv = self._run(
                    ["--base-url", "https://screenote.ai", "--project", "project-7", noun, verb, "--body", hostile]
                )
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(
                    ["--base-url", "https://screenote.ai", "--project", "project-7", noun, verb, "--body", hostile],
                    argv,
                )
                self.assertEqual('{"ok":true}\n', result.stdout)

        for command in (("snapshot", "create"), ("project", "create"), ("annotation", "resolve"), ("login", "--device")):
            with self.subTest(rejected=" ".join(command)):
                result, argv = self._run(list(command))
                self.assertNotEqual(0, result.returncode)
                self.assertEqual([], argv)
                self.assertIn("command_not_allowed", result.stderr)

    def test_launcher_rejects_credential_arguments(self):
        for flag in ("--token", "--api-key", "--password"):
            result, argv = self._run(["project", "list", flag, "secret"])
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([], argv)
            self.assertNotIn("secret", result.stderr)

    def test_launcher_detects_missing_and_incompatible_cli_contracts(self):
        compatible, argv = self._run(["--check-contract"])
        self.assertEqual(0, compatible.returncode, compatible.stderr)
        self.assertIn("screenote-cli-pr-37", compatible.stdout)
        self.assertEqual(["comment", "add", "--help"], argv)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            missing = subprocess.run(
                ["/bin/bash", str(LAUNCHER), "--check-contract"],
                text=True,
                capture_output=True,
                env={**os.environ, "PATH": str(root)},
                check=False,
            )
            self.assertEqual(127, missing.returncode)
            self.assertIn("screenote_not_found", missing.stderr)

            incompatible = root / "screenote"
            incompatible.write_text(
                "#!/bin/sh\n"
                "if [ \"$1 $2\" = \"annotation get\" ]; then exit 1; fi\n"
                "exit 0\n",
                encoding="utf-8",
            )
            incompatible.chmod(incompatible.stat().st_mode | stat.S_IXUSR)
            rejected = subprocess.run(
                ["/bin/bash", str(LAUNCHER), "--check-contract"],
                text=True,
                capture_output=True,
                env={**os.environ, "PATH": str(root)},
                check=False,
            )
            self.assertEqual(65, rejected.returncode)
            self.assertIn("screenote_contract_incompatible", rejected.stderr)

    def test_screenote_manifests_and_repository_have_no_mcp_transport(self):
        self.assertFalse((PLUGIN_ROOT / ".mcp.json").exists())
        for manifest in (PLUGIN_ROOT / ".claude-plugin/plugin.json", PLUGIN_ROOT / ".codex-plugin/plugin.json"):
            self.assertNotIn("mcpServers", json.loads(manifest.read_text()))
        forbidden = ("mcpServers", "screenote_browser_use_mcp", "Browser Use MCP", "annotation resolve", "project create")
        scanned = [
            *PLUGIN_ROOT.glob("skills/*/SKILL.md"),
            PLUGIN_ROOT / "references/cli.md",
        ]
        for path in scanned:
            body = path.read_text()
            for phrase in forbidden:
                self.assertNotIn(phrase, body, f"{path}: obsolete {phrase}")

    def test_skills_document_project_errors_and_capture_lifecycle(self):
        combined = "\n".join(path.read_text() for path in PLUGIN_ROOT.glob("skills/*/SKILL.md"))
        for phrase in (
            "--project",
            "SCREENOTE_PROJECT",
            "missing_token",
            "missing_project",
            "exit 2",
            "exit 3",
            "HTTP(S)",
            "mktemp",
            "0700",
            "0600",
            "screenshot create",
            "comment add",
            "Screenote UI",
        ):
            self.assertIn(phrase, combined)
        self.assertIn("screenote feedback", combined)

    def test_success_flows_use_only_approved_command_tuples(self):
        for workflow in ("screenote", "snapshot", "feedback"):
            with self.subTest(workflow=workflow):
                _, report, records = self._run_flow("success.json", workflow)
                self.assertFalse(report.stopped)
                tuples = []
                for record in records:
                    index = 2 if record and record[0] == "--project" else 0
                    tuples.append(tuple(record[index : index + 2]))
                self.assertTrue(set(tuples).issubset(APPROVED))
                workflow_tuples = [command for command, record in zip(tuples, records) if "--help" not in record]
                self.assertEqual(("project", "list"), workflow_tuples[0])
                if workflow == "screenote":
                    self.assertEqual(1, workflow_tuples.count(("screenshot", "create")))
                elif workflow == "snapshot":
                    self.assertEqual(2, workflow_tuples.count(("screenshot", "create")))
                    self.assertNotIn(("snapshot", "create"), workflow_tuples)
                else:
                    self.assertEqual(
                        [
                            ("project", "list"),
                            ("page", "list"),
                            ("screenshot", "list"),
                            ("annotation", "list"),
                            ("annotation", "get"),
                            ("comment", "add"),
                        ],
                        workflow_tuples,
                    )

    def test_error_scenarios_stop_and_preserve_json_codes(self):
        cases = {
            "missing-token.json": (2, "missing_token", "SCREENOTE_TOKEN"),
            "missing-project.json": (2, "missing_project", "--project"),
            "invalid-token.json": (3, "invalid_token", "invalid"),
            "expired-token.json": (3, "expired_token", "expired"),
            "ambiguous-project.json": (5, "ambiguous_project", "stopped"),
            "inaccessible-project.json": (5, "inaccessible_project", "stopped"),
            "not-found.json": (4, "not_found", "stopped"),
            "rate-limited.json": (5, "rate_limited", "stopped"),
            "generic-error.json": (17, "unexpected_failure", "stopped"),
        }
        for scenario, (exit_code, error_code, guidance) in cases.items():
            with self.subTest(scenario=scenario):
                _, report, _ = self._run_flow(scenario)
                self.assertTrue(report.stopped)
                self.assertEqual(2, len(report.outputs))
                self.assertTrue(report.outputs[0].ok)
                result = report.outputs[-1]
                self.assertEqual(exit_code, result.exit_code)
                self.assertEqual(error_code, result.error_code)
                self.assertIn(error_code, result.diagnostic)
                self.assertIn(guidance.casefold(), result.guidance.casefold())

        _, interactive, _ = self._run_flow("missing-token.json", interactive=True)
        self.assertIn("screenote login", interactive.outputs[-1].guidance)

    def test_project_precedence_and_accessibility(self):
        accessible = [
            {"id": "project-explicit", "name": "Explicit"},
            {"id": "project-env", "name": "Environment"},
            {"id": "project-config", "name": "Configured"},
        ]
        self.assertEqual(
            "project-explicit",
            resolve_project(
                explicit="project-explicit", environment="project-env", configured="project-config", accessible=accessible
            )["id"],
        )
        self.assertEqual(
            "project-env",
            resolve_project(explicit=None, environment="Environment", configured="project-config", accessible=accessible)["id"],
        )
        self.assertEqual(
            "project-config",
            resolve_project(explicit=None, environment=None, configured="Configured", accessible=accessible)["id"],
        )
        with self.assertRaisesRegex(ProjectResolutionError, "missing_project"):
            resolve_project(explicit=None, environment=None, configured=None, accessible=accessible)
        with self.assertRaisesRegex(ProjectResolutionError, "inaccessible_project"):
            resolve_project(explicit="unknown", environment=None, configured=None, accessible=accessible)
        with self.assertRaisesRegex(ProjectResolutionError, "ambiguous_project"):
            resolve_project(
                explicit="same",
                environment=None,
                configured=None,
                accessible=[{"id": "1", "name": "same"}, {"id": "2", "name": "Same"}],
            )

    def test_private_capture_cleanup_recovery_and_collisions(self):
        root, report, _ = self._run_flow("success.json")
        self.assertFalse(report.recovery_paths)
        self.assertEqual([], list((root / "captures").glob("screenote-*")))

        _, retained, _ = self._run_flow("success.json", retain=True)
        self.assertEqual(1, len(retained.recovery_paths))
        retained_path = Path(retained.recovery_paths[0])
        self.assertTrue(retained_path.is_file())
        self.assertEqual(0o600, stat.S_IMODE(retained_path.stat().st_mode))
        self.assertEqual(0o700, stat.S_IMODE(retained_path.parent.stat().st_mode))

        _, failed, _ = self._run_flow("upload-failure.json")
        self.assertTrue(failed.stopped)
        failed_path = Path(failed.recovery_paths[0])
        self.assertTrue(failed_path.is_file())
        self.assertEqual(0o600, stat.S_IMODE(failed_path.stat().st_mode))

        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        private = create_private_directory(Path(temporary.name))
        create_private_file(private, "capture.png")
        with self.assertRaises(CaptureSafetyError):
            create_private_file(private, "capture.png")
        with self.assertRaises(CaptureSafetyError):
            create_private_file(private, "../escape.png")
        symlink = private / "linked.png"
        symlink.symlink_to(private / "capture.png")
        with self.assertRaises(CaptureSafetyError):
            create_private_file(private, "linked.png")

    def test_capture_targets_must_be_safe_http_urls(self):
        self.assertEqual("https://example.test/login?q=one", validate_http_url("https://example.test/login?q=one"))
        for unsafe in (
            "file:///etc/passwd",
            "/tmp/capture.png",
            "javascript:alert(1)",
            "https://user:password@example.test/",
            "https://example.test/;touch-pwned",
            "https://example.test/$(unsafe)",
        ):
            with self.subTest(unsafe=unsafe), self.assertRaises(ValueError):
                validate_http_url(unsafe)


if __name__ == "__main__":
    unittest.main()
