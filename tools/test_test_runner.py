import unittest
from pathlib import Path

import test_runner as runner


class TestSelection(unittest.TestCase):
    def test_fast_task_profile(self):
        mode, groups, _ = runner.select("fast", [], {"quests", "npc"})
        self.assertEqual(mode, "fast")
        self.assertEqual(runner.suites_for(mode, groups),
                         ["tests/quests/test_dialogue.gd", "tests/quests/test_quests.gd"])

    def test_targeted_closes_over_dependents_without_duplicate_suites(self):
        mode, groups, _ = runner.select("targeted", ["data/world.json"], set())
        self.assertEqual(mode, "targeted")
        self.assertTrue({"regions", "quests", "npc", "ui", "server"} <= groups)
        suites = runner.suites_for(mode, groups)
        self.assertIn("tests/world", suites)
        self.assertNotIn("tests/world/test_world_scenes.gd", suites)

    def test_unknown_shared_and_network_force_full_even_in_fast(self):
        for path in ("src/shared/quests/quest_log.gd", "src/server/server_main.gd",
                     "project.godot", "assets/future.bin", ".github/workflows/ci.yml"):
            for requested in ("fast", "targeted"):
                with self.subTest(path=path, requested=requested):
                    mode, groups, _ = runner.select(requested, [path], {"ui"})
                    self.assertEqual(mode, "full")
                    self.assertEqual(runner.suites_for(mode, groups), ["tests"])

    def test_empty_scope_and_network_profile_force_full(self):
        self.assertEqual(runner.select("fast", [], set())[0], "full")
        self.assertEqual(runner.select("targeted", [], {"network"})[0], "full")

    def test_registered_profiles_and_suites_exist(self):
        import json
        registry = json.loads((runner.ROOT / "docs/plan/tasks.json").read_text())
        for task in registry["tasks"] + registry.get("work_items", []):
            self.assertFalse(set(task.get("test_groups", [])) - runner.GROUPS.keys(), task["id"])
        for paths in runner.GROUPS.values():
            for path in paths:
                self.assertTrue(Path(runner.ROOT, path).exists(), path)
