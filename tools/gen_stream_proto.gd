extends SceneTree
## Генератор тестового мира для потоковой подгрузки (WP-22A): 5x5 чанков по 32x32 плитки, сцены scenes/world/proto/chunk_X_Y.tscn,
## манифест scenes/world/proto/manifest.json и сцена scenes/world/stream_test.tscn.
## Запуск (после --import):  godot --headless --path . -s tools/gen_stream_proto.gd
## Рельеф непрерывен на границах чанков: он считается по глобальным координатам плитки (шум, озёра, дороги, деревья).

var CHUNK := 32
var GRID := 5
var OUT := "proto"
const ROADS_X := [10, 80, 150]
const ROADS_Y := [10, 80, 150]

var amap: Dictionary
var tileset: TileSet
var ground_noise := FastNoiseLite.new()
var lake_noise := FastNoiseLite.new()
var tree_noise := FastNoiseLite.new()


func _init() -> void:
	# Для замеров размеров чанка: CHUNK=16 GRID=10 OUT=proto16 godot --headless --path . -s tools/gen_stream_proto.gd
	if OS.get_environment("CHUNK") != "":
		CHUNK = int(OS.get_environment("CHUNK"))
		GRID = int(OS.get_environment("GRID"))
		OUT = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute("res://scenes/world/" + OUT)
	var f := FileAccess.open("res://tools/atlas_map.json", FileAccess.READ)
	amap = JSON.parse_string(f.get_as_text())["tiles"]
	tileset = load("res://tilesets/world_tiles.tres")
	ground_noise.seed = 11
	ground_noise.frequency = 0.02
	lake_noise.seed = 23
	lake_noise.frequency = 0.012
	tree_noise.seed = 5
	tree_noise.frequency = 0.08
	var chunks: Array = []
	for cy in GRID:
		for cx in GRID:
			var path := "res://scenes/world/%s/chunk_%d_%d.tscn" % [OUT, cx, cy]
			_chunk(cx, cy, path)
			chunks.append({"x": cx, "y": cy, "scene": path, "zone": "proto_zone"})
	var man := FileAccess.open("res://scenes/world/%s/manifest.json" % OUT, FileAccess.WRITE)
	man.store_string(JSON.stringify({"chunk_tiles": CHUNK, "note": "Прототип WP-22A. Формат манифеста: docs/plan/CHUNK_FORMAT.md", "chunks": chunks}, " "))
	man.close()
	if OUT == "proto":
		var root := Node2D.new()
		root.name = "StreamTest"
		root.set_script(load("res://demo/world/stream_test.gd"))
		GenLib.save(root, "res://scenes/world/stream_test.tscn")
	quit()


func _near_road(gx: int, gy: int, w: int) -> bool:
	for r in ROADS_X:
		if absi(gx - r) <= w:
			return true
	for r in ROADS_Y:
		if absi(gy - r) <= w:
			return true
	return false


func _t(layer: TileMapLayer, x: int, y: int, tile_name: String) -> void:
	var c: Array = amap[tile_name]
	layer.set_cell(Vector2i(x, y), 0, Vector2i(int(c[0]), int(c[1])))


func _chunk(cx: int, cy: int, path: String) -> void:
	var root := Node2D.new()
	root.set_script(load("res://demo/world/location_chunk.gd"))
	root.name = "chunk_%d_%d" % [cx, cy]
	root.set("zone_id", "proto_zone")
	root.set("zone_name", "Тестовая зона")
	root.set("size_tiles", Vector2i(CHUNK, CHUNK))
	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	ground.scale = Vector2(4, 4)
	GenLib.add(root, ground, "Ground", root)
	var objects := TileMapLayer.new()
	objects.tile_set = tileset
	objects.scale = Vector2(4, 4)
	GenLib.add(root, objects, "Objects", root)
	var rng := RandomNumberGenerator.new()
	for y in CHUNK:
		for x in CHUNK:
			var gx := cx * CHUNK + x
			var gy := cy * CHUNK + y
			rng.seed = hash(Vector2i(gx, gy))
			var r := rng.randf()
			var tile_name := "grass_tufts" if r < 0.16 else "grass"
			var g := ground_noise.get_noise_2d(gx, gy)
			var lake := lake_noise.get_noise_2d(gx, gy)
			var on_road := _near_road(gx, gy, 1)
			if on_road:
				tile_name = ["dirt", "dirt_a", "dirt_b"][rng.randi_range(0, 2)]
			elif lake > 0.45 and not _near_road(gx, gy, 4):
				tile_name = "water" if (gx + gy) % 2 == 0 else "water_b"
			elif g > 0.2:
				tile_name = "grass_dark_tufts" if r < 0.3 else "grass_dark"
			_t(ground, x, y, tile_name)
			if on_road or _near_road(gx, gy, 3) or tile_name.begins_with("water"):
				continue
			if tree_noise.get_noise_2d(gx, gy) > 0.25 and rng.randf() < 0.5:
				_t(objects, x, y, ["tree_round", "tree_pine", "bush"][rng.randi_range(0, 2)])
	GenLib.save(root, path)
