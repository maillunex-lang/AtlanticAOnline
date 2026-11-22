class_name TabSettings
extends Control
## Вкладка «Настройки»: скорость боя, управление, подсказки, автобой. Сохраняются в user://demo_settings.cfg.

var menu: MenuScreen

@onready var speed_buttons: Array[Button] = [%Speed1, %Speed2, %Speed3]
@onready var control_touch: Button = %ControlTouch
@onready var control_stick: Button = %ControlStick
@onready var hints_toggle: Button = %HintsToggle
@onready var auto_toggle: Button = %AutoToggle


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


func _rebind(b: Button, cb: Callable) -> void:
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(cb)
