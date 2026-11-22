class_name PlayerWorld
extends RefCounted
## Состояние игрока в мире: где находится, что открыто, движение, запас хода и перезарядка столкновений.
## Время передаётся явно (секунды), поэтому поведение детерминировано и тестируется без часов.

var gd: GameData
var graph: WorldGraph
var zone_id := ""
var discovered: Dictionary = {}

var traveling := false
var destination := ""
var arrive_at := 0.0
var _route: Array[String] = []

var _will := 0
var _will_time := 0.0
var _encounter_ready: Dictionary = {}


func _init(p_gd: GameData, now := 0.0) -> void:
	gd = p_gd
	graph = WorldGraph.new(gd.world)
	zone_id = graph.start_zone
	discovered[zone_id] = true
	_will = will_max()
	_will_time = now


func will_max() -> int:
	return int(gd.rules["world"]["will_max"])


## Запас хода (ресурс телепорта) на момент now: восстанавливается со временем до максимума.
func will_at(now: float) -> int:
	_sync_will(now)
	return _will


## Завершить путь, если время пришло. Возвращает true, если игрок только что прибыл.
func update(now: float) -> bool:
	if traveling and now >= arrive_at:
		traveling = false
		zone_id = destination
		for z in _route:
			discovered[z] = true
		_route = []
		return true
	return false


## Отправиться в зону пешком. Возвращает {"ok", "error", "seconds", "path"}.
func travel_to(dest: String, level: int, now: float) -> Dictionary:
	update(now)
	if traveling:
		return _fail("busy")
	if not graph.has_zone(dest):
		return _fail("unknown_zone")
	if dest == zone_id:
		return _fail("already_there")
	if graph.min_level(dest) > level:
		return _fail("level_too_low")
	var r := graph.shortest_path(zone_id, dest, level)
	if r.path.is_empty():
		return _fail("no_route")
	traveling = true
	destination = dest
	arrive_at = now + float(r.seconds)
	_route = []
	for z in r.path:
		_route.append(z)
	return {"ok": true, "error": "", "seconds": r.seconds, "path": r.path}


## Мгновенный переход между уже посещёнными городами за запас хода.
func teleport(dest: String, level: int, now: float) -> Dictionary:
	update(now)
	if traveling:
		return _fail("busy")
	if not graph.has_zone(dest):
		return _fail("unknown_zone")
	if graph.zone_type(dest) != "town":
		return _fail("not_town")
	if not discovered.has(dest):
		return _fail("not_discovered")
	if dest == zone_id:
		return _fail("already_there")
	if graph.min_level(dest) > level:
		return _fail("level_too_low")
	var cost := int(gd.rules["world"]["teleport_cost"])
	_sync_will(now)
	if _will < cost:
		return _fail("no_will")
	_spend_will(cost, now)
	zone_id = dest
	return {"ok": true, "error": ""}


## "" если можно начать бой со столкновением, иначе код ошибки.
func can_fight(enc_id: String, now: float) -> String:
	update(now)
	if traveling:
		return "busy"
	var enc := EncounterFactory.find(gd, enc_id)
	if enc.is_empty():
		return "unknown_encounter"
	if enc["zone"] != zone_id:
		return "wrong_zone"
	if graph.zone_type(zone_id) == "dungeon":
		return "dungeon_only"
	if float(_encounter_ready.get(enc_id, 0.0)) > now:
		return "respawning"
	return ""


func mark_cleared(enc_id: String, now: float) -> void:
	var enc := EncounterFactory.find(gd, enc_id)
	_encounter_ready[enc_id] = now + float(enc["respawn_seconds"])


func respawn_in(enc_id: String, now: float) -> float:
	return maxf(0.0, float(_encounter_ready.get(enc_id, 0.0)) - now)


func _sync_will(now: float) -> void:
	var step := float(gd.rules["world"]["will_regen_seconds_per_point"])
	if _will >= will_max():
		_will_time = now
		return
	var gained := int(floor((now - _will_time) / step))
	if gained > 0:
		_will = mini(will_max(), _will + gained)
		_will_time += gained * step
		if _will >= will_max():
			_will_time = now


func _spend_will(cost: int, now: float) -> void:
	if _will >= will_max():
		_will_time = now  # отсчёт восстановления начинается с траты
	_will -= cost


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
