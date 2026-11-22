class_name ScreenStick
extends Control
## Экранный джойстик для управления героем на телефоне. Включается в настройках.

const RADIUS := 90.0
var value := Vector2.ZERO
var _active := false


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.4, RADIUS * 2.4)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active = event.pressed
		if _active:
			_set_from(event.position)
		else:
			value = Vector2.ZERO
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _active:
		_set_from(event.position)
		accept_event()


func _set_from(p: Vector2) -> void:
	var c := size * 0.5
	var d := p - c
	value = d / RADIUS
	if value.length() > 1.0:
		value = value.normalized()
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(0.05, 0.08, 0.12, 0.4))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 4.0)
	draw_circle(c + value * RADIUS * 0.6, 34.0, Color(0.95, 0.85, 0.55, 0.85))
	draw_arc(c + value * RADIUS * 0.6, 34.0, 0.0, TAU, 32, Color(0.25, 0.15, 0.05, 0.9), 3.0)
