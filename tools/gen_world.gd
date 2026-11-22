extends SceneTree
## Генератор мира: набор плиток tilesets/world_tiles.tres, сцены объектов (враги, NPC, герой), куски-локации и scenes/world/world.tscn.
## Запуск (после импорта):  godot --headless --path . -s tools/gen_world.gd
## Дальше локации правятся в редакторе: открывайте scenes/world/loc_*.tscn и рисуйте кистью в слоях Ground и Objects.
## Повторный запуск перезапишет ваши правки.

const TILE := 64
const ROAD := [Vector2(130, 900), Vector2(520, 880), Vector2(900, 860), Vector2(1400, 780), Vector2(1900, 800), Vector2(2400, 700), Vector2(2900, 760)]
const BLOCKED := ["water", "water_b", "tree_round", "tree_pine", "tree_autumn", "bush", "sign", "fence_h",
	"roof_top_l", "roof_top_m", "roof_top_r", "roof_mid_l", "roof_mid_m", "roof_mid_r", "wall_window", "wall_door", "wall",
	"roofg_top_l", "roofg_top_m", "roofg_top_r", "roofg_mid_l", "roofg_mid_m", "roofg_mid_r", "wallg_window", "wallg_door", "wallg"]

var amap: Dictionary
var tileset: TileSet
var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	DirAccess.make_dir_recursive_absolute("res://tilesets")
	var f := FileAccess.open("res://tools/atlas_map.json", FileAccess.READ)
	amap = JSON.parse_string(f.get_as_text())["tiles"]
	_tileset()
	_enemy_spawn()
	_npc_marker()
	_hero()
	var harbor := _chunk("loc_harbor", "z_harbor", "Порт Эверхейм", 1, Vector2i(14, 27), Vector2(0, 0), "harbor", Color("6a8f4e"))
	var meadow := _chunk("loc_meadow", "z_meadow", "Луга Зари", 1, Vector2i(17, 27), Vector2(14 * TILE, 0), "meadow", Color("7fae52"))
	var forest := _chunk("loc_forest", "z_forest", "Шепчущий лес", 4, Vector2i(16, 27), Vector2(31 * TILE, 0), "forest", Color("3f6b3a"))
	_world([[harbor, Vector2(0, 0)], [meadow, Vector2(14 * TILE, 0)], [forest, Vector2(31 * TILE, 0)]])
	quit()


func _tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "blocked")
	tileset.set_custom_data_layer_type(0, TYPE_BOOL)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://demo/assets/atlas/world.png")
	src.texture_region_size = Vector2i(16, 16)
	tileset.add_source(src, 0)
	for n in amap:
		var c := Vector2i(int(amap[n][0]), int(amap[n][1]))
		src.create_tile(c)
		(src.get_tile_data(c, 0) as TileData).set_custom_data("blocked", BLOCKED.has(n))
	print("tileset ", ResourceSaver.save(tileset, "res://tilesets/world_tiles.tres"))
	tileset = load("res://tilesets/world_tiles.tres")


func _shadow(parent: Node, root: Node, pos: Vector2, k: float) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://demo/assets/atlas/shadow.png")
	s.scale = Vector2(k, k)
	s.position = pos
	GenLib.add(parent, s, "Shadow", root)


func _enemy_spawn() -> void:
	var r := Marker2D.new()
	r.set_script(load("res://demo/world/enemy_spawn.gd"))
	r.name = "EnemySpawn"
	_shadow(r, r, Vector2(0, 8), 3.6)
	var ring := Sprite2D.new()
	ring.texture = load("res://demo/assets/atlas/ring.png")
	ring.scale = Vector2(3.4, 3.4)
	ring.modulate = Color(1, 0.3, 0.25, 0.6)
	GenLib.add(r, ring, "Ring", r)
	GenLib.add(r, Node2D.new(), "Sprites", r)
	var l := GenLib.label("", 16, Color(1, 0.94, 0.9), 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.rect(l, -110, -118, 220, 26)
	GenLib.add(r, l, "NameLabel", r)
	GenLib.save(r, "res://scenes/world/enemy_spawn.tscn")


func _npc_marker() -> void:
	var r := Marker2D.new()
	r.set_script(load("res://demo/world/npc_marker.gd"))
	r.name = "NpcMarker"
	_shadow(r, r, Vector2(0, 6), 3.0)
	var sp := Sprite2D.new()
	sp.scale = Vector2(5, 5)
	sp.position = Vector2(0, -32)
	GenLib.add(r, sp, "Sprite", r)
	var l := GenLib.label("", 16, Color.WHITE, 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.rect(l, -100, -92, 200, 26)
	GenLib.add(r, l, "NameLabel", r)
	var q := GenLib.label("!", 40, Color("ffe066"), 6)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.rect(q, -20, -128, 40, 50)
	GenLib.add(r, q, "QuestMark", r)
	GenLib.save(r, "res://scenes/world/npc_marker.tscn")


func _hero() -> void:
	var r := Node2D.new()
	r.name = "Hero"
	_shadow(r, r, Vector2(0, 8), 3.4)
	var sp := Sprite2D.new()
	sp.texture = load("res://demo/assets/chars/knight.png")
	sp.scale = Vector2(5, 5)
	sp.position = Vector2(0, -32)
	GenLib.add(r, sp, "Sprite", r)
	GenLib.save(r, "res://scenes/world/hero.tscn")


func _road_dist(p: Vector2) -> float:
	var best := 1e9
	for i in ROAD.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, ROAD[i], ROAD[i + 1]).distance_to(p))
	return best


func _t(layer: TileMapLayer, x: int, y: int, tile_name: String) -> void:
	var c: Array = amap[tile_name]
	layer.set_cell(Vector2i(x, y), 0, Vector2i(int(c[0]), int(c[1])))


func _chunk(file: String, zone_id: String, zone_name: String, min_level: int, size: Vector2i, origin: Vector2, style: String, color: Color) -> String:
	rng.seed = hash(file)
	var root := Node2D.new()
	root.set_script(load("res://demo/world/location_chunk.gd"))
	root.name = file
	root.set("zone_id", zone_id)
	root.set("zone_name", zone_name)
	root.set("min_level", min_level)
	root.set("size_tiles", size)
	root.set("minimap_color", color)
	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	ground.scale = Vector2(4, 4)
	GenLib.add(root, ground, "Ground", root)
	var objects := TileMapLayer.new()
	objects.tile_set = tileset
	objects.scale = Vector2(4, 4)
	GenLib.add(root, objects, "Objects", root)
	var otile_origin := Vector2i(int(origin.x) / TILE, int(origin.y) / TILE)
	# земля
	for y in size.y:
		for x in size.x:
			var gx := otile_origin.x + x
			var center := origin + Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
			var tile_name := "grass"
			var r := rng.randf()
			if style == "harbor" and gx < 2:
				tile_name = "water" if (gx + y) % 2 == 0 else "water_b"
			elif style == "harbor" and gx == 2:
				tile_name = "dirt_a"
			elif _road_dist(center) <= 50.0:
				tile_name = ["dirt", "dirt_a", "dirt_b"][rng.randi_range(0, 2)]
			elif style == "forest":
				# переход от лугов к лесу: первые 5 колонок смешивают светлую и тёмную траву
				var mix := clampf(float(x) / 5.0, 0.0, 1.0)
				var dark := rng.randf() < mix
				tile_name = ("grass_dark_tufts" if r < 0.3 else "grass_dark") if dark else ("grass_tufts" if r < 0.16 else "grass")
			elif style == "meadow":
				var edge := clampf(float(x - (size.x - 5)) / 5.0, 0.0, 1.0)
				if rng.randf() < edge * 0.9:
					tile_name = "grass_dark_tufts" if r < 0.3 else "grass_dark"
				else:
					tile_name = "grass_tufts" if r < 0.16 else ("grass_flowers" if r < 0.22 else "grass")
			else:
				tile_name = "grass_tufts" if r < 0.16 else "grass"
			_t(ground, x, y, tile_name)
	# дома гавани
	var house_rects: Array[Rect2] = []
	if style == "harbor":
		for h in [[4, 7, "red"], [10, 6, "grey"], [5, 17, "grey"], [11, 18, "red"]]:
			var pre: String = "roof" if h[2] == "red" else "roofg"
			var wall: Array = ["wall_window", "wall_door", "wall"] if h[2] == "red" else ["wallg_window", "wallg_door", "wallg"]
			var rows: Array = [[pre + "_top_l", pre + "_top_m", pre + "_top_r"], [pre + "_mid_l", pre + "_mid_m", pre + "_mid_r"], wall]
			for ry in 3:
				for rx in 3:
					_t(objects, int(h[0]) + rx, int(h[1]) + ry, rows[ry][rx])
			house_rects.append(Rect2(Vector2(int(h[0]), int(h[1])) * TILE - Vector2(30, 30), Vector2(3, 3) * TILE + Vector2(60, 60)))
		_t(objects, 13, 12, "sign")
	# деревья
	var keep: float = {"harbor": 0.2, "meadow": 0.4, "forest": 1.0}[style]
	var tries := 260
	for i in tries:
		var tx := rng.randi_range(0, size.x - 1)
		var ty := rng.randi_range(0, size.y - 1)
		var center := origin + Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)
		if style == "harbor" and otile_origin.x + tx < 3:
			continue
		if _road_dist(center) < 100.0 or rng.randf() > keep * 0.6:
			continue
		if center.distance_to(Vector2(520, 820)) < 150.0 or center.distance_to(Vector2(380, 900)) < 140.0:
			continue
		var blocked := false
		for hr in house_rects:
			if hr.has_point(center - origin):
				blocked = true
		if blocked or objects.get_cell_source_id(Vector2i(tx, ty)) != -1:
			continue
		var kinds := ["tree_round", "tree_pine", "bush"] if style != "forest" else ["tree_pine", "tree_round", "tree_autumn", "tree_pine", "bush"]
		_t(objects, tx, ty, kinds[rng.randi_range(0, kinds.size() - 1)])
	# маркеры
	var spawn_scene: PackedScene = load("res://scenes/world/enemy_spawn.tscn")
	var spawns: Array = {
		"harbor": [],
		"meadow": [["enc_meadow_slimes", Vector2(1250, 450)], ["enc_meadow_slimes", Vector2(1450, 1250)], ["enc_meadow_wolves", Vector2(1700, 800)]],
		"forest": [["enc_forest_wolves", Vector2(2350, 420)], ["enc_forest_bandits", Vector2(2650, 1000)], ["enc_forest_wolves", Vector2(2400, 1400)]],
	}[style]
	var i2 := 1
	for sp in spawns:
		var inst: Marker2D = spawn_scene.instantiate()
		inst.set("encounter_id", sp[0])
		inst.position = (sp[1] as Vector2) - origin
		GenLib.add(root, inst, "EnemySpawn%d" % i2, root)
		i2 += 1
	if style == "harbor":
		var npc: Marker2D = (load("res://scenes/world/npc_marker.tscn") as PackedScene).instantiate()
		npc.set("npc_id", "npc_orvin")
		npc.set("sprite_name", "captain")
		npc.position = Vector2(520, 820)
		GenLib.add(root, npc, "NpcOrvin", root)
		var start := Marker2D.new()
		start.position = Vector2(380, 900)
		GenLib.add(root, start, "PlayerStart", root)
	var path := "res://scenes/world/%s.tscn" % file
	GenLib.save(root, path)
	return path


func _world(parts: Array) -> void:
	var root := Node2D.new()
	root.set_script(load("res://demo/world/world_view.gd"))
	root.name = "World"
	var chunks := Node2D.new()
	GenLib.add(root, chunks, "Chunks", root)
	for p in parts:
		var inst: Node2D = (load(str(p[0])) as PackedScene).instantiate()
		inst.position = p[1]
		chunks.add_child(inst)
		inst.owner = root
	var hero: Node2D = (load("res://scenes/world/hero.tscn") as PackedScene).instantiate()
	GenLib.add(root, hero, "Hero", root)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	GenLib.add(root, cam, "Camera2D", root)
	GenLib.save(root, "res://scenes/world/world.tscn")
