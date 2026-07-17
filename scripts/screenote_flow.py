#!/usr/bin/env python3
"""Deterministic Screenote flow helpers used by offline contract tests."""

from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
from typing import Any, Mapping, Sequence
from urllib.parse import urlsplit


class CaptureSafetyError(ValueError):
    """Raised before an unsafe local capture path can be written or uploaded."""


class ProjectResolutionError(ValueError):
    """Raised when project precedence cannot resolve one accessible project."""


def validate_http_url(value: str) -> str:
    if any(character in value for character in ("\n", "\r", "\x00", ";", "`", "$")):
        raise ValueError("capture URL contains unsafe shell or control characters")
    parsed = urlsplit(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("capture target must be an absolute HTTP(S) URL")
    if parsed.username or parsed.password:
        raise ValueError("capture URL must not contain credentials")
    return value


@dataclass(frozen=True)
class ClassifiedResult:
    ok: bool
    exit_code: int
    error_code: str | None
    diagnostic: str
    guidance: str
    payload: Any


@dataclass
class FlowReport:
    workflow: str
    commands: list[tuple[str, str]] = field(default_factory=list)
    outputs: list[ClassifiedResult] = field(default_factory=list)
    review_urls: list[str] = field(default_factory=list)
    recovery_paths: list[str] = field(default_factory=list)
    stopped: bool = False


def _json_payload(stream: str) -> Any:
    try:
        return json.loads(stream)
    except json.JSONDecodeError:
        return {"error": {"code": "invalid_json", "message": "CLI output was not valid JSON."}}


def classify_result(result: subprocess.CompletedProcess[str], *, interactive: bool = False) -> ClassifiedResult:
    stream = result.stdout if result.returncode == 0 else result.stderr
    payload = _json_payload(stream)
    diagnostic = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    error = payload.get("error", {}) if isinstance(payload, dict) else {}
    error_code = error.get("code") if isinstance(error, dict) else None
    guidance = ""
    if result.returncode == 0:
        return ClassifiedResult(True, 0, None, diagnostic, guidance, payload)
    if result.returncode == 2 and error_code == "missing_token":
        guidance = "Run screenote login separately." if interactive else "Provide SCREENOTE_TOKEN through the environment."
    elif result.returncode == 2 and error_code == "missing_project":
        guidance = "Select an accessible project with --project, SCREENOTE_PROJECT, or CLI config."
    elif result.returncode == 3:
        guidance = "Authentication is invalid, expired, or not authorized; refresh it separately and retry."
    else:
        guidance = "The Screenote CLI stopped the workflow; inspect the preserved JSON diagnostic."
    return ClassifiedResult(False, result.returncode, error_code, diagnostic, guidance, payload)


def resolve_project(
    *,
    explicit: str | None,
    environment: str | None,
    configured: str | None,
    accessible: Sequence[Mapping[str, Any]],
) -> Mapping[str, Any]:
    selected = explicit or environment or configured
    if not selected:
        raise ProjectResolutionError("missing_project")
    matches = [
        project
        for project in accessible
        if str(project.get("id")) == selected or str(project.get("name", "")).casefold() == selected.casefold()
    ]
    if not matches:
        raise ProjectResolutionError("inaccessible_project")
    if len(matches) > 1:
        raise ProjectResolutionError("ambiguous_project")
    return matches[0]


def create_private_directory(parent: Path) -> Path:
    parent.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="screenote-", dir=parent))
    directory.chmod(0o700)
    return directory


def create_private_file(directory: Path, name: str, content: bytes = b"screenote-test-png") -> Path:
    if not name or Path(name).name != name or name in {".", ".."}:
        raise CaptureSafetyError("capture name must be a new basename inside the private directory")
    if stat.S_IMODE(directory.stat().st_mode) != 0o700:
        raise CaptureSafetyError("capture directory must have mode 0700")
    path = directory / name
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags, 0o600)
    except OSError as exc:
        raise CaptureSafetyError("capture destination already exists or is unsafe") from exc
    with os.fdopen(descriptor, "wb") as handle:
        handle.write(content)
    path.chmod(0o600)
    return path


def find_secret_artifacts(root: Path, secrets: Sequence[str]) -> list[str]:
    secret_bytes = [secret.encode() for secret in secrets if secret]
    contaminated: list[str] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        try:
            body = path.read_bytes()
        except OSError:
            continue
        if any(secret in body for secret in secret_bytes):
            contaminated.append(str(path.relative_to(root)))
    return contaminated


def _run(
    launcher: Path,
    arguments: Sequence[str],
    env: Mapping[str, str],
    report: FlowReport,
    *,
    interactive: bool,
) -> ClassifiedResult:
    result = subprocess.run(
        [str(launcher), *arguments],
        text=True,
        capture_output=True,
        env=dict(env),
        check=False,
    )
    command_index = 2 if arguments and arguments[0] in {"--base-url", "--project"} else 0
    if command_index and arguments[0] == "--base-url" and len(arguments) > 2 and arguments[2] == "--project":
        command_index = 4
    report.commands.append((arguments[command_index], arguments[command_index + 1]))
    classified = classify_result(result, interactive=interactive)
    report.outputs.append(classified)
    if not classified.ok:
        report.stopped = True
    return classified


def _items(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, dict):
        return []
    value = payload.get("items", payload.get("data", []))
    return value if isinstance(value, list) else []


def run_flow(
    workflow: str,
    *,
    launcher: Path,
    workspace: Path,
    env: Mapping[str, str],
    project: str | None = None,
    retain: bool = False,
    interactive: bool = False,
) -> FlowReport:
    if workflow not in {"screenote", "snapshot", "feedback"}:
        raise ValueError(f"unknown workflow: {workflow}")
    report = FlowReport(workflow)
    globals_: list[str] = ["--project", project] if project else []

    contract_process = subprocess.run(
        [str(launcher), "--check-contract"],
        text=True,
        capture_output=True,
        env=dict(env),
        check=False,
    )
    contract_result = classify_result(contract_process, interactive=interactive)
    report.outputs.append(contract_result)
    if not contract_result.ok:
        report.stopped = True
        return report

    preflight = _run(launcher, [*globals_, "project", "list"], env, report, interactive=interactive)
    if not preflight.ok:
        return report

    if workflow in {"screenote", "snapshot"}:
        captures = [("login", "Login")]
        if workflow == "snapshot":
            captures.append(("dashboard", "Dashboard"))
        for index, (page, title) in enumerate(captures):
            directory = create_private_directory(workspace)
            capture = create_private_file(directory, f"capture-{index}.png")
            result = _run(
                launcher,
                [*globals_, "screenshot", "create", "--title", title, "--page", page, "--file", str(capture)],
                env,
                report,
                interactive=interactive,
            )
            if not result.ok:
                report.recovery_paths.append(str(capture))
                return report
            if isinstance(result.payload, dict):
                review_url = result.payload.get("review_url") or result.payload.get("url")
                if isinstance(review_url, str):
                    report.review_urls.append(review_url)
            if not retain:
                shutil.rmtree(directory)
            else:
                report.recovery_paths.append(str(capture))
        return report

    page_result = _run(launcher, [*globals_, "page", "list", "--limit", "100", "--offset", "0"], env, report, interactive=interactive)
    if not page_result.ok:
        return report
    page_id = str((_items(page_result.payload) or [{"id": "page-1"}])[0]["id"])
    screenshot_result = _run(
        launcher,
        [*globals_, "screenshot", "list", "--page", page_id, "--limit", "100", "--offset", "0"],
        env,
        report,
        interactive=interactive,
    )
    if not screenshot_result.ok:
        return report
    screenshot_id = str((_items(screenshot_result.payload) or [{"id": "screenshot-1"}])[0]["id"])
    annotations_result = _run(
        launcher,
        [*globals_, "annotation", "list", "--screenshot", screenshot_id, "--limit", "100", "--offset", "0"],
        env,
        report,
        interactive=interactive,
    )
    if not annotations_result.ok:
        return report
    annotation_id = str((_items(annotations_result.payload) or [{"id": "annotation-1"}])[0]["id"])
    crop_directory = create_private_directory(workspace)
    crop_path = crop_directory / "annotation.png"
    detail_result = _run(
        launcher,
        [*globals_, "annotation", "get", "--annotation", annotation_id, "--crop-file", str(crop_path)],
        env,
        report,
        interactive=interactive,
    )
    if not detail_result.ok:
        report.recovery_paths.append(str(crop_path))
        return report
    comment_result = _run(
        launcher,
        [*globals_, "comment", "add", "--annotation", annotation_id, "--body", "Applied and verified the requested fix."],
        env,
        report,
        interactive=interactive,
    )
    if comment_result.ok and not retain:
        shutil.rmtree(crop_directory)
    elif crop_path.exists():
        report.recovery_paths.append(str(crop_path))
    return report
