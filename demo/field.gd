class_name DemoField
extends Node2D
## Карта для демо: гавань, луга и лес на одной полосе. Герой бежит по касанию или клавишам (стрелки, WASD),
## врагов видно на карте, при контакте начинается бой. Земля, деревья и дома нарисованы плитками (Kenney, CC0).

signal enemy_contact(index: int)
signal npc_contact(npc_id: String)
signal zone_changed(zone_id: String)

const MAP := Vector2(3000, 1700)
const SPEED := 330.0
const ZONES := {
	"z_harbor": {"rect": Rect2(0, 0, 900, 1700), "color": Color("6a8f4e"), "name": "Порт Эверхейм"},
	"z_meadow": {"rect": Rect2(900, 0, 1100, 1700), "color": Color("7fae52"), "name": "Луга Зари"},
	"z_forest": {"rect": Rect2(2000, 0, 1000, 1700), "color": Color("3f6b3a"), "name": "Шепчущий лес"},
}
const NPC_POS := {"npc_orvin": Vector2(520, 820)}
const ROAD := [Vector2(130, 900), Vector2(520, 880), Vector2(900, 860), Vector2(1400, 780), Vector2(1900, 800), Vector2(2400, 700), Vector2(2900, 760)]
## Дома гавани: левый верхний угол в плитках (3x3), стиль крыши.
const HOUSES := [[4, 7, "red"], [10, 6, "grey"], [5, 17, "grey"], [11, 18, "red"]]

var hero_pos := Vector2(380, 900)
var target := Vector2(380, 900)
var has_target := false
var zone_id := "z_harbor"
var frozen := false
var groups: Array[Dictionary] = []
var camera: Camera2D
var monsters: Dictionary = {}
var quest_marker := true
var hero_sprite := "knight"
var _t := 0.0
var _npc_armed := true
var _facing := 1.0
var _moving := false
var _ground: GroundLayer


## Статичный слой: земля, дороги, дома и деревья. Рисуется один раз и кешируется.
class GroundLayer extends Node2D:
	var trees: Array[Vector3] = []

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var T := float(Art.TILE)
		var cols := int(ceil(DemoField.MAP.x / T))
		var rows := int(ceil(DemoField.MAP.y / T))
		var road_tiles := {}
		for ty in rows:
			for tx in cols:
				var c := Vector2(tx * T + T * 0.5, ty * T + T * 0.5)
				if _near_road(c, 50.0):
					road_tiles[Vector2i(tx, ty)] = true
		for ty in rows:
			for tx in cols:
				var p := Vector2(tx * T, ty * T)
				var zone := DemoField.zone_at(p + Vector2(T, T) * 0.5)
				var tint := Color.WHITE
				var tex: Texture2D
				if tx < 2:
					tex = Art.tile("water" if (tx + ty) % 2 == 0 else "water_b")
				elif tx == 2:
					tex = Art.tile("dirt_a")
				elif road_tiles.has(Vector2i(tx, ty)):
					tex = Art.tile(["dirt", "dirt_a", "dirt_b"][rng.randi_range(0, 2)])
				else:
					var r := rng.randf()
					if zone == "z_forest":
						tint = Color(0.72, 0.86, 0.72)
						tex = Art.tile("grass_tufts" if r < 0.3 else "grass")
					elif r < 0.16:
						tex = Art.tile("grass_tufts")
					elif r < 0.22 and zone == "z_meadow":
						tex = Art.tile("grass_flowers")
					else:
						tex = Art.tile("grass")
				draw_texture_rect(tex, Rect2(p, Vector2(T, T)), false, tint)
		# дома
		for h in DemoField.HOUSES:
			_house(Vector2(int(h[0]), int(h[1])) * T, str(h[2]))
		# указатель
		draw_texture_rect(Art.tile("sign"), Rect2(Vector2(840, 780), Vector2(T, T)), false)
		# деревья по глубине
		var sorted := trees.duplicate()
		sorted.sort_custom(func(a: Vector3, b: Vector3): return a.y < b.y)
		for t in sorted:
			var names := ["tree_round", "tree_pine", "bush"]
			var idx := int(t.z)
			if DemoField.zone_at(Vector2(t.x, t.y)) == "z_forest":
				names = ["tree_pine", "tree_round", "tree_autumn", "tree_pine", "bush"]
			var pick: String = names[idx % names.size()]
			var tex2: Texture2D = Art.tile(pick)
			var sz := T * (0.85 if pick == "bush" else 1.0)
			draw_texture_rect(tex2, Rect2(Vector2(t.x - sz * 0.5, t.y - sz), Vector2(sz, sz)), false)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(200, 380), "ПОРТ ЭВЕРХЕЙМ", HORIZONTAL_ALIGNMENT_CENTER, 500, 36, Color(1, 1, 1, 0.65))
		draw_string(font, Vector2(1250, 110), "ЛУГА ЗАРИ", HORIZONTAL_ALIGNMENT_CENTER, 500, 36, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(2250, 110), "ШЕПЧУЩИЙ ЛЕС", HORIZONTAL_ALIGNMENT_CENTER, 500, 36, Color(1, 1, 1, 0.6))

	func _house(origin: Vector2, style: String) -> void:
		var T := float(Art.TILE)
		var pre := "roof" if style == "red" else "roofg"
		var wall := ["wall_window", "wall_door", "wall"] if style == "red" else ["wallg_window", "wallg_door", "wallg"]
		var rows := [
			[pre + "_top_l", pre + "_top_m", pre + "_top_r"],
			[pre + "_mid_l", pre + "_mid_m", pre + "_mid_r"],
			wall,
		]
		for r in 3:
			for c in 3:
				draw_texture_rect(Art.tile(rows[r][c]), Rect2(origin + Vector2(c, r) * T, Vector2(T, T)), false)

	static func _near_road(p: Vector2, dist: float) -> bool:
		for i in DemoField.ROAD.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, DemoField.ROAD[i], DemoField.ROAD[i + 1])
			if q.distance_to(p) <= dist:
				return true
		return false


func setup(gd: GameData) -> void:
	monsters = gd.monsters
	var spawns := [
		["enc_meadow_slimes", Vector2(1250, 450)], ["enc_meadow_slimes", Vector2(1450, 1250)],
		["enc_meadow_wolves", Vector2(1700, 800)],
		["enc_forest_wolves", Vector2(2350, 420)], ["enc_forest_bandits", Vector2(2650, 1000)], ["enc_forest_wolves", Vector2(2400, 1400)],
	]
	for s in spawns:
		var enc: Dictionary = gd.encounters[s[0]]
		groups.append({"enc": enc, "id": str(s[0]), "pos": s[1], "alive": true, "back_at": 0.0})
	_ground = GroundLayer.new()
	_ground.z_index = -5
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var house_rects: Array[Rect2] = []
	for h in HOUSES:
		house_rects.append(Rect2(Vector2(int(h[0]), int(h[1])) * float(Art.TILE) - Vector2(30, 30), Vector2(3, 3) * float(Art.TILE) + Vector2(60, 60)))
	for i in 220:
		var x := rng.randf_range(180, MAP.x - 40)
		var y := rng.randf_range(80, MAP.y - 20)
		var p := Vector2(x, y)
		var z := zone_at(p)
		var dense := z == "z_forest"
		if GroundLayer._near_road(p, 95.0):
			continue
		var blocked := false
		for hr in house_rects:
			if hr.has_point(p):
				blocked = true
		if blocked or p.distance_to(NPC_POS["npc_orvin"]) < 150.0 or p.distance_to(hero_pos) < 140.0:
			continue
		if z == "z_harbor" and rng.randf() < 0.75:
			continue
		if not dense and rng.randf() < 0.55:
			continue
		for g in groups:
			if p.distance_to(g["pos"]) < 130.0:
				blocked = true
		if blocked:
			continue
		_ground.trees.append(Vector3(x, y, float(rng.randi_range(0, 4))))
	add_child(_ground)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP.x)
	camera.limit_bottom = int(MAP.y)
	camera.position = hero_pos
	add_child(camera)


static func zone_at(p: Vector2) -> String:
	for id in ZONES:
		if (ZONES[id]["rect"] as Rect2).has_point(p):
			return id
	return "z_forest" if p.x >= 2000.0 else "z_harbor"


func respawn_ready(now: float) -> void:
	for g in groups:
		if not g["alive"] and now >= float(g["back_at"]):
			g["alive"] = true


func mark_defeated(index: int, back_at: float) -> void:
	groups[index]["alive"] = false
	groups[index]["back_at"] = back_at


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = get_global_mouse_position().clamp(Vector2(30, 30), MAP - Vector2(30, 30))
		has_target = true
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		target = get_global_mouse_position().clamp(Vector2(30, 30), MAP - Vector2(30, 30))
		has_target = true


func _process(delta: float) -> void:
	_t += delta
	_moving = false
	if not frozen:
		var key := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
		var before := hero_pos
		if key != Vector2.ZERO:
			has_target = false
			hero_pos += key.normalized() * SPEED * delta
		elif has_target:
			var to := target - hero_pos
			var step := SPEED * delta
			if to.length() <= step:
				hero_pos = target
				has_target = false
			else:
				hero_pos += to.normalized() * step
		hero_pos = hero_pos.clamp(Vector2(140, 30), MAP - Vector2(30, 30))
		var dx := hero_pos.x - before.x
		if absf(dx) > 0.01:
			_facing = 1.0 if dx > 0.0 else -1.0
		_moving = hero_pos.distance_to(before) > 0.01
		var z := zone_at(hero_pos)
		if z != zone_id:
			zone_id = z
			zone_changed.emit(z)
		for i in groups.size():
			var g: Dictionary = groups[i]
			if g["alive"] and hero_pos.distance_to(g["pos"]) < 70.0:
				has_target = false
				enemy_contact.emit(i)
				break
		var near := hero_pos.distance_to(NPC_POS["npc_orvin"])
		if near < 90.0 and _npc_armed:
			_npc_armed = false
			has_target = false
			npc_contact.emit("npc_orvin")
		elif near > 180.0:
			_npc_armed = true
	camera.position = hero_pos
	queue_redraw()


func _sprite(name: String, center: Vector2, size: float, flip := 1.0) -> void:
	var r := Rect2(center - Vector2(size * 0.5 * flip, size * 0.82), Vector2(size * flip, size))
	draw_texture_rect(Art.character(name), r, false)


func _shadow(center: Vector2, radius: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# NPC
	var np: Vector2 = NPC_POS["npc_orvin"]
	_shadow(np + Vector2(0, 8), 30)
	_sprite("captain", np, float(Art.CHAR))
	draw_string(font, np + Vector2(-100, -88), "Капитан Орвин", HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color.WHITE)
	if quest_marker:
		draw_string(font, np + Vector2(-10, -102 + sin(_t * 4.0) * 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 40, Color("ffe066"))
	# враги
	for g in groups:
		if not g["alive"]:
			continue
		var enc: Dictionary = g["enc"]
		var p: Vector2 = g["pos"]
		var n := mini((enc["enemies"] as Array).size(), 4)
		_shadow(p + Vector2(0, 30), 60)
		for k in n:
			var m: Dictionary = monsters[enc["enemies"][k]["monster"]]
			var off := Vector2(cos(k * TAU / n + 0.6) * 34.0, sin(k * TAU / n + 0.6) * 20.0) if n > 1 else Vector2.ZERO
			var bob := sin(_t * 3.0 + k * 1.7 + p.x) * 3.0
			_sprite(Art.monster_sprite(str(m["id"])), p + off + Vector2(0, bob), 64.0)
		draw_arc(p + Vector2(0, 10), 68, 0.0, TAU, 32, Color(1, 0.3, 0.25, 0.5), 2.0)
		draw_string(font, p + Vector2(-110, -70), "%s (%d)" % [enc["name"], (enc["enemies"] as Array).size()], HORIZONTAL_ALIGNMENT_CENTER, 220, 16, Color(1, 0.94, 0.9))
	# цель
	if has_target:
		draw_arc(target, 16 + sin(_t * 8.0) * 3.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 3.0)
		draw_line(hero_pos, target, Color(1, 1, 1, 0.25), 2.0)
	# герой
	var hop := absf(sin(_t * 14.0)) * 6.0 if _moving else 0.0
	_shadow(hero_pos + Vector2(0, 8), 28)
	_sprite(hero_sprite, hero_pos + Vector2(0, -hop), float(Art.CHAR), _facing)
