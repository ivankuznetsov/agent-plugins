import hashlib
import json
import unittest
from pathlib import Path

from scripts.plugin_surfaces import canonical_semantic_bytes, load_contract


REPO_ROOT = Path(__file__).resolve().parents[1]


class SemanticParityTests(unittest.TestCase):
    def test_lock_covers_every_canonical_skill_and_generated_adapter(self):
        contract = load_contract(REPO_ROOT)
        lock = json.loads((REPO_ROOT / "plugin-surfaces.lock.json").read_text())
        self.assertEqual({plugin["name"] for plugin in contract["plugins"]}, set(lock["plugins"]))
        for plugin in contract["plugins"]:
            package_root = REPO_ROOT / plugin["path"]
            entry = lock["plugins"][plugin["name"]]
            expected_skills = {skill["path"] for skill in plugin["canonical"]["skills"]}
            self.assertEqual(expected_skills, set(entry["canonical"]))
            for skill in plugin["canonical"]["skills"]:
                path = package_root / skill["path"]
                locked = entry["canonical"][skill["path"]]
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), locked["sha256"])
                self.assertEqual(
                    hashlib.sha256(canonical_semantic_bytes(path.read_text())).hexdigest(),
                    locked["semantic_sha256"],
                )
            expected_adapter_count = len(plugin["canonical"]["skills"]) * 2
            self.assertEqual(expected_adapter_count, len(entry["adapters"]))
            for adapter in entry["adapters"].values():
                self.assertIn("invocation", adapter["overlays"])
                self.assertIn("install-path", adapter["overlays"])

    def test_immutable_sections_are_recorded(self):
        lock = json.loads((REPO_ROOT / "plugin-surfaces.lock.json").read_text())
        for plugin in lock["plugins"].values():
            for skill in plugin["canonical"].values():
                self.assertIn("sections", skill)
                self.assertIsInstance(skill["sections"], dict)


if __name__ == "__main__":
    unittest.main()
