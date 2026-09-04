import base64
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.screenote_flow import (
    CaptureSafetyError,
    MAX_IMAGE_BYTES,
    ProjectResolutionError,
    WORKFLOW_CONTRACT,
    create_private_directory,
    create_private_file,
    create_snapshot_manifest,
    prepare_existing_image,
    resolve_project,
    run_flow,
    validate_http_url,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "plugins/screenote"
LAUNCHER = PLUGIN_ROOT / "scripts/screenote-cli.sh"
SHIPPED_FLOW = PLUGIN_ROOT / "scripts/screenote_flow.py"
AGENT_PLATFORMS_WORKFLOW = REPO_ROOT / ".github/workflows/agent-platforms.yml"
FIXTURE_ROOT = REPO_ROOT / "tests/fixtures/screenote-cli"
SCENARIOS = FIXTURE_ROOT / "scenarios"
APPROVED = {tuple(command.split()) for command in WORKFLOW_CONTRACT["commands"]}
PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=="
)
JPEG_1X1 = base64.b64decode(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a"
    "HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIy"
    "MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIA"
    "AhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQA"
    "AAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3"
    "ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWm"
    "p6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEA"
    "AwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSEx"
    "BhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElK"
    "U1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3"
    "uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iii"
    "gD//2Q=="
)


class ScreenoteCliContractTests(unittest.TestCase):
    def test_protected_integration_configures_the_trusted_production_endpoint(self):
        workflow = AGENT_PLATFORMS_WORKFLOW.read_text(encoding="utf-8")
        screenote_job = workflow.split("\n  screenote-live:\n", 1)[1]
        job_configuration = screenote_job.split("\n    steps:\n", 1)[0]

        self.assertIn('SCREENOTE_BASE_URL: "https://screenote.ai"', job_configuration)

    def test_protected_integration_embeds_a_valid_upload_image(self):
        workflow = AGENT_PLATFORMS_WORKFLOW.read_text(encoding="utf-8")
        marker = 'content = base64.b64decode("'
        self.assertEqual(1, workflow.count(marker))
        encoded = workflow.split(marker, 1)[1].split('")', 1)[0]

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "workflow-fixture.png"
            source.write_bytes(base64.b64decode(encoded, validate=True))
            private = create_private_directory(root / "captures")

            prepared = prepare_existing_image(source, private)

        self.assertEqual("image/png", prepared.content_type)
        self.assertEqual((1, 1), (prepared.width, prepared.height))

    def _run(self, arguments):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        binary = root / "screenote"
        binary.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "args = sys.argv[1:]\n"
            "pathlib.Path(os.environ['SCREENOTE_MOCK_ARGV']).write_text('\\n'.join(args) + '\\n')\n"
            "if args == ['--help']:\n"
            "    print('Usage: screenote --base-url URL --project PROJECT --config PATH')\n"
            "elif '--help' in args:\n"
            "    flags = {\n"
            "      'project list': [], 'project create': ['--name'], 'page list': [],\n"
            "      'screenshot list': ['--page', '--status', '--limit', '--offset'],\n"
            "      'screenshot create': ['--title', '--page', '--file'],\n"
            "      'annotation list': ['--screenshot', '--status', '--viewport', '--limit', '--offset'],\n"
            "      'annotation get': ['--annotation', '--crop-file', '--attachments-dir'],\n"
            "      'comment add': ['--annotation', '--body', '--image'],\n"
            "      'snapshot': ['--manifest', '--wait'],\n"
            "    }\n"
            "    command = 'snapshot' if args[0] == 'snapshot' else ' '.join(args[:2])\n"
            "    if command not in flags: raise SystemExit(2)\n"
            "    print('Usage: screenote ' + command + ' ' + ' '.join(flags[command]))\n"
            "else:\n"
            "    print(json.dumps({'ok': True}, separators=(',', ':')))\n",
            encoding="utf-8",
        )
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
        argv_path = root / "argv"
        env = {
            **os.environ,
            "PATH": f"{root}:{os.environ.get('PATH', '')}",
            "SCREENOTE_MOCK_ARGV": str(argv_path),
            "SCREENOTE_BASE_URL": "https://trusted-screenote.example",
            "SCREENOTE_TOKEN": "trusted-token-kept-only-in-env",
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
            if (noun, verb) == ("project", "create"):
                continue
            with self.subTest(command=f"{noun} {verb}"):
                result, argv = self._run(["--project", "project-7", noun, verb, "--body", hostile])
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(
                    ["--project", "project-7", noun, verb, "--body", hostile],
                    argv,
                )
                self.assertEqual('{"ok":true}\n', result.stdout)

        for command in (("snapshot", "create"), ("annotation", "resolve"), ("login", "--device")):
            with self.subTest(rejected=" ".join(command)):
                result, argv = self._run(list(command))
                self.assertNotEqual(0, result.returncode)
                self.assertEqual([], argv)
                self.assertIn("command_not_allowed", result.stderr)

    def test_launcher_allows_explicit_project_creation_only_with_an_exact_name(self):
        result, argv = self._run(["project", "create", "--name", "rabata.io"])
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["project", "create", "--name", "rabata.io"], argv)

        for arguments in (
            ["project", "create"],
            ["project", "create", "--name"],
            ["project", "create", "--name", ""],
            ["--project", "project-7", "project", "create", "--name", "rabata.io"],
        ):
            with self.subTest(arguments=arguments):
                rejected, rejected_argv = self._run(arguments)
                self.assertEqual(64, rejected.returncode)
                self.assertEqual([], rejected_argv)
                self.assertIn("invalid_arguments", rejected.stderr)

    def test_launcher_preserves_an_explicit_image_comment_path_as_one_argument(self):
        image = "/private/review images/verified.png"
        result, argv = self._run(
            [
                "--project",
                "project-7",
                "comment",
                "add",
                "--annotation",
                "31",
                "--body",
                "Verified the requested fix.",
                "--image",
                image,
            ]
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            [
                "--project",
                "project-7",
                "comment",
                "add",
                "--annotation",
                "31",
                "--body",
                "Verified the requested fix.",
                "--image",
                image,
            ],
            argv,
        )

    def test_launcher_rejects_every_runtime_endpoint_or_config_override(self):
        attacks = (
            ["--base-url", "https://attacker.example", "project", "list"],
            ["--base-url=https://attacker.example", "project", "list"],
            ["--config", "/tmp/attacker.toml", "project", "list"],
            ["--config=/tmp/attacker.toml", "project", "list"],
            ["project", "list", "--base-url", "https://attacker.example"],
            ["comment", "add", "--annotation", "31", "--body", "ok", "--config=/tmp/attacker.toml"],
        )
        for arguments in attacks:
            with self.subTest(arguments=arguments):
                result, argv = self._run(arguments)
                self.assertEqual(64, result.returncode)
                self.assertEqual([], argv, "the authenticated CLI must not be invoked")
                self.assertIn("endpoint_argument_forbidden", result.stderr)
                self.assertNotIn("attacker.example", result.stderr)
                self.assertNotIn("attacker.toml", result.stderr)

    def test_launcher_rejects_credential_arguments(self):
        for flag in ("--token", "--api-key", "--password"):
            result, argv = self._run(["project", "list", flag, "secret"])
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([], argv)
            self.assertNotIn("secret", result.stderr)

    def test_launcher_detects_missing_and_incompatible_cli_contracts(self):
        compatible, argv = self._run(["--check-contract"])
        self.assertEqual(0, compatible.returncode, compatible.stderr)
        self.assertIn("screenote-cli-v0.4.0", compatible.stdout)
        self.assertIn("bc45930aae38acc892324a5e80e097a1761fa17b", compatible.stdout)
        self.assertIn('"minimum_release":"0.4.0"', compatible.stdout)
        self.assertEqual(["snapshot", "--help"], argv)

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

            missing_flag = root / "screenote"
            for command, incomplete_flags in (
                ("annotation get", "--annotation --crop-file"),
                ("comment add", "--annotation --body"),
            ):
                with self.subTest(missing_flag=command):
                    missing_flag.write_text(
                        "#!/bin/sh\n"
                        "if [ \"$1\" = \"--help\" ]; then printf '%s\\n' '--base-url --project --config'; exit 0; fi\n"
                        f"if [ \"$1 $2\" = \"{command}\" ]; then printf '%s\\n' '{incomplete_flags}'; exit 0; fi\n"
                        "printf '%s\\n' '--page --status --limit --offset --title --file --screenshot --viewport --annotation --crop-file --attachments-dir --body --image --manifest --wait --name'\n",
                        encoding="utf-8",
                    )
                    missing_flag.chmod(missing_flag.stat().st_mode | stat.S_IXUSR)
                    rejected_flag = subprocess.run(
                        ["/bin/bash", str(LAUNCHER), "--check-contract"],
                        text=True,
                        capture_output=True,
                        env={**os.environ, "PATH": str(root)},
                        check=False,
                    )
                    self.assertEqual(65, rejected_flag.returncode)
                    self.assertIn("screenote_contract_incompatible", rejected_flag.stderr)

    def test_shipped_workflow_contract_is_the_canonical_cli_authority(self):
        self.assertEqual(SHIPPED_FLOW.resolve(), Path(run_flow.__code__.co_filename).resolve())
        contract_path = PLUGIN_ROOT / "references/workflows.json"
        self.assertTrue(contract_path.is_file())
        self.assertEqual(
            ["browser_capture", "existing_image"],
            WORKFLOW_CONTRACT["workflows"]["screenote"]["input_modes"],
        )
        for workflow, specification in WORKFLOW_CONTRACT["workflows"].items():
            skill_path = PLUGIN_ROOT / specification["skill"]
            body = skill_path.read_text(encoding="utf-8")
            self.assertIn("../../references/workflows.json", body)
            for command in specification["ordered_commands"]:
                self.assertIn(command, body, f"{skill_path}: canonical workflow lost {command}")
            for command in specification.get("conditional_commands", []):
                self.assertIn(command, body, f"{skill_path}: conditional workflow lost {command}")

    def test_screenote_manifests_and_repository_have_no_mcp_transport(self):
        self.assertFalse((PLUGIN_ROOT / ".mcp.json").exists())
        for manifest in (PLUGIN_ROOT / ".claude-plugin/plugin.json", PLUGIN_ROOT / ".codex-plugin/plugin.json"):
            self.assertNotIn("mcpServers", json.loads(manifest.read_text()))
        forbidden = ("mcpServers", "screenote_browser_use_mcp", "Browser Use MCP", "annotation resolve")
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
            "snapshot --manifest",
            "comment add",
            "--attachments-dir",
            "--image",
            "comment_result_unknown",
            "image_comments_unsupported",
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
                    if "--help" in record:
                        continue
                    index = 2 if record and record[0] == "--project" else 0
                    tuples.append(tuple(record[index : index + 2]))
                self.assertTrue(set(tuples).issubset(APPROVED))
                workflow_tuples = tuples
                self.assertEqual(("project", "list"), workflow_tuples[0])
                if workflow == "screenote":
                    self.assertEqual(1, workflow_tuples.count(("snapshot", "--manifest")))
                    self.assertNotIn(("screenshot", "create"), workflow_tuples)
                elif workflow == "snapshot":
                    self.assertEqual(1, workflow_tuples.count(("snapshot", "--manifest")))
                    self.assertNotIn(("screenshot", "create"), workflow_tuples)
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

    def test_capture_workflows_publish_viewports_in_one_manifest(self):
        for workflow, expected_pages in (("screenote", 1), ("snapshot", 2)):
            with self.subTest(workflow=workflow):
                _, report, records = self._run_flow("success.json", workflow, retain=True)

                self.assertFalse(report.stopped)
                snapshot_call = next(record for record in records if record[:2] == ["snapshot", "--manifest"])
                self.assertEqual(["--wait", "2m"], snapshot_call[-2:])
                manifest_path = Path(snapshot_call[snapshot_call.index("--manifest") + 1])
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                grouped = {}
                for image in manifest["images"]:
                    grouped.setdefault((image["page"], image["title"]), set()).add(image["viewport"])

                self.assertEqual(expected_pages, len(grouped))
                self.assertTrue(all(viewports == {"desktop", "tablet", "mobile"} for viewports in grouped.values()))
                self.assertEqual(expected_pages * 3, len(manifest["images"]))
                self.assertEqual(["https://screenote.test/projects/7?snapshot_id=41"], report.review_urls)

    def test_snapshot_terminal_contract_failures_preserve_recovery_directory(self):
        for scenario in ("missing-snapshot-terminal.json", "missing-snapshot-review-url.json"):
            with self.subTest(scenario=scenario):
                _, report, _ = self._run_flow(scenario)

                self.assertTrue(report.stopped)
                self.assertEqual("invalid_response", report.outputs[-1].error_code)
                self.assertEqual([], report.review_urls)
                self.assertEqual(1, len(report.recovery_paths))
                self.assertTrue(Path(report.recovery_paths[0]).is_dir())

    def test_snapshot_timeout_preserves_recovery_directory(self):
        with patch.dict(run_flow.__globals__, {"COMMAND_TIMEOUT_SECONDS": 0.5}):
            _, report, _ = self._run_flow("snapshot-timeout.json")

        self.assertTrue(report.stopped)
        self.assertEqual("command_timeout", report.outputs[-1].error_code)
        self.assertEqual(124, report.outputs[-1].exit_code)
        self.assertEqual(1, len(report.recovery_paths))
        self.assertTrue(Path(report.recovery_paths[0]).is_dir())

    def test_invalid_success_json_and_malformed_collections_fail_closed(self):
        for scenario, code in (
            ("invalid-success-json.json", "invalid_json"),
            ("malformed-collection.json", "invalid_response"),
            ("missing-identifier.json", "invalid_response"),
        ):
            with self.subTest(scenario=scenario):
                _, report, _ = self._run_flow(scenario)
                self.assertTrue(report.stopped)
                self.assertEqual(code, report.outputs[-1].error_code)

    def test_pagination_stops_on_empty_page_before_reported_total(self):
        _, report, records = self._run_flow("incomplete-pagination.json", workflow="feedback")
        self.assertTrue(report.stopped)
        self.assertEqual("incomplete_pagination", report.outputs[-1].error_code)
        screenshot_calls = [
            record for record in records if record[:2] == ["screenshot", "list"] and "--help" not in record
        ]
        self.assertEqual(2, len(screenshot_calls))
        self.assertEqual(["--offset", "0"], screenshot_calls[0][-2:])
        self.assertEqual(["--offset", "1"], screenshot_calls[1][-2:])

    def test_feedback_exhausts_pages_and_processes_only_returned_identifiers(self):
        _, report, records = self._run_flow("paginated-success.json", workflow="feedback")
        self.assertFalse(report.stopped)
        command_records = [record for record in records if "--help" not in record]
        screenshot_calls = [record for record in command_records if record[:2] == ["screenshot", "list"]]
        annotation_calls = [record for record in command_records if record[:2] == ["annotation", "list"]]
        detail_calls = [record for record in command_records if record[:2] == ["annotation", "get"]]
        comment_calls = [record for record in command_records if record[:2] == ["comment", "add"]]
        self.assertEqual([["--offset", "0"], ["--offset", "1"]], [call[-2:] for call in screenshot_calls])
        self.assertEqual([["--offset", "0"], ["--offset", "1"]], [call[-2:] for call in annotation_calls])
        self.assertEqual(["31", "32"], [call[call.index("--annotation") + 1] for call in detail_calls])
        self.assertEqual(["31", "32"], [call[call.index("--annotation") + 1] for call in comment_calls])
        for call in detail_calls:
            self.assertIn("--crop-file", call)
            self.assertIn("--attachments-dir", call)
            attachment_directory = Path(call[call.index("--attachments-dir") + 1])
            crop_file = Path(call[call.index("--crop-file") + 1])
            self.assertEqual(crop_file.parent, attachment_directory.parent)
            self.assertEqual("attachments", attachment_directory.name)
        self.assertTrue(all("--image" not in call for call in comment_calls))

    def test_feedback_recovers_attachments_when_the_crop_is_unavailable(self):
        _, report, records = self._run_flow("crop-unavailable.json", workflow="feedback")

        self.assertFalse(report.stopped)
        detail_calls = [record for record in records if record[:2] == ["annotation", "get"] and "--help" not in record]
        self.assertEqual(2, len(detail_calls))
        self.assertIn("--crop-file", detail_calls[0])
        self.assertNotIn("--crop-file", detail_calls[1])
        self.assertIn("--attachments-dir", detail_calls[0])
        self.assertIn("--attachments-dir", detail_calls[1])
        first_directory = detail_calls[0][detail_calls[0].index("--attachments-dir") + 1]
        second_directory = detail_calls[1][detail_calls[1].index("--attachments-dir") + 1]
        self.assertEqual(first_directory, second_directory)
        self.assertEqual(
            1,
            sum(record[:2] == ["comment", "add"] and "--help" not in record for record in records),
        )

    def test_error_scenarios_stop_and_preserve_json_codes(self):
        cases = {
            "missing-token.json": (2, "missing_token", "SCREENOTE_TOKEN"),
            "missing-project.json": (2, "missing_project", "--project"),
            "invalid-token.json": (3, "invalid_token", "invalid"),
            "not-found.json": (4, "not_found", "stopped"),
            "rate-limited.json": (5, "rate_limited", "stopped"),
            "generic-error.json": (1, "unexpected_failure", "stopped"),
        }
        for scenario, (exit_code, error_code, guidance) in cases.items():
            with self.subTest(scenario=scenario):
                _, report, _ = self._run_flow(scenario)
                self.assertTrue(report.stopped)
                expected_outputs = 3 if scenario == "missing-project.json" else 2
                self.assertEqual(expected_outputs, len(report.outputs))
                self.assertTrue(report.outputs[0].ok)
                result = report.outputs[-1]
                self.assertEqual(exit_code, result.exit_code)
                self.assertEqual(error_code, result.error_code)
                self.assertIn(error_code, result.diagnostic)
                self.assertIn(guidance.casefold(), result.guidance.casefold())

        _, interactive, _ = self._run_flow("missing-token.json", interactive=True)
        self.assertIn("screenote --base-url https://screenote.ai login", interactive.outputs[-1].guidance)

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
        self.assertTrue(retained_path.is_dir())
        self.assertEqual(0o700, stat.S_IMODE(retained_path.stat().st_mode))
        self.assertTrue((retained_path / "snapshot.json").is_file())
        self.assertTrue(all(stat.S_IMODE(path.stat().st_mode) == 0o600 for path in retained_path.iterdir()))

        _, failed, _ = self._run_flow("upload-failure.json")
        self.assertTrue(failed.stopped)
        failed_path = Path(failed.recovery_paths[0])
        self.assertTrue(failed_path.is_dir())
        self.assertEqual(0o700, stat.S_IMODE(failed_path.stat().st_mode))
        self.assertTrue((failed_path / "snapshot.json").is_file())

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

    def test_existing_images_are_validated_and_copied_to_private_paths(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        source = root / "shared.png"
        source.write_bytes(PNG_1X1)
        private = create_private_directory(root / "captures")

        prepared = prepare_existing_image(source, private)

        self.assertEqual(private / "existing-desktop.png", prepared.path)
        self.assertEqual("desktop", prepared.viewport)
        self.assertEqual("image/png", prepared.content_type)
        self.assertEqual((1, 1), (prepared.width, prepared.height))
        self.assertEqual(PNG_1X1, prepared.path.read_bytes())
        self.assertEqual(0o600, stat.S_IMODE(prepared.path.stat().st_mode))
        self.assertEqual(PNG_1X1, source.read_bytes(), "the user-owned source must remain unchanged")

        jpeg_source = root / "shared.jpeg"
        jpeg_source.write_bytes(JPEG_1X1)
        jpeg = prepare_existing_image(jpeg_source, private, viewport="tablet")
        self.assertEqual(private / "existing-tablet.jpg", jpeg.path)
        self.assertEqual("image/jpeg", jpeg.content_type)
        self.assertEqual((1, 1), (jpeg.width, jpeg.height))

    def test_existing_image_helper_rejects_unsafe_or_invalid_sources(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        private = create_private_directory(root / "captures")

        valid = root / "valid.png"
        valid.write_bytes(PNG_1X1)
        linked = root / "linked.png"
        linked.symlink_to(valid)
        linked_parent = root / "linked-parent"
        actual_parent = root / "actual-parent"
        actual_parent.mkdir()
        (actual_parent / "nested.png").write_bytes(PNG_1X1)
        linked_parent.symlink_to(actual_parent, target_is_directory=True)
        mismatched = root / "mismatched.jpg"
        mismatched.write_bytes(PNG_1X1)
        malformed = root / "malformed.png"
        malformed.write_bytes(b"not-an-image")
        empty = root / "empty.png"
        empty.touch()
        bad_png_crc = root / "bad-crc.png"
        bad_png_crc.write_bytes(PNG_1X1[:29] + bytes([PNG_1X1[29] ^ 1]) + PNG_1X1[30:])
        header_only_jpeg = root / "header-only.jpg"
        header_only_jpeg.write_bytes(
            b"\xff\xd8\xff\xc0\x00\x11\x08\x00\x01\x00\x01\x03"
            b"\x01\x11\x00\x02\x11\x00\x03\x11\x00\xff\xd9"
        )
        fifo = root / "blocking.png"
        os.mkfifo(fifo)
        oversized = root / "oversized.png"
        with oversized.open("wb") as handle:
            handle.truncate(MAX_IMAGE_BYTES + 1)

        for source in (
            linked,
            linked_parent / "nested.png",
            mismatched,
            malformed,
            empty,
            bad_png_crc,
            header_only_jpeg,
            fifo,
            oversized,
            root / "missing.png",
        ):
            with self.subTest(source=source.name), self.assertRaises(CaptureSafetyError):
                prepare_existing_image(source, private)

        first = prepare_existing_image(valid, private, viewport="mobile")
        second = prepare_existing_image(valid, private, viewport="mobile")
        self.assertEqual(private / "existing-mobile.png", first.path)
        self.assertEqual(private / "existing-mobile-2.png", second.path)
        self.assertEqual(PNG_1X1, first.path.read_bytes())
        self.assertEqual(PNG_1X1, second.path.read_bytes())
        with self.assertRaises(CaptureSafetyError):
            prepare_existing_image(valid, private, viewport="watch")

    def test_existing_image_prepare_command_returns_only_private_metadata(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        source = root / "private-name.png"
        source.write_bytes(PNG_1X1)
        private = create_private_directory(root / "captures")

        result = subprocess.run(
            [
                str(SHIPPED_FLOW),
                "prepare-existing-image",
                "--source",
                str(source),
                "--directory",
                str(private),
                "--viewport",
                "mobile",
            ],
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(0, result.returncode, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(str(private / "existing-mobile.png"), payload["path"])
        self.assertEqual("mobile", payload["viewport"])
        self.assertNotIn(str(source), result.stdout)

        rejected = subprocess.run(
            [
                str(SHIPPED_FLOW),
                "prepare-existing-image",
                "--source",
                str(root / "missing.png"),
                "--directory",
                str(private),
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(64, rejected.returncode)
        self.assertEqual("", rejected.stdout)
        self.assertEqual("unsafe_existing_image", json.loads(rejected.stderr)["code"])
        self.assertNotIn(str(root / "missing.png"), rejected.stderr)

        manifest = create_snapshot_manifest(
            private,
            git_commit="abc1234",
            taken_at="2026-07-10T10:00:00Z",
            entries=[
                {
                    "page": "dashboard",
                    "title": "Existing screenshot",
                    "file": Path(payload["path"]).name,
                    "viewport": payload["viewport"],
                }
            ],
        )
        upload, argv = self._run(
            [
                "--project",
                "project-7",
                "snapshot",
                "--manifest",
                str(manifest),
            ]
        )
        self.assertEqual(0, upload.returncode, upload.stderr)
        self.assertIn(str(manifest), argv)
        self.assertNotIn(str(source), argv)

    def test_snapshot_manifest_helper_preserves_logical_viewport_groups(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        private = create_private_directory(Path(temporary.name))
        for viewport in ("desktop", "tablet", "mobile"):
            create_private_file(private, f"capture-{viewport}.png")

        manifest_path = create_snapshot_manifest(
            private,
            git_commit="abc1234",
            taken_at="2026-07-10T10:00:00Z",
            entries=[
                {
                    "page": "/admin",
                    "title": "Admin users workspace",
                    "file": f"capture-{viewport}.png",
                    "viewport": viewport,
                }
                for viewport in ("desktop", "tablet", "mobile")
            ],
        )

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(0o600, stat.S_IMODE(manifest_path.stat().st_mode))
        self.assertEqual({"/admin"}, {entry["page"] for entry in manifest["images"]})
        self.assertEqual({"Admin users workspace"}, {entry["title"] for entry in manifest["images"]})
        self.assertEqual({"desktop", "tablet", "mobile"}, {entry["viewport"] for entry in manifest["images"]})

        with self.assertRaises(CaptureSafetyError):
            create_snapshot_manifest(
                private,
                git_commit="abc1234",
                taken_at="2026-07-10T10:00:00Z",
                entries=[
                    {"page": "/admin", "title": "Admin", "file": "../escape.png", "viewport": "desktop"}
                ],
                name="other.json",
            )

    def test_snapshot_manifest_helper_rejects_multiple_screens_for_one_page(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        private = create_private_directory(Path(temporary.name))
        create_private_file(private, "task-board.png")
        create_private_file(private, "agent-status.png")

        with self.assertRaisesRegex(CaptureSafetyError, "one logical screen"):
            create_snapshot_manifest(
                private,
                git_commit="abc1234",
                taken_at="2026-07-10T10:00:00Z",
                entries=[
                    {
                        "page": "Hive Web",
                        "title": "Task board",
                        "file": "task-board.png",
                        "viewport": "desktop",
                    },
                    {
                        "page": "hive web",
                        "title": "Agent status",
                        "file": "agent-status.png",
                        "viewport": "desktop",
                    },
                ],
            )

    def test_snapshot_manifest_helper_uses_server_page_case_normalization(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        private = create_private_directory(Path(temporary.name))
        create_private_file(private, "street.png")
        create_private_file(private, "capital-street.png")

        manifest_path = create_snapshot_manifest(
            private,
            git_commit="abc1234",
            taken_at="2026-07-10T10:00:00Z",
            entries=[
                {
                    "page": "Straße",
                    "title": "German street",
                    "file": "street.png",
                    "viewport": "desktop",
                },
                {
                    "page": "STRASSE",
                    "title": "Capital street",
                    "file": "capital-street.png",
                    "viewport": "desktop",
                },
            ],
        )

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(["Straße", "STRASSE"], [entry["page"] for entry in manifest["images"]])

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
