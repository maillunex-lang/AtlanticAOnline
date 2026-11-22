#!/usr/bin/env python3
"""Summarize verified quest references for regional world production."""

import csv
import json
from collections import defaultdict
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "docs/plan"
STORY_REGIONS = {
    "Forest_of_Spirits": ("main_01", "northeast_asia"),
    "Ruins_of_the_Yellow_River": ("main_02", "northeast_asia"),
    "Sea_Palace": ("main_03", "northeast_asia"),
    "Angkor_Wat": ("main_04", "southeast_asia_india"),
    "Nest_of_Insects": ("main_05", "southeast_asia_india"),
    "Mohenjodaro": ("main_06", "southeast_asia_india"),
    "Bran_Castle": ("main_07", "south_america"),
    "Cretan_Labyrinth": ("main_08", "southern_europe"),
    "Hanging_Gardens": ("main_09", "southwest_asia"),
    "Valley_of_the_Kings": ("main_10", "southwest_asia"),
    "Sunken_Machine_Shrine": ("main_11", "north_america"),
    "Shogun_Castle_of_Death": ("main_12", "northeast_asia"),
    "Key": ("main_13", ""),
    "Lost_Volcano_Valley": ("main_14", "northern_europe"),
    "Yggdrasil": ("main_15", "northern_europe"),
    "Constantinople_Battlefield": ("main_16", ""),
    "Katherine_at_Katherine_Gorge": ("main_17", "australia"),
}
OTHER_REGIONS = {
    "Beginner_Tutorial_(Scion)": "northeast_asia",
    "The_Yellow_River": "northeast_asia",
    "Ocean_Abyss": "northeast_asia",
}


def article_name(url):
    return unquote(urlsplit(url).path.rsplit("/", 1)[-1]).removesuffix("_(Quest)").removesuffix("_(quest)")


def references():
    with (PLAN / "QUEST_WIKI_STEPS.csv").open(encoding="utf-8", newline="") as source:
        grouped = defaultdict(list)
        for step in csv.DictReader(source):
            grouped[article_name(step["Источник"])].append(step)
    for name in STORY_REGIONS:
        grouped.setdefault(name, [])
    return grouped


def main():
    regions = json.loads((ROOT / "data/regions.json").read_text(encoding="utf-8"))
    zones = json.loads((ROOT / "data/world.json").read_text(encoding="utf-8"))["zones"]
    chunks = json.loads((ROOT / "data/chunks.json").read_text(encoding="utf-8"))["chunks"]
    known_regions = {region["id"] for region in regions["regions"]}
    zones_with_scenes = {chunk["zone"] for chunk in chunks}
    regions_with_scenes = {zone["region"] for zone in zones if zone["id"] in zones_with_scenes}

    with (PLAN / "QUEST_REGION_BACKLOG.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow([
            "Группа вики", "Слот сюжета", "Регион проекта", "Есть сцены региона",
            "Этапов в справочнике", "Уровни в источнике", "Число NPC в источнике",
            "Типы целей", "Что запланировать", "Источник",
        ])
        for name, steps in sorted(references().items()):
            slot, region = STORY_REGIONS.get(name, ("", OTHER_REGIONS.get(name, "")))
            if region and region not in known_regions:
                raise ValueError(f"Unknown target region: {region}")
            goal_types = {kind for step in steps for kind in step["Тип цели"].split("+") if kind}
            npcs = {step["NPC"] for step in steps if step["NPC"] != "Не указан в строке"}
            levels = sorted({int(step["Уровень"]) for step in steps if step["Уровень"].isdecimal()})
            requirements = []
            if not steps:
                requirements.append("Уточнить этапы по источникам")
            if npcs or goal_types & {"talk", "recruit"}:
                requirements.append("Назначить NPC и точки диалога")
            if goal_types & {"kill", "collect_drop"}:
                requirements.append("Разместить столкновения и проверить добычу")
            if goal_types & {"visit", "travel", "dungeon_clear"}:
                requirements.append("Проложить маршрут или вход в подземелье")
            if goal_types & {"collect", "collect_drop", "buy", "craft", "use_item", "delivery"}:
                requirements.append("Привязать предметы и способы получения")
            if goal_types - {"talk", "kill", "visit", "collect", "collect_drop", "dungeon_clear"}:
                requirements.append("Проверить поддержку целей")
            sources = sorted({step["Источник"].split("#", 1)[0] for step in steps})
            writer.writerow([
                name, slot, region, ("да" if region in regions_with_scenes else "нет") if region else "",
                len(steps), ", ".join(map(str, levels)), len(npcs),
                ", ".join(sorted(goal_types)), " | ".join(requirements),
                " | ".join(sources) or "https://rikagro.ru/wiki/Quest_Chain#Main_Quest_Chains",
            ])


if __name__ == "__main__":
    main()
