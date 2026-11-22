extends GdUnitTestSuite
## Потоковая подгрузка чанков на реальных сценах тестового мира 5x5 (WP-22A).

const MANIFEST := "res://scenes/world/proto/manifest.json"

var grid: ChunkGrid
var man: Dictionary
var streamer: ChunkStreamer


func before_test() -> void:
	grid = ChunkGrid.from_rules(GameData.load_dir().rules)
	man = ChunkStreamer.read_manifest(MANIFEST)
	streamer = auto_free(ChunkStreamer.new()) as ChunkStreamer
	add_child(streamer)
	streamer.use_threads = false
	streamer.setup(man, grid, 99)  # без ограничения созданий за кадр, чтобы проверять состояние сразу


func _tile_center(gx: int, gy: int) -> Vector2:
	return Vector2(gx + 0.5, gy + 0.5) * grid.tile_px


func test_manifest_is_valid_and_world_is_5x5() -> void:
	assert_array(ChunkManifest.validate(man, grid)).is_empty()
	assert_int(streamer.existing.size()).is_equal(25)
	assert_int(int(man["chunk_tiles"])).is_equal(32)


func test_every_chunk_scene_follows_the_format() -> void:
	for c in man["chunks"]:
		var node := (load(c["scene"]) as PackedScene).instantiate()
		var chunk := node as LocationChunk
		assert_object(chunk).is_not_null()
		assert_object(chunk.size_tiles).is_equal(Vector2i(32, 32))
		var ground := chunk.get_node("Ground") as TileMapLayer
		var objects := chunk.get_node("Objects") as TileMapLayer
		assert_int(ground.get_used_cells().size()).is_equal(32 * 32)  # земля закрашена целиком
		for cell in ground.get_used_cells() + objects.get_used_cells():
			assert_bool(cell.x >= 0 and cell.y >= 0 and cell.x < 32 and cell.y < 32).is_true()
		node.free()


func test_roads_continue_across_chunk_borders() -> void:
	# Дороги идут по глобальным строкам y=10 и y=80: на границе чанков по x плитки по обе стороны это дорога.
	var dirt: Array[Vector2i] = []
	for n in ["dirt", "dirt_a", "dirt_b"]:
		var f := FileAccess.open("res://tools/atlas_map.json", FileAccess.READ)
		var a: Array = JSON.parse_string(f.get_as_text())["tiles"][n]
		dirt.append(Vector2i(int(a[0]), int(a[1])))
	for gy in [10, 80]:
		var cy: int = gy / 32
		for cx in 4:
			var left := (load("res://scenes/world/proto/chunk_%d_%d.tscn" % [cx, cy]) as PackedScene).instantiate()
			var right := (load("res://scenes/world/proto/chunk_%d_%d.tscn" % [cx + 1, cy]) as PackedScene).instantiate()
			var l_atlas := (left.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(Vector2i(31, gy - cy * 32))
			var r_atlas := (right.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(Vector2i(0, gy - cy * 32))
			assert_bool(dirt.has(l_atlas)).is_true()
			assert_bool(dirt.has(r_atlas)).is_true()
			left.free()
			right.free()


func test_loads_chunks_around_hero_and_nothing_else() -> void:
	var pos := _tile_center(80, 80)  # центр мира, чанк (2, 2), середина чанка
	streamer.update(pos)
	var want: Array = grid.plan(pos, streamer.existing, [])["load"]
	assert_int(streamer.nodes.size()).is_equal(want.size())
	for k in want:
		assert_bool(streamer.is_loaded(k)).is_true()
	assert_bool(streamer.is_loaded(Vector2i(0, 0))).is_false()
	assert_str(streamer.zone_at(pos)).is_equal("proto_zone")
	assert_object(streamer.chunk_at(pos)).is_not_null()


func test_walking_loads_ahead_and_unloads_behind() -> void:
	streamer.update(_tile_center(10, 10))  # угол мира, чанк (0, 0)
	assert_bool(streamer.is_loaded(Vector2i(0, 0))).is_true()
	assert_bool(streamer.is_loaded(Vector2i(4, 4))).is_false()
	var unloaded: Array = []
	streamer.chunk_unloaded.connect(func(k: Vector2i) -> void: unloaded.append(k))
	var x := 10
	while x < 150:  # идём вдоль дороги y=10 к дальнему краю
		x += 4
		streamer.update(_tile_center(x, 10))
		await get_tree().process_frame  # даём queue_free отработать
		assert_bool(streamer.is_loaded_at(_tile_center(x, 10))).is_true()  # под героем чанк есть всегда
		assert_int(streamer.nodes.size()).is_less_equal(9)
	assert_bool(streamer.is_loaded(Vector2i(4, 0))).is_true()
	assert_bool(streamer.is_loaded(Vector2i(0, 0))).is_false()
	assert_bool(unloaded.has(Vector2i(0, 0))).is_true()


func test_budget_limits_instances_per_frame() -> void:
	streamer.max_instances_per_frame = 2
	streamer.update(_tile_center(80, 80))
	assert_int(streamer.nodes.size()).is_equal(2)
	streamer.update(_tile_center(80, 80))
	assert_int(streamer.nodes.size()).is_equal(4)


func test_unloaded_and_missing_chunks_are_blocked() -> void:
	streamer.update(_tile_center(80, 80))
	assert_bool(streamer.blocked_at(_tile_center(80, 80))).is_false()  # дорога, чанк загружен
	assert_bool(streamer.blocked_at(_tile_center(5, 5))).is_true()  # чанк (0,0) существует, но не загружен
	assert_bool(streamer.blocked_at(Vector2(-100, -100))).is_true()  # за краем мира
	assert_bool(streamer.blocked_at(_tile_center(400, 400))).is_true()


func test_trees_and_water_are_blocked_in_loaded_chunks() -> void:
	streamer.update(_tile_center(80, 80))
	var chunk := streamer.chunk_at(_tile_center(80, 80))
	var found := false
	for layer_name in ["Ground", "Objects"]:
		for cell in (chunk.get_node(layer_name) as TileMapLayer).get_used_cells():
			var p := chunk.global_position + Vector2(cell) * grid.tile_px + Vector2(32, 32)
			if chunk.is_blocked_at(p):
				assert_bool(streamer.blocked_at(p)).is_true()
				found = true
	assert_bool(found).is_true()


func test_threaded_loading_eventually_loads_the_same_chunks() -> void:
	var threaded: ChunkStreamer = auto_free(ChunkStreamer.new())
	add_child(threaded)
	threaded.setup(man, grid, 1)
	var pos := _tile_center(80, 80)
	for i in 200:
		threaded.update(pos)
		await get_tree().process_frame
	var want: Array = grid.plan(pos, threaded.existing, [])["load"]
	var have: Array = threaded.loaded_coords()
	for k in want + [Vector2i(2, 2)]:
		assert_bool(have.has(k)).is_true()
