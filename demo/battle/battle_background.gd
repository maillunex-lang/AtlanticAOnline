class_name BattleBackground
extends Control
## Фон боя: трава плиткой, полоса земли между сторонами, платформы под бойцами. Подстраивается под любой размер экрана.
## Плитки берутся из demo/assets/tiles (см. Art). Размеры и тон правятся здесь или подменой фона на свою сцену.

@export var grass_tint := Color(0.62, 0.7, 0.66)
@export var dirt_tint := Color(0.78, 0.74, 0.7)
@export var dim := Color(0.04, 0.07, 0.12, 0.22)

var view: BattleView


func _draw() -> void:
	var T := float(Art.TILE)
	var cols := int(ceil(size.x / T))
	var rows := int(ceil(size.y / T))
	for ty in rows:
		for tx in cols:
			var p := Vector2(tx * T, ty * T)
			var mid := absf(p.x + T * 0.5 - size.x * 0.5) < T * 0.9
			var tex_name := "dirt" if mid else "grass"
			if not mid and (tx * 7 + ty * 13) % 9 == 0:
				tex_name = "grass_tufts"
			draw_texture_rect(Art.tile(tex_name), Rect2(p, Vector2(T, T)), false, dirt_tint if mid else grass_tint)
	draw_rect(Rect2(Vector2.ZERO, size), dim)
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
