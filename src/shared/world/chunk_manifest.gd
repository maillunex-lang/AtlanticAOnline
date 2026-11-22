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
		seen[k] = true
		var scene := str(c.get("scene", ""))
		if scene == "" or not ResourceLoader.exists(scene):
			errs.append("чанк %s: нет сцены %s" % [str(k), scene])
		elif scenes.has(scene):
			errs.append("чанк %s: сцена %s уже у чанка %s" % [str(k), scene, str(scenes[scene])])
		scenes[scene] = k
		if str(c.get("zone", "")) == "":
			errs.append("чанк %s: не указана зона" % str(k))
	# Связность: все чанки образуют единую область (соседство по сторонам).
	if not seen.is_empty():
		var start: Vector2i = seen.keys()[0]
		var stack: Array[Vector2i] = [start]
		var reach := {start: true}
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if seen.has(nb) and not reach.has(nb):
					reach[nb] = true
					stack.append(nb)
		if reach.size() != seen.size():
			errs.append("чанки не образуют единую область (%d из %d связаны)" % [reach.size(), seen.size()])
	return errs
