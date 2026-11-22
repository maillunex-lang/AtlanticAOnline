class_name Minimap
extends Control
## Миникарта: зоны, враги, NPC и герой. Источник данных задаётся полем provider (мир), у которого есть методы
## minimap_size(), minimap_zones(), minimap_enemies(), minimap_npcs(), minimap_hero().

var provider: Object
const MAX_SIZE := Vector2(250, 138)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	if provider == null:
		return
	var w: Vector2 = provider.minimap_size()
	var k := minf(size.x / w.x, size.y / w.y)
	for z in provider.minimap_zones():
		var r: Rect2 = z["rect"]
		draw_rect(Rect2(r.position * k, r.size * k), (z["color"] as Color).darkened(0.25))
	for p in provider.minimap_enemies():
		draw_circle((p as Vector2) * k, 4.0, Color("ff5a4d"))
	for p in provider.minimap_npcs():
		draw_circle((p as Vector2) * k, 4.0, Color("ffe066"))
	var h: Vector2 = provider.minimap_hero()
	draw_circle(h * k, 5.0, Color.WHITE)
	draw_circle(h * k, 3.5, Color("5b8def"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
