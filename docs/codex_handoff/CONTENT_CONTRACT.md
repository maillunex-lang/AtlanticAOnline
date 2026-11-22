# Контракт контента и миграции

## Файлы игры
data/regions.json: регионы и уровни.
data/world.json: зоны и переходы.
data/npcs.json: NPC и привязка к зоне/диалогу.
data/dialogues.json: узлы и варианты ответов.
data/quests.json: задания, giver, turn_in, objectives, rewards.
data/chains.json: категории, последовательность шагов, prereq_chains, reset.
Реальные допустимые поля уточнять по коду загрузки и GameData.validate, не создавать альтернативный runtime без отдельного согласования.

## Справочные материалы
source_chains.json: 300 кандидатов цепочек (158 табличных по прежнему аудиту).
source_quest_steps.json: 2099 извлечённых шагов, НЕ 2099 отдельных готовых игровых квестов.
source_npcs.json: 476 кандидатов.
source_locations.json: 238 кандидатов.
source_world_requirements.json: неполные связи локаций/NPC/квестов.
supplemental_quest_graph.json: разрозненные дополнительные задания и связи.
nonstandard_page_review.json: нестандартные страницы, требующие проверки.
game_source_mapping_candidates.json: прямых совпадений оригинальных имён игры с Wiki не обнаружено.
world_development_roadmap.json: справочная стратегия, не финальная игровая карта.

## Артефакты каждого региона
docs/content_migration/REGION_ID/source_mapping.csv
Колонки: source_type,source_id,game_type,game_id,confidence,decision,rationale
docs/content_migration/REGION_ID/legacy_id_map.json
Для типов quest,chain,npc,dialogue,zone; стратегия preserve/redirect/complete/reset_with_approval.
docs/content_migration/REGION_ID/coverage.md
docs/content_migration/REGION_ID/test_report.md

## Диалоги
Текущий dialogue_runner.gd и JSON-диалоги работают как существующий контракт. Dialogue Manager 4 НЕ установлен. Не предполагать наличие стороннего плагина. До отдельного решения развивать data-driven диалоги с сохранением совместимости.

## Безопасная замена
1. Read-only inventory и source mapping.
2. Staging нового региона и тесты.
3. Миграция старых ID и тест на копии сохранений.
4. Переключение региона, удаление только заменённых записей.
5. Повторные проверки, откат при ошибках.
Никогда не удалять действующий контент до готовности нового.
