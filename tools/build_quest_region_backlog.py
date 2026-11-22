#!/usr/bin/env python3
"""Summarize verified quest references for regional world production."""

import csv
import json
import re
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
    "Constantinople_Battlefield": ("main_16", "southern_europe"),
    "Katherine_at_Katherine_Gorge": ("main_17", "australia"),
}
# Placement uses the project's regions, with source locations as evidence.
LOCATION_GROUPS = {
    "northeast_asia": (
        "A_Tense_Moment", "Bandit_Clearing", "Beginner_Tutorial_(Scion)", "Boatman's_Daughter",
        "Cannoneer_Recruitment", "Chang_An's_Watchman", "Cleaning_the_Art_Gallery!", "Community",
        "Groundless_Rumor", "Hwarang_Recruitment", "Momotaro", "Monk_Recruitment",
        "Noble_Shaman's_Soul", "Ocean_Abyss", "Shadow_Membership_Test", "Shogun_Secret_Garden",
        "Special_Sauce", "The_Yellow_River", "Warrior's_Path", "Alishan_Mountain",
        "Lijiang_Women's_Village", "Shaolin_in_Danger",
    ),
    "southeast_asia_india": (
        "Beast_Trainer_Recruitment", "Competition", "Contaminated_Nest", "Quiz",
        "Stigmatized_Shrine", "Trip_to_Angkor_Wat", "Trip_to_Taj_Mahal",
    ),
    "southern_europe": (
        "Airship_Trade", "Byzantium_Ruins", "Dimension_Strider", "Dimension_Strider's_Request",
        "Janissary_Recruitment", "Labyrinthos", "Legion_Storage_Slot_Expansion",
        "Legion_Storage_Slot_Expansion_Hidden", "Navigator's_Dream", "Sanctum's_Secret",
        "The_Iron_Doll", "Princess_Fausta", "Title_1", "Title_2", "Title_3", "Title_4", "Trip_to_Colosseum", "Witch's_Lab",
    ),
    "northern_europe": (
        "Dinosaur_Master", "Freyja's_Necklace", "Hero's_Passage", "Kriemhild's_Forest",
        "Mercenary_Arthur_Specialization", "Trip_to_Cathedral", "Trip_to_Stonehenge",
        "Valhalla's_Bow", "Van_Gogh's_Hometown", "Guardian_of_Moscow", "Ruric's_Broken_Axe", "Ruric's_Broken_Shield",
    ),
    "southwest_asia": ("Animal_Researcher", "Destiny_of_Marduk", "Human_Heritage_I", "Sanctum_of_Eternal_Sleep"),
    "north_america": ("Deserted_Hall", "Lucky_Coin_1", "Lucky_Coin_2", "Lucky_Coin_3", "Pirate_Recruitment", "Robbers'_Hideout", "Patriot_Recruitment"),
    "africa": ("Legendary_Hero", "Lucky_Coin_6", "Sorceress"),
    "australia": (
        "Best_Jewels", "Blue_Guardian", "Converting_Mercenaries", "Exploration_Activities",
        "Hermit_of_the_Blue_Mountains", "Katherine_Gorge", "Prankster", "Pure_Waters", "Raging_Vortex",
        "Secrets_of_the_Deep", "The_Explorers",
    ),
    "atlantica_outskirts": ("Atlantis", "Dreaming_Path", "Grave_of_Cubes"),
    "west_atlantis": ("Centaur_Village", "Centaur_Hero", "Magician's_Tower"),
    "central_asia": ("Wulin",),
}
OTHER_REGIONS = {name: region for region, names in LOCATION_GROUPS.items() for name in names}
GOAL_ACTIONS = {
    "battle_move": "Переместить бойца в бою",
    "buy": "Купить предмет",
    "collect": "Собрать предмет",
    "collect_drop": "Добыть предмет из столкновения",
    "craft": "Изготовить предмет",
    "delivery": "Доставить предмет",
    "dungeon_clear": "Пройти подземелье",
    "formation": "Изменить формацию",
    "guide": "Следовать указателю",
    "inventory": "Выполнить действие с инвентарём",
    "kill": "Победить противника",
    "loot": "Забрать добычу",
    "mercenary_storage": "Поместить наёмника в резерв",
    "quest_log": "Открыть журнал заданий",
    "quest_reference": "Проверить связанное задание",
    "quiz": "Ответить на вопрос",
    "read": "Прочитать предмет",
    "recruit": "Нанять бойца",
    "rest": "Отдохнуть",
    "select_ally": "Выбрать союзника в бою",
    "settings": "Изменить настройку",
    "skill": "Повысить навык",
    "talk": "Поговорить с NPC",
    "travel": "Добраться до локации",
    "use_item": "Применить предмет",
    "visit": "Посетить локацию",
}


# The earlier extraction left these explicit formulations unclassified.
EXPLICIT_ACTIONS = (
    (r"^hunt\b.+\bfor\b", "Добыть предмет из столкновения"),
    (r"^go to\b", "Добраться до локации"),
    (r"^return to\b", "Вернуться к указанному NPC"),
    (r"^acquire (basic |detailed )?info", "Получить сведения"),
    (r"^(fully heal|heal (all|your))\b", "Вылечить отряд"),
    (r"^reach level\s+\d+", "Достичь указанного уровня"),
    (r"^open\b|^game info\b.+\bopen\b", "Открыть указанный экран"),
    (r"^raise\b.+\bskill\b", "Повысить навык"),
    (r"^enchant\b", "Зачаровать предмет"),
    (r"^complete\b.+\(tbs\)", "Завершить тактическую миссию"),
    (r"^complete\b.+\bquest\b", "Завершить указанное задание"),
    (r"^win\b", "Одержать победу"),
)


def describe_action(kind, objective):
    if kind in GOAL_ACTIONS:
        return GOAL_ACTIONS[kind]
    for pattern, description in EXPLICIT_ACTIONS:
        if re.search(pattern, objective, flags=re.IGNORECASE):
            return description
    return "Уточнить действие"


def region_for(name):
    return STORY_REGIONS.get(name, ("", OTHER_REGIONS.get(name, "")))


def write_step_plan(grouped, region_names):
    with (PLAN / "QUEST_REGION_OBJECTIVES.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow([
            "Группа вики", "Слот сюжета", "Регион ID", "Регион", "Позиция", "Этап",
            "Действие", "Цель по источнику", "NPC по источнику", "Источник", "Дополнительный источник",
        ])
        for name, steps in sorted(grouped.items()):
            slot, region = region_for(name)
            for step in steps:
                kinds = step["Тип цели"].split("+")
                actions = " + ".join(describe_action(kind, step["Цель по вики"]) for kind in kinds)
                writer.writerow([
                    name, slot, region, region_names.get(region, "Требует привязки"),
                    step["Позиция в таблице"], step["Этап"], actions, step["Цель по вики"],
                    step["NPC"], step["Источник"], step["Дополнительный источник"],
                ])



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
    region_names = {region["id"]: region["name"] for region in regions["regions"]}
    grouped = references()
    for _, region in map(region_for, grouped):
        if region and region not in region_names:
            raise ValueError(f"Unknown target region: {region}")
    zones_with_scenes = {chunk["zone"] for chunk in chunks}
    regions_with_scenes = {zone["region"] for zone in zones if zone["id"] in zones_with_scenes}

    with (PLAN / "QUEST_REGION_BACKLOG.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow([
            "Группа вики", "Слот сюжета", "Регион проекта", "Название региона", "Есть сцены региона",
            "Этапов в справочнике", "Уровни в источнике", "Число NPC в источнике",
            "Типы целей", "Что запланировать", "Источник",
        ])
        for name, steps in sorted(grouped.items()):
            slot, region = region_for(name)
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
                name, slot, region, region_names.get(region, "Требует привязки"), ("да" if region in regions_with_scenes else "нет") if region else "",
                len(steps), ", ".join(map(str, levels)), len(npcs),
                ", ".join(sorted(goal_types)), " | ".join(requirements),
                " | ".join(sources) or "https://rikagro.ru/wiki/Quest_Chain#Main_Quest_Chains",
            ])
    write_step_plan(grouped, region_names)


if __name__ == "__main__":
    main()
