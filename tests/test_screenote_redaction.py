from dataclasses import asdict
import json
import os
from pathlib import Path
import secrets
import stat
import subprocess
import tempfile
import unittest

from scripts.screenote_flow import find_secret_artifacts, run_flow


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins/screenote"
LAUNCHER = PLUGIN_ROOT / "scripts/screenote-cli.sh"
FIXTURE_ROOT = REPO_ROOT / "tests/fixtures/screenote-cli"
SCENARIOS = FIXTURE_ROOT / "scenarios"


class ScreenoteRedactionTests(unittest.TestCase):
    def _environment(self, root: Path, scenario: Path, sentinel: str) -> dict[str, str]:
        return {
            **os.environ,
            "PATH": f"{FIXTURE_ROOT}:{os.environ.get('PATH', '')}",
            "SCREENOTE_MOCK_SCENARIO": str(scenario),
            "SCREENOTE_MOCK_ARGV": str(root / "argv.jsonl"),
            "SCREENOTE_TOKEN": sentinel,
        }

    def test_sentinel_is_absent_from_every_success_and_failure_artifact(self):
        sentinel = "screenote-sentinel-" + secrets.token_urlsafe(37)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for scenario in sorted(SCENARIOS.glob("*.json")):
                case_root = root / scenario.stem
                case_root.mkdir()
                env = self._environment(case_root, scenario, sentinel)
                workflow = "feedback" if scenario.name == "success.json" else "screenote"
                report = run_flow(
                    workflow,
                    launcher=LAUNCHER,
                    workspace=case_root / "captures",
                    env=env,
                    project="project-7",
                )
                (case_root / "report.json").write_text(json.dumps(asdict(report), sort_keys=True), encoding="utf-8")
                cache = case_root / ".cache"
                cache.mkdir()
                (cache / "diagnostics.log").write_text(
                    "\n".join(output.diagnostic for output in report.outputs), encoding="utf-8"
                )

            trace_root = root / "shell-trace"
            trace_root.mkdir()
            trace_env = self._environment(trace_root, SCENARIOS / "success.json", sentinel)
            traced = subprocess.run(
                ["bash", "-x", str(LAUNCHER), "project", "list"],
                text=True,
                capture_output=True,
                env=trace_env,
                check=False,
            )
            self.assertEqual(0, traced.returncode, traced.stderr)
            (trace_root / "stdout.log").write_text(traced.stdout, encoding="utf-8")
            (trace_root / "stderr.log").write_text(traced.stderr, encoding="utf-8")

            self.assertEqual([], find_secret_artifacts(root, [sentinel]))
            self.assertEqual([], find_secret_artifacts(PLUGIN_ROOT / "pi", [sentinel]))
            self.assertEqual([], find_secret_artifacts(PLUGIN_ROOT / "openclaw", [sentinel]))
            self.assertNotIn(sentinel, (REPO_ROOT / "plugin-surfaces.lock.json").read_text())

    def test_scanner_detects_a_leaking_mock_without_reprinting_the_secret(self):
        sentinel = "screenote-sentinel-" + secrets.token_urlsafe(37)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mock = root / "screenote"
            mock.write_text('#!/bin/sh\nprintf "%s\\n" "$SCREENOTE_TOKEN"\n', encoding="utf-8")
            mock.chmod(mock.stat().st_mode | stat.S_IXUSR)
            env = {**os.environ, "PATH": f"{root}:{os.environ.get('PATH', '')}", "SCREENOTE_TOKEN": sentinel}
            result = subprocess.run(
                [str(LAUNCHER), "project", "list"], text=True, capture_output=True, env=env, check=False
            )
            (root / "leaked-output.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            contaminated = find_secret_artifacts(root, [sentinel])
            self.assertEqual(["leaked-output.log"], contaminated)
            self.assertNotIn(sentinel, repr(contaminated))

    def test_active_packages_exclude_retired_transport_and_credential_arguments(self):
        forbidden = (
            "mcpServers",
            "screenote_browser_use_mcp",
            "/mcp/messages",
            "create_multi_viewport_screenshot",
            "annotation resolve",
            "--token ",
        )
        active = [
            *PLUGIN_ROOT.glob("skills/*/SKILL.md"),
            *PLUGIN_ROOT.glob("pi/skills/*/SKILL.md"),
            *PLUGIN_ROOT.glob("openclaw/skills/*/SKILL.md"),
            PLUGIN_ROOT / "references/cli.md",
            PLUGIN_ROOT / ".claude-plugin/plugin.json",
            PLUGIN_ROOT / ".codex-plugin/plugin.json",
            PLUGIN_ROOT / "package.json",
            PLUGIN_ROOT / "openclaw.plugin.json",
        ]
        self.assertFalse((PLUGIN_ROOT / ".mcp.json").exists())
        for path in active:
            body = path.read_text(encoding="utf-8")
            for phrase in forbidden:
                self.assertNotIn(phrase, body, f"{path}: forbidden active text {phrase}")


if __name__ == "__main__":
    unittest.main()
