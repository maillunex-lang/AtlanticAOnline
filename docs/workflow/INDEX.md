# Индекс для исполнителя

Сначала получите карточку `python3 tools/roadmap.py context ID`. Открывайте только подходящую строку.

| Область | Первый файл | Код, данные и тесты |
| --- | --- | --- |
| Архитектура и границы изменений | [GDD02](../GDD02_TECH_ARCHITECTURE.md), [DESIGN_GUARD](../plan/DESIGN_GUARD.md) | [src/shared](../../src/shared), [project.godot](../../project.godot) |
| Бой и отряд | [GDD04](../GDD04_COMBAT.md) | [симуляция](../../src/shared/battle), [отряд](../../src/shared/roster), [тесты боя](../../tests/battle) |
| Мир и регион | [WORLD_DESIGN](../plan/WORLD_DESIGN.md), [текущий южный маршрут](../content_migration/southeast_asia_india/coverage.md) | [граф](../../data/world.json), [чанки](../../data/chunks.json), [тесты мира](../../tests/world) |
| Квесты, NPC и диалоги | [CONTENT_PIPELINE](../plan/CONTENT_PIPELINE.md) | [квесты](../../data/quests.json), [NPC](../../data/npcs.json), [цепочки](../../data/chains.json), [диалоги](../../data/dialogues.json), [тесты](../../tests/quests) |
| Инвентарь, ремесло и торговля | [Каталог данных](../../data) | [предметы](../../src/shared/items), [службы](../../src/shared/world/town_services.gd), [тесты](../../tests/items) |
| Сеть и SQLite | [WP-72A](../WP-72A.md) | [сервер](../../src/server), [клиент](../../src/client), [тесты](../../tests/server) |
| Godot UI и проверки | [GDD10](../GDD10_UI.md), [команды запуска](../plan/AI_HANDOFF.md#как-работать) | [интерфейс](../../demo/ui), [CI](../../.github/workflows/ci.yml), [офлайн smoke](../../tools/smoke_region_one.gd) |
| Причины решений | [DECISIONS](../DECISIONS.md) | [Исторический handoff регионов](../codex_handoff/START_HERE.md) |

Для выбора Fast, Targeted или Full смотрите [аудит и режимы тестов](../testing/TEST-OPS-01.md).

Для новой карточки используйте [шаблон](TASK_TEMPLATE.md). Для передачи запишите сделанное, реально запущенные проверки и следующий шаг в реестр через `checkpoint`.
