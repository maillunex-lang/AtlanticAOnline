extends SceneTree
## Генератор мира: набор плиток tilesets/world_tiles.tres, сцены объектов (враги, NPC, герой), чанки мира 32x32 плитки (tools/world_gen.gd),
## манифест data/chunks.json и scenes/world/world.tscn. Входные данные: tools/world_layout.json (зоны, дороги, здания, враги, NPC)
## и tools/world_themes.json (темы рельефа). Запуск (после импорта):  godot --headless --path . -s tools/gen_world.gd
## Дальше чанки правятся в редакторе: открывайте scenes/world/<регион>/chunk_*.tscn и рисуйте кистью в слоях Ground и Objects.
## Повторный запуск перезапишет ваши правки.

const TILE := 64
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
	# Раскладка зон и темы лежат в tools/world_layout.json и tools/world_themes.json; результат: сцены чанков, data/chunks.json, world.tscn.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/world_layout.json"))
	var themes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/world_themes.json"))
	var gd := GameData.load_dir()
	var zone_region := {}
	for z in gd.world["zones"]:
		zone_region[str(z["id"])] = str(z["region"])
	var gen := WorldGen.new()
	gen.setup(layout, themes, amap, tileset, load("res://scenes/world/enemy_spawn.tscn"), load("res://scenes/world/npc_marker.tscn"), zone_region)
	var errs := gen.validate()
	if not errs.is_empty():
		push_error("Раскладка мира с ошибками:\n" + "\n".join(errs))
		quit(1)
		return
	for c in gen.zone_of_chunk:
		var path := gen.scene_path(c)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var node := gen.build_chunk(c)
		GenLib.save(node, path)
		node.free()
	var man := FileAccess.open("res://data/chunks.json", FileAccess.WRITE)
	man.store_string(JSON.stringify(gen.manifest(), " "))
	man.close()
	_world()
	quit()


func _tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "blocked")
	tileset.set_custom_data_layer_type(0, TYPE_BOOL)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/world/world_atlas_64.png")
	src.texture_region_size = Vector2i(TILE, TILE)
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


func _world() -> void:
	var root := Node2D.new()
	root.set_script(load("res://demo/world/world_view.gd"))
	root.name = "World"
	var streamer := Node2D.new()
	streamer.set_script(load("res://demo/world/chunk_streamer.gd"))
	GenLib.add(root, streamer, "Chunks", root)
	var hero: Node2D = (load("res://scenes/world/hero.tscn") as PackedScene).instantiate()
	GenLib.add(root, hero, "Hero", root)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	GenLib.add(root, cam, "Camera2D", root)
	GenLib.save(root, "res://scenes/world/world.tscn")
