#!/usr/bin/env python3
"""Portable schema and skill-frontmatter checks for the Screenote plugin."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlparse


SEMVER_RE = re.compile(
    r"^(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)"
    r"(?:-(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\."
    r"(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
EXPECTED_SKILLS = {"screenote", "snapshot", "feedback"}
EXPECTED_PLUGIN_NAME = "screenote"
EXPECTED_BROWSER_ARGS = [
    "run",
    "--with",
    "browser-use[cli]==0.13.4",
    "--with",
    "mcp==1.26.0",
    "python",
    "-c",
    (
        "import os, runpy; runpy.run_path(os.path.join("
        "os.environ.get('CLAUDE_PLUGIN_ROOT', '.'), 'mcp', "
        "'screenote_browser_use_mcp.py'), run_name='__main__')"
    ),
]

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
VENDORED_REPO_ROOT = PLUGIN_ROOT.parents[1]
if not (VENDORED_REPO_ROOT / ".agents" / "plugins" / "marketplace.json").is_file():
    VENDORED_REPO_ROOT = None
REPO_ROOT = VENDORED_REPO_ROOT or PLUGIN_ROOT
ERRORS: list[str] = []


def fail(label: str, message: str) -> None:
    ERRORS.append(f"{label}: {message}")


def load_json(path: Path) -> Any:
    label = path.relative_to(REPO_ROOT).as_posix()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(label, "file is missing")
    except OSError as error:
        fail(label, f"cannot be read: {error}")
    except json.JSONDecodeError as error:
        fail(label, f"invalid JSON at line {error.lineno}, column {error.colno}")
    return None


def require_object(value: Any, label: str) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        fail(label, "must be an object")
        return None
    return value


def require_string(payload: dict[str, Any], field: str, label: str) -> str | None:
    value = payload.get(field)
    if not isinstance(value, str) or not value.strip():
        fail(label, f"{field} must be a non-empty string")
        return None
    return value


def require_semver(payload: dict[str, Any], label: str) -> str | None:
    version = require_string(payload, "version", label)
    if version is not None and SEMVER_RE.fullmatch(version) is None:
        fail(label, "version must use strict semantic versioning")
    return version


def require_string_list(payload: dict[str, Any], field: str, label: str) -> list[str] | None:
    value = payload.get(field)
    if not isinstance(value, list) or not value or not all(
        isinstance(item, str) and item.strip() for item in value
    ):
        fail(label, f"{field} must be a non-empty array of strings")
        return None
    return value


def reject_unknown(payload: dict[str, Any], allowed: set[str], label: str) -> None:
    for field in sorted(set(payload) - allowed):
        fail(label, f"unsupported field {field!r}")


def validate_https(value: Any, label: str) -> None:
    if value is None:
        return
    if not isinstance(value, str):
        fail(label, "must be an HTTPS URL")
        return
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc:
        fail(label, "must be an absolute HTTPS URL")


def resolve_local_path(base: Path, raw: Any, label: str, *, directory: bool) -> Path | None:
    if not isinstance(raw, str) or not raw.startswith("./"):
        fail(label, "must be a ./-relative path")
        return None
    posix_path = PurePosixPath(raw)
    if posix_path.is_absolute() or ".." in posix_path.parts:
        fail(label, "must stay within its owning directory")
        return None
    resolved = (base / Path(*posix_path.parts)).resolve()
    try:
        resolved.relative_to(base.resolve())
    except ValueError:
        fail(label, "resolves outside its owning directory")
        return None
    exists = resolved.is_dir() if directory else resolved.is_file()
    if not exists:
        kind = "directory" if directory else "file"
        fail(label, f"does not point to an existing {kind}")
        return None
    return resolved


def validate_author(payload: dict[str, Any], label: str) -> None:
    author = require_object(payload.get("author"), f"{label}.author")
    if author is None:
        return
    reject_unknown(author, {"name", "email", "url"}, f"{label}.author")
    require_string(author, "name", f"{label}.author")
    if "email" in author and (
        not isinstance(author["email"], str) or not author["email"].strip()
    ):
        fail(f"{label}.author", "email must be a non-empty string")
    validate_https(author.get("url"), f"{label}.author.url")


def validate_manifest_common(payload: dict[str, Any], label: str) -> tuple[str | None, str | None]:
    name = require_string(payload, "name", label)
    version = require_semver(payload, label)
    require_string(payload, "description", label)
    validate_author(payload, label)
    require_string(payload, "license", label)
    repository = require_string(payload, "repository", label)
    validate_https(repository, f"{label}.repository")
    validate_https(payload.get("homepage"), f"{label}.homepage")
    require_string_list(payload, "keywords", label)
    if "[TODO:" in json.dumps(payload):
        fail(label, "contains a TODO placeholder")
    return name, version


def validate_codex_manifest() -> tuple[str | None, str | None]:
    path = PLUGIN_ROOT / ".codex-plugin" / "plugin.json"
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = require_object(load_json(path), label)
    if payload is None:
        return None, None

    reject_unknown(
        payload,
        {
            "id",
            "name",
            "version",
            "description",
            "author",
            "homepage",
            "repository",
            "license",
            "keywords",
            "skills",
            "apps",
            "mcpServers",
            "interface",
        },
        label,
    )
    name, version = validate_manifest_common(payload, label)
    if name is not None and name != EXPECTED_PLUGIN_NAME:
        fail(label, f"name must be {EXPECTED_PLUGIN_NAME!r}")
    if payload.get("skills") != "./skills/":
        fail(label, "skills must be ./skills/")
    else:
        resolve_local_path(PLUGIN_ROOT, payload["skills"], f"{label}.skills", directory=True)
    if "apps" in payload:
        fail(label, "apps must be absent")
    if payload.get("mcpServers") != "./.mcp.json":
        fail(label, "mcpServers must point to ./.mcp.json")
    else:
        resolve_local_path(
            PLUGIN_ROOT,
            payload["mcpServers"],
            f"{label}.mcpServers",
            directory=False,
        )

    interface = require_object(payload.get("interface"), f"{label}.interface")
    if interface is None:
        return name, version
    reject_unknown(
        interface,
        {
            "displayName",
            "shortDescription",
            "longDescription",
            "developerName",
            "category",
            "capabilities",
            "websiteURL",
            "privacyPolicyURL",
            "termsOfServiceURL",
            "brandColor",
            "composerIcon",
            "logo",
            "logoDark",
            "screenshots",
            "defaultPrompt",
            "default_prompt",
        },
        f"{label}.interface",
    )
    for field in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
        require_string(interface, field, f"{label}.interface")
    require_string_list(interface, "capabilities", f"{label}.interface")
    prompts = interface.get("defaultPrompt", interface.get("default_prompt"))
    if not isinstance(prompts, list) or not 1 <= len(prompts) <= 3 or not all(
        isinstance(prompt, str) and prompt.strip() and len(prompt) <= 128 for prompt in prompts
    ):
        fail(f"{label}.interface", "defaultPrompt must contain 1-3 non-empty strings of at most 128 characters")
    for field in ("websiteURL", "privacyPolicyURL", "termsOfServiceURL"):
        validate_https(interface.get(field), f"{label}.interface.{field}")
    screenshots = interface.get("screenshots", [])
    if not isinstance(screenshots, list):
        fail(f"{label}.interface", "screenshots must be an array")
    else:
        for index, screenshot in enumerate(screenshots):
            resolve_local_path(
                PLUGIN_ROOT,
                screenshot,
                f"{label}.interface.screenshots[{index}]",
                directory=False,
            )
    return name, version


def validate_claude_manifest(expected_name: str | None, expected_version: str | None) -> None:
    path = PLUGIN_ROOT / ".claude-plugin" / "plugin.json"
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = require_object(load_json(path), label)
    if payload is None:
        return
    reject_unknown(
        payload,
        {
            "name",
            "version",
            "description",
            "author",
            "homepage",
            "repository",
            "license",
            "keywords",
            "skills",
            "commands",
            "agents",
            "hooks",
            "mcpServers",
        },
        label,
    )
    name, version = validate_manifest_common(payload, label)
    if name != expected_name:
        fail(label, "name must match the Codex manifest")
    if version != expected_version:
        fail(label, "version must match the Codex manifest")
    for legacy_field in ("mcpServers", "apps"):
        if legacy_field in payload:
            fail(label, f"{legacy_field} must be absent; Claude discovers the root capture config")


def validate_mcp_config() -> None:
    path = PLUGIN_ROOT / ".mcp.json"
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = require_object(load_json(path), label)
    if payload is None:
        return
    reject_unknown(payload, {"mcpServers"}, label)
    servers = require_object(payload.get("mcpServers"), f"{label}.mcpServers")
    if servers is None:
        return
    if set(servers) != {"browser-use"}:
        fail(f"{label}.mcpServers", "must contain exactly the browser-use capture server")
        return

    browser = require_object(servers.get("browser-use"), f"{label}.mcpServers.browser-use")
    if browser is None:
        return
    reject_unknown(
        browser,
        {"type", "command", "args", "cwd", "env"},
        f"{label}.mcpServers.browser-use",
    )
    if browser.get("type") != "stdio":
        fail(f"{label}.mcpServers.browser-use", "type must be stdio")
    if browser.get("command") != "uv":
        fail(f"{label}.mcpServers.browser-use", "command must be uv")
    if browser.get("cwd") != ".":
        fail(f"{label}.mcpServers.browser-use", "cwd must be the plugin root")
    if browser.get("args") != EXPECTED_BROWSER_ARGS:
        fail(
            f"{label}.mcpServers.browser-use",
            "args must use the exact pinned Browser Use adapter launch",
        )
    if browser.get("env") != {"BROWSER_USE_HEADLESS": "false"}:
        fail(
            f"{label}.mcpServers.browser-use",
            "env must default Browser Use to a visible ephemeral browser",
        )

    for relative in (
        "mcp/screenote_browser_use_mcp.py",
        "evals/browser-use-mcp-smoke.sh",
        "evals/browser-use-mcp-surface.md",
    ):
        asset = PLUGIN_ROOT / relative
        if not asset.is_file():
            fail(label, f"required Browser Use asset is missing: {relative}")


def validate_codex_marketplace() -> None:
    path = REPO_ROOT / ".agents" / "plugins" / "marketplace.json"
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = require_object(load_json(path), label)
    if payload is None:
        return
    reject_unknown(payload, {"name", "interface", "plugins"}, label)
    require_string(payload, "name", label)
    interface = require_object(payload.get("interface"), f"{label}.interface")
    if interface is not None:
        reject_unknown(interface, {"displayName"}, f"{label}.interface")
        require_string(interface, "displayName", f"{label}.interface")
    plugins = payload.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        fail(label, "plugins must be a non-empty array")
        return
    screenote_entries = []
    for index, raw_entry in enumerate(plugins):
        entry_label = f"{label}.plugins[{index}]"
        entry = require_object(raw_entry, entry_label)
        if entry is None:
            continue
        reject_unknown(entry, {"name", "source", "policy", "category"}, entry_label)
        name = require_string(entry, "name", entry_label)
        source = require_object(entry.get("source"), f"{entry_label}.source")
        if source is not None:
            reject_unknown(source, {"source", "path"}, f"{entry_label}.source")
            if source.get("source") != "local":
                fail(f"{entry_label}.source", "source must be local")
            resolve_local_path(REPO_ROOT, source.get("path"), f"{entry_label}.source.path", directory=True)
            if name is not None and source.get("path") != f"./plugins/{name}":
                fail(f"{entry_label}.source", "path must match the plugin name")
        policy = require_object(entry.get("policy"), f"{entry_label}.policy")
        if policy is not None:
            reject_unknown(policy, {"installation", "authentication", "products"}, f"{entry_label}.policy")
            if policy.get("installation") not in {"NOT_AVAILABLE", "AVAILABLE", "INSTALLED_BY_DEFAULT"}:
                fail(f"{entry_label}.policy", "installation has an unsupported value")
            if policy.get("authentication") not in {"ON_INSTALL", "ON_USE"}:
                fail(f"{entry_label}.policy", "authentication has an unsupported value")
            if "products" in policy:
                require_string_list(policy, "products", f"{entry_label}.policy")
        require_string(entry, "category", entry_label)
        if name == "screenote":
            screenote_entries.append(entry)
    if len(screenote_entries) != 1:
        fail(label, "must contain exactly one Screenote entry")
    elif screenote_entries[0].get("source", {}).get("path") != "./plugins/screenote":
        fail(label, "Screenote source must be ./plugins/screenote")


def validate_claude_marketplace(path: Path, base: Path, expected_source: str, expected_version: str | None) -> None:
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = require_object(load_json(path), label)
    if payload is None:
        return
    reject_unknown(payload, {"name", "owner", "metadata", "plugins"}, label)
    require_string(payload, "name", label)
    owner = require_object(payload.get("owner"), f"{label}.owner")
    if owner is not None:
        reject_unknown(owner, {"name", "email", "url"}, f"{label}.owner")
        require_string(owner, "name", f"{label}.owner")
        validate_https(owner.get("url"), f"{label}.owner.url")
    metadata = require_object(payload.get("metadata"), f"{label}.metadata")
    if metadata is not None:
        reject_unknown(metadata, {"description", "version"}, f"{label}.metadata")
        require_string(metadata, "description", f"{label}.metadata")
        require_semver(metadata, f"{label}.metadata")
    plugins = payload.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        fail(label, "plugins must be a non-empty array")
        return
    screenote_entries = []
    for index, raw_entry in enumerate(plugins):
        entry_label = f"{label}.plugins[{index}]"
        entry = require_object(raw_entry, entry_label)
        if entry is None:
            continue
        reject_unknown(
            entry,
            {
                "name",
                "source",
                "description",
                "version",
                "author",
                "homepage",
                "repository",
                "license",
                "keywords",
                "category",
                "tags",
            },
            entry_label,
        )
        name = require_string(entry, "name", entry_label)
        source = require_string(entry, "source", entry_label)
        if source is not None:
            resolve_local_path(base, source, f"{entry_label}.source", directory=True)
        require_string(entry, "description", entry_label)
        require_semver(entry, entry_label)
        validate_author(entry, entry_label)
        if name == "screenote":
            screenote_entries.append(entry)
    if len(screenote_entries) != 1:
        fail(label, "must contain exactly one Screenote entry")
        return
    screenote = screenote_entries[0]
    if screenote.get("source") != expected_source:
        fail(label, f"Screenote source must be {expected_source}")
    if screenote.get("version") != expected_version:
        fail(label, "Screenote version must match both plugin manifests")


def parse_frontmatter(path: Path) -> dict[str, Any] | None:
    label = path.relative_to(REPO_ROOT).as_posix()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        fail(label, f"cannot be read: {error}")
        return None
    if not lines or lines[0] != "---":
        fail(label, "must start with YAML frontmatter")
        return None
    try:
        closing = lines.index("---", 1)
    except ValueError:
        fail(label, "frontmatter is not closed")
        return None
    if not any(line.strip() for line in lines[closing + 1 :]):
        fail(label, "skill body must not be empty")

    parsed: dict[str, Any] = {}
    parent: str | None = None
    for line_number, line in enumerate(lines[1:closing], start=2):
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        content = line.strip()
        if ":" not in content:
            fail(label, f"frontmatter line {line_number} must contain a key/value pair")
            continue
        key, raw_value = content.split(":", 1)
        value = raw_value.strip()
        if indent == 0:
            if key in parsed:
                fail(label, f"duplicate frontmatter key {key!r}")
            parsed[key] = {} if not value else value.strip('"\'')
            parent = key if not value else None
        elif indent == 2 and parent is not None and isinstance(parsed.get(parent), dict):
            nested = parsed[parent]
            if key in nested:
                fail(label, f"duplicate frontmatter key {parent}.{key}")
            nested[key] = value.strip('"\'')
        else:
            fail(label, f"unsupported indentation on frontmatter line {line_number}")
    return parsed


def validate_skills() -> None:
    skills_root = PLUGIN_ROOT / "skills"
    if (PLUGIN_ROOT / "codex-skills").exists():
        fail("plugins/screenote/codex-skills", "obsolete skill mirrors must be removed")
    actual_skills = {path.name for path in skills_root.iterdir() if path.is_dir()}
    if actual_skills != EXPECTED_SKILLS:
        fail("plugins/screenote/skills", f"expected exactly {sorted(EXPECTED_SKILLS)}, found {sorted(actual_skills)}")
    for skill_name in sorted(EXPECTED_SKILLS):
        path = skills_root / skill_name / "SKILL.md"
        frontmatter = parse_frontmatter(path)
        if frontmatter is None:
            continue
        unknown = set(frontmatter) - {"name", "description", "metadata"}
        if unknown:
            fail(path.relative_to(REPO_ROOT).as_posix(), f"unknown frontmatter keys: {sorted(unknown)}")
        name = frontmatter.get("name")
        if name != skill_name or not isinstance(name, str) or SKILL_NAME_RE.fullmatch(name) is None:
            fail(path.relative_to(REPO_ROOT).as_posix(), "name must match its lowercase hyphen-case directory")
        description = frontmatter.get("description")
        if not isinstance(description, str) or not description.strip() or len(description) > 1024:
            fail(path.relative_to(REPO_ROOT).as_posix(), "description must contain 1-1024 characters")
        metadata = frontmatter.get("metadata")
        if not isinstance(metadata, dict) or not isinstance(metadata.get("argument"), str) or not metadata["argument"].strip():
            fail(path.relative_to(REPO_ROOT).as_posix(), "metadata.argument must be a non-empty string")


def validate_trigger_dataset() -> None:
    path = PLUGIN_ROOT / "evals" / "trigger-eval-set.json"
    label = path.relative_to(REPO_ROOT).as_posix()
    payload = load_json(path)
    if not isinstance(payload, list) or not payload:
        fail(label, "must be a non-empty array")
        return
    queries: set[str] = set()
    seen_triggers: set[str | None] = set()
    for index, item in enumerate(payload):
        item_label = f"{label}[{index}]"
        if not isinstance(item, dict) or set(item) != {"query", "should_trigger"}:
            fail(item_label, "must contain exactly query and should_trigger")
            continue
        query = item.get("query")
        trigger = item.get("should_trigger")
        if not isinstance(query, str) or not query.strip():
            fail(item_label, "query must be a non-empty string")
        elif query in queries:
            fail(item_label, "query must be unique")
        else:
            queries.add(query)
        if trigger not in EXPECTED_SKILLS | {None}:
            fail(item_label, "should_trigger must name a Screenote skill or be null")
        seen_triggers.add(trigger)
    expected_triggers: set[str | None] = EXPECTED_SKILLS | {None}
    if seen_triggers != expected_triggers:
        fail(label, "must exercise every skill and a non-triggering query")


def main() -> int:
    name, version = validate_codex_manifest()
    validate_claude_manifest(name, version)
    validate_mcp_config()
    if VENDORED_REPO_ROOT is not None:
        validate_codex_marketplace()
        validate_claude_marketplace(
            REPO_ROOT / ".claude-plugin" / "marketplace.json",
            REPO_ROOT,
            "./plugins/screenote",
            version,
        )
    validate_claude_marketplace(
        PLUGIN_ROOT / ".claude-plugin" / "marketplace.json",
        PLUGIN_ROOT,
        "./",
        version,
    )
    validate_skills()
    validate_trigger_dataset()

    if ERRORS:
        print("Portable Screenote plugin validation failed:", file=sys.stderr)
        for error in ERRORS:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Portable Screenote plugin schema and frontmatter validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
