class_name ChunkManifest
extends RefCounted
## Манифест чанков мира: {"chunk_tiles": 32, "chunks": [{"x", "y", "scene", "zone"}]}. Формат описан в docs/plan/CHUNK_FORMAT.md.
## Проверки чистые (без загрузки сцен), сами сцены проверяет тест `test_chunk_streamer.gd`.


static func index(manifest: Dictionary) -> Dictionary:
	var out := {}
	for c in manifest["chunks"]:
		out[Vector2i(int(c["x"]), int(c["y"]))] = c
	return out


## Список ошибок манифеста.
static func validate(manifest: Dictionary, grid: ChunkGrid) -> Array[String]:
	var errs: Array[String] = []
	if int(manifest.get("chunk_tiles", 0)) != grid.chunk_tiles:
		errs.append("chunk_tiles манифеста (%d) не равен размеру сетки (%d)" % [int(manifest.get("chunk_tiles", 0)), grid.chunk_tiles])
	var seen := {}
	var scenes := {}
	for c in manifest.get("chunks", []):
		var k := Vector2i(int(c["x"]), int(c["y"]))
		if seen.has(k):
			errs.append("чанк %s повторяется" % str(k))
		seen[k] = str(c.get("zone", ""))
		var scene := str(c.get("scene", ""))
		if scene == "" or not ResourceLoader.exists(scene):
			errs.append("чанк %s: нет сцены %s" % [str(k), scene])
		elif scenes.has(scene):
			errs.append("чанк %s: сцена %s уже у чанка %s" % [str(k), scene, str(scenes[scene])])
		scenes[scene] = k
		if str(c.get("zone", "")) == "":
			errs.append("чанк %s: не указана зона" % str(k))
	var landing_chunks := {}
	var landings: Dictionary = manifest.get("ferry_landings", {})
	for zone in landings:
		var tile: Array = landings[zone]
		if SeaFerry.destination(zone).is_empty() or tile.size() != 2:
			errs.append("chunks: неверный причал %s" % zone)
			continue
		var coord := grid.coord_of(Vector2(tile[0], tile[1]) * grid.tile_px)
		if seen.get(coord) != zone:
			errs.append("chunks: причал %s вне зоны" % zone)
			continue
		landing_chunks[zone] = coord
	for zone in landing_chunks:
		if not landing_chunks.has(SeaFerry.destination(zone)):
			errs.append("chunks: для причала %s нет ответного причала" % zone)
	# Связность учитывает сухопутное соседство и проверенные пары причалов.
	if not seen.is_empty():
		var start: Vector2i = seen.keys()[0]
		var stack: Array[Vector2i] = [start]
		var reach := {start: true}
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			var neighbors := [cur + Vector2i.RIGHT, cur + Vector2i.LEFT, cur + Vector2i.UP, cur + Vector2i.DOWN]
			var zone: String = seen[cur]
			var across := SeaFerry.destination(zone)
			if landing_chunks.get(zone) == cur and landing_chunks.has(across):
				neighbors.append(landing_chunks[across])
			for nb: Vector2i in neighbors:
				if seen.has(nb) and not reach.has(nb):
					reach[nb] = true
					stack.append(nb)
		if reach.size() != seen.size():
			errs.append("чанки не образуют единую область (%d из %d связаны)" % [reach.size(), seen.size()])
	return errs
