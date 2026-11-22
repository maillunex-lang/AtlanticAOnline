extends GdUnitTestSuite
## Сетка чанков и манифест (WP-22A).

var g: ChunkGrid


func before_test() -> void:
	g = ChunkGrid.new()  # чанк 32 плитки по 64 px = 2048 px, подгрузка 1200, выгрузка 2400


func _all(n: int) -> Dictionary:
	var d := {}
	for y in n:
		for x in n:
			d[Vector2i(x, y)] = true
	return d


func test_sizes_and_defaults_from_rules() -> void:
	assert_float(g.chunk_px()).is_equal(2048.0)
	var r := ChunkGrid.from_rules(GameData.load_dir().rules)
	assert_int(r.chunk_tiles).is_equal(32)
	assert_float(r.load_margin).is_equal(1200.0)
	assert_float(r.unload_margin).is_equal(2400.0)
	assert_float(r.unload_margin).is_greater(r.load_margin)


func test_coord_of_handles_borders_and_negatives() -> void:
	assert_object(g.coord_of(Vector2(0, 0))).is_equal(Vector2i(0, 0))
	assert_object(g.coord_of(Vector2(2047.9, 2047.9))).is_equal(Vector2i(0, 0))
	assert_object(g.coord_of(Vector2(2048, 0))).is_equal(Vector2i(1, 0))
	assert_object(g.coord_of(Vector2(-1, -1))).is_equal(Vector2i(-1, -1))
	assert_object(g.coord_of(Vector2(-2048, 5000))).is_equal(Vector2i(-1, 2))
	assert_object(g.rect_of(Vector2i(2, -1))).is_equal(Rect2(4096, -2048, 2048, 2048))


func test_distance_to_chunk_rect() -> void:
	assert_float(g.distance_to(Vector2i(0, 0), Vector2(100, 100))).is_equal(0.0)
	assert_float(g.distance_to(Vector2i(1, 0), Vector2(1000, 500))).is_equal(1048.0)
	assert_float(g.distance_to(Vector2i(1, 1), Vector2(1000, 1000))).is_equal_approx(Vector2(1048, 1048).length(), 0.01)


func test_plan_loads_neighbors_within_margin_sorted_by_distance() -> void:
	var existing := _all(5)
	var center := Vector2(2048.0 * 2 + 1024.0, 2048.0 * 2 + 1024.0)  # середина чанка (2, 2)
	var p := g.plan(center, existing, [])
	# От середины чанка до края 1024 < 1200: все 4 соседа по сторонам; диагонали на расстоянии ~1448, дальше 1200.
	assert_int(p.load.size()).is_equal(5)
	assert_object(p.load[0]).is_equal(Vector2i(2, 2))
	assert_array(p.unload).is_empty()
	var near_corner := Vector2(2048.0 * 2 + 100.0, 2048.0 * 2 + 100.0)
	var p2 := g.plan(near_corner, existing, [])
	assert_bool((p2.load as Array).has(Vector2i(1, 1))).is_true()  # диагональ у угла
	assert_int(p2.load.size()).is_equal(4)  # свой, левый, верхний и диагональный; правые и нижние дальше 1200


func test_plan_skips_missing_and_already_loaded() -> void:
	var existing := {Vector2i(0, 0): true, Vector2i(1, 0): true}
	var p := g.plan(Vector2(1000, 1000), existing, [Vector2i(0, 0)])
	assert_array(p.load).is_equal([Vector2i(1, 0)])
	var p2 := g.plan(Vector2(1000, 1000), existing, [Vector2i(0, 0), Vector2i(1, 0)])
	assert_array(p2.load).is_empty()


func test_hysteresis_prevents_flicker_on_border() -> void:
	var existing := _all(5)
	var loaded := [Vector2i(0, 0)]
	# Игрок в чанке (2,2): дальше load_margin, но ближе unload_margin: чанк (0,0) остаётся.
	var pos := Vector2(2048.0 * 2 + 10.0, 2048.0 * 2 + 10.0)
	# Расстояние до (0,0) по диагонали: (4096-2048-10 ... ) = ~2038*sqrt2 = 2882 > 2400, значит выгрузка
	assert_array(g.plan(pos, existing, loaded).unload).is_equal([Vector2i(0, 0)])
	var near := Vector2(2048.0 * 1 + 10.0, 2048.0 * 1 + 10.0)  # игрок в (1,1), до (0,0) рукой подать
	assert_array(g.plan(near, existing, loaded).unload).is_empty()
	# Чанк (1,0) на расстоянии между 1200 и 2400 не загружается, но и не выгружается, если уже загружен.
	var far_pos := Vector2(4096.0 + 1800.0, 1000.0)  # чанк (2,0); до правого края чанка (1,0) 1800 px
	var d := g.distance_to(Vector2i(1, 0), far_pos)
	assert_bool(d > g.load_margin and d <= g.unload_margin).is_true()
	assert_array(g.plan(far_pos, existing, [Vector2i(1, 0)]).unload).is_empty()
	assert_bool((g.plan(far_pos, existing, []).load as Array).has(Vector2i(1, 0))).is_false()


func test_unload_order_is_farthest_first() -> void:
	var existing := _all(5)
	var p := g.plan(Vector2(10, 10), existing, [Vector2i(4, 4), Vector2i(3, 3), Vector2i(0, 0)])
	assert_array(p.unload).is_equal([Vector2i(4, 4), Vector2i(3, 3)])


func test_within_for_server_interest() -> void:
	var existing := _all(5)
	var v := g.within(Vector2(2048.0 * 2 + 1024.0, 2048.0 * 2 + 1024.0), 1100.0, existing)
	assert_int(v.size()).is_equal(5)
	assert_array(g.within(Vector2(-9000, -9000), 1100.0, existing)).is_empty()


func test_manifest_validation() -> void:
	var good := {"chunk_tiles": 32, "chunks": [{"x": 0, "y": 0, "scene": "res://scenes/world/proto/chunk_0_0.tscn", "zone": "z"},
		{"x": 1, "y": 0, "scene": "res://scenes/world/proto/chunk_1_0.tscn", "zone": "z"}]}
	assert_array(ChunkManifest.validate(good, g)).is_empty()
	var bad := {"chunk_tiles": 16, "chunks": [{"x": 0, "y": 0, "scene": "res://nope.tscn", "zone": ""},
		{"x": 0, "y": 0, "scene": "res://scenes/world/proto/chunk_0_0.tscn", "zone": "z"},
		{"x": 3, "y": 3, "scene": "res://scenes/world/proto/chunk_0_0.tscn", "zone": "z"}]}
	var t := "\n".join(ChunkManifest.validate(bad, g))
	for part in ["не равен размеру сетки", "повторяется", "нет сцены res://nope.tscn", "не указана зона", "уже у чанка", "не образуют единую область"]:
		assert_bool(t.contains(part)).is_true()
