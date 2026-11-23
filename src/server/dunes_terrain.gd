class_name DunesTerrain
extends RefCounted
## Геометрия пилота берётся из тех же чанков, что и карта клиента.

var grid: ChunkGrid
var _chunks: Dictionary = {}


func _init(data: GameData) -> void:
	grid = ChunkGrid.from_rules(data.rules)
	for entry in data.chunk_manifest["chunks"]:
		if entry["zone"] in DunesMap.ZONES:
			var coord := Vector2i(int(entry["x"]), int(entry["y"]))
			var chunk: LocationChunk = (load(entry["scene"]) as PackedScene).instantiate()
			chunk.position = Vector2(coord) * grid.chunk_px()
			_chunks[coord] = chunk


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for chunk in _chunks.values():
			chunk.free()


func point(tile: Vector2i) -> Vector2:
	return DunesMap.point(tile, grid.tile_px)


func entrance(zone: String) -> Vector2:
	return point(Vector2i(32, 111) if zone == DunesMap.DUNES else Vector2i(28, 111))


func pack_position(pack: String) -> Vector2:
	if pack == "personal":
		return point(DunesMap.PACK_TILES[-1])
	for i in range(DunesMap.PACK_TILES.size() - 1):
		if pack == "dunes_pack_%d" % (i + 1):
			return point(DunesMap.PACK_TILES[i])
	return Vector2.INF


func zone_at(pos: Vector2) -> String:
	var chunk: LocationChunk = _chunks.get(grid.coord_of(pos))
	return chunk.zone_id if chunk != null else ""


func blocked(pos: Vector2) -> bool:
	for offset in [Vector2.ZERO, Vector2(-DunesMap.FEET_RADIUS, 0), Vector2(DunesMap.FEET_RADIUS, 0)]:
		var sample: Vector2 = pos + offset
		var chunk: LocationChunk = _chunks.get(grid.coord_of(sample))
		if chunk == null or chunk.is_blocked_at(sample):
			return true
	return false


func walk(position: Vector2, target: Vector2, delta: float) -> Vector2:
	var step := (target - position).limit_length(DunesMap.SPEED * delta)
	var next := position + Vector2(step.x, 0)
	if not blocked(next):
		position = next
	next = position + Vector2(0, step.y)
	if not blocked(next):
		position = next
	return position
