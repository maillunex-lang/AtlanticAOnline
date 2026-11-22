class_name WorldView
extends Node2D
## Единый бесшовный мир: чанки 32x32 плитки подгружаются вокруг героя (ChunkStreamer, манифест data/chunks.json), герой, камера.
## Движение по касанию, клавишам или джойстику, столкновение с непроходимыми плитками, контакт с врагами и NPC.
## Враги и NPC живут в чанках; состояние (побеждённые враги, отметки заданий) хранится здесь и переживает выгрузку чанков.

signal enemy_contact(spawn: EnemySpawn)
signal npc_contact(npc_id: String)
signal zone_changed(zone_id: String, zone_name: String)

const SPEED := 330.0
const FEET_RADIUS := 16.0
const FOREST_GLOW := preload("res://assets/world/layers/forest_glow.tres")

## Загруженные сейчас чанки, враги и NPC в них (обновляются при подгрузке и выгрузке).
var chunks: Array[LocationChunk] = []
var spawns: Array[EnemySpawn] = []
var npcs: Array[NpcMarker] = []
var bounds := Rect2()
var frozen := false
var has_target := false
var target := Vector2.ZERO
var joystick := Vector2.ZERO
var zone_id := ""
var gd: GameData
var manifest: Dictionary = {}
var streamer: ChunkStreamer
var grid: ChunkGrid
var _facing := 1.0
var _moving := false
var _stuck := 0.0
var _armed: Dictionary = {}
var _defeated: Dictionary = {}
var _quest_markers: Dictionary = {}
var _entities: Dictionary = {}
var _road_open := false

@onready var hero: Node2D = $Hero
var _hero_animation: HeroAnimation
var _hero_direction := "south"

@onready var hero_sprite: Sprite2D = $Hero/Sprite
@onready var camera: Camera2D = $Camera2D


## Данные игры нужны до входа в дерево сцены. Без вызова мир загрузит их сам (для тестов и редактора).
func configure(p_gd: GameData) -> void:
	gd = p_gd
	grid = ChunkGrid.from_rules(gd.rules)
	manifest = ChunkStreamer.read_manifest("res://data/chunks.json")


func _ready() -> void:
	if gd == null:
		configure(GameData.load_dir())
	streamer = $Chunks as ChunkStreamer
	streamer.setup(manifest, grid, int(gd.rules["chunks"]["max_instances_per_frame"]))
	streamer.chunk_loaded.connect(_on_chunk_loaded)
	streamer.chunk_unloaded.connect(_on_chunk_unloaded)
	var first := true
	for k in streamer.existing:
		bounds = grid.rect_of(k) if first else bounds.merge(grid.rect_of(k))
		first = false
	var st: Array = manifest["start"]
	hero.position = Vector2(float(st[0]) + 0.5, float(st[1]) + 0.5) * grid.tile_px
	streamer.prime(hero.position)
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.position = hero.position
	camera.reset_smoothing()
	zone_id = _zone_here()


func set_hero_animation(hero_class: String) -> void:
	_hero_animation = HeroAnimation.create_for(hero_class)
	if _hero_animation == null:
		return
	hero.add_child(_hero_animation)
	_hero_animation.play(&"idle_south")
	hero_sprite.hide()


func setup_content(p_gd: GameData) -> void:
	gd = p_gd
	for s in spawns:
		_setup_spawn(s)
	for n in npcs:
		_setup_npc(n)


func _spawn_key(s: EnemySpawn) -> String:
	return "%s@%d,%d" % [s.encounter_id, int(s.global_position.x), int(s.global_position.y)]


func _setup_spawn(s: EnemySpawn) -> void:
	if gd.encounters.has(s.encounter_id):
		s.setup(gd.encounters[s.encounter_id], gd.monsters)
	if _defeated.has(_spawn_key(s)):
		s.set_alive(false)


func _setup_npc(n: NpcMarker) -> void:
	if gd.npcs.has(n.npc_id):
		n.setup(gd.npcs[n.npc_id])
	n.set_quest_marker(bool(_quest_markers.get(n.npc_id, false)))


func _on_chunk_loaded(coord: Vector2i) -> void:
	var c := streamer.nodes[coord] as LocationChunk
	chunks.append(c)
	if c.zone_id == "z_forest":
		var ground: TileMapLayer = c.get_node("Ground")
		for point in [Vector2(560, 750), Vector2(1500, 1250)]:
			var glow := Sprite2D.new()
			glow.texture = FOREST_GLOW
			glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			glow.position = point
			glow.scale = Vector2(2.2, 1.5)
			ground.add_child(glow)
	var mine := {"spawns": [], "npcs": [], "chunk": c}
	for child in c.get_children():
		if child is EnemySpawn:
			spawns.append(child)
			mine["spawns"].append(child)
			_setup_spawn(child)
		elif child is NpcMarker:
			npcs.append(child)
			mine["npcs"].append(child)
			_setup_npc(child)
	_entities[coord] = mine
	_update_beacon(c)


func set_road_open(open: bool) -> void:
	if _road_open == open:
		return
	_road_open = open
	for chunk in chunks:
		_update_beacon(chunk)


func _update_beacon(chunk: LocationChunk) -> void:
	var beacon := chunk.get_node_or_null("SignalBeacon") as CanvasItem
	if beacon != null:
		beacon.visible = _road_open


func _on_chunk_unloaded(coord: Vector2i) -> void:
	var mine: Dictionary = _entities.get(coord, {})
	for s in mine.get("spawns", []):
		spawns.erase(s)
	for n in mine.get("npcs", []):
		npcs.erase(n)
		_armed.erase((n as NpcMarker).npc_id)
	chunks.erase(mine.get("chunk"))
	_entities.erase(coord)


func chunk_at(p: Vector2) -> LocationChunk:
	return streamer.chunk_at(p)


func zone_name_of(id: String) -> String:
	for z in gd.world["zones"]:
		if z["id"] == id:
			return str(z["name"])
	return id


func has_zone_scene(id: String) -> bool:
	for entry in streamer.existing.values():
		if entry.get("zone") == id:
			return true
	return false


func arrival_point(id: String) -> Vector2:
	if id == gd.world["start_zone"]:
		var start: Array = manifest["start"]
		return (Vector2(float(start[0]), float(start[1])) + Vector2(0.5, 0.5)) * grid.tile_px
	for coord in streamer.existing:
		if streamer.existing[coord].get("zone") != id:
			continue
		var rect := grid.rect_of(coord)
		streamer.prime(rect.get_center())
		for y in grid.chunk_tiles:
			for x in grid.chunk_tiles:
				var tile := Vector2((x + grid.chunk_tiles / 2) % grid.chunk_tiles, (y + grid.chunk_tiles / 2) % grid.chunk_tiles)
				var point := rect.position + (tile + Vector2(0.5, 0.5)) * grid.tile_px
				if not _blocked(point):
					return point
	return Vector2.INF


func arrive_at(point: Vector2, id: String) -> void:
	hero.position = point
	has_target = false
	streamer.prime(point)
	camera.position = point
	camera.reset_smoothing()
	zone_id = id
	zone_changed.emit(id, zone_name_of(id))


func _zone_here() -> String:
	var z := streamer.zone_at(hero.position)
	return z if z != "" else zone_id


func respawn_ready(now: float) -> void:
	for key in _defeated.keys():
		if now >= float(_defeated[key]):
			_defeated.erase(key)
	for s in spawns:
		if not s.alive and not _defeated.has(_spawn_key(s)):
			s.set_alive(true)


func mark_defeated(s: EnemySpawn, back_at: float) -> void:
	s.back_at = back_at
	_defeated[_spawn_key(s)] = back_at
	s.set_alive(false)


func set_quest_marker(npc_id: String, on: bool) -> void:
	_quest_markers[npc_id] = on
	for n in npcs:
		if n.npc_id == npc_id:
			n.set_quest_marker(on)


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = get_global_mouse_position()
		has_target = true
		_stuck = 0.0
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		target = get_global_mouse_position()
		has_target = true


func _blocked(p: Vector2) -> bool:
	if not bounds.grow(-8.0).has_point(p):
		return true
	for off in [Vector2.ZERO, Vector2(FEET_RADIUS, 0), Vector2(-FEET_RADIUS, 0)]:
		if streamer.blocked_at(p + off):
			return true
	return false


func _move(step: Vector2) -> bool:
	var moved := false
	var nx := hero.position + Vector2(step.x, 0.0)
	if step.x != 0.0 and not _blocked(nx):
		hero.position = nx
		moved = true
	var ny := hero.position + Vector2(0.0, step.y)
	if step.y != 0.0 and not _blocked(ny):
		hero.position = ny
		moved = true
	return moved


func _process(delta: float) -> void:
	_moving = false
	if not frozen:
		var key := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
		var dir := Vector2.ZERO
		if joystick != Vector2.ZERO:
			has_target = false
			dir = joystick
		elif key != Vector2.ZERO:
			has_target = false
			dir = key.normalized()
		elif has_target:
			var to := target - hero.position
			if to.length() <= SPEED * delta:
				dir = to / maxf(delta * SPEED, 0.001)
				has_target = false
			else:
				dir = to.normalized()
		if dir != Vector2.ZERO:
			var before := hero.position
			_moving = _move(dir * SPEED * delta)
			if _moving:
				_hero_direction = HeroAnimation.facing(hero.position - before)
			if absf(dir.x) > 0.05:
				_facing = 1.0 if dir.x > 0.0 else -1.0
			if has_target and not _moving:
				_stuck += delta
				if _stuck > 0.25:
					has_target = false
			else:
				_stuck = 0.0
		var z := _zone_here()
		if z != zone_id:
			zone_id = z
			zone_changed.emit(z, zone_name_of(z))
		for s in spawns:
			if s.alive and hero.global_position.distance_to(s.global_position) < s.contact_radius:
				has_target = false
				enemy_contact.emit(s)
				break
		for n in npcs:
			var near := hero.global_position.distance_to(n.global_position)
			if near < n.talk_radius and bool(_armed.get(n.npc_id, true)):
				_armed[n.npc_id] = false
				has_target = false
				npc_contact.emit(n.npc_id)
			elif near > 180.0:
				_armed[n.npc_id] = true
	if _hero_animation != null:
		_hero_animation.play(StringName("%s_%s" % ["walk" if _moving else "idle", _hero_direction]))
	else:
		hero_sprite.flip_h = _facing < 0.0
		hero_sprite.position.y = -32.0 - (absf(sin(Time.get_ticks_msec() / 1000.0 * 14.0)) * 6.0 if _moving else 0.0)
	camera.position = hero.position
	streamer.update(hero.position)


# Источник данных для миникарты (см. Minimap).
func minimap_size() -> Vector2:
	return bounds.size


func minimap_zones() -> Array:
	var rects := {}
	for k in streamer.existing:
		var zone := str(streamer.existing[k]["zone"])
		var r := grid.rect_of(k)
		rects[zone] = (rects[zone] as Rect2).merge(r) if rects.has(zone) else r
	var out: Array = []
	for zone in rects:
		var r: Rect2 = rects[zone]
		out.append({"rect": Rect2(r.position - bounds.position, r.size), "color": Color(str(manifest["zones"][zone]["color"]))})
	return out


func minimap_enemies() -> Array:
	var out: Array = []
	for s in spawns:
		if s.alive:
			out.append(s.global_position - bounds.position)
	return out


func minimap_npcs() -> Array:
	var out: Array = []
	for n in npcs:
		out.append(n.global_position - bounds.position)
	return out


func minimap_hero() -> Vector2:
	return hero.global_position - bounds.position
