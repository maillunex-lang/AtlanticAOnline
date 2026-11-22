# GDD-02 Техархитектура: кандидаты с GitHub

Статус: **ожидает утверждения**. Дата поиска: 2026-11-22.

Проверены только метаданные (лицензия, звёзды, дата последнего пуша, описание). Код внутри
кандидатов не изучался и совместимость с Godot 4.7 не проверялась: она проверяется изолированным
тестом после утверждения. Код из репозиториев без лицензии не копируется, только изучается.

## Рекомендуем внедрить

| # | Репозиторий | Лицензия | Что берём и как адаптируем |
|---|-------------|----------|-----------------------------|
| 1 | [abarichello/godot-ci](https://github.com/abarichello/godot-ci) ★1158 | MIT | Docker-образ и шаблон GitHub Actions: автоматический экспорт Android APK и headless-сборки сервера. Адаптируем под Godot 4.7, подпись keystore через секреты. |
| 2 | [godot-gdunit-labs/gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) ★1311 | MIT | Юнит-тесты правил боя, формаций и экономики, запуск в CI. Главная ценность: один и тот же код боя на клиенте и сервере проверяется одними тестами. |
| 3 | [2shady4u/godot-sqlite](https://github.com/2shady4u/godot-sqlite) ★1462 | MIT | Хранилище сервера для прототипа (аккаунты, персонажи, инвентарь). GDExtension собираем под Linux-сервер. Схема БД делается так, чтобы позже перейти на PostgreSQL. |
| 4 | [MechanicalFlower/godot-template](https://github.com/MechanicalFlower/godot-template) ★69 | MIT | Только идеи: форматирование и линтер GDScript, учёт лицензий ассетов. Учёт лицензий нужен нам из-за решения «оригинальный контент». |

## Отложить / изучить без внедрения

| # | Репозиторий | Лицензия | Почему не сейчас |
|---|-------------|----------|-------------------|
| 5 | [oniksan/godobuf](https://github.com/oniksan/godobuf) ★410 | BSD-3 | Protobuf на GDScript. Начинаем со встроенного MultiplayerAPI (ENet/WebSocket + RPC). Вернёмся, когда трафик станет узким местом. |
| 6 | [heroiclabs/nakama-godot](https://github.com/heroiclabs/nakama-godot) ★786 | Apache-2.0 | Противоречит решению «Godot headless». Изучаем только как образец авторизации, сессий и матчмейкинга. |
| 7 | [chickensoft-games/setup-godot](https://github.com/chickensoft-games/setup-godot) ★188 | MIT | Запасной вариант вместо godot-ci, если образ не поддержит Godot 4.7. |
| 8 | [dulvui/godot-android-export](https://github.com/dulvui/godot-android-export) ★26 | MIT | Ещё один запасной вариант для экспорта APK. |

## Только чтение (нет лицензии, код не копируем)

- [YaroslavHimko/Arvenok](https://github.com/YaroslavHimko/Arvenok): 2D MMORPG на Godot 4 (C#).
- [caiofb47/TopdownMMO](https://github.com/caiofb47/TopdownMMO): клиент Godot + WebSocket-сервер.
- [Luisr-nunes/mmo_rpg_godot](https://github.com/Luisr-nunes/mmo_rpg_godot): клиент на GDScript с WebSocket-сервером.
- [Gandalf-Le-Dev/SingleProject_ClientDedicatedServerArchitecture_Template](https://github.com/Gandalf-Le-Dev/SingleProject_ClientDedicatedServerArchitecture_Template): структура «клиент и выделенный сервер в одном проекте».
- [jerryshell/agarust](https://github.com/jerryshell/agarust) (MIT, Godot + Rust): пример клиент-серверной игры.

## Что не нашлось

Готового MMO-шаблона на Godot 4.7 с авторитетным сервером и пошаговым боем нет. Сетевой слой и
структуру клиента и сервера придётся проектировать самим.
