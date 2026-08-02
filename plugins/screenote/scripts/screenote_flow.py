#!/usr/bin/env python3
"""Executable Screenote CLI workflow contract used by offline verification.

Browser capture and interactive user choices remain agent-host responsibilities.
This module owns the deterministic CLI sequence, JSON shape, pagination, and
private-file behavior shared by the canonical Screenote skills.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zlib
from typing import Any, Mapping, Sequence
from urllib.parse import urlsplit


WORKFLOW_CONTRACT_PATH = Path(__file__).resolve().parents[1] / "references" / "workflows.json"


def load_workflow_contract() -> dict[str, Any]:
    contract = json.loads(WORKFLOW_CONTRACT_PATH.read_text(encoding="utf-8"))
    if not isinstance(contract.get("commands"), dict) or not isinstance(contract.get("workflows"), dict):
        raise ValueError("invalid Screenote workflow contract")
    return contract


WORKFLOW_CONTRACT = load_workflow_contract()
MAX_IMAGE_BYTES = 20 * 1024 * 1024
COMMAND_TIMEOUT_SECONDS = 150
CANONICAL_VIEWPORT_WIDTHS = {1280: "desktop", 768: "tablet", 390: "mobile"}
VALID_VIEWPORTS = frozenset(CANONICAL_VIEWPORT_WIDTHS.values())
GIT_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{7,40}$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
JPEG_SOF_MARKERS = frozenset(
    {
        0xC0,
        0xC1,
        0xC2,
        0xC3,
        0xC5,
        0xC6,
        0xC7,
        0xC9,
        0xCA,
        0xCB,
        0xCD,
        0xCE,
        0xCF,
    }
)


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


@dataclass(frozen=True)
class PreparedExistingImage:
    path: Path
    viewport: str
    content_type: str
    width: int
    height: int
    size_bytes: int


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


def classify_result(
    result: subprocess.CompletedProcess[str],
    *,
    interactive: bool = False,
    json_lines: bool = False,
) -> ClassifiedResult:
    stream = result.stdout if result.returncode == 0 else result.stderr
    if result.returncode == 0 and json_lines:
        records: list[dict[str, Any]] = []
        valid_json = True
        for line in stream.splitlines():
            if not line.strip():
                continue
            valid_record, record = _json_payload(line)
            if not valid_record or not isinstance(record, dict):
                valid_json = False
                break
            records.append(record)
        valid_json = valid_json and bool(records)
        payload: Any = records if valid_json else None
    else:
        valid_json, payload = _json_payload(stream)
    if not valid_json:
        expectation = "one JSON object per non-empty line" if json_lines else "one complete JSON value"
        payload = {"code": "invalid_json", "error": f"CLI output was not {expectation}."}
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


def _validate_private_directory(directory: Path, resource_name: str) -> None:
    try:
        directory_status = directory.lstat()
    except OSError as exc:
        raise CaptureSafetyError(f"private {resource_name} directory must be a real directory") from exc
    if not stat.S_ISDIR(directory_status.st_mode):
        raise CaptureSafetyError(f"private {resource_name} directory must be a real directory")
    if stat.S_IMODE(directory_status.st_mode) != 0o700:
        raise CaptureSafetyError(f"private {resource_name} directory must have mode 0700")


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


def create_snapshot_manifest(
    directory: Path,
    *,
    git_commit: str,
    taken_at: str,
    entries: Sequence[Mapping[str, str]],
    name: str = "snapshot.json",
) -> Path:
    _validate_private_directory(directory, "manifest")

    normalized_commit = git_commit.strip().casefold()
    if not GIT_COMMIT_PATTERN.fullmatch(normalized_commit):
        raise CaptureSafetyError("git commit must contain 7-40 hexadecimal characters")
    try:
        parsed_taken_at = datetime.fromisoformat(taken_at.replace("Z", "+00:00"))
    except ValueError as exc:
        raise CaptureSafetyError("capture timestamp must be ISO 8601 with an explicit offset") from exc
    if parsed_taken_at.tzinfo is None or parsed_taken_at.utcoffset() is None:
        raise CaptureSafetyError("capture timestamp must be ISO 8601 with an explicit offset")
    if not 1 <= len(entries) <= 100:
        raise CaptureSafetyError("snapshot manifest must contain 1-100 images")

    normalized_entries: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for entry in entries:
        page = str(entry.get("page", "")).strip()
        title = str(entry.get("title", "")).strip()
        viewport = str(entry.get("viewport", "")).strip().casefold()
        filename = str(entry.get("file", ""))
        if not page or len(page) > 255 or not title or len(title) > 255:
            raise CaptureSafetyError("snapshot page and title must contain 1-255 characters")
        if viewport not in VALID_VIEWPORTS:
            raise CaptureSafetyError("viewport must be desktop, tablet, or mobile")
        if not filename or Path(filename).name != filename or filename in {".", ".."}:
            raise CaptureSafetyError("snapshot image file must be a basename inside the private directory")
        image_path = directory / filename
        try:
            image_status = image_path.lstat()
        except OSError as exc:
            raise CaptureSafetyError("snapshot image must be a real file inside the private directory") from exc
        if not stat.S_ISREG(image_status.st_mode):
            raise CaptureSafetyError("snapshot image must be a real file inside the private directory")
        if stat.S_IMODE(image_status.st_mode) != 0o600:
            raise CaptureSafetyError("snapshot image files must have mode 0600")

        key = (page, title, viewport)
        if key in seen:
            raise CaptureSafetyError("viewport must be unique within each page and title group")
        seen.add(key)
        normalized_entries.append({"page": page, "title": title, "file": filename, "viewport": viewport})

    body = json.dumps(
        {
            "version": 1,
            "git_commit": normalized_commit,
            "taken_at": taken_at,
            "images": normalized_entries,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode()
    return create_private_file(directory, name, body)


def _png_dimensions(content: bytes) -> tuple[int, int]:
    if len(content) < 45 or not content.startswith(PNG_SIGNATURE):
        raise CaptureSafetyError("PNG structure is incomplete or malformed")

    offset = len(PNG_SIGNATURE)
    dimensions: tuple[int, int] | None = None
    idat_bytes = 0
    while offset + 12 <= len(content):
        data_length = int.from_bytes(content[offset : offset + 4], "big")
        chunk_end = offset + 12 + data_length
        if chunk_end > len(content):
            raise CaptureSafetyError("PNG chunk length is invalid")
        chunk_type = content[offset + 4 : offset + 8]
        chunk_data = content[offset + 8 : offset + 8 + data_length]
        expected_crc = int.from_bytes(content[offset + 8 + data_length : chunk_end], "big")
        actual_crc = zlib.crc32(chunk_data, zlib.crc32(chunk_type)) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise CaptureSafetyError("PNG chunk checksum is invalid")

        if dimensions is None:
            if chunk_type != b"IHDR" or data_length != 13:
                raise CaptureSafetyError("PNG must begin with one IHDR chunk")
            width = int.from_bytes(chunk_data[0:4], "big")
            height = int.from_bytes(chunk_data[4:8], "big")
            if width <= 0 or height <= 0:
                raise CaptureSafetyError("image dimensions must be positive")
            dimensions = (width, height)
        elif chunk_type == b"IHDR":
            raise CaptureSafetyError("PNG contains more than one IHDR chunk")
        elif chunk_type == b"IDAT":
            idat_bytes += data_length
        elif chunk_type == b"IEND":
            if data_length != 0 or chunk_end != len(content) or idat_bytes == 0:
                raise CaptureSafetyError("PNG structure is incomplete or malformed")
            return dimensions
        offset = chunk_end

    raise CaptureSafetyError("PNG structure is incomplete or malformed")


def _jpeg_dimensions(content: bytes) -> tuple[int, int]:
    if len(content) < 4 or not content.startswith(b"\xff\xd8") or not content.endswith(b"\xff\xd9"):
        raise CaptureSafetyError("JPEG structure is incomplete or malformed")
    offset = 2
    dimensions: tuple[int, int] | None = None
    saw_scan_data = False
    while offset < len(content) - 1:
        if content[offset] != 0xFF:
            raise CaptureSafetyError("JPEG marker sequence is invalid")
        while offset < len(content) and content[offset] == 0xFF:
            offset += 1
        if offset >= len(content):
            break
        marker = content[offset]
        offset += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(content):
            break
        segment_length = int.from_bytes(content[offset : offset + 2], "big")
        if segment_length < 2 or offset + segment_length > len(content):
            raise CaptureSafetyError("JPEG segment length is invalid")
        if marker in JPEG_SOF_MARKERS:
            if segment_length < 7:
                raise CaptureSafetyError("JPEG dimensions are missing")
            height = int.from_bytes(content[offset + 3 : offset + 5], "big")
            width = int.from_bytes(content[offset + 5 : offset + 7], "big")
            if width <= 0 or height <= 0:
                raise CaptureSafetyError("image dimensions must be positive")
            dimensions = (width, height)
        if marker == 0xDA:
            if dimensions is None:
                raise CaptureSafetyError("JPEG scan appears before image dimensions")
            scan_offset = offset + segment_length
            while scan_offset < len(content) - 1:
                marker_offset = content.find(b"\xff", scan_offset)
                if marker_offset == -1:
                    break
                if marker_offset > scan_offset:
                    saw_scan_data = True
                next_offset = marker_offset + 1
                while next_offset < len(content) and content[next_offset] == 0xFF:
                    next_offset += 1
                if next_offset >= len(content):
                    break
                scan_marker = content[next_offset]
                if scan_marker == 0x00 or 0xD0 <= scan_marker <= 0xD7:
                    saw_scan_data = True
                    scan_offset = next_offset + 1
                    continue
                if scan_marker == 0xD9:
                    if saw_scan_data and next_offset == len(content) - 1:
                        return dimensions
                    raise CaptureSafetyError("JPEG scan data is missing or incomplete")
                offset = marker_offset
                break
            else:
                raise CaptureSafetyError("JPEG end marker is missing")
            if offset != marker_offset:
                break
            continue
        offset += segment_length
    raise CaptureSafetyError("JPEG dimensions are missing")


def _existing_image_metadata(source: Path, content: bytes) -> tuple[str, str, int, int]:
    suffix = source.suffix.casefold()
    if content.startswith(PNG_SIGNATURE):
        if suffix != ".png":
            raise CaptureSafetyError("PNG bytes require a .png source filename")
        width, height = _png_dimensions(content)
        return "image/png", "png", width, height
    if content.startswith(b"\xff\xd8"):
        if suffix not in {".jpg", ".jpeg"}:
            raise CaptureSafetyError("JPEG bytes require a .jpg or .jpeg source filename")
        width, height = _jpeg_dimensions(content)
        return "image/jpeg", "jpg", width, height
    raise CaptureSafetyError("existing image must contain PNG or JPEG bytes")


def _open_existing_image(source: Path) -> int:
    if not all((hasattr(os, "O_DIRECTORY"), hasattr(os, "O_NOFOLLOW"), os.open in os.supports_dir_fd)):
        raise CaptureSafetyError("this platform cannot safely inspect existing-image paths")
    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    directory = os.open("/" if source.is_absolute() else ".", directory_flags)
    try:
        for component in source.parent.parts:
            if component in {"", ".", os.sep}:
                continue
            child = os.open(component, directory_flags, dir_fd=directory)
            os.close(directory)
            directory = child
        if not source.name:
            raise OSError("source has no filename")
        source_flags = os.O_RDONLY | os.O_NOFOLLOW
        if hasattr(os, "O_NONBLOCK"):
            source_flags |= os.O_NONBLOCK
        return os.open(source.name, source_flags, dir_fd=directory)
    except OSError as exc:
        raise CaptureSafetyError("existing image is missing or unreadable") from exc
    finally:
        os.close(directory)


def _read_existing_image(source: Path) -> bytes:
    descriptor = _open_existing_image(source)
    with os.fdopen(descriptor, "rb") as handle:
        before = os.fstat(handle.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise CaptureSafetyError("existing image must be a regular file, not a symlink")
        if before.st_size <= 0 or before.st_size > MAX_IMAGE_BYTES:
            raise CaptureSafetyError("existing image size must be between 1 byte and 20 MB")
        content = handle.read(MAX_IMAGE_BYTES + 1)
        after = os.fstat(handle.fileno())
    if len(content) != before.st_size or len(content) > MAX_IMAGE_BYTES:
        raise CaptureSafetyError("existing image changed while it was being prepared")
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
    ):
        raise CaptureSafetyError("existing image changed while it was being prepared")
    return content


def prepare_existing_image(
    source: Path,
    directory: Path,
    *,
    viewport: str | None = None,
) -> PreparedExistingImage:
    _validate_private_directory(directory, "image")
    if viewport is not None and viewport not in VALID_VIEWPORTS:
        raise CaptureSafetyError("viewport must be desktop, tablet, or mobile")

    content = _read_existing_image(source)
    content_type, extension, width, height = _existing_image_metadata(source, content)
    selected_viewport = viewport or CANONICAL_VIEWPORT_WIDTHS.get(width, "desktop")
    stem = f"existing-{selected_viewport}"
    for index in range(1, 10_001):
        suffix = "" if index == 1 else f"-{index}"
        candidate = directory / f"{stem}{suffix}.{extension}"
        try:
            destination = create_private_file(directory, candidate.name, content)
            break
        except CaptureSafetyError:
            if os.path.lexists(candidate):
                continue
            raise
    else:
        raise CaptureSafetyError("private image directory has no available destination name")
    return PreparedExistingImage(
        path=destination,
        viewport=selected_viewport,
        content_type=content_type,
        width=width,
        height=height,
        size_bytes=len(content),
    )


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
    command_index = _command_index(arguments)
    report.commands.append((arguments[command_index], arguments[command_index + 1]))
    command = " ".join(arguments[command_index : command_index + 2])
    try:
        result = subprocess.run(
            [str(launcher), *arguments],
            text=True,
            capture_output=True,
            env=dict(env),
            check=False,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        payload = {"code": "command_timeout", "error": f"{command} exceeded the bounded execution time."}
        classified = ClassifiedResult(
            False,
            124,
            "command_timeout",
            json.dumps(payload, sort_keys=True, separators=(",", ":")),
            "The Screenote CLI timed out; keep unchanged recovery artifacts and retry only when the runtime is healthy.",
            payload,
        )
        report.outputs.append(classified)
        report.stopped = True
        return classified
    classified = classify_result(
        result,
        interactive=interactive,
        json_lines=WORKFLOW_CONTRACT["commands"].get(command, {}).get("output") == "json_lines",
    )
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

    try:
        contract_process = subprocess.run(
            [str(launcher), "--check-contract"],
            text=True,
            capture_output=True,
            env=dict(env),
            check=False,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        payload = {"code": "command_timeout", "error": "CLI contract verification exceeded the bounded execution time."}
        report.outputs.append(
            ClassifiedResult(
                False,
                124,
                "command_timeout",
                json.dumps(payload, sort_keys=True, separators=(",", ":")),
                "The Screenote CLI timed out before publication; retry only when the runtime is healthy.",
                payload,
            )
        )
        report.stopped = True
        return report
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
        directory = create_private_directory(workspace)
        entries = []
        for index, (page, title) in enumerate(captures):
            for viewport in ("desktop", "tablet", "mobile"):
                filename = f"capture-{index}-{viewport}.png"
                create_private_file(directory, filename)
                entries.append({"page": page, "title": title, "file": filename, "viewport": viewport})
        manifest = create_snapshot_manifest(
            directory,
            git_commit="abc1234",
            taken_at="2026-07-10T10:00:00Z",
            entries=entries,
        )
        result = _run(
            launcher,
            [*globals_, "snapshot", "--manifest", str(manifest), "--wait", "2m"],
            env,
            report,
            interactive=interactive,
        )
        if not result.ok:
            report.recovery_paths.append(str(directory))
            return report
        terminal_event = WORKFLOW_CONTRACT["commands"]["snapshot --manifest"]["terminal_event"]
        if not isinstance(result.payload, list) or result.payload[-1].get("event") != terminal_event:
            _contract_failure(report, "invalid_response", f"snapshot must end with a {terminal_event} JSON Lines event")
            report.recovery_paths.append(str(directory))
            return report
        review_url = result.payload[-1].get("review_url")
        if not isinstance(review_url, str) or not review_url:
            _contract_failure(report, "invalid_response", f"{terminal_event} must contain a review_url")
            report.recovery_paths.append(str(directory))
            return report
        report.review_urls.append(review_url)
        if not retain:
            shutil.rmtree(directory)
        else:
            report.recovery_paths.append(str(directory))
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


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Screenote private-file workflow helper")
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare = subparsers.add_parser(
        "prepare-existing-image",
        help="validate an explicit PNG/JPEG and copy it into a private Screenote directory",
    )
    prepare.add_argument("--source", required=True, type=Path)
    prepare.add_argument("--directory", required=True, type=Path)
    prepare.add_argument("--viewport", choices=sorted(VALID_VIEWPORTS))
    manifest = subparsers.add_parser(
        "prepare-snapshot-manifest",
        help="write a private Screenote snapshot manifest from prepared image files",
    )
    manifest.add_argument("--directory", required=True, type=Path)
    manifest.add_argument("--git-commit", required=True)
    manifest.add_argument("--taken-at", required=True)
    manifest.add_argument(
        "--entry",
        action="append",
        nargs=4,
        required=True,
        metavar=("PAGE", "TITLE", "VIEWPORT", "FILE"),
    )
    arguments = parser.parse_args(argv)

    try:
        if arguments.command == "prepare-existing-image":
            prepared = prepare_existing_image(
                arguments.source,
                arguments.directory,
                viewport=arguments.viewport,
            )
        else:
            manifest_path = create_snapshot_manifest(
                arguments.directory,
                git_commit=arguments.git_commit,
                taken_at=arguments.taken_at,
                entries=[
                    {"page": page, "title": title, "viewport": viewport, "file": filename}
                    for page, title, viewport, filename in arguments.entry
                ],
            )
    except CaptureSafetyError as exc:
        error_code = "unsafe_existing_image" if arguments.command == "prepare-existing-image" else "unsafe_snapshot_manifest"
        print(
            json.dumps({"code": error_code, "error": str(exc)}, separators=(",", ":")),
            file=sys.stderr,
        )
        return 64
    if arguments.command == "prepare-existing-image":
        payload = {
            "path": str(prepared.path),
            "viewport": prepared.viewport,
            "content_type": prepared.content_type,
            "width": prepared.width,
            "height": prepared.height,
            "size_bytes": prepared.size_bytes,
        }
    else:
        payload = {"path": str(manifest_path), "image_count": len(arguments.entry)}
    print(json.dumps(payload, separators=(",", ":")))
    return 0


__all__ = [
    "COMMAND_TIMEOUT_SECONDS",
    "CaptureSafetyError",
    "MAX_IMAGE_BYTES",
    "ClassifiedResult",
    "FlowReport",
    "PreparedExistingImage",
    "ProjectResolutionError",
    "ResponseContractError",
    "WORKFLOW_CONTRACT",
    "WORKFLOW_CONTRACT_PATH",
    "classify_result",
    "create_private_directory",
    "create_private_file",
    "create_snapshot_manifest",
    "find_secret_artifacts",
    "load_workflow_contract",
    "prepare_existing_image",
    "resolve_project",
    "run_flow",
    "validate_http_url",
]


if __name__ == "__main__":
    raise SystemExit(main())
