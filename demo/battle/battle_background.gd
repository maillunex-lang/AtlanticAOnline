class_name BattleBackground
extends Control
## Фон боя: трава плиткой, полоса земли между сторонами, платформы под бойцами. Подстраивается под любой размер экрана.
## Тайлы Kenney с отдельным освещением. Клетки и подсветка следуют координатам боя.

@export var grass_tint := Color(0.62, 0.7, 0.66)
@export var dirt_tint := Color(0.78, 0.74, 0.7)
@export var dim := Color(0.04, 0.07, 0.12, 0.22)

const GRASS := preload("res://demo/assets/tiles/grass.png")
const GRASS_TUFTS := preload("res://demo/assets/tiles/grass_tufts.png")
const DIRT := preload("res://demo/assets/tiles/dirt.png")
const PINE := preload("res://demo/assets/tiles/tree_pine.png")
const OAK := preload("res://demo/assets/tiles/tree_round.png")
const BUSH := preload("res://demo/assets/tiles/bush.png")
const FOREST_GLOW := preload("res://assets/world/layers/forest_glow.tres")

var view: BattleView


func _draw() -> void:
	var T := float(Art.TILE)
	var cols := int(ceil(size.x / T))
	var rows := int(ceil(size.y / T))
	for ty in rows:
		for tx in cols:
			var p := Vector2(tx * T, ty * T)
			var mid := absf(p.x + T * 0.5 - size.x * 0.5) < T * 0.9
			var texture := DIRT if mid else (GRASS_TUFTS if (tx * 7 + ty * 13) % 9 == 0 else GRASS)
			draw_texture_rect(texture, Rect2(p, Vector2(T, T)), false, dirt_tint if mid else grass_tint)
	_draw_forest_edges()
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	draw_texture_rect(FOREST_GLOW, Rect2(Vector2(size.x * 0.14, -120.0), Vector2(630, 520)), false)
	draw_texture_rect(FOREST_GLOW, Rect2(Vector2(size.x * 0.61, 88.0), Vector2(460, 340)), false)
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
			if not (side == BattleRules.SIDE_A and view.cells_highlight.has(slot)):
				draw_circle(Vector2.ZERO, 43, Color(0.015, 0.03, 0.025, 0.15))
				draw_circle(Vector2.ZERO, 31, Color(0.015, 0.03, 0.025, 0.12))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 176), "ПЕРЕДНЯЯ ЛИНИЯ ближе к центру", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))


func _draw_forest_edges() -> void:
	for i in 4:
		var y := 35.0 + i * (size.y - 254.0) / 4.0
		var tree := PINE if i % 2 == 0 else OAK
		draw_texture_rect(tree, Rect2(12.0 + (i % 2) * 44.0, y, 96, 96), false)
		draw_texture_rect(tree, Rect2(size.x - 110.0 - (i % 2) * 39.0, y + 20, 96, 96), false)
	draw_texture_rect(BUSH, Rect2(102, size.y - 250, 56, 56), false)
	draw_texture_rect(BUSH, Rect2(size.x - 168, size.y - 211, 64, 64), false)
