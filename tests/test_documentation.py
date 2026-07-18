import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class DocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads(
            (REPO_ROOT / "plugin-surfaces.json").read_text(encoding="utf-8")
        )
        cls.compatibility = (REPO_ROOT / "docs" / "agent-compatibility.md").read_text(
            encoding="utf-8"
        )

    def test_every_plugin_version_and_host_are_documented(self):
        for plugin in self.contract["plugins"]:
            with self.subTest(plugin=plugin["name"]):
                self.assertIn(plugin["metadata"]["display_name"], self.compatibility)
                self.assertIn(f"`{plugin['version']}`", self.compatibility)
                changelog = REPO_ROOT / plugin["path"] / "CHANGELOG.md"
                self.assertTrue(changelog.is_file(), changelog)
                self.assertRegex(
                    changelog.read_text(encoding="utf-8"),
                    rf"(?m)^## \[{re.escape(plugin['version'])}\]",
                )

        for host in ("Claude Code", "Codex", "Pi", "OpenClaw"):
            with self.subTest(host=host):
                self.assertIn(host, self.compatibility)

    def test_screenote_migration_keeps_credentials_out_of_examples(self):
        paths = (
            REPO_ROOT / "docs" / "screenote-cli-migration.md",
            REPO_ROOT / "plugins" / "screenote" / "README.md",
        )
        for path in paths:
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=path):
                self.assertNotRegex(text, r"(?i)(?:--token|token=)[^\s`]+")
                self.assertNotIn("mcpServers", text)
                self.assertNotIn(".mcp.json", text)

    def test_compatibility_resource_paths_exist(self):
        for plugin in self.contract["plugins"]:
            plugin_root = REPO_ROOT / plugin["path"]
            for skill in plugin["canonical"]["skills"]:
                with self.subTest(plugin=plugin["name"], path=skill["path"]):
                    self.assertTrue((plugin_root / skill["path"]).is_file())
            for resource in plugin.get("resources", []):
                resource_path = resource if isinstance(resource, str) else resource["path"]
                with self.subTest(plugin=plugin["name"], path=resource_path):
                    self.assertTrue((plugin_root / resource_path).exists())


if __name__ == "__main__":
    unittest.main()
