class_name BattleBackground
extends Control
## Фон боя: трава плиткой, полоса земли между сторонами, платформы под бойцами. Подстраивается под любой размер экрана.
## Материалы лесной арены из пакета Kimi. Клетки и подсветку рисуем по координатам боя.

@export var grass_tint := Color(0.62, 0.7, 0.66)
@export var dirt_tint := Color(0.78, 0.74, 0.7)
@export var dim := Color(0.04, 0.07, 0.12, 0.22)

const RUINS_FLOOR := preload("res://assets/world/arena/guardian_ruins_floor.png")
const GRASS := preload("res://assets/stylized/world/grass.png")
const DIRT := preload("res://assets/stylized/world/path.png")
const TREE := preload("res://assets/stylized/world/tree.png")
const ROCK := preload("res://assets/stylized/world/mossy_rock.png")
const RUIN_WALL := preload("res://assets/stylized/world/ruin_wall.png")
const RUIN_ARCH := preload("res://assets/stylized/world/ruin_arch.png")

var view: BattleView
var use_ruins_floor := false


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if use_ruins_floor:
		draw_texture_rect(RUINS_FLOOR, rect, true, Color(0.78, 0.81, 0.85))
		draw_texture_rect(RUIN_WALL, Rect2(12, 105, 120, 120), false)
		draw_texture_rect(RUIN_ARCH, Rect2(size.x - 132.0, 120, 120, 120), false)
	else:
		_draw_forest()
	draw_rect(rect, dim)
	if view == null:
		return
	for side in [BattleRules.SIDE_A, BattleRules.SIDE_B]:
		for slot in BattleRules.SLOTS_PER_SIDE:
			var c := view.cell_center(side, slot)
			var col := Color(0, 0, 0, 0.16)
			if side == BattleRules.SIDE_A and view.cells_highlight.has(slot):
				col = Color(0.4, 0.8, 1.0, 0.45)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, 54, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 176), "ПЕРЕДНЯЯ ЛИНИЯ ближе к центру", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))


func _draw_forest() -> void:
	var tile_size := float(Art.TILE)
	var cols := int(ceil(size.x / tile_size))
	var rows := int(ceil(size.y / tile_size))
	for ty in rows:
		for tx in cols:
			var p := Vector2(tx * tile_size, ty * tile_size)
			var mid := absf(p.x + tile_size * 0.5 - size.x * 0.5) < tile_size * 0.9
			var texture := DIRT if mid else GRASS
			draw_texture_rect(texture, Rect2(p, Vector2(tile_size, tile_size)), false, dirt_tint if mid else grass_tint)
	draw_texture_rect(TREE, Rect2(4, 75, 160, 160), false)
	draw_texture_rect(TREE, Rect2(size.x - 142.0, 220, 138, 138), false)
	draw_texture_rect(ROCK, Rect2(40, size.y - 278.0, 82, 82), false)
