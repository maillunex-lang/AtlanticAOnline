class_name BattleBackground
extends Control
## Фон боя берёт местность из зоны столкновения. Клетки следуют координатам боя.
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

const SAND := preload("res://assets/world/tiles_64/sand.png")
const SAND_RIPPLES := preload("res://assets/world/tiles_64/sand_ripples.png")
const ROCKS := preload("res://assets/world/tiles_64/rocks.png")
const COBBLE := preload("res://assets/world/tiles_64/cobble.png")
const GRAVEL := preload("res://assets/world/tiles_64/gravel.png")
const BOULDER := preload("res://assets/world/tiles_64/boulder.png")
const WALL := preload("res://assets/world/tiles_64/broken_wall.png")
const COLUMN := preload("res://assets/world/tiles_64/column.png")
const FERN := preload("res://assets/world/tiles_64/fern.png")

const TERRAIN := {
	"meadow": {"floor": [GRASS, GRASS_TUFTS, DIRT], "color": Color("b3b899"), "edge": [BUSH, FERN]},
	"desert": {"floor": [SAND, SAND_RIPPLES, SAND], "color": Color("f3e0c8"), "edge": [BOULDER, ROCKS]},
	"mountain": {"floor": [GRAVEL, COBBLE, DIRT], "color": Color("a8a3a1"), "edge": [BOULDER, WALL]},
	"ruins": {"floor": [COBBLE, COBBLE, COBBLE], "color": Color("a39899"), "edge": [WALL, COLUMN]},
}

var view: BattleView
var biome := "forest"


static func biome_for(zone: String, manifest: Dictionary) -> String:
	if zone in ["z_ruins", "z_tomb"]:
		return "ruins"
	return str(manifest.get("zones", {}).get(zone, {}).get("theme", "forest"))


func _draw() -> void:
	var T := float(Art.TILE)
	var terrain: Dictionary = TERRAIN.get(biome, {})
	var floor_tiles: Array = terrain.get("floor", [GRASS, GRASS_TUFTS, DIRT])
	var cols := int(ceil(size.x / T))
	var rows := int(ceil(size.y / T))
	for ty in rows:
		for tx in cols:
			var p := Vector2(tx * T, ty * T)
			var mid := absf(p.x + T * 0.5 - size.x * 0.5) < T * 0.9
			var texture: Texture2D = floor_tiles[2 if mid else int((tx * 7 + ty * 13) % 9 == 0)]
			var tint: Color = terrain.get("color", dirt_tint if mid else grass_tint)
			draw_texture_rect(texture, Rect2(p, Vector2(T, T)), false, tint)
	if terrain.is_empty():
		_draw_forest_edges()
	else:
		_draw_terrain_edges(terrain["edge"])
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	if terrain.is_empty():
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


func _draw_terrain_edges(props: Array) -> void:
	for i in 4:
		var y := 20.0 + i * (size.y - 230.0) / 4.0
		var texture: Texture2D = props[i % props.size()]
		draw_texture_rect(texture, Rect2(8.0 + (i % 2) * 28.0, y, 88, 88), false)
		draw_texture_rect(texture, Rect2(size.x - 105.0 - (i % 2) * 18.0, y + 26.0, 88, 88), false)
