"""Regression checks for the task registry and handoff CLI."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import roadmap


class RoadmapTests(unittest.TestCase):
    def setUp(self):
        self.data = roadmap.load()

    def test_registry_and_links(self):
        self.assertEqual(roadmap.check(self.data), [])
        self.assertEqual(roadmap.check_links(), [])
        self.assertEqual(roadmap.render(self.data, write=False), Path(roadmap.OUT).read_text())

    def test_invalid_and_implicit_dependencies(self):
        invalid = copy.deepcopy(self.data)
        ids = roadmap.by_id(invalid)
        ids["WP-25.1"]["deps"].extend(["WP-25", "NO-SUCH-TASK"])
        invalid["tasks"].append(copy.deepcopy(ids["WP-25.1"]))
        errors = "\n".join(roadmap.check(invalid))
        self.assertIn("цикл", errors)
        self.assertIn("повторяющиеся id", errors)
        self.assertIn("нет зависимости", errors)
        self.assertNotIn("WP-25.1", {t["id"] for t in roadmap.ready(invalid)})

    def pending_pier(self):
        data = copy.deepcopy(self.data)
        data["meta"].pop("last_completed", None)
        ids = roadmap.by_id(data)
        ids["WP-25"]["status"] = "partial"
        ids["WP-25.1"].update(status="todo", log=[])
        ids["WP-25.1"].pop("owner", None)
        return data

    def test_queue_respects_parent_approval_and_coordinated_work(self):
        data = self.pending_pier()
        ids = roadmap.by_id(data)
        ids["WP-72A"]["requires_approval"] = "Тестовое решение"
        ready = {t["id"] for t in roadmap.ready(data)}
        self.assertIn("WP-25.1", ready)
        self.assertNotIn("WP-25", ready)
        self.assertNotIn("WP-32", ready)
        self.assertNotIn("WP-72A.1", ready)
        self.assertTrue(roadmap.approval(data, ids["WP-72A.1"]))

    def test_handoff_and_completion_using_separate_executor(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            tasks = folder / "tasks.json"
            tasks.write_text(json.dumps(self.pending_pier()), encoding="utf-8")

            def run(author, *args):
                script = (
                    "import sys, roadmap;"
                    f"roadmap.TASKS={str(tasks)!r};"
                    f"roadmap.OUT={str(folder / 'ROADMAP.md')!r};"
                    f"roadmap.WHO={author!r};"
                    "sys.argv=['roadmap',*sys.argv[1:]];roadmap.main()"
                )
                return subprocess.run([sys.executable, "-c", script, *args],
                                      cwd=Path(__file__).parent, capture_output=True, text=True)

            tid = "WP-25.1"
            self.assertEqual(run("A", "start", tid).returncode, 0)
            self.assertEqual(run("A", "checkpoint", tid, "--note", "Проверен маршрут",
                                 "--next", "Проверить диалог").returncode, 0)
            self.assertIn("Следующий шаг: Проверить диалог", run("B", "context", tid).stdout)
            self.assertNotEqual(run("B", "start", tid).returncode, 0)
            self.assertEqual(run("B", "start", tid, "--take", "--note", "Передано A").returncode, 0)
            self.assertEqual(run("B", "done", tid, "--note", "Проверено",
                                 "--manual", "Тестовая копия", "--tests", "1").returncode, 0)
            self.assertIn("СДЕЛАНО: Проверено", run("C", "report", tid).stdout)
            self.assertIn("tests: 1", run("C", "report", tid).stdout)
            self.assertIn("### WP-25.1", (folder / "ROADMAP.md").read_text())
