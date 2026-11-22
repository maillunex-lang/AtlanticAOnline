# Фаза 4 (герои и наёмники): кандидаты с GitHub

Шлюз выполнен 2026-11-22 перед WP-40 (для WP-43 шлюз был пропущен: там данные из вики, кода не заимствовалось). Запросы: `godot character class system`, `godot rpg stats`, `godot skill tree`, `godot talent tree`, `godot character creation`.
Ранее (GDD-05) изучены godot-wyvernshield-triggers (модель листа статов: идея внедрена без кода), godot_ability_system, godot-gameplay-abilities, effects: см. GDD05_GITHUB_CANDIDATES.md.

| Репозиторий | Звёзды | Лицензия | Что даёт | Решение |
|-------------|--------|----------|----------|---------|
| don-tnowe/godot-worldmap-builder | 144 | MIT | деревья навыков и выбор уровней | изучить для окна талантов (WP-46, интерфейс WP-100); код не берём |
| greenpixels/greenpixels-skill-tree-maker | 7 | MIT | редактор деревьев навыков | изучить идею формата (WP-46) |
| Flynsarmy/gd-character-creation | 23 | MIT | создатель персонажа (внешность) | отклонить: у нас выбор класса, а не конструктор внешности |
| BennyTheHeal/godot-skill-tree-kit | 0 | не определена | ранги, требования, сброс | отклонить (лицензия) |
| jerryshell/stat-growth-rpg-system | 4 | AGPL-3.0 | рост характеристик | отклонить (AGPL) |
| прочие (`godot character class system`, `godot rpg stats`) | | none | учебные прототипы | отклонить: без лицензии |

Вывод: готового решения «класс героя как данные для детерминированной серверной симуляции» нет. Классы, рост характеристик и навыки героя пишутся самими на данных JSON и чистой логике (как наёмники GDD-05). Для окна выбора класса (экран создания героя) берётся тема и компоненты проекта.

## Шлюз перед WP-47 (каталог навыков)

Выполнен 2026-11-22. Поиск репозиториев `godot ability skill system` через `gh api search` в этой среде не вернул результатов; использованы выводы GDD-05 и фазы 4 выше: готовые аддоны способностей (godot_ability_system, godot-gameplay-abilities) рассчитаны на реальное время и узлы сцены, а не на детерминированную серверную симуляцию боя. Свойства навыков (пассивки, яд, оглушение, многократный удар, пробитие, вампиризм, снятие эффектов) реализованы самостоятельно в `SkillDef` и `BattleSim`, данные в JSON. Решение: код со стороны не берём.


## Шлюз перед WP-41

22 ноября 2026 года. Запросы: `godot tactical rpg`, `godot gameplay abilities`, `godot turn based combat formation`.

| Репозиторий | Звёзды | Лицензия | Дата обновления | Решение |
|---|---:|---|---|---|
| [ramaureirac/godot-tactical-rpg](https://github.com/ramaureirac/godot-tactical-rpg) | 983 | MIT | 2026-02-21 | Пример тактического RPG-среза. В проекте уже есть сетка 3×3 и тесты шаблонов ударов, поэтому зависимости не нужны. |
| [OctoD/godot-gameplay-abilities](https://github.com/OctoD/godot-gameplay-abilities) | 79 | MIT | 2026-01-19 | Пример системы способностей. WP-41 использует действующие `SkillDef` и `BattleSim` с теми же правилами детерминизма. |

## Шлюз перед WP-42

22 ноября 2026 года. Запросы: `godot rpg progression`, `godot skill tree`, `godot inventory crafting rpg`. По первому и третьему запросам подходящих результатов не получено.

| Репозиторий | Звёзды | Лицензия | Дата обновления | Решение |
|---|---:|---|---|---|
| [Reneator/godot-skill-tree](https://github.com/Reneator/godot-skill-tree) | 14 | MIT | 2021-05-18 | Инструмент связей для дерева навыков. Для линейных порогов используем имеющиеся данные прогрессии. |
| [KDahdah/GodotSkillTreeEditor](https://github.com/KDahdah/GodotSkillTreeEditor) | 1 | Apache-2.0 | 2026-08-25 | Редактор дерева навыков. Применение можно оценить в WP-46, где будут таланты. |
