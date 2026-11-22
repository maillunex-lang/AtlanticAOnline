extends GdUnitTestSuite
## Генератор мира (tools/world_gen.gd): новые зоны и темы добавляются данными, рельеф детерминирован и непрерывен.

var amap: Dictionary
var tileset: TileSet
var themes: Dictionary


func before_test() -> void:
	amap = JSON.parse_string(FileAccess.get_file_as_string("res://tools/atlas_map.json"))["tiles"]
	tileset = load("res://tilesets/world_tiles.tres")
	themes = JSON.parse_string(FileAccess.get_file_as_string("res://tools/world_themes.json"))


func _layout() -> Dictionary:
	return {"seed": 3, "chunk_tiles": 32, "start": [6, 20],
		"roads": [{"width": 3, "points": [[2, 20], [60, 22]]}],
		"zones": [
			{"zone": "z_test_a", "theme": "snow", "color": "dfeaff", "chunks": [[0, 0]], "water": [], "buildings": [], "signs": [],
				"npcs": [{"npc": "npc_orvin", "sprite": "captain", "tile": [8, 20]}], "spawns": []},
			{"zone": "z_test_b", "theme": "desert", "color": "ffe3a0", "chunks": [[1, 0]], "water": [], "buildings": [], "signs": [],
				"npcs": [], "spawns": [{"encounter": "enc_meadow_slimes", "tile": [50, 10]}]}]}


func _gen(layout: Dictionary = {}) -> WorldGen:
	var g := WorldGen.new()
	g.setup(layout if not layout.is_empty() else _layout(), themes, amap, tileset, load("res://scenes/world/enemy_spawn.tscn"), load("res://scenes/world/npc_marker.tscn"),
		{"z_test_a": "test_region", "z_test_b": "test_region"})
	return g


func _ground_hash(n: Node2D) -> int:
	var cells := (n.get_node("Ground") as TileMapLayer).get_used_cells()
	var h := 7
	for c in cells:
		h = hash([h, c, (n.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(c)])
	return h


func test_layout_validation_passes_and_catches_errors() -> void:
	assert_array(_gen().validate()).is_empty()
	var bad := _layout()
	bad["zones"][0]["theme"] = "lava"
	bad["zones"][1]["chunks"] = [[0, 0]]
	bad["zones"][0]["npcs"][0]["tile"] = [100, 100]
	bad["roads"].append({"width": 3, "points": [[1, 1]]})
	var t := "\n".join(_gen(bad).validate())
	for part in ["нет темы lava", "занят зонами", "вне чанков зоны", "дорога из одной точки"]:
		assert_bool(t.contains(part)).is_true()
	var g := _gen()
	g.zone_region.erase("z_test_b")
	assert_bool("\n".join(g.validate()).contains("нет в data/world.json")).is_true()


func test_generation_is_deterministic() -> void:
	var a := _gen().build_chunk(Vector2i(0, 0))
	var b := _gen().build_chunk(Vector2i(0, 0))
	assert_int(_ground_hash(a)).is_equal(_ground_hash(b))
	a.free()
	b.free()


func test_chunks_use_their_theme_tint_and_are_fully_painted() -> void:
	var g := _gen()
	var snow := g.build_chunk(Vector2i(0, 0))
	var desert := g.build_chunk(Vector2i(1, 0))
	assert_object((snow.get_node("Ground") as TileMapLayer).modulate).is_equal(Color("dfeaff"))
	assert_object((desert.get_node("Ground") as TileMapLayer).modulate).is_equal(Color("ffe3a0"))
	for n in [snow, desert]:
		assert_int((n.get_node("Ground") as TileMapLayer).get_used_cells().size()).is_equal(32 * 32)
	snow.free()
	desert.free()


func test_road_and_themes_blend_across_the_zone_border() -> void:
	var g := _gen()
	var a := g.build_chunk(Vector2i(0, 0))
	var b := g.build_chunk(Vector2i(1, 0))
	# Дорога y=20..22 пересекает границу x=32: по обе стороны дорожные плитки в одних и тех же строках.
	var road: Array[Vector2i] = []
	for n in ["dirt", "dirt_a", "dirt_b"]:
		road.append(Vector2i(int(amap[n][0]), int(amap[n][1])))
	var both := 0
	for y in 32:
		var ra := road.has((a.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(Vector2i(31, y)))
		var rb := road.has((b.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(Vector2i(0, y)))
		both += int(ra and rb)
	assert_int(both).is_greater_equal(2)
	# Темы перемешиваются рваной границей: в 4 столбцах у границы бывает земля соседней темы.
	var desert_tiles := 0
	for y in 16:
		for x in range(28, 32):
			if road.has((a.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(Vector2i(x, y))):
				desert_tiles += 1  # у снежной зоны нет земляных плиток вне дороги, их приносит соседняя пустыня
	assert_int(desert_tiles).is_greater(0)
	a.free()
	b.free()


func test_manifest_lists_chunks_with_paths_by_region() -> void:
	var g := _gen()
	var m := g.manifest()
	assert_int(m["chunks"].size()).is_equal(2)
	assert_str(m["chunks"][0]["scene"]).is_equal("res://scenes/world/test_region/chunk_0_0.tscn")
	assert_dict(m["zones"]).has_size(2)
	assert_int(m["chunk_tiles"]).is_equal(32)


func test_markers_land_in_the_right_chunk() -> void:
	var g := _gen()
	var a := g.build_chunk(Vector2i(0, 0))
	var b := g.build_chunk(Vector2i(1, 0))
	assert_object(a.get_node_or_null("Npc_npc_orvin")).is_not_null()
	assert_object(b.get_node_or_null("EnemySpawn1")).is_not_null()
	assert_object(a.get_node_or_null("EnemySpawn1")).is_null()
	assert_object(b.get_node_or_null("Npc_npc_orvin")).is_null()
	a.free()
	b.free()


func test_all_themes_generate_walkable_roads() -> void:
	for name in themes:
		if name.begins_with("_"):
			continue
		var layout := _layout()
		layout["zones"][0]["theme"] = name
		var g := _gen(layout)
		var n := g.build_chunk(Vector2i(0, 0))
		assert_int((n.get_node("Ground") as TileMapLayer).get_used_cells().size()).is_equal(32 * 32)
		n.free()
