extends SceneTree
## Реальный стартовый экран, повторный онлайн-вход и восстановление старого локального сохранения.

const BOOT := "res://scenes/boot.tscn"
const DEMO := preload("res://scenes/demo.tscn")
const SAVED_COINS := 947


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	if OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(DemoSettings.PATH):
		_fail("Для сценария нужен отдельный пустой каталог сохранений.")
		return
	var bootstrap := DemoSettings.new()
	bootstrap.hero_class = "warden"
	bootstrap.save_file()
	var demo: DemoMain = DEMO.instantiate()
	root.add_child(demo)
	demo.wallet["coins"] = SAVED_COINS
	demo.log.completed["m01_first_steps"] = true
	demo._save_tomb_checkpoint()
	demo.free()
	var saved := FileAccess.get_file_as_bytes(DemoSettings.PATH)

	if change_scene_to_file(BOOT) != OK:
		_fail("Не открылась обычная точка входа.")
		return
	if not await _wait_for(func(): return current_scene is StartScreen, "Обычный запуск открывает меню"):
		return
	var menu := current_scene as StartScreen
	(menu.get_node("%Online") as Button).pressed.emit()
	if not menu.login.visible or not menu.key_input.secret:
		_fail("Ключ должен вводиться в скрытом поле.")
		return
	menu.port_input.text = "65536"
	(menu.get_node("%Connect") as Button).pressed.emit()
	if not menu.status.visible or menu.pilot != null:
		_fail("Недопустимый порт должен отклоняться до входа.")
		return
	menu.port_input.text = str(port)
	menu.key_input.text = "g".repeat(64)
	(menu.get_node("%Connect") as Button).pressed.emit()
	if not menu.status.visible or menu.pilot != null:
		_fail("Неверный формат ключа должен отклоняться до входа.")
		return
	menu.key_input.text = "f".repeat(64)
	(menu.get_node("%Connect") as Button).pressed.emit()
	if not await _wait_for(func(): return menu.pilot == null and menu.login.visible and menu.status.visible, "Отказ сервера возвращает к форме"):
		return

	var key := OS.get_environment("ATLANTIC_SMOKE_SECRET")
	menu.key_input.text = key
	(menu.get_node("%Connect") as Button).pressed.emit()
	(menu.get_node("%Cancel") as Button).pressed.emit()
	if not menu.modes.visible or menu.pilot != null:
		_fail("Отмена должна возвращать к выбору режима.")
		return
	for _attempt in 2:
		(menu.get_node("%Online") as Button).pressed.emit()
		menu.key_input.text = key
		(menu.get_node("%Connect") as Button).pressed.emit()
		if not await _wait_for(func(): return menu.pilot != null and menu.pilot._ready_to_play and not menu.screen.visible, "Вход в сетевой мир"):
			return
		if not menu.key_input.text.is_empty():
			_fail("Поле ключа должно очищаться после отправки.")
			return
		menu.pilot.hud.menu_button.pressed.emit()
		if not await _wait_for(func(): return menu.pilot == null and menu.modes.visible, "Возврат в главное меню"):
			return
		await create_timer(0.25).timeout
	if FileAccess.get_file_as_bytes(DemoSettings.PATH) != saved:
		_fail("Сетевой вход изменил локальное сохранение.")
		return
	(menu.get_node("%Campaign") as Button).pressed.emit()
	if not await _wait_for(func(): return current_scene is DemoMain and (current_scene as DemoMain).hud != null, "Одиночная игра загружается штатно"):
		return
	var restored := current_scene as DemoMain
	if int(restored.wallet["coins"]) != SAVED_COINS or not restored.log.completed.has("m01_first_steps"):
		_fail("Одиночная игра должна восстановить монеты и журнал.")
		return
	print("WP-70 entry PASS: login validation, cancel, two online entries and unchanged campaign save")
	quit()


func _wait_for(predicate: Callable, stage: String) -> bool:
	var deadline := Time.get_ticks_msec() + 9500
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	_fail(stage)
	return false


func _fail(stage: String) -> void:
	printerr("WP-70 entry FAIL: ", stage)
	quit(1)
