class_name DemoSettings
extends RefCounted
## Настройки демо. Хранятся в user://demo_settings.cfg (на Android во внутреннем хранилище приложения).

const PATH := "user://demo_settings.cfg"

var battle_speed := 1.0
var joystick := false
var hints := true
var auto_start := false


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	battle_speed = clampf(float(cfg.get_value("game", "battle_speed", 1.0)), 1.0, 3.0)
	joystick = bool(cfg.get_value("game", "joystick", false))
	hints = bool(cfg.get_value("game", "hints", true))
	auto_start = bool(cfg.get_value("game", "auto_start", false))


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "battle_speed", battle_speed)
	cfg.set_value("game", "joystick", joystick)
	cfg.set_value("game", "hints", hints)
	cfg.set_value("game", "auto_start", auto_start)
	cfg.save(PATH)
