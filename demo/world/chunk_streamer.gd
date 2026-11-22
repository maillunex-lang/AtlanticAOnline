class_name ChunkStreamer
extends Node2D
## Потоковая подгрузка чанков мира (WP-22A). Держит загруженными чанки вокруг героя, дальние выгружает.
## Сцены грузятся в фоновом потоке (ResourceLoader.load_threaded_*), в кадр создаётся не больше `max_instances_per_frame` чанков,
## поэтому рывков нет. Что и где лежит описывает манифест: {"chunk_tiles": 32, "chunks": [{"x": 0, "y": 0, "scene": "res://...", "zone": "z_id"}]}.
## Чанк это сцена с корнем LocationChunk (слои Ground и Objects), размер 32x32 плитки.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

var grid := ChunkGrid.new()
var max_instances_per_frame := 1
## Для тестов: грузить синхронно в update().
var use_threads := true

var manifest: Dictionary = {}
var existing: Dictionary = {}
var nodes: Dictionary = {}
var _pending: Dictionary = {}
var stats := {"loaded_total": 0, "unloaded_total": 0, "peak_loaded": 0, "peak_nodes": 0, "max_update_ms": 0.0, "max_instance_ms": 0.0, "instance_ms_total": 0.0}


func setup(p_manifest: Dictionary, p_grid: ChunkGrid, max_per_frame := 1) -> void:
	manifest = p_manifest
	grid = p_grid
	max_instances_per_frame = max_per_frame
	existing.clear()
	for c in manifest["chunks"]:
		existing[Vector2i(int(c["x"]), int(c["y"]))] = c


static func read_manifest(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func is_loaded(coord: Vector2i) -> bool:
	return nodes.has(coord)


func is_loaded_at(pos: Vector2) -> bool:
	return nodes.has(grid.coord_of(pos))


func chunk_at(pos: Vector2) -> LocationChunk:
	return nodes.get(grid.coord_of(pos)) as LocationChunk


## Точка непроходима, если в ней непроходимая плитка. Незагруженный существующий чанк считается непроходимым (ждём подгрузки).
func blocked_at(pos: Vector2) -> bool:
	var k := grid.coord_of(pos)
	if not existing.has(k):
		return true
	var c := nodes.get(k) as LocationChunk
	return c == null or c.is_blocked_at(pos)


func zone_at(pos: Vector2) -> String:
	var k := grid.coord_of(pos)
	return str((existing[k] as Dictionary).get("zone", "")) if existing.has(k) else ""


## Вызывать каждый кадр с позицией героя (глобальные координаты мира).
func update(hero_pos: Vector2) -> void:
	var t0 := Time.get_ticks_usec()
	var tracked: Array = nodes.keys() + _pending.keys()
	var plan := grid.plan(hero_pos, existing, tracked)
	for k in plan["unload"]:
		_unload(k)
	for k in plan["load"]:
		if not _pending.has(k):
			_request(k)
	_poll()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	stats["max_update_ms"] = maxf(float(stats["max_update_ms"]), ms)
	stats["peak_loaded"] = maxi(int(stats["peak_loaded"]), nodes.size())
	stats["peak_nodes"] = maxi(int(stats["peak_nodes"]), get_tree().get_node_count() if is_inside_tree() else 0)


func _request(k: Vector2i) -> void:
	var path: String = (existing[k] as Dictionary)["scene"]
	if use_threads:
		ResourceLoader.load_threaded_request(path)
	_pending[k] = path


func _poll() -> void:
	var made := 0
	for k in _pending.keys():
		if made >= max_instances_per_frame:
			break
		var path: String = _pending[k]
		var res: PackedScene = null
		if use_threads:
			var st := ResourceLoader.load_threaded_get_status(path)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			if st != ResourceLoader.THREAD_LOAD_LOADED:
				push_error("ChunkStreamer: не удалось загрузить %s" % path)
				_pending.erase(k)
				continue
			res = ResourceLoader.load_threaded_get(path) as PackedScene
		else:
			res = load(path) as PackedScene
		_pending.erase(k)
		var t0 := Time.get_ticks_usec()
		var inst := res.instantiate() as Node2D
		inst.position = Vector2(k) * grid.chunk_px()
		add_child(inst)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		stats["max_instance_ms"] = maxf(float(stats["max_instance_ms"]), ms)
		stats["instance_ms_total"] = float(stats["instance_ms_total"]) + ms
		nodes[k] = inst
		stats["loaded_total"] = int(stats["loaded_total"]) + 1
		made += 1
		chunk_loaded.emit(k)


func _unload(k: Vector2i) -> void:
	if _pending.has(k):
		# Запрос уже ушёл в поток: дождёмся результата в _poll и выгрузим при следующем плане.
		return
	var n := nodes.get(k) as Node
	if n != null:
		nodes.erase(k)
		n.queue_free()
		stats["unloaded_total"] = int(stats["unloaded_total"]) + 1
		chunk_unloaded.emit(k)


func loaded_coords() -> Array:
	return nodes.keys()
