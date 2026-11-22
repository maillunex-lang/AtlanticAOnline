# Сборка и запуск

Нужен Godot 4.7.2 (stable).

```bash
# Тесты
godot --headless --path . --import
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests

# Сервер локально
godot --headless --path . -- --server --port=7777

# Клиент
godot --path .
```

## Релизная подпись Android (секреты GitHub)
Keystore в репозиторий не добавляем. Экспорт читает переменные окружения:
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
Файл ключа восстанавливается в CI из секрета в формате base64. Этот шаг ещё не настроен и не проверялся.
