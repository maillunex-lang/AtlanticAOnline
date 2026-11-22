# Сторонний код и лицензии

| Компонент | Версия | Лицензия | Где | Как используем |
|-----------|--------|----------|-----|----------------|
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | 7.0.0 | MIT | `addons/gdUnit4` | Скопирован целиком, тесты в `tests/` |
| [godot-ci](https://github.com/abarichello/godot-ci) | образ 4.7.2 | MIT | `.github/workflows/ci.yml` | Docker-образ и структура workflow |
| [godot-sqlite](https://github.com/2shady4u/godot-sqlite) | 4.9 | MIT | пока не добавлен | Бинарники GDExtension берутся из релизов, см. docs/GDD-02 |

Правило: любой новый ассет или библиотека добавляется строкой в эту таблицу с лицензией и источником.

Вдохновение без копирования кода: godot-open-rpg (MIT, GDQuest): структура боя, см. docs/GDD04_COMBAT.md.
Вдохновение без копирования кода: wyvernshield-triggers (MIT, don-tnowe): модель листа статов с модификаторами, см. docs/GDD05_MERCENARIES.md.
