extends GdUnitTestSuite
## Проверка сцен мира (scenes/world): куски стыкуются вплотную, земля нарисована без дыр, маркеры ссылаются на существующие данные.
## Эти же тесты защищают от ошибок при правке локаций в редакторе Godot.

var gd: GameData
var chunks: Array[LocationChunk]
var root: Node2D


func before_test() -> void:
	gd = GameData.load_dir()
	root = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	chunks = []
	for c in root.get_node("Chunks").get_children():
		chunks.append(c)


func after_test() -> void:
	root.free()


func test_world_has_three_chunks_with_zone_info() -> void:
	assert_int(chunks.size()).is_equal(3)
	var ids: Array[String] = []
	for c in chunks:
		assert_bool(c.zone_id != "" and c.zone_name != "").is_true()
		ids.append(c.zone_id)
	assert_array(ids).is_equal(["z_harbor", "z_meadow", "z_forest"])


func test_chunks_touch_without_gaps_or_overlap() -> void:
	chunks.sort_custom(func(a: LocationChunk, b: LocationChunk): return a.position.x < b.position.x)
	for i in chunks.size() - 1:
		var a := chunks[i].world_rect()
		var b := chunks[i + 1].world_rect()
		assert_float(a.end.x).is_equal(b.position.x)  # вплотную по горизонтали
		assert_float(a.position.y).is_equal(b.position.y)
		assert_float(a.size.y).is_equal(b.size.y)  # одинаковая высота: стык без ступеньки


func test_ground_is_fully_painted_inside_each_chunk() -> void:
	for c in chunks:
		var ground := c.get_node("Ground") as TileMapLayer
		for y in c.size_tiles.y:
			for x in c.size_tiles.x:
				assert_int(ground.get_cell_source_id(Vector2i(x, y))).is_not_equal(-1)


func test_nothing_is_painted_outside_the_chunk_rectangle() -> void:
	for c in chunks:
		for layer_name in ["Ground", "Objects"]:
			var layer := c.get_node(layer_name) as TileMapLayer
			var used := layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			assert_bool(used.position.x >= 0 and used.position.y >= 0).is_true()
			assert_bool(used.end.x <= c.size_tiles.x and used.end.y <= c.size_tiles.y).is_true()


func test_road_crosses_chunk_borders_at_matching_rows() -> void:
	chunks.sort_custom(func(a: LocationChunk, b: LocationChunk): return a.position.x < b.position.x)
	for i in chunks.size() - 1:
		var left := chunks[i].get_node("Ground") as TileMapLayer
		var right := chunks[i + 1].get_node("Ground") as TileMapLayer
		var lx := chunks[i].size_tiles.x - 1
		var matches := 0
		for y in chunks[i].size_tiles.y:
			var a := _is_road(left, Vector2i(lx, y))
			var b := _is_road(right, Vector2i(0, y))
			if a and b:
				matches += 1
		assert_bool(matches >= 1).is_true()  # дорога продолжается через границу


func _is_road(layer: TileMapLayer, cell: Vector2i) -> bool:
	var c := layer.get_cell_atlas_coords(cell)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/atlas_map.json"))["tiles"]
	for n in ["dirt", "dirt_a", "dirt_b"]:
		if Vector2i(int(m[n][0]), int(m[n][1])) == c:
			return true
	return false


func test_water_is_blocked_and_grass_is_walkable() -> void:
	var harbor: LocationChunk = chunks[0]
	assert_bool(harbor.is_blocked_at(harbor.global_position + Vector2(40, 400))).is_true()  # море слева
	assert_bool(harbor.is_blocked_at(harbor.global_position + Vector2(380, 900))).is_false()  # старт героя


func test_houses_and_trees_block_movement() -> void:
	var harbor: LocationChunk = chunks[0]
	assert_bool(harbor.is_blocked_at(harbor.global_position + Vector2(5 * 64 + 32, 8 * 64 + 32))).is_true()  # крыша дома
	var forest: LocationChunk = chunks[2]
	var objects := forest.get_node("Objects") as TileMapLayer
	assert_bool(objects.get_used_cells().size() > 20).is_true()  # лес плотный


func test_markers_reference_existing_game_data() -> void:
	var spawn_count := 0
	for c in chunks:
		for n in c.get_children():
			if n is EnemySpawn:
				spawn_count += 1
				assert_bool(gd.encounters.has(n.encounter_id)).is_true()
				assert_bool(c.world_rect().has_point(n.global_position)).is_true()
			elif n is NpcMarker:
				assert_bool(gd.npcs.has(n.npc_id)).is_true()
				assert_bool(c.world_rect().has_point(n.global_position)).is_true()
	assert_int(spawn_count).is_equal(6)
	assert_object(chunks[0].get_node_or_null("PlayerStart")).is_not_null()


func test_tileset_has_blocked_data_layer() -> void:
	var ts: TileSet = load("res://tilesets/world_tiles.tres")
	assert_int(ts.get_custom_data_layers_count()).is_equal(1)
	assert_str(ts.get_custom_data_layer_name(0)).is_equal("blocked")
