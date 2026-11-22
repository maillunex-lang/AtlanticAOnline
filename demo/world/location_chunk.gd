@tool
class_name LocationChunk
extends Node2D
## Кусок мира (локация). Мир собран из таких кусков, лежащих вплотную друг к другу в сцене world.tscn,
## поэтому экранов загрузки нет: герой пересекает границу, а соседний кусок уже на месте.
## Рисуйте землю и объекты кистью в слоях Ground и Objects (TileMapLayer, набор плиток tilesets/world_tiles.tres).
## Плитка с отметкой blocked=true непроходима (вода, деревья, дома).
## Obstacles содержит скрытые коллизии для объектов из спрайтов.

const TILE := 64

@export var zone_id := ""
@export var zone_name := ""
@export var min_level := 1
## Цвет зоны на миникарте.
@export var minimap_color := Color("6a8f4e")
## Размер куска в плитках. Он нужен для границ зоны и подгрузки, рисуйте внутри этого прямоугольника.
@export var size_tiles := Vector2i(14, 27):
	set(v):
		size_tiles = v
		queue_redraw()


func world_rect() -> Rect2:
	return Rect2(global_position, Vector2(size_tiles) * TILE)


func is_blocked_at(world_p: Vector2) -> bool:
	var local_point := to_local(world_p)
	for layer_name in ["Ground", "Objects", "Obstacles"]:
		var l := get_node_or_null(layer_name) as TileMapLayer
		if l == null:
			continue
		var cell := l.local_to_map(l.transform.affine_inverse() * local_point)
		var td := l.get_cell_tile_data(cell)
		if td != null and bool(td.get_custom_data("blocked")):
			return true
	return false


## Куски вне экрана отключаются (не рисуются и не обрабатываются), но мир остаётся единым.
func set_active(on: bool) -> void:
	if visible != on:
		visible = on
		process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(size_tiles) * TILE), Color(1, 0.9, 0.2, 0.7), false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(12, 34), "%s (%s)" % [zone_name, zone_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.95, 0.5))
