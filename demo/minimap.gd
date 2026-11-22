class_name Minimap
extends Control
## Миникарта: зоны, враги, NPC и герой. Показывает карту целиком, масштаб 1:12.

var field: DemoField
const SCALE := 1.0 / 12.0


func _init() -> void:
	custom_minimum_size = Vector2(DemoField.MAP.x * SCALE, DemoField.MAP.y * SCALE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	if field == null:
		return
	for id in DemoField.ZONES:
		var r: Rect2 = DemoField.ZONES[id]["rect"]
		draw_rect(Rect2(r.position * SCALE, r.size * SCALE), (DemoField.ZONES[id]["color"] as Color).darkened(0.25))
	for g in field.groups:
		if g["alive"]:
			draw_circle((g["pos"] as Vector2) * SCALE, 4.0, Color("ff5a4d"))
	draw_circle((DemoField.NPC_POS["npc_orvin"] as Vector2) * SCALE, 4.0, Color("ffe066"))
	draw_circle(field.hero_pos * SCALE, 5.0, Color.WHITE)
	draw_circle(field.hero_pos * SCALE, 3.5, Color("5b8def"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
