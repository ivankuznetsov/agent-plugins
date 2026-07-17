#!/usr/bin/env python3
"""Shared parsing and validation for the repository plugin surface contract."""

from __future__ import annotations

import json
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


PLATFORMS = ("claude", "codex", "pi", "openclaw")
DISTRIBUTION_STATES = {"stable", "experimental", "deprecated", "excluded"}


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _catalog_entries(root: Path, relative_path: str, codex: bool) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    path = root / relative_path
    try:
        payload = load_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [f"{relative_path}: cannot read catalog: {exc}"]

    entries: dict[str, str] = {}
    for index, entry in enumerate(payload.get("plugins", [])):
        label = f"{relative_path}.plugins[{index}]"
        if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
            errors.append(f"{label}: missing plugin name")
            continue
        name = entry["name"]
        raw_source = entry.get("source")
        source = raw_source.get("path") if codex and isinstance(raw_source, dict) else raw_source
        if not isinstance(source, str):
            errors.append(f"{label}: missing source path")
            continue
        if name in entries:
            errors.append(f"{label}: duplicate plugin name {name!r}")
        entries[name] = source
    return entries, errors


def _approval_errors(value: Any, label: str) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}: requires approval with reason, owner, and review_condition"]
    missing = [key for key in ("reason", "owner", "review_condition") if not value.get(key)]
    if missing:
        return [f"{label}: requires approval; missing {', '.join(missing)}"]
    return []


def _relative_path_error(value: Any, label: str) -> str | None:
    if not isinstance(value, str) or not value:
        return f"{label}: path must be a non-empty string"
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts:
        return f"{label}: path escapes the plugin package: {value!r}"
    return None


def _iter_declared_paths(plugin: dict[str, Any]) -> Iterable[tuple[str, str, bool]]:
    canonical = plugin.get("canonical", {})
    for index, skill in enumerate(canonical.get("skills", [])):
        if isinstance(skill, dict):
            yield f"canonical.skills[{index}].path", skill.get("path"), True
    for index, resource in enumerate(plugin.get("resources", [])):
        if isinstance(resource, str):
            yield f"resources[{index}]", resource, True
        elif isinstance(resource, dict):
            yield f"resources[{index}].path", resource.get("path"), bool(resource.get("required", True))
    for platform_name, platform in plugin.get("platforms", {}).items():
        if not isinstance(platform, dict):
            continue
        manifest = platform.get("manifest")
        if manifest:
            # Pi and OpenClaw files are declared by U1 and materialized by U2.
            required = platform_name in {"claude", "codex"}
            yield f"platforms.{platform_name}.manifest", manifest, required
        for index, root in enumerate(platform.get("skill_roots", [])):
            if isinstance(root, str):
                yield f"platforms.{platform_name}.skill_roots[{index}]", root, False


def validate_repository(root: Path) -> list[str]:
    """Return all contract/inventory errors without mutating the checkout."""

    root = root.resolve()
    errors: list[str] = []
    contract_path = root / "plugin-surfaces.json"
    try:
        contract = load_json(contract_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"plugin-surfaces.json: cannot read contract: {exc}"]

    claude, catalog_errors = _catalog_entries(root, ".claude-plugin/marketplace.json", False)
    errors.extend(catalog_errors)
    codex, catalog_errors = _catalog_entries(root, ".agents/plugins/marketplace.json", True)
    errors.extend(catalog_errors)

    plugins_dir = root / "plugins"
    directories = {path.name for path in plugins_dir.iterdir() if path.is_dir()} if plugins_dir.is_dir() else set()
    claude_names = set(claude)
    codex_names = set(codex)
    catalog_union = claude_names | codex_names

    for name in sorted(catalog_union - directories):
        errors.append(f"catalog-only plugin {name!r}: no plugins/{name} directory")
    for name in sorted(directories - catalog_union):
        errors.append(f"directory-only plugin {name!r}: missing marketplace registrations")
    for name in sorted(claude_names ^ codex_names):
        errors.append(f"catalog mismatch for {name!r}: plugin must appear in both root catalogs")

    raw_plugins = contract.get("plugins")
    if not isinstance(raw_plugins, list):
        return errors + ["plugin-surfaces.json.plugins: must be an array"]
    contract_plugins: dict[str, dict[str, Any]] = {}
    for index, plugin in enumerate(raw_plugins):
        label = f"plugins[{index}]"
        if not isinstance(plugin, dict) or not isinstance(plugin.get("name"), str):
            errors.append(f"{label}: missing plugin name")
            continue
        name = plugin["name"]
        if name in contract_plugins:
            errors.append(f"{label}: duplicate plugin name {name!r}")
        contract_plugins[name] = plugin

    contract_names = set(contract_plugins)
    for name in sorted((catalog_union | directories) - contract_names):
        errors.append(f"inventory plugin {name!r}: missing contract entry")
    for name in sorted(contract_names - (catalog_union | directories)):
        errors.append(f"contract-only plugin {name!r}: no catalog or directory entry")

    expected_platforms = set(PLATFORMS)
    declared_global = contract.get("compatibility", {}).get("platforms")
    if declared_global != list(PLATFORMS):
        errors.append(f"compatibility.platforms: expected {list(PLATFORMS)!r}")

    for name, plugin in sorted(contract_plugins.items()):
        label = f"plugins.{name}"
        expected_path = f"plugins/{name}"
        if plugin.get("path") != expected_path:
            errors.append(f"{label}.path: path mismatch; expected {expected_path!r}")

        stability = plugin.get("stability")
        if stability not in DISTRIBUTION_STATES:
            errors.append(f"{label}: missing stability or invalid distribution state")
        if stability in {"deprecated", "excluded"}:
            errors.extend(_approval_errors(plugin.get("approval"), f"{label}.{stability}"))

        platforms = plugin.get("platforms")
        if not isinstance(platforms, dict):
            errors.append(f"{label}.platforms: missing platform declarations")
            platforms = {}
        missing_platforms = expected_platforms - set(platforms)
        extra_platforms = set(platforms) - expected_platforms
        for platform_name in sorted(missing_platforms):
            errors.append(f"{label}.platforms: missing platform {platform_name!r}")
        for platform_name in sorted(extra_platforms):
            errors.append(f"{label}.platforms: unknown platform {platform_name!r}")
        for platform_name, surface in platforms.items():
            surface_label = f"{label}.platforms.{platform_name}"
            if not isinstance(surface, dict):
                errors.append(f"{surface_label}: must be an object")
                continue
            support = surface.get("support")
            if support not in {"supported", "unsupported"}:
                errors.append(f"{surface_label}.support: must be supported or unsupported")
            if support == "unsupported":
                errors.extend(_approval_errors(surface.get("approval"), surface_label))
            minimum = surface.get("minimum_host_version")
            evidence = surface.get("minimum_evidence")
            if minimum is None and evidence != "upstream_minimum_unspecified":
                errors.append(
                    f"{surface_label}: null minimum_host_version requires upstream_minimum_unspecified"
                )

        version = plugin.get("version")
        plugin_root = root / expected_path
        if name in claude:
            source = claude[name]
            if source != f"./{expected_path}":
                errors.append(f"{label}: path mismatch in Claude catalog: {source!r}")
            claude_entry = next(
                (entry for entry in load_json(root / ".claude-plugin/marketplace.json").get("plugins", []) if entry.get("name") == name),
                {},
            )
            if claude_entry.get("version") != version:
                errors.append(f"{label}: version mismatch with Claude catalog")
        if name in codex and codex[name] != f"./{expected_path}":
            errors.append(f"{label}: path mismatch in Codex catalog: {codex[name]!r}")

        for manifest in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json", "package.json"):
            path = plugin_root / manifest
            if not path.is_file():
                continue
            try:
                marker = load_json(path).get("version")
            except (OSError, json.JSONDecodeError) as exc:
                errors.append(f"{label}.{manifest}: invalid JSON: {exc}")
                continue
            if marker is not None and marker != version:
                errors.append(f"{label}: version mismatch with {manifest}")

        for field, value, required in _iter_declared_paths(plugin):
            path_error = _relative_path_error(value, f"{label}.{field}")
            if path_error:
                errors.append(path_error)
                continue
            if required and not (plugin_root / value).exists():
                errors.append(f"{label}.{field}: declared path does not exist: {value!r}")

    return errors


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate_repository(args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Validated plugin inventory and surface contract.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
