class_name WorldView
extends Node2D
## Единый бесшовный мир: куски-локации (LocationChunk) в узле Chunks, герой, камера.
## Движение по касанию, клавишам или джойстику, столкновение с непроходимыми плитками, контакт с врагами и NPC.

signal enemy_contact(spawn: EnemySpawn)
signal npc_contact(npc_id: String)
signal zone_changed(zone_id: String, zone_name: String)

const SPEED := 330.0
const FEET_RADIUS := 16.0

@export var stream_margin := 200.0

var chunks: Array[LocationChunk] = []
var spawns: Array[EnemySpawn] = []
var npcs: Array[NpcMarker] = []
var bounds := Rect2()
var frozen := false
var has_target := false
var target := Vector2.ZERO
var joystick := Vector2.ZERO
var zone_id := ""
var _facing := 1.0
var _moving := false
var _stuck := 0.0
var _armed: Dictionary = {}

@onready var hero: Node2D = $Hero
@onready var hero_sprite: Sprite2D = $Hero/Sprite
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	var first := true
	for c in $Chunks.get_children():
		if c is LocationChunk:
			chunks.append(c)
			bounds = c.world_rect() if first else bounds.merge(c.world_rect())
			first = false
	for s in get_tree().get_nodes_in_group("enemy_spawn"):
		spawns.append(s)
	for n in get_tree().get_nodes_in_group("npc_marker"):
		npcs.append(n)
	var start := _find_start()
	if start != null:
		hero.global_position = start.global_position
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.position = hero.position
	camera.reset_smoothing()
	zone_id = _zone_here()


func setup_content(gd: GameData) -> void:
	for s in spawns:
		if gd.encounters.has(s.encounter_id):
			s.setup(gd.encounters[s.encounter_id], gd.monsters)
	for n in npcs:
		if gd.npcs.has(n.npc_id):
			n.setup(gd.npcs[n.npc_id])


func _find_start() -> Node2D:
	for c in chunks:
		var m := c.get_node_or_null("PlayerStart") as Node2D
		if m != null:
			return m
	return null


func chunk_at(p: Vector2) -> LocationChunk:
	for c in chunks:
		if c.world_rect().has_point(p):
			return c
	return null


func zone_name_of(id: String) -> String:
	for c in chunks:
		if c.zone_id == id:
			return c.zone_name
	return id


func _zone_here() -> String:
	var c := chunk_at(hero.position)
	return c.zone_id if c != null else zone_id


func respawn_ready(now: float) -> void:
	for s in spawns:
		if not s.alive and now >= s.back_at:
			s.set_alive(true)


func mark_defeated(s: EnemySpawn, back_at: float) -> void:
	s.back_at = back_at
	s.set_alive(false)


func set_quest_marker(npc_id: String, on: bool) -> void:
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
		var q: Vector2 = p + off
		var c := chunk_at(q)
		if c != null and c.is_blocked_at(q):
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
			_moving = _move(dir * SPEED * delta)
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
	hero_sprite.flip_h = _facing < 0.0
	hero_sprite.position.y = -32.0 - (absf(sin(Time.get_ticks_msec() / 1000.0 * 14.0)) * 6.0 if _moving else 0.0)
	camera.position = hero.position
	_stream()


func _stream() -> void:
	var vp := get_viewport_rect().size
	var view := Rect2(camera.get_screen_center_position() - vp * 0.5, vp).grow(stream_margin)
	for c in chunks:
		c.set_active(view.intersects(c.world_rect()))
