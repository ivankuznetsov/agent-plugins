#!/usr/bin/env python3
"""Executable Screenote CLI workflow contract used by offline verification.

Browser capture and interactive user choices remain agent-host responsibilities.
This module owns the deterministic CLI sequence, JSON shape, pagination, and
private-file behavior shared by the canonical Screenote skills.
"""

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


WORKFLOW_CONTRACT_PATH = Path(__file__).resolve().parents[1] / "references" / "workflows.json"


def load_workflow_contract() -> dict[str, Any]:
    contract = json.loads(WORKFLOW_CONTRACT_PATH.read_text(encoding="utf-8"))
    if not isinstance(contract.get("commands"), dict) or not isinstance(contract.get("workflows"), dict):
        raise ValueError("invalid Screenote workflow contract")
    return contract


WORKFLOW_CONTRACT = load_workflow_contract()


class CaptureSafetyError(ValueError):
    """Raised before an unsafe local capture path can be written or uploaded."""


class ProjectResolutionError(ValueError):
    """Raised when project precedence cannot resolve one accessible project."""


class ResponseContractError(ValueError):
    """Raised when successful CLI JSON does not match the pinned public shape."""


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


def _json_payload(stream: str) -> tuple[bool, Any]:
    try:
        return True, json.loads(stream)
    except (json.JSONDecodeError, TypeError):
        return False, None


def _error_code(payload: Any) -> str | None:
    if not isinstance(payload, dict):
        return None
    top_level = payload.get("code")
    if isinstance(top_level, str):
        return top_level
    nested = payload.get("error")
    if isinstance(nested, dict) and isinstance(nested.get("code"), str):
        return nested["code"]
    return None


def classify_result(result: subprocess.CompletedProcess[str], *, interactive: bool = False) -> ClassifiedResult:
    stream = result.stdout if result.returncode == 0 else result.stderr
    valid_json, payload = _json_payload(stream)
    if not valid_json:
        payload = {"code": "invalid_json", "error": "CLI output was not one complete JSON value."}
        diagnostic = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return ClassifiedResult(
            False,
            result.returncode,
            "invalid_json",
            diagnostic,
            "The Screenote CLI violated its JSON output contract; stop without assuming success.",
            payload,
        )

    diagnostic = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    error_code = _error_code(payload)
    guidance = ""
    if result.returncode == 0:
        return ClassifiedResult(True, 0, None, diagnostic, guidance, payload)
    if result.returncode == 2 and error_code == "missing_token":
        guidance = "Run screenote --base-url https://screenote.ai login separately." if interactive else "Provide SCREENOTE_TOKEN through the environment."
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


def _command_index(arguments: Sequence[str]) -> int:
    index = 0
    while index < len(arguments) and arguments[index] == "--project":
        index += 2
    return index


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
    command_index = _command_index(arguments)
    report.commands.append((arguments[command_index], arguments[command_index + 1]))
    classified = classify_result(result, interactive=interactive)
    report.outputs.append(classified)
    if not classified.ok:
        report.stopped = True
    return classified


def _contract_failure(report: FlowReport, code: str, message: str) -> None:
    payload = {"code": code, "error": message}
    report.outputs.append(
        ClassifiedResult(
            False,
            65,
            code,
            json.dumps(payload, sort_keys=True, separators=(",", ":")),
            "The Screenote CLI response did not match the pinned public contract; stop without inventing identifiers.",
            payload,
        )
    )
    report.stopped = True


def _collection(payload: Any, key: str) -> list[dict[str, Any]]:
    if not isinstance(payload, dict) or key not in payload or not isinstance(payload[key], list):
        raise ResponseContractError(f"successful response must contain a {key} array")
    items: list[dict[str, Any]] = []
    for item in payload[key]:
        if not isinstance(item, dict) or item.get("id") in {None, ""}:
            raise ResponseContractError(f"every {key} item must contain an id")
        items.append(item)
    return items


def _single_collection(report: FlowReport, result: ClassifiedResult, key: str) -> list[dict[str, Any]] | None:
    if not result.ok:
        return None
    try:
        items = _collection(result.payload, key)
    except ResponseContractError as exc:
        _contract_failure(report, "invalid_response", str(exc))
        return None
    if not items:
        _contract_failure(report, "empty_collection", f"the {key} collection was empty")
        return None
    return items


def _paginated_collection(
    launcher: Path,
    globals_: Sequence[str],
    noun: str,
    verb: str,
    fixed_arguments: Sequence[str],
    env: Mapping[str, str],
    report: FlowReport,
    *,
    interactive: bool,
) -> list[dict[str, Any]] | None:
    command = f"{noun} {verb}"
    spec = WORKFLOW_CONTRACT["commands"][command]
    key = spec["collection"]
    limit = 100
    offset = 0
    collected: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    for _ in range(10_000):
        result = _run(
            launcher,
            [*globals_, noun, verb, *fixed_arguments, "--limit", str(limit), "--offset", str(offset)],
            env,
            report,
            interactive=interactive,
        )
        if not result.ok:
            return None
        try:
            page = _collection(result.payload, key)
            pagination = result.payload.get("pagination") if isinstance(result.payload, dict) else None
            if not isinstance(pagination, dict):
                raise ResponseContractError(f"{command} must contain pagination")
            total = pagination.get("total")
            response_offset = pagination.get("offset")
            response_limit = pagination.get("limit")
            if not isinstance(total, int) or total < 0:
                raise ResponseContractError(f"{command} pagination total must be a non-negative integer")
            if response_offset != offset or not isinstance(response_limit, int) or response_limit <= 0:
                raise ResponseContractError(f"{command} pagination offset/limit did not match the request")
        except ResponseContractError as exc:
            _contract_failure(report, "invalid_response", str(exc))
            return None

        if not page and len(collected) < total:
            _contract_failure(report, "incomplete_pagination", f"{command} returned an empty page before total={total}")
            return None
        for item in page:
            item_id = str(item["id"])
            if item_id in seen_ids:
                _contract_failure(report, "duplicate_identifier", f"{command} repeated id {item_id} across pages")
                return None
            seen_ids.add(item_id)
            collected.append(item)
        if len(collected) > total:
            _contract_failure(report, "invalid_response", f"{command} returned more rows than pagination total")
            return None
        if len(collected) == total:
            return collected
        offset += len(page)

    _contract_failure(report, "pagination_limit_exceeded", f"{command} exceeded the pagination safety bound")
    return None


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
    if workflow not in WORKFLOW_CONTRACT["workflows"]:
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
    if _single_collection(report, preflight, "projects") is None:
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
            if not isinstance(result.payload, dict):
                _contract_failure(report, "invalid_response", "screenshot create must return a JSON object")
                report.recovery_paths.append(str(capture))
                return report
            review_url = result.payload.get("review_url") or result.payload.get("url")
            if isinstance(review_url, str):
                report.review_urls.append(review_url)
            if not retain:
                shutil.rmtree(directory)
            else:
                report.recovery_paths.append(str(capture))
        return report

    page_result = _run(launcher, [*globals_, "page", "list"], env, report, interactive=interactive)
    pages = _single_collection(report, page_result, "pages")
    if pages is None:
        return report
    page_id = str(pages[0]["id"])

    screenshots = _paginated_collection(
        launcher,
        globals_,
        "screenshot",
        "list",
        ["--page", page_id],
        env,
        report,
        interactive=interactive,
    )
    if screenshots is None or not screenshots:
        if screenshots == []:
            _contract_failure(report, "empty_collection", "the screenshots collection was empty")
        return report
    screenshot_id = str(screenshots[0]["id"])

    annotations = _paginated_collection(
        launcher,
        globals_,
        "annotation",
        "list",
        ["--screenshot", screenshot_id],
        env,
        report,
        interactive=interactive,
    )
    if annotations is None:
        return report

    for index, annotation in enumerate(annotations):
        annotation_id = str(annotation["id"])
        crop_directory = create_private_directory(workspace)
        crop_path = crop_directory / f"annotation-{index}.png"
        detail_result = _run(
            launcher,
            [*globals_, "annotation", "get", "--annotation", annotation_id, "--crop-file", str(crop_path)],
            env,
            report,
            interactive=interactive,
        )
        if not detail_result.ok:
            if crop_path.exists():
                report.recovery_paths.append(str(crop_path))
            else:
                shutil.rmtree(crop_directory)
            return report
        comment_result = _run(
            launcher,
            [*globals_, "comment", "add", "--annotation", annotation_id, "--body", "Applied and verified the requested fix."],
            env,
            report,
            interactive=interactive,
        )
        if not comment_result.ok:
            if crop_path.exists():
                report.recovery_paths.append(str(crop_path))
            else:
                shutil.rmtree(crop_directory)
            return report
        if not retain:
            shutil.rmtree(crop_directory)
        elif crop_path.exists():
            report.recovery_paths.append(str(crop_path))
    return report


__all__ = [
    "CaptureSafetyError",
    "ClassifiedResult",
    "FlowReport",
    "ProjectResolutionError",
    "ResponseContractError",
    "WORKFLOW_CONTRACT",
    "WORKFLOW_CONTRACT_PATH",
    "classify_result",
    "create_private_directory",
    "create_private_file",
    "find_secret_artifacts",
    "load_workflow_contract",
    "resolve_project",
    "run_flow",
    "validate_http_url",
]
