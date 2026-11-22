class_name DemoSettings
extends RefCounted
## Настройки демо. Хранятся в user://demo_settings.cfg (на Android во внутреннем хранилище приложения).

const PATH := "user://demo_settings.cfg"

var battle_speed := 1.0
var joystick := false
var hints := true
var auto_start := false
var loot_robots := 1
var jackpot_item := ""


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	battle_speed = clampf(float(cfg.get_value("game", "battle_speed", 1.0)), 1.0, 3.0)
	joystick = bool(cfg.get_value("game", "joystick", false))
	hints = bool(cfg.get_value("game", "hints", true))
	auto_start = bool(cfg.get_value("game", "auto_start", false))
	loot_robots = int(cfg.get_value("game", "loot_robots", 1))
	jackpot_item = str(cfg.get_value("game", "jackpot_item", ""))


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "battle_speed", battle_speed)
	cfg.set_value("game", "joystick", joystick)
	cfg.set_value("game", "hints", hints)
	cfg.set_value("game", "auto_start", auto_start)
	cfg.set_value("game", "loot_robots", loot_robots)
	cfg.set_value("game", "jackpot_item", jackpot_item)
	cfg.save(PATH)
