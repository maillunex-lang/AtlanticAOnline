class_name TacticalBoard
extends Control

signal cell_pressed(at: Vector2i)

var sim: TacticalBattle
var sprites := {}
var move_cells: Array[Vector2i] = []
var area_cells: Array[Vector2i] = []
var targets: Array[int] = []
var selected := -1
var cursor := Vector2i.ZERO
var pointer_preview := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _metrics() -> Vector3:
	var step := floorf(minf((size.x - 24.0) / sim.size.x, (size.y - 16.0) / sim.size.y))
	var origin := (size - Vector2(sim.size) * step) / 2.0
	return Vector3(origin.x, origin.y, step)


func _draw() -> void:
	if sim == null:
		return
	var metrics := _metrics()
	var step := metrics.z
	if step <= 0:
		return
	var origin := Vector2(metrics.x, metrics.y)
	var objective := sim.objective()
	var goal := TacticalBattle.cell(objective["cell"]) if objective.get("type") == "occupy" else Vector2i(-1, -1)
	for y in sim.size.y:
		for x in sim.size.x:
			var at := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(at) * step, Vector2.ONE * step)
			var is_wall := sim.walls.has(at)
			draw_texture_rect(Art.tile("dirt" if is_wall else "grass"), rect, false, Color("858171") if is_wall else Color("829b84"))
			draw_rect(rect, Color("10262571"), false, 1.0)
			if is_wall:
				draw_rect(rect.grow(-step * 0.15), Color("303841"), true)
				draw_rect(rect.grow(-step * 0.22), Color("596166"), false, 2.0)
			if at == goal:
				draw_rect(rect.grow(-2), Color("ffd883"), false, 3.0)
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, 17), "Маяк", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff1b6"))
			if at in move_cells:
				draw_rect(rect.grow(-2), Color("49d7c176"))
				draw_rect(rect.grow(-2), Color("7ddccd"), false, 1.0)
			if at in area_cells:
				draw_rect(rect.grow(-2), Color("fcc46965"))
				draw_rect(rect.grow(-2), Color("ffc672"), false, 1.0)
			if has_focus() and pointer_preview and at == cursor:
				draw_rect(rect.grow(-2), Color.WHITE, false, 2.0)
	for id in sim.units:
		var unit: BattleUnit = sim.units[id]
		if not unit.is_alive():
			continue
		var rect := Rect2(origin + Vector2(sim.positions[id]) * step, Vector2.ONE * step)
		var center := rect.get_center()
		var allied := unit.side == BattleRules.SIDE_A
		if int(id) == selected:
			draw_rect(rect.grow(-2), Color("fff0a1"), false, 3.0)
		if int(id) in targets or (objective.get("type") == "defeat" and int(objective["unit"]) == int(id)):
			draw_rect(rect.grow(-3), Color("ff8769"), false, 3.0)
		draw_circle(center + Vector2(0.0, step * 0.2), step * 0.32, Color("26312b"))
		var sprite_size := step * 0.76
		draw_texture_rect(sprites[id], Rect2(center - Vector2(sprite_size / 2, step * 0.48), Vector2.ONE * sprite_size), false)
		var hp := Rect2(rect.position + Vector2(step * 0.12, step * 0.84), Vector2(step * 0.76, 5))
		draw_rect(hp, Color("222830"))
		hp.size.x *= float(unit.hp) / unit.max_hp
		draw_rect(hp, Color("8ae2b0") if allied else Color("ff897c"))


func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var metrics := _metrics()
		if metrics.z <= 0:
			return
		var relative: Vector2 = (event.position - Vector2(metrics.x, metrics.y)) / metrics.z
		var at := Vector2i(floori(relative.x), floori(relative.y))
		if sim.inside(at):
			grab_focus()
			cursor = at
			pointer_preview = false
			cell_pressed.emit(at)
			accept_event()
	elif event.is_pressed():
		var direction := Vector2i.ZERO
		if event.is_action("ui_left"):
			direction = Vector2i.LEFT
		elif event.is_action("ui_right"):
			direction = Vector2i.RIGHT
		elif event.is_action("ui_up"):
			direction = Vector2i.UP
		elif event.is_action("ui_down"):
			direction = Vector2i.DOWN
		elif event.is_action("ui_accept"):
			cell_pressed.emit(cursor)
			accept_event()
			return
		else:
			return
		pointer_preview = true
		if sim.inside(cursor + direction):
			cursor += direction
		queue_redraw()
		accept_event()
