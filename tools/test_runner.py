#!/usr/bin/env python3
"""Select conservative local test suites and run the required CI stages."""
import argparse
from fnmatch import fnmatchcase
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from time import monotonic

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")
GROUPS = {
    "battle": ("tests/battle",),
    "roster": ("tests/roster", "tests/stats"),
    "items": ("tests/items",),
    "quests": ("tests/quests/test_chains.gd", "tests/quests/test_quests.gd", "tests/daily"),
    "npc": ("tests/quests/test_dialogue.gd",),
    "regions": ("tests/world",),
    "trade": ("tests/world/test_town_services.gd",),
    "server": ("tests/server",),
    "network": ("tests/test_net_config.gd",),
    "social": ("tests/social",),
    "ui": ("tests/world/test_world_map.gd", "tests/world/test_world_scenes.gd"),
    "infra": (),
}
FAST = {
    "battle": "tests/battle/test_battle_sim.gd",
    "roster": "tests/roster/test_squad.gd",
    "items": "tests/items/test_items.gd",
    "quests": "tests/quests/test_quests.gd",
    "npc": "tests/quests/test_dialogue.gd",
    "regions": "tests/world/test_regions.gd",
    "trade": "tests/world/test_town_services.gd",
    "server": "tests/server/test_player_repository.gd",
    "network": "tests/test_net_config.gd",
    "social": "tests/social/test_party_guild.gd",
    "ui": "tests/world/test_world_map.gd",
}
DEPENDENTS = {
    "battle": ("roster", "items", "quests", "social", "ui"),
    "roster": ("battle", "quests"),
    "items": ("trade", "quests", "server"),
    "quests": ("npc", "server", "ui"),
    "npc": ("quests", "regions"),
    "regions": ("quests", "server", "ui"),
    "trade": ("items", "quests", "server", "ui"),
    "server": ("quests",),
}
FULL_PATTERNS = (
    "src/shared/*", "src/client/*", "src/server/server_main.gd*", "addons/*",
    "project.godot", "export_presets.cfg", ".github/*", "tools/smoke_enet*",
    "tools/install_server_sqlite.sh", "tests/test_net_config.gd*",
)
FILE_GROUPS = {
    "tests/battle/*": ("battle",), "tests/roster/*": ("roster",),
    "tests/stats/*": ("roster",), "tests/items/*": ("items",),
    "tests/quests/test_dialogue.gd*": ("npc",), "tests/quests/*": ("quests",),
    "tests/daily/*": ("quests",), "tests/world/test_town_services.gd*": ("trade",),
    "tests/world/*": ("regions",), "tests/server/*": ("server",),
    "tests/social/*": ("social",), "src/server/db/*": ("server",),
    "src/server/south_route_service.gd*": ("server", "regions", "trade"),
    "demo/ui/*": ("ui",), "scenes/ui/*": ("ui",),
    "demo/battle/*": ("battle", "ui"), "scenes/battle/*": ("battle", "ui"),
    "demo/world/*": ("regions", "ui"), "scenes/world/*": ("regions",),
    "data/world.json": ("regions",), "data/chunks.json": ("regions",),
    "data/npcs.json": ("npc",), "data/dialogues.json": ("npc",),
    "data/quests.json": ("quests",), "data/chains.json": ("quests",),
    "data/town_services.json": ("trade",),
    "tools/world_layout.json": ("regions",), "tools/world_gen.gd*": ("regions",),
    "tools/smoke_region_one.gd*": ("ui", "regions", "quests"),
    "docs/*": ("infra",), "*.md": ("infra",), "tools/roadmap.py": ("infra",),
    "tools/test_roadmap.py": ("infra",), "tools/test_runner.py": ("infra",),
    "tools/test_test_runner.py": ("infra",),
}
OFFLINE_MARKERS = (
    "WP-24 PASS: story and recruitment", "Release start PASS", "Quest autorun PASS",
    "Southeast Asia ferry and dunes PASS", "Echo Canyon PASS", "Sand Tomb PASS", "East Arch Market PASS",
    "Lower Docks PASS", "Sluice finale PASS", "Copper Cove PASS", "Convoy progression PASS", "Copper Ridge PASS", "Reed Camp PASS", "Harbor fishing PASS", "Cove fishing PASS",
    "Everheim road PASS", "Resident routines PASS",
)
SMOKE_GROUPS = {"battle", "npc", "regions", "trade", "ui", "quests"}


def select(mode, files, task_groups):
    groups = set(task_groups)
    if mode == "full":
        return "full", set(GROUPS), "явный Full"
    for path in sorted(set(files)):
        if any(fnmatchcase(path, pattern) for pattern in FULL_PATTERNS):
            return "full", set(GROUPS), f"общий, сетевой или конфигурационный файл: {path}"
        match = next((group for pattern, group in FILE_GROUPS.items() if fnmatchcase(path, pattern)), None)
        if match is None:
            return "full", set(GROUPS), f"неизвестное влияние: {path}"
        groups.update(match)
    if not groups or "network" in groups:
        return "full", set(GROUPS), "пустая область либо сетевой профиль"
    if mode == "targeted":
        pending = list(groups)
        while pending:
            extra = set(DEPENDENTS.get(pending.pop(), ())) - groups
            pending.extend(extra)
            groups.update(extra)
    return mode, groups, "выбор по задаче и изменённым путям"


def suites_for(mode, groups):
    if mode == "full":
        return ["tests"]
    candidates = set()
    for group in groups:
        candidates.update((FAST[group],) if mode == "fast" and group in FAST else GROUPS[group])
    return sorted(path for path in candidates if not any(path.startswith(other + "/") for other in candidates))


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def changed_files(base):
    commit = git("rev-parse", "--verify", "--end-of-options", base + "^{commit}").strip()
    return set((
        git("diff", "--no-renames", "--name-only", "-z", commit + "...HEAD")
        + git("diff", "--no-renames", "--name-only", "-z", "HEAD")
        + git("ls-files", "--others", "--exclude-standard", "-z")
    ).split("\0")) - {""}


def task_groups(task_id):
    if not task_id:
        return set()
    registry = json.loads((ROOT / "docs/plan/tasks.json").read_text(encoding="utf-8"))
    tasks = {t["id"]: t for t in registry["tasks"] + registry.get("work_items", [])}
    if task_id not in tasks:
        raise ValueError(f"неизвестная задача: {task_id}")
    task = tasks[task_id]
    return set(task.get("test_groups", tasks.get(task.get("parent"), {}).get("test_groups", [])))


def run(label, args, timeout=180, capture=False):
    start = monotonic()
    try:
        result = subprocess.run(args, cwd=ROOT, timeout=timeout, check=True,
                                text=True, stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.STDOUT if capture else None)
    except subprocess.CalledProcessError as error:
        if error.stdout:
            print(error.stdout, end="", flush=True)
        raise
    finally:
        print(f"{label}: {monotonic() - start:.2f} с", flush=True)
    if capture:
        print(result.stdout, end="", flush=True)
    return result.stdout


def docs():
    run("Python unittest", [sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"])
    run("Реестр и ссылки", [sys.executable, "tools/roadmap.py", "check"])


def game(suites, smoke):
    if suites:
        paths = [arg for path in suites for arg in ("-a", "res://" + path)]
        if not all((ROOT / path).exists() for path in suites):
            raise ValueError("в карте тестов есть отсутствующий путь")
        output = run("gdUnit4", [GODOT, "--headless", "--path", ".", "-s", "-d",
                                "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                                "--ignoreHeadlessMode", *paths], capture=True)
        if not re.search(r"Executed test cases\s*:\s*\([1-9][0-9]*/[1-9][0-9]*\)", output):
            raise ValueError("gdUnit4 не подтвердил запуск тестов")
        if re.search(r"SCRIPT ERROR|Parse Error", output):
            raise ValueError("ошибка GDScript в gdUnit4")
    if smoke:
        output = run("Офлайн smoke", [GODOT, "--headless", "--path", ".", "--script",
                                      "tools/smoke_region_one.gd"], timeout=40, capture=True)
        if any(marker not in output for marker in OFFLINE_MARKERS) or re.search(r"SCRIPT ERROR|Parse Error", output):
            raise ValueError("офлайн smoke не прошёл все контрольные точки")


def network(server):
    with tempfile.TemporaryDirectory(prefix="atlantic-test-") as temp:
        if server is None:
            server = str(Path(temp) / "atlantic-server.x86_64")
            run("Linux export", [GODOT, "--headless", "--path", ".", "--export-release", "Linux Server", server])
        run("ENet smoke", ["sh", "tools/smoke_enet.sh", str(Path(server).resolve())])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("fast", "targeted", "full"))
    parser.add_argument("--task")
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--plan", action="store_true", help="показать набор без запуска")
    parser.add_argument("--stage", choices=("docs", "game", "network"), help="отдельная часть Full для CI")
    parser.add_argument("--server", help="готовый Linux-экспорт для ENet")
    args = parser.parse_args()
    if args.stage and args.mode != "full":
        parser.error("--stage доступен только для Full")
    start = monotonic()
    try:
        files = set()
        if args.mode != "full":
            try:
                files = changed_files(args.base)
            except (OSError, subprocess.CalledProcessError, UnicodeError):
                files = {"<невозможно определить diff>"}
        mode, groups, reason = select(args.mode, files, task_groups(args.task))
        suites = suites_for(mode, groups)
        want_docs = mode == "full" or "infra" in groups
        want_smoke = mode == "full" or (mode == "targeted" and bool(groups & SMOKE_GROUPS))
        want_network = mode == "full" or "network" in groups
        print(f"{mode.upper()}: {reason}; gdUnit4={', '.join(suites) or '—'}; "
              f"docs={want_docs}; offline={want_smoke}; ENet={want_network}", flush=True)
        if args.plan:
            return
        if want_docs and args.stage in (None, "docs"):
            docs()
        if args.stage in (None, "game"):
            game(suites, want_smoke)
        if want_network and args.stage in (None, "network"):
            network(args.server)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"Проверка остановлена: {error}")
    finally:
        print(f"Всего: {monotonic() - start:.2f} с", flush=True)


if __name__ == "__main__":
    main()
