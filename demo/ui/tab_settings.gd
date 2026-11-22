class_name TabSettings
extends Control
## Вкладка «Настройки»: скорость боя, управление, подсказки, автобой. Сохраняются в user://demo_settings.cfg.

var menu: MenuScreen

@onready var speed_buttons: Array[Button] = [%Speed1, %Speed2, %Speed3]
@onready var control_touch: Button = %ControlTouch
@onready var control_stick: Button = %ControlStick
@onready var hints_toggle: Button = %HintsToggle
@onready var auto_toggle_label: Label = %AutoToggleLabel
@onready var auto_toggle: Button = %AutoToggle
@onready var auto_options: HBoxContainer = %AutoOptions
@onready var loot_options: HBoxContainer = %LootOptions


func rebuild(m: MenuScreen) -> void:
	menu = m
	var s := menu.main.settings
	for i in 3:
		var val := float(i + 1)
		speed_buttons[i].disabled = is_equal_approx(s.battle_speed, val)
		_rebind(speed_buttons[i], func(): s.battle_speed = val; s.save_file(); menu.rebuild())
	control_touch.disabled = not s.joystick
	control_stick.disabled = s.joystick
	_rebind(control_touch, func(): s.joystick = false; s.save_file(); menu.main.apply_settings(); menu.rebuild())
	_rebind(control_stick, func(): s.joystick = true; s.save_file(); menu.main.apply_settings(); menu.rebuild())
	hints_toggle.text = "Вкл" if s.hints else "Выкл"
	_rebind(hints_toggle, func(): s.hints = not s.hints; s.save_file(); menu.main.apply_settings(); menu.rebuild())
	auto_toggle.text = "Вкл" if s.auto_start else "Выкл"
	_rebind(auto_toggle, func(): s.auto_start = not s.auto_start; s.save_file(); menu.rebuild())

	MenuScreen.clear(auto_options)
	_add_toggle("Лицензия: %s" % ("да" if s.auto_license else "нет"), func(): s.auto_license = not s.auto_license)
	_add_toggle("Авто: %s" % ("наёмники" if s.auto_mercs_only else "весь отряд"), func(): s.auto_mercs_only = not s.auto_mercs_only)
	_add_toggle("Навыки: %s" % ("да" if s.auto_skills else "нет"), func(): s.auto_skills = not s.auto_skills)
	_add_toggle("Благословение: %s" % ("да" if s.blessing else "нет"), func(): s.blessing = not s.blessing)
	auto_toggle_label.text = "Авто с начала боя · очки %d/%d" % [menu.main.pve.auto_points, menu.main.pve.config["auto_points_cap"]]

	MenuScreen.clear(loot_options)
	var cfg: Dictionary = menu.main.gd.rules["battle_loot"]
	var robots := OptionButton.new()
	robots.custom_minimum_size = Vector2(185, 64)
	for n in range(int(cfg["max_robots"]) + 1):
		robots.add_item("Сборщики: %d" % n)
	robots.select(clampi(s.loot_robots, 0, int(cfg["max_robots"])))
	robots.item_selected.connect(func(index: int):
		s.loot_robots = index
		s.save_file())
	loot_options.add_child(robots)
	var jackpot := OptionButton.new()
	jackpot.custom_minimum_size.y = 64
	jackpot.add_item("Джекпот: выключен")
	var items: Array = cfg["jackpot_items"]
	for id in items:
		var def: ItemDef = menu.main.gd.items[id]
		jackpot.add_item("%s · %d/%d" % [def.name, menu.main.jackpot_bank.get(id, 0), cfg["jackpot_threshold"]])
	jackpot.select(items.find(s.jackpot_item) + 1)
	jackpot.item_selected.connect(func(index: int):
		s.jackpot_item = "" if index == 0 else str(items[index - 1])
		s.save_file())
	loot_options.add_child(jackpot)


func _add_toggle(label: String, change: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 64
	button.pressed.connect(func():
		change.call()
		menu.main.settings.save_file()
		menu.rebuild())
	auto_options.add_child(button)


func _rebind(b: Button, cb: Callable) -> void:
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(cb)
