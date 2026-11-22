class_name DemoSettings
extends RefCounted
## Настройки демо. Хранятся в user://demo_settings.cfg (на Android во внутреннем хранилище приложения).

const PATH := "user://demo_settings.cfg"

var battle_speed := 1.0
var joystick := false
var hints := true
var auto_start := false
var teleport_license := true
var auto_license := true
var auto_mercs_only := false
var auto_skills := true
var auto_disabled_units := {}
var auto_blocked_skills := {}
var blessing := false
var loot_robots := 1
var jackpot_item := ""
## Выбранный класс героя (пусто: при запуске показывается экран создания героя).
var hero_class := ""


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	battle_speed = clampf(float(cfg.get_value("game", "battle_speed", 1.0)), 1.0, 3.0)
	joystick = bool(cfg.get_value("game", "joystick", false))
	hints = bool(cfg.get_value("game", "hints", true))
	auto_start = bool(cfg.get_value("game", "auto_start", false))
	teleport_license = bool(cfg.get_value("game", "teleport_license", true))
	auto_license = bool(cfg.get_value("game", "auto_license", true))
	auto_mercs_only = bool(cfg.get_value("game", "auto_mercs_only", false))
	auto_skills = bool(cfg.get_value("game", "auto_skills", true))
	auto_disabled_units = cfg.get_value("game", "auto_disabled_units", {})
	auto_blocked_skills = cfg.get_value("game", "auto_blocked_skills", {})
	blessing = bool(cfg.get_value("game", "blessing", false))
	loot_robots = int(cfg.get_value("game", "loot_robots", 1))
	jackpot_item = str(cfg.get_value("game", "jackpot_item", ""))
	hero_class = str(cfg.get_value("game", "hero_class", ""))


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "battle_speed", battle_speed)
	cfg.set_value("game", "joystick", joystick)
	cfg.set_value("game", "hints", hints)
	cfg.set_value("game", "auto_start", auto_start)
	cfg.set_value("game", "teleport_license", teleport_license)
	cfg.set_value("game", "auto_license", auto_license)
	cfg.set_value("game", "auto_mercs_only", auto_mercs_only)
	cfg.set_value("game", "auto_skills", auto_skills)
	cfg.set_value("game", "auto_disabled_units", auto_disabled_units)
	cfg.set_value("game", "auto_blocked_skills", auto_blocked_skills)
	cfg.set_value("game", "blessing", blessing)
	cfg.set_value("game", "loot_robots", loot_robots)
	cfg.set_value("game", "jackpot_item", jackpot_item)
	cfg.set_value("game", "hero_class", hero_class)
	cfg.save(PATH)
