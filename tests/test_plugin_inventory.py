import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

from scripts.plugin_surfaces import validate_repository


REPO_ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = ("claude", "codex", "pi", "openclaw")


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def make_fixture(root):
    plugin_root = root / "plugins" / "demo"
    (plugin_root / "skills" / "demo").mkdir(parents=True)
    (plugin_root / "skills" / "demo" / "SKILL.md").write_text(
        "---\nname: demo\ndescription: Demo skill.\n---\n",
        encoding="utf-8",
    )
    manifest = {"name": "demo", "version": "1.0.0"}
    write_json(plugin_root / ".claude-plugin" / "plugin.json", manifest)
    write_json(plugin_root / ".codex-plugin" / "plugin.json", manifest)

    claude_catalog = {
        "plugins": [{"name": "demo", "source": "./plugins/demo", "version": "1.0.0"}]
    }
    codex_catalog = {
        "plugins": [
            {
                "name": "demo",
                "source": {"source": "local", "path": "./plugins/demo"},
            }
        ]
    }
    write_json(root / ".claude-plugin" / "marketplace.json", claude_catalog)
    write_json(root / ".agents" / "plugins" / "marketplace.json", codex_catalog)

    platform = {
        "support": "supported",
        "state": "declared",
        "tested_host_version": None,
        "minimum_host_version": None,
        "minimum_evidence": "upstream_minimum_unspecified",
        "manifest": None,
        "skill_roots": ["skills"],
        "metadata": {"entrypoint_style": "skill"},
    }
    contract = {
        "$schema": "./schemas/plugin-surfaces.schema.json",
        "contract_version": "1.0.0",
        "compatibility": {
            "platforms": list(PLATFORMS),
            "allowed_overlays": ["commands", "agents", "pi/skills", "openclaw/skills"],
        },
        "plugins": [
            {
                "name": "demo",
                "path": "plugins/demo",
                "version": "1.0.0",
                "stability": "stable",
                "canonical": {
                    "skill_roots": ["skills"],
                    "skills": [{"name": "demo", "path": "skills/demo/SKILL.md"}],
                },
                "legacy_entrypoints": [],
                "resources": [],
                "platforms": {
                    name: deepcopy(platform)
                    for name in PLATFORMS
                },
            }
        ],
    }
    contract["plugins"][0]["platforms"]["claude"]["manifest"] = ".claude-plugin/plugin.json"
    contract["plugins"][0]["platforms"]["codex"]["manifest"] = ".codex-plugin/plugin.json"
    write_json(root / "plugin-surfaces.json", contract)
    return contract


class PluginInventoryTests(unittest.TestCase):
    def test_repository_contract_is_valid(self):
        self.assertEqual([], validate_repository(REPO_ROOT))

    def test_schema_and_contract_are_valid_json(self):
        for relative_path in ("schemas/plugin-surfaces.schema.json", "plugin-surfaces.json"):
            with self.subTest(path=relative_path):
                json.loads((REPO_ROOT / relative_path).read_text(encoding="utf-8"))

    def test_inventory_detects_catalog_only_directory_only_and_catalog_mismatch(self):
        scenarios = {
            "catalog-only": lambda root, contract: self._add_catalog_plugin(root, "ghost"),
            "directory-only": lambda root, contract: (root / "plugins" / "orphan").mkdir(),
            "catalog mismatch": lambda root, contract: self._rename_codex_catalog_plugin(root),
        }
        for expected, mutate in scenarios.items():
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                contract = make_fixture(root)
                mutate(root, contract)
                self.assertTrue(
                    any(expected in error for error in validate_repository(root)),
                    validate_repository(root),
                )

    def test_contract_detects_missing_labels_platforms_and_unapproved_support(self):
        scenarios = {
            "missing stability": lambda contract: contract["plugins"][0].pop("stability"),
            "missing platform": lambda contract: contract["plugins"][0]["platforms"].pop("openclaw"),
            "requires approval": self._make_unsupported_without_approval,
        }
        for expected, mutate in scenarios.items():
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                contract = make_fixture(root)
                mutate(contract)
                write_json(root / "plugin-surfaces.json", contract)
                self.assertTrue(
                    any(expected in error for error in validate_repository(root)),
                    validate_repository(root),
                )

    def test_contract_detects_version_path_mismatches_and_path_escapes(self):
        scenarios = {
            "version mismatch": lambda contract: contract["plugins"][0].update(version="2.0.0"),
            "path mismatch": lambda contract: contract["plugins"][0].update(path="plugins/not-demo"),
            "path escapes": lambda contract: contract["plugins"][0]["canonical"]["skills"][0].update(path="../outside/SKILL.md"),
        }
        for expected, mutate in scenarios.items():
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                contract = make_fixture(root)
                mutate(contract)
                write_json(root / "plugin-surfaces.json", contract)
                self.assertTrue(
                    any(expected in error for error in validate_repository(root)),
                    validate_repository(root),
                )

    @staticmethod
    def _add_catalog_plugin(root, name):
        for path in (
            root / ".claude-plugin" / "marketplace.json",
            root / ".agents" / "plugins" / "marketplace.json",
        ):
            catalog = json.loads(path.read_text(encoding="utf-8"))
            source = f"./plugins/{name}"
            if path.parts[-3:-1] == (".agents", "plugins"):
                source = {"source": "local", "path": source}
            catalog["plugins"].append({"name": name, "source": source, "version": "1.0.0"})
            write_json(path, catalog)

    @staticmethod
    def _rename_codex_catalog_plugin(root):
        path = root / ".agents" / "plugins" / "marketplace.json"
        catalog = json.loads(path.read_text(encoding="utf-8"))
        catalog["plugins"][0]["name"] = "renamed"
        write_json(path, catalog)

    @staticmethod
    def _make_unsupported_without_approval(contract):
        contract["plugins"][0]["platforms"]["pi"]["support"] = "unsupported"


if __name__ == "__main__":
    unittest.main()
