# Конвейер контента

Как добавлять новое в игру. Принцип: **данные в JSON, вид в сценах, логика в `src/shared`**.

## Добавить регион
Все 13 регионов уже описаны в `data/regions.json` со статусом `planned`; «добавить регион» значит наполнить его и перевести в `active`.
1. В `data/regions.json` у региона проверьте часть, порядок, `level_band`, `map_pos`; названия реальных городов лежат в `town_names` (справочно). Поменяйте `status` на `active`.
2. Добавьте зоны в `data/world.json`: `id`, `name`, `region` (id региона), `type` (`town`, `outpost`, `field`, `dungeon`), `min_level` внутри полосы региона, службы города. Пути в `edges` (`seconds`); путь между регионами обязан иметь `kind: "sea"` или `"portal"`, внутри региона `kind` не указывают.
3. Раскладка зоны в `tools/world_layout.json` (тема, чанки, вода, здания, враги, NPC, дороги) и запуск генератора `godot --headless --path . -s tools/gen_world.gd`: он создаёт чанки 32x32 по формату [CHUNK_FORMAT.md](CHUNK_FORMAT.md) (`scenes/world/<регион>/chunk_<x>_<y>.tscn`), манифест `data/chunks.json` и `world.tscn`; рельеф и дороги непрерывны на границах. Темы: `tools/world_themes.json`. Подробно: docs/EDITING.md, раздел 3.
4. Проверка: `GameData.validate()` (ссылки зон на регион, уровни в полосе, активный регион имеет город, плановый без зон, все зоны достижимы из стартового города, переходы между регионами явные) и `tests/world/test_world_scenes.gd` для нового куска.

## Добавить зону с врагами
1. Монстры: `data/monsters.json` (статы, дальность). Группа: `data/encounters.json` (слоты 0..8, опыт, монеты, таблица добычи, перезарядка).
2. Добыча: `data/loot.json`.
3. В куске: узел `EnemySpawn` с `encounter_id`.

## Добавить NPC и диалог
`data/npcs.json` (город, роли, диалог), `data/dialogues.json` (узлы, выборы, `offer_quests`, `turn_in_quests`, действие `service`), маркер `NpcMarker` в сцене.

## Добавить квест или цепочку
Шаг: `data/quests.json` (цели, награды, NPC, уровень, предшествующие). Цепочка (после WP-30): `data/chains.json`. Проверка ссылок: `GameData.validate()`.

## Добавить наёмника
`data/mercenaries.json` (оружие, ступень/ранг, статы, рост, навыки, способ найма, улучшение), квест вербовки в `quests.json`, спрайт в `Art` (`MERC_SPRITES`).

## Добавить предмет, рецепт, оружие и навык
`data/items.json`, `data/recipes.json`, `data/weapons.json`, `data/skills.json`; иконка в `UiKit.ITEM_ICONS`.

## Добавить экран интерфейса
Сцена в `scenes/ui/` (якоря, контейнеры, тема `theme/pixel_theme.tres`, уникальные имена `%` для узлов, которые трогает скрипт) и скрипт в `demo/ui/`. Скриншот на 2000x916 и 1280x720 обязателен.

## Добавить графику
Только CC0 или собственная. Положить в `demo/assets/...`, записать источник и лицензию в `third_party/ASSETS.md`, при необходимости пересобрать атлас (`tools/atlas_map.json`) и набор плиток.
