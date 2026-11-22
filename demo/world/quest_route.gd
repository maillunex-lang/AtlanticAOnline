class_name QuestRoute
extends RefCounted
## Find the closest reachable quest target in walking distance across streamed chunks.


static func find(map: WorldView, goals: Array[Dictionary], defeated: Dictionary) -> Dictionary:
	var chunks := {}
	var markers := {}
	var zones := {}
	for goal in goals:
		if goal.kind == "zone":
			zones[goal.id] = true
	for coord in map.streamer.existing:
		var entry: Dictionary = map.streamer.existing[coord]
		if map.zone_access.is_valid() and entry.zone != map.zone_id and not map.zone_access.call(entry.zone):
			continue
		var scene := load(entry.scene) as PackedScene
		var chunk := scene.instantiate() as LocationChunk
		chunk.position = Vector2(coord) * map.grid.chunk_px()
		chunks[coord] = chunk
		for child in chunk.get_children():
			var kind := "npc" if child is NpcMarker else ("enemy" if child is EnemySpawn else "")
			if kind.is_empty():
				continue
			var id: String = child.npc_id if kind == "npc" else child.encounter_id
			var point: Vector2 = chunk.position + child.position
			if kind == "enemy" and defeated.has("%s@%d,%d" % [id, int(point.x), int(point.y)]):
				continue
			if goals.any(func(goal): return goal.kind == kind and goal.id in [id, "*"]):
				markers[_tile(point, map.grid.tile_px)] = {"kind": kind, "id": id, "point": point}
	var result := _walk(map, chunks, markers, zones)
	for chunk in chunks.values():
		chunk.free()
	return result


static func _walk(map: WorldView, chunks: Dictionary, markers: Dictionary, zones: Dictionary) -> Dictionary:
	var size := map.grid.tile_px
	var start := _tile(map.hero.position, size)
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		var point := _center(tile, size)
		var chunk: LocationChunk = chunks.get(map.grid.coord_of(point))
		var goal: Dictionary = markers.get(tile, {})
		if goal.is_empty() and chunk != null and zones.has(chunk.zone_id):
			goal = {"kind": "zone", "id": chunk.zone_id, "point": point}
		if not goal.is_empty():
			var path: Array[Vector2] = [point]
			while tile != start:
				tile = previous[tile]
				path.push_front(_center(tile, size))
			goal["path"] = path
			return goal
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + offset
			if previous.has(next):
				continue
			var next_point := _center(next, size)
			var next_chunk: LocationChunk = chunks.get(map.grid.coord_of(next_point))
			if next_chunk == null or next_chunk.is_blocked_at(next_point):
				continue
			previous[next] = tile
			queue.append(next)
	return {}


static func _tile(point: Vector2, size: float) -> Vector2i:
	return Vector2i(floori(point.x / size), floori(point.y / size))


static func _center(tile: Vector2i, size: float) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * size
