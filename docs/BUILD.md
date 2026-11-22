# Сборка и запуск

Нужен Godot 4.7.2 (stable). Для тестов и сервера на Linux x86_64 установите расширение командой ниже.

```bash
# Тесты
sh tools/install_server_sqlite.sh
godot --headless --path . --import
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests

# Сервер локально
godot --headless --path . -- --server --port=7777

# Клиент
godot --path .
```

## Серверная база

По умолчанию сервер использует `user://atlantic-server.db`. Параметр `--db=/абсолютный/путь.db` выбирает другой файл, а `--db=:memory:` подходит для одноразовой проверки запуска. Сервер применяет миграции до открытия порта. При неудачной миграции запуск завершается с ошибкой.

Скрипт установки скачивает закреплённый релиз godot-sqlite v4.9, сверяет SHA‑256 и кладёт Linux-библиотеки в игнорируемую папку `addons/godot-sqlite`. В CI расширение устанавливается для тестов и экспорта Linux-сервера. Офлайн-клиент Android данные SQLite не открывает.

## Релизная подпись Android (секреты GitHub)
Keystore в репозиторий не добавляем. Экспорт читает переменные окружения:
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
Файл ключа восстанавливается в CI из секрета в формате base64. Этот шаг ещё не настроен и не проверялся.
