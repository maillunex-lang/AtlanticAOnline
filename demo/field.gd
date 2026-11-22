class_name DemoField
extends Node2D
## Карта для демо: гавань, луга и лес на одной полосе. Герой бежит по касанию или клавишам (стрелки, WASD),
## врагов видно на карте, при контакте начинается бой. Всё рисуется кодом, без ассетов.

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

var hero_pos := Vector2(380, 900)
var target := Vector2(380, 900)
var has_target := false
var zone_id := "z_harbor"
var frozen := false
var groups: Array[Dictionary] = []
var camera: Camera2D
var monsters: Dictionary = {}
var quest_marker := true
var _t := 0.0
var _trees: Array[Vector3] = []
var _npc_armed := true
var _now := 0.0


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
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 140:
		var x := rng.randf_range(40, MAP.x - 40)
		var y := rng.randf_range(40, MAP.y - 40)
		var z := zone_at(Vector2(x, y))
		var dense := z == "z_forest"
		if z == "z_harbor" and x < 1400 and rng.randf() < 0.8:
			continue
		if not dense and rng.randf() < 0.55:
			continue
		if Vector2(x, y).distance_to(hero_pos) < 120:
			continue
		_trees.append(Vector3(x, y, rng.randf_range(0.8, 1.3)))
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
	_now = now
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
	if not frozen:
		var key := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
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
		hero_pos = hero_pos.clamp(Vector2(30, 30), MAP - Vector2(30, 30))
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


func _draw() -> void:
	for id in ZONES:
		draw_rect(ZONES[id]["rect"], ZONES[id]["color"])
	# узор травы
	for i in 220:
		var p := Vector2(fposmod(i * 197.0, MAP.x), fposmod(i * 311.0, MAP.y))
		draw_line(p, p + Vector2(4, -9), Color(0, 0.25, 0, 0.18), 2.0)
	# море у гавани
	draw_rect(Rect2(0, 0, 110, MAP.y), Color("2f6fa8"))
	for y in range(0, int(MAP.y), 60):
		draw_arc(Vector2(70 + sin(_t + y) * 8, y), 14, 0.2, 2.9, 8, Color(1, 1, 1, 0.25), 2.0)
	# дорога
	var road := PackedVector2Array([Vector2(130, 900), Vector2(520, 880), Vector2(900, 860), Vector2(1400, 780), Vector2(1900, 800), Vector2(2400, 700), Vector2(2900, 760)])
	draw_polyline(road, Color("b99b6b"), 70.0)
	draw_polyline(road, Color("cdb283"), 50.0)
	# границы зон
	draw_line(Vector2(900, 0), Vector2(900, MAP.y), Color(1, 1, 1, 0.15), 3.0)
	draw_line(Vector2(2000, 0), Vector2(2000, MAP.y), Color(1, 1, 1, 0.15), 3.0)
	# дома гавани
	for h in [Rect2(200, 560, 150, 110), Rect2(560, 520, 170, 120), Rect2(250, 1100, 160, 110), Rect2(640, 1130, 150, 110)]:
		draw_rect(h, Color("c9a77a"))
		draw_colored_polygon(PackedVector2Array([h.position + Vector2(-12, 0), h.position + Vector2(h.size.x * 0.5, -60), h.position + Vector2(h.size.x + 12, 0)]), Color("a14d3a"))
		draw_rect(Rect2(h.position.x + h.size.x * 0.4, h.position.y + h.size.y * 0.45, h.size.x * 0.2, h.size.y * 0.55), Color("5b3a22"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(330, 480), "ПОРТ ЭВЕРХЕЙМ", HORIZONTAL_ALIGNMENT_CENTER, 400, 34, Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(1250, 120), "ЛУГА ЗАРИ", HORIZONTAL_ALIGNMENT_CENTER, 500, 34, Color(1, 1, 1, 0.45))
	draw_string(font, Vector2(2250, 120), "ШЕПЧУЩИЙ ЛЕС", HORIZONTAL_ALIGNMENT_CENTER, 500, 34, Color(1, 1, 1, 0.4))
	# деревья
	for t in _trees:
		var s := t.z
		draw_rect(Rect2(t.x - 5 * s, t.y, 10 * s, 24 * s), Color("5b3a22"))
		draw_circle(Vector2(t.x, t.y - 6 * s), 30 * s, Color("2f5d2a"))
		draw_circle(Vector2(t.x - 8 * s, t.y - 14 * s), 22 * s, Color("3a7233"))
	# NPC
	var np: Vector2 = NPC_POS["npc_orvin"]
	draw_circle(np + Vector2(0, 26), 20, Color(0, 0, 0, 0.25))
	draw_circle(np, 24, Color("d9b25a"))
	draw_circle(np, 24, Color("7a5a14"), false, 3.0)
	draw_string(font, np + Vector2(-100, -38), "Капитан Орвин", HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color.WHITE)
	if quest_marker:
		draw_string(font, np + Vector2(-10, -58 + sin(_t * 4.0) * 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 40, Color("ffe066"))
	# враги
	for g in groups:
		if not g["alive"]:
			continue
		var enc: Dictionary = g["enc"]
		var p: Vector2 = g["pos"] + Vector2(0, sin(_t * 2.0 + g["pos"].x) * 4.0)
		draw_circle(p + Vector2(0, 38), 46, Color(0, 0, 0, 0.22))
		var n := mini((enc["enemies"] as Array).size(), 4)
		for k in n:
			var m: Dictionary = monsters[enc["enemies"][k]["monster"]]
			var off := Vector2(cos(k * TAU / n) * 26.0, sin(k * TAU / n) * 18.0) if n > 1 else Vector2.ZERO
			var col := Color.from_hsv(float(abs(str(m["id"]).hash()) % 100) / 100.0 * 0.1, 0.65, 0.75)
			draw_circle(p + off, 17, col.darkened(0.4))
			draw_circle(p + off, 14, col)
			draw_circle(p + off + Vector2(-4, -3), 2.5, Color.WHITE)
			draw_circle(p + off + Vector2(4, -3), 2.5, Color.WHITE)
		draw_arc(p, 52, 0.0, TAU, 28, Color(1, 0.3, 0.25, 0.55), 2.0)
		draw_string(font, p + Vector2(-90, -58), "%s (%d)" % [enc["name"], (enc["enemies"] as Array).size()], HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color(1, 0.92, 0.9))
	# цель
	if has_target:
		draw_arc(target, 16 + sin(_t * 8.0) * 3.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 3.0)
		draw_line(hero_pos, target, Color(1, 1, 1, 0.25), 2.0)
	# герой
	draw_circle(hero_pos + Vector2(0, 28), 24, Color(0, 0, 0, 0.3))
	draw_circle(hero_pos, 25, Color("1e3a6e"))
	draw_circle(hero_pos, 22, Color("5b8def"))
	draw_string(font, hero_pos + Vector2(-20, 11), "М", HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Color.WHITE)
