import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins/screenote"
LAUNCHER = PLUGIN_ROOT / "scripts/screenote-cli.sh"
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


if __name__ == "__main__":
    unittest.main()
