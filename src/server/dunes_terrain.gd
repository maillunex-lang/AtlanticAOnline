class_name DunesTerrain
extends RefCounted
## Геометрия пилота берётся из тех же чанков, что и карта клиента.

const ROME_ROUTE := [SeaFerry.NORTH, "z_europe_causeway", RomeAuction.ZONE]

var grid: ChunkGrid
var _chunks: Dictionary = {}


func _init(data: GameData) -> void:
	grid = ChunkGrid.from_rules(data.rules)
	for entry in data.chunk_manifest["chunks"]:
		if entry["zone"] in DunesMap.ZONES or entry["zone"] in ROME_ROUTE:
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
	if zone == DunesMap.CANYON:
		return point(Vector2i(97, 110))
	if zone == SeaFerry.NORTH:
		return point(Vector2i(37, 336))
	if zone == "z_europe_causeway":
		return point(Vector2i(65, 336))
	if zone == RomeAuction.ZONE:
		return auctioneer() + Vector2(0, 64)
	return point(Vector2i(32, 111) if zone == DunesMap.DUNES else Vector2i(28, 111))


func auctioneer() -> Vector2:
	return point(Vector2i(119, 338))


func pack_position(pack: String, zone := DunesMap.DUNES) -> Vector2:
	var tiles := DunesMap.pack_tiles(zone)
	if pack == "personal":
		return point(tiles[-1])
	for i in range(tiles.size() - 1):
		if pack == DunesMap.pack_id(zone, i):
			return point(tiles[i])
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
