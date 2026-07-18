import os
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SMOKE_SCRIPT = REPO_ROOT / "scripts" / "smoke-agent-packages.sh"


class NativeSmokeTests(unittest.TestCase):
    def run_missing_claude(self, required):
        environment = os.environ.copy()
        environment["CLAUDE_EXECUTABLE"] = "agent-plugins-test-missing-claude"
        environment["REQUIRE_AGENT_CLI"] = "1" if required else "0"
        return subprocess.run(
            [str(SMOKE_SCRIPT), "claude"],
            cwd=REPO_ROOT,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_missing_host_is_optional_by_default(self):
        result = self.run_missing_claude(required=False)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('"status": "skipped"', result.stdout)

    def test_missing_host_fails_when_agent_cli_is_required(self):
        result = self.run_missing_claude(required=True)
        self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('"status": "skipped"', result.stdout)


if __name__ == "__main__":
    unittest.main()
