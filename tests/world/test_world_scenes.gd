extends GdUnitTestSuite
## Проверка мира из чанков (scenes/world/<регион>/chunk_*.tscn, data/chunks.json): формат, стыки, маркеры, проходимость.
## Эти же тесты защищают от ошибок при правке чанков в редакторе Godot и при перегенерации мира.

var gd: GameData
var grid: ChunkGrid
var man: Dictionary
var nodes: Dictionary = {}  # Vector2i -> LocationChunk (все чанки мира, добавлены в дерево)


func before_test() -> void:
	gd = GameData.load_dir()
	grid = ChunkGrid.from_rules(gd.rules)
	man = gd.chunk_manifest
	var holder := Node2D.new()
	add_child(holder)
	for c in man["chunks"]:
		var inst := (load(c["scene"]) as PackedScene).instantiate() as LocationChunk
		inst.position = Vector2(int(c["x"]), int(c["y"])) * grid.chunk_px()
		holder.add_child(inst)
		nodes[Vector2i(int(c["x"]), int(c["y"]))] = inst
	auto_free(holder)


func _road_atlas() -> Array[Vector2i]:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/atlas_map.json"))["tiles"]
	var out: Array[Vector2i] = []
	for n in ["dirt", "dirt_a", "dirt_b"]:
		out.append(Vector2i(int(m[n][0]), int(m[n][1])))
	return out


func _is_road(c: LocationChunk, cell: Vector2i) -> bool:
	return _road_atlas().has((c.get_node("Ground") as TileMapLayer).get_cell_atlas_coords(cell))


func test_data_and_manifest_are_valid() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(man["chunks"].size()).is_equal(41)
	assert_int(nodes.size()).is_equal(41)
	var per_zone := {}
	for c in man["chunks"]:
		per_zone[c["zone"]] = int(per_zone.get(c["zone"], 0)) + 1
	assert_dict(per_zone).is_equal({"z_harbor": 2, "z_meadow": 4, "z_forest": 4, "z_crossroads": 1, "z_mine": 1, "z_ruins": 1, "z_hills": 1, "z_citadel": 1, "z_oasis": 1, "z_dunes": 2, "z_canyon": 2, "z_tomb": 2, "z_east_market": 2, "z_lower_dock": 1, "z_river_marsh": 1, "z_sluice_town": 1, "z_copper_cove": 1, "z_fog_trail": 1, "z_copper_ridge": 1, "z_river_crossing": 1, "z_reed_camp": 1, "z_pass_foothills": 1, "z_pass_settlement": 1, "z_watershed": 1, "z_cistern_halls": 1, "z_north_quay": 1, "z_europe_causeway": 1, "z_rome": 1, "z_salt_road": 1, "z_ostia": 1})


func test_every_chunk_follows_the_format() -> void:
	for k in nodes:
		var c: LocationChunk = nodes[k]
		assert_object(c.size_tiles).is_equal(Vector2i(32, 32))
		assert_str(c.zone_id).is_equal(str(gd.chunk_manifest["chunks"].filter(func(m): return Vector2i(int(m["x"]), int(m["y"])) == k)[0]["zone"]))
		var ground := c.get_node("Ground") as TileMapLayer
		assert_int(ground.get_used_cells().size()).is_equal(32 * 32)
		for layer_name in ["Ground", "Objects", "Obstacles"]:
			var layer := c.get_node_or_null(layer_name) as TileMapLayer
			if layer == null:
				continue
			var used := layer.get_used_rect()
			if used.size != Vector2i.ZERO:
				assert_bool(used.position.x >= 0 and used.position.y >= 0 and used.end.x <= 32 and used.end.y <= 32).is_true()


func test_roads_continue_across_every_chunk_border() -> void:
	for k in nodes:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = k + d
			if not nodes.has(nb):
				continue
			var a: LocationChunk = nodes[k]
			var b: LocationChunk = nodes[nb]
			var a_road := 0
			var b_road := 0
			var both := 0
			for i in 32:
				var ca := Vector2i(31, i) if d.x == 1 else Vector2i(i, 31)
				var cb := Vector2i(0, i) if d.x == 1 else Vector2i(i, 0)
				var ra := _is_road(a, ca)
				var rb := _is_road(b, cb)
				a_road += int(ra)
				b_road += int(rb)
				both += int(ra and rb)
			if a_road > 0 or b_road > 0:
				assert_int(both).is_greater(0)  # дорога продолжается через границу


func test_water_is_blocked_start_and_npc_are_walkable() -> void:
	var harbor: LocationChunk = nodes[Vector2i(0, 0)]
	assert_bool(harbor.is_blocked_at(harbor.global_position + Vector2(1 * 64 + 32, 10 * 64 + 32))).is_true()  # море слева
	var st: Array = man["start"]
	var p := Vector2(float(st[0]) + 0.5, float(st[1]) + 0.5) * grid.tile_px
	assert_bool((nodes[grid.coord_of(p)] as LocationChunk).is_blocked_at(p)).is_false()


func test_houses_and_trees_block_movement() -> void:
	var harbor: LocationChunk = nodes[Vector2i(0, 0)]
	assert_bool(harbor.is_blocked_at(harbor.global_position + Vector2(6 * 64 + 32, 12 * 64 + 32))).is_true()  # крыша дома
	var trees := 0
	for k in [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)]:
		trees += ((nodes[k] as LocationChunk).get_node("Objects") as TileMapLayer).get_used_cells().size()
	assert_bool(trees > 150).is_true()  # лес плотный


func test_markers_reference_data_and_sit_in_their_zone() -> void:
	var spawn_count := 0
	var npc_count := 0
	for k in nodes:
		var c: LocationChunk = nodes[k]
		for n in c.get_children():
			if n is EnemySpawn:
				spawn_count += 1
				assert_bool(gd.encounters.has(n.encounter_id)).is_true()
				assert_bool(c.world_rect().has_point(n.global_position)).is_true()
				assert_str(c.zone_id).is_equal(str(gd.encounters[n.encounter_id]["zone"]))
			elif n is NpcMarker:
				npc_count += 1
				assert_bool(gd.npcs.has(n.npc_id)).is_true()
				assert_str(c.zone_id).is_equal(str(gd.npcs[n.npc_id]["zone"]))
	assert_int(spawn_count).is_equal(89)
	assert_int(npc_count).is_equal(50)


func test_every_marker_is_reachable_on_foot_from_the_regional_landing() -> void:
	# Обходим сушу каждого региона от стартовой точки и причалов.
	var w := 17 * 32
	var h := 11 * 32
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) * grid.tile_px
			var chunk := nodes.get(grid.coord_of(p)) as LocationChunk
			blocked[y * w + x] = 1 if chunk == null or chunk.is_blocked_at(p) else 0
	var st: Array = man["start"]
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue: Array[Vector2i] = [Vector2i(int(st[0]), int(st[1]))]
	for port: Array in man["ferry_landings"].values():
		queue.append(Vector2i(int(port[0]), int(port[1])))
	for landing in queue:
		var idx := landing.y * w + landing.x
		assert_int(blocked[idx]).is_equal(0)
		seen[idx] = 1
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and seen[n.y * w + n.x] == 0 and blocked[n.y * w + n.x] == 0:
				seen[n.y * w + n.x] = 1
				queue.append(n)
	for k in nodes:
		for m in (nodes[k] as LocationChunk).get_children():
			if m is EnemySpawn or m is NpcMarker:
				var t := Vector2i(floori(m.global_position.x / grid.tile_px), floori(m.global_position.y / grid.tile_px))
				assert_int(seen[t.y * w + t.x]).override_failure_message("%s: %s" % [m.name, t]).is_equal(1)

	for tile: Vector2i in DunesMap.PACK_TILES:
		assert_int(seen[tile.y * w + tile.x]).override_failure_message("Сетевой дозор: %s" % tile).is_equal(1)
		assert_str((nodes[Vector2i(tile.x / 32, tile.y / 32)] as LocationChunk).zone_id).is_equal("z_dunes")


func test_harbor_pier_and_citadel_gate_remain_walkable() -> void:
	var harbor: LocationChunk = nodes[Vector2i(0, 0)]
	var landing: Array = man["ferry_landings"]["z_harbor"]
	for x in range(1, int(landing[0]) + 1):
		assert_bool(harbor.is_blocked_at(Vector2(x + 0.5, float(landing[1]) + 0.5) * grid.tile_px)).is_false()
	assert_bool(harbor.is_blocked_at(Vector2(13.5, 27.5) * grid.tile_px)).is_true()

	var citadel: LocationChunk = nodes[Vector2i(9, 0)]
	var origin := citadel.global_position
	assert_bool(citadel.is_blocked_at(origin + Vector2(5.5, 29.5) * grid.tile_px)).is_false()
	assert_bool(citadel.is_blocked_at(origin + Vector2(4.5, 29.5) * grid.tile_px)).is_true()


func test_unloaded_chunk_uses_its_world_offset_for_routing() -> void:
	var coord := Vector2i(1, 0)
	var loaded: LocationChunk = nodes[coord]
	var path := str(man["chunks"].filter(func(c): return c["x"] == 1 and c["y"] == 0)[0]["scene"])
	var detached := (load(path) as PackedScene).instantiate() as LocationChunk
	detached.position = loaded.global_position
	for tile: Vector2 in [Vector2(1.5, 25.5), Vector2(1.5, 31.5), Vector2(18.5, 27.5)]:
		var point := detached.position + tile * grid.tile_px
		assert_bool(detached.is_blocked_at(point)).is_equal(loaded.is_blocked_at(point))
	detached.free()


func test_settlement_routines_stay_on_walkable_tiles_in_their_zone() -> void:
	var settlements := {}
	for zone in gd.world["zones"]:
		if GameData.is_settlement(str(zone["type"])):
			settlements[zone["id"]] = true
	var residents := 0
	for chunk: LocationChunk in nodes.values():
		for child in chunk.get_children():
			var npc := child as NpcMarker
			if npc == null:
				continue
			if not settlements.has(chunk.zone_id) or npc.is_prop():
				assert_bool(npc.routine.is_empty()).is_true()
				continue
			assert_bool(not npc.routine.is_empty()).is_true()
			residents += 1
			var previous := npc.position
			for point: Vector2 in npc.routine:
				assert_bool(previous.distance_to(point) <= grid.tile_px).is_true()
				var world_point := chunk.to_global(point)
				assert_bool(chunk.world_rect().has_point(world_point)).is_true()
				assert_bool(chunk.is_blocked_at(world_point)).is_false()
				previous = point
	assert_int(residents).is_equal(26)


func test_tileset_has_blocked_data_layer() -> void:
	var ts: TileSet = load("res://tilesets/world_tiles.tres")
	assert_int(ts.get_custom_data_layers_count()).is_equal(1)
	assert_str(ts.get_custom_data_layer_name(0)).is_equal("blocked")


func test_world_view_streams_chunks_around_hero() -> void:
	var view := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as WorldView
	view.configure(gd)
	add_child(view)
	auto_free(view)
	assert_bool(view.chunks.size() > 0 and view.chunks.size() < 10).is_true()  # не весь мир сразу
	assert_str(view.zone_id).is_equal("z_harbor")
	assert_bool(view.npcs.any(func(npc): return npc.npc_id == "npc_orvin")).is_true()
	assert_int(view.spawns.size()).is_equal(0)  # враги лугов дальше радиуса подгрузки
	var loaded_before := view.chunks.size()
	view.hero.position = Vector2(150.0, 32.0) * grid.tile_px  # дальний лес
	for i in 30:
		view.streamer.update(view.hero.position)
		await get_tree().process_frame
	assert_bool(view.npcs.any(func(npc): return npc.npc_id == "npc_orvin")).is_false()
	assert_bool(view.npcs.any(func(npc): return npc.npc_id == "npc_tavia")).is_true()
	assert_str(view.streamer.zone_at(view.hero.position)).is_equal("z_forest")
	assert_bool(view.chunks.size() > 0 and loaded_before > 0).is_true()


func test_defeated_enemy_stays_defeated_after_chunk_reload() -> void:
	var view := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as WorldView
	view.configure(gd)
	add_child(view)
	auto_free(view)
	view.hero.position = Vector2(46.0, 18.0) * grid.tile_px
	for i in 30:
		view.streamer.update(view.hero.position)
		await get_tree().process_frame
	var slimes: EnemySpawn
	for s in view.spawns:
		if s.encounter_id == "enc_meadow_slimes":
			slimes = s
			break
	assert_object(slimes).is_not_null()
	var slimes_pos := slimes.global_position
	view.mark_defeated(slimes, 500.0)
	view.hero.position = Vector2(150.0, 32.0) * grid.tile_px
	for i in 40:
		view.streamer.update(view.hero.position)
		await get_tree().process_frame
	view.hero.position = Vector2(46.0, 18.0) * grid.tile_px
	for i in 40:
		view.streamer.update(view.hero.position)
		await get_tree().process_frame
	var found := false
	for s in view.spawns:
		if s.encounter_id == "enc_meadow_slimes" and s.global_position.is_equal_approx(slimes_pos):
			found = true
			assert_bool(s.alive).is_false()  # состояние пережило выгрузку
	assert_bool(found).is_true()
	view.respawn_ready(600.0)
	for s in view.spawns:
		assert_bool(s.alive).is_true()


func test_server_dunes_walk_uses_map_collisions_and_speed() -> void:
	var geometry := DunesTerrain.new(gd)
	var oasis := DunesMap.point(Vector2i(31, 111), grid.tile_px)
	var crossing := geometry.walk(oasis, Vector2(4000, oasis.y), 0.1)
	assert_float(crossing.distance_to(oasis)).is_equal_approx(33.0, 0.01)
	assert_str(geometry.zone_at(crossing)).is_equal("z_dunes")
	var edge := geometry.point(Vector2i(95, 110))
	var blocked := geometry.walk(edge, edge + Vector2(300, 0), 0.1)
	assert_vector(blocked).is_equal(edge)
	assert_bool(geometry.blocked(geometry.point(Vector2i(3, 111)))).is_true()


func test_world_landmarks_cover_every_playable_zone_and_animate_in_loaded_chunks() -> void:
	var covered := {}
	for kind: String in gd.world_landmarks["placements"]:
		assert_bool(kind in WorldView.LANDMARK_ROWS).is_true()
		for tile: Array in gd.world_landmarks["placements"][kind]:
			var point := (Vector2(float(tile[0]), float(tile[1])) + Vector2(0.5, 0.5)) * grid.tile_px
			var chunk: LocationChunk = nodes[grid.coord_of(point)]
			covered[chunk.zone_id] = true
	for chunk: LocationChunk in nodes.values():
		assert_bool(covered.has(chunk.zone_id)).is_true()
	var map: WorldView = load("res://scenes/world/world.tscn").instantiate()
	map.configure(gd)
	add_child(auto_free(map))
	var oasis := grid.coord_of(Vector2(17.5, 106.5) * grid.tile_px)
	map.streamer.prime(grid.rect_of(oasis).get_center())
	var well := map.streamer.nodes[oasis].get_node("Landmark_well") as AnimatedSprite2D
	assert_int(well.sprite_frames.get_frame_count(&"default")).is_equal(4)
	assert_bool(well.is_playing()).is_true()
