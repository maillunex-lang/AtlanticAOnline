# Сторонний код и лицензии

| Компонент | Версия | Лицензия | Где | Как используем |
|-----------|--------|----------|-----|----------------|
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | 7.0.0 | MIT | `addons/gdUnit4` | Скопирован целиком, тесты в `tests/` |
| [godot-ci](https://github.com/abarichello/godot-ci) | образ 4.7.2 | MIT | `.github/workflows/ci.yml` | Docker-образ и структура workflow |
| [godot-sqlite](https://github.com/2shady4u/godot-sqlite) | 4.9 | MIT | Linux-сервер и тесты | Закреплённый релиз v4.9, установщик `tools/install_server_sqlite.sh`, лицензия `third_party/godot-sqlite.LICENSE` |

Правило: любой новый ассет или библиотека добавляется строкой в эту таблицу с лицензией и источником.

Вдохновение без копирования кода: godot-open-rpg (MIT, GDQuest): структура боя, см. docs/GDD04_COMBAT.md.
Вдохновение без копирования кода: wyvernshield-triggers (MIT, don-tnowe): модель листа статов с модификаторами, см. docs/GDD05_MERCENARIES.md.
Вдохновение без копирования кода: Lootie (MIT, sempitern0): таблицы добычи, см. docs/GDD06_PROGRESSION_ITEMS.md.
Вдохновение без копирования кода: Rubonnek/quest-manager и Dialogue Manager (MIT): журнал заданий и диалоги, см. docs/GDD07_QUESTS_NPC.md.

Графика и иконки демо: см. third_party/ASSETS.md (Kenney, CC0).
