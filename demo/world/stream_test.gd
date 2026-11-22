extends Node2D
## Прототип бесшовного мира с потоковой подгрузкой чанков (WP-22A): ходьба по тестовому миру 5x5 чанков.
## Управление: касание или мышь (идти к точке), стрелки или WASD. Запуск: godot --path . res://scenes/world/stream_test.tscn
## Снимок: -- --shot=путь.png (через 90 кадров). Замеры без экрана: godot --path . res://scenes/world/stream_test.tscn -- --bench  (печатает итоги и выходит).

var manifest_path := "res://scenes/world/proto/manifest.json"
const SPEED := 330.0

var streamer: ChunkStreamer
var hero: Node2D
var camera: Camera2D
var label: Label
var target := Vector2.ZERO
var has_target := false
var _bench := false
var _frame := 0
var _route: Array[Vector2] = []
var _leg := 0
var _frame_ms: Array[float] = []
var _last_us := 0
var _spikes := 0
var _gap_frames := 0
var _shot := ""


func _ready() -> void:
	var gd := GameData.load_dir()
	var grid := ChunkGrid.from_rules(gd.rules)
	streamer = ChunkStreamer.new()
	streamer.name = "Chunks"
	add_child(streamer)
	# Параметры замеров: --manifest=путь, --load=пиксели, --unload=пиксели.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--manifest="):
			manifest_path = a.substr(11)
		elif a.begins_with("--load="):
			grid.load_margin = float(a.substr(7))
		elif a.begins_with("--unload="):
			grid.unload_margin = float(a.substr(9))
	var man := ChunkStreamer.read_manifest(manifest_path)
	grid.chunk_tiles = int(man["chunk_tiles"])
	streamer.setup(man, grid, int(gd.rules["chunks"]["max_instances_per_frame"]))
	hero = (load("res://scenes/world/hero.tscn") as PackedScene).instantiate()
	add_child(hero)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	hero.position = Vector2(80, 80) * grid.tile_px
	camera.position = hero.position
	camera.reset_smoothing()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
	_bench = "--bench" in OS.get_cmdline_user_args()
	if _bench:
		_make_route(grid)
		print("BENCH старт: чанков в мире %d, маршрут %d точек" % [streamer.existing.size(), _route.size()])
	# Чанк под героем должен быть готов до первого шага.
	for i in 400:
		streamer.update(hero.position)
		if streamer.is_loaded_at(hero.position):
			break
		await get_tree().process_frame


## Маршрут по мосту дорог через весь мир: восток, юг, запад, север, диагональ.
func _make_route(grid: ChunkGrid) -> void:
	var s := grid.tile_px
	for p in [Vector2(80, 80), Vector2(150, 80), Vector2(150, 150), Vector2(10, 150), Vector2(10, 10), Vector2(150, 10), Vector2(150, 80), Vector2(80, 80)]:
		_route.append(p * s)


func _unhandled_input(event: InputEvent) -> void:
	if _bench:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = get_global_mouse_position()
		has_target = true
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		target = get_global_mouse_position()
		has_target = true


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	var step_dt := delta
	if _bench:
		step_dt = 1.0 / 60.0
		if _leg < _route.size():
			var to := _route[_leg] - hero.position
			if to.length() < SPEED * step_dt * 1.5:
				_leg += 1
			else:
				dir = to.normalized()
		else:
			_finish()
			return
	else:
		var key := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
		if key != Vector2.ZERO:
			has_target = false
			dir = key.normalized()
		elif has_target:
			var to := target - hero.position
			if to.length() <= SPEED * delta:
				has_target = false
			else:
				dir = to.normalized()
	if dir != Vector2.ZERO:
		var step := dir * SPEED * step_dt
		var nx := hero.position + Vector2(step.x, 0.0)
		if not streamer.blocked_at(nx) or _bench:
			hero.position = nx
		var ny := hero.position + Vector2(0.0, step.y)
		if not streamer.blocked_at(ny) or _bench:
			hero.position = ny
	camera.position = hero.position
	streamer.update(hero.position)
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := (now - _last_us) / 1000.0
		_frame_ms.append(ms)
		if ms > 50.0:
			_spikes += 1
	_last_us = now
	_frame += 1
	if _shot != "" and _frame == 90:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
	# Пустое место на экране: видимая область пересекает существующий, но не загруженный чанк.
	var vp := get_viewport_rect().size
	var view := Rect2(camera.get_screen_center_position() - vp * 0.5, vp)
	for k in streamer.existing:
		if view.intersects(streamer.grid.rect_of(k)) and not streamer.is_loaded(k):
			_gap_frames += 1
			break
	label.text = "чанк %s, загружено %d, в очереди %d, FPS %d, узлов %d" % [str(streamer.grid.coord_of(hero.position)), streamer.nodes.size(),
		streamer._pending.size(), Engine.get_frames_per_second(), get_tree().get_node_count()]


func _finish() -> void:
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var s := streamer.stats
	print("BENCH кадров: %d, чанков загружено всего %d, выгружено %d, пик загруженных %d, пик узлов %d" % [_frame, s["loaded_total"], s["unloaded_total"], s["peak_loaded"], s["peak_nodes"]])
	print("BENCH создание чанка: среднее %.2f мс, максимум %.2f мс; update: максимум %.2f мс" % [float(s["instance_ms_total"]) / maxf(float(s["loaded_total"]), 1.0), s["max_instance_ms"], s["max_update_ms"]])
	print("BENCH кадр: медиана %.1f мс, p95 %.1f мс, p99 %.1f мс, максимум %.1f мс, кадров дольше 50 мс: %d" % [sorted[n / 2], sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1], _spikes])
	print("BENCH кадров с пустым местом на экране: %d" % _gap_frames)
	print("BENCH память: статическая %.1f МБ, видео %.1f МБ" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_tree().quit()
