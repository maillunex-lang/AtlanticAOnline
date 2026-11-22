class_name PlayerWorld
extends RefCounted
## Состояние игрока в мире: где находится, что открыто, движение, запас хода и перезарядка столкновений.
## Время передаётся явно (секунды), поэтому поведение детерминировано и тестируется без часов.

var gd: GameData
var graph: WorldGraph
var zone_id := ""
var discovered: Dictionary = {}
var favorites: Dictionary = {}

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


## Регион, в котором сейчас игрок.
func region() -> String:
	return gd.region_of_zone(zone_id)


func will_max() -> int:
	return int(gd.rules["world"]["will_max"])


## Запас хода (ресурс телепорта) на момент now: восстанавливается со временем до максимума.
func will_at(now: float) -> int:
	_sync_will(now)
	return _will


func restore_will(amount: int, now: float) -> void:
	_sync_will(now)
	_will = mini(will_max(), _will + maxi(0, amount))


func will_snapshot(now: float) -> Dictionary:
	_sync_will(now)
	return {"points": _will, "time": _will_time}


func restore_will_snapshot(saved: Dictionary) -> void:
	if not saved.is_empty():
		_will = clampi(int(saved["points"]), 0, will_max())
		_will_time = float(saved["time"])


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


## Мгновенный переход между уже посещёнными городами и форпостами за запас хода.
func teleport(dest: String, level: int, now: float) -> Dictionary:
	update(now)
	if traveling:
		return _fail("busy")
	if not graph.has_zone(dest):
		return _fail("unknown_zone")
	if not GameData.is_settlement(graph.zone_type(dest)):
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


func toggle_favorite(dest: String) -> bool:
	if not graph.has_zone(dest):
		return false
	if favorites.has(dest):
		favorites.erase(dest)
	else:
		favorites[dest] = true
	return favorites.has(dest)


## group_entrance задаётся состоянием группы, а не произвольным запросом игрока.
func map_quote(dest: String, level: int, now: float, licensed: bool, coins: int, bureau := false, group_entrance := "") -> Dictionary:
	update(now)
	if traveling:
		return _fail("busy")
	if not graph.has_zone(dest):
		return _fail("unknown_zone")
	if zone_id == dest:
		return _fail("already_there")
	if graph.min_level(dest) > level:
		return _fail("level_too_low")
	var cfg: Dictionary = gd.rules["world"]
	var target: Dictionary = graph.zones[dest]
	var is_free_capital := GameData.is_settlement(graph.zone_type(dest)) and bool(target.get("capital", false)) and level >= int(cfg["capital_free_level"])
	var is_free_entrance := dest == group_entrance and graph.zone_type(dest) == "dungeon"
	if not bureau and (is_free_capital or is_free_entrance):
		return {"ok": true, "will": 0, "coins": 0}
	if not GameData.is_settlement(graph.zone_type(dest)):
		return _fail("not_town")
	if not discovered.has(dest):
		return _fail("not_discovered")
	var gold_cost := 0
	if bureau:
		var origin: Dictionary = graph.zones[zone_id]
		if "travel_agent" not in origin.get("services", []) and "travel_agent" not in TownServices.services_at(gd, origin):
			return _fail("no_bureau")
		gold_cost = int(cfg["bureau_coin_cost"])
		if coins < gold_cost:
			return _fail("no_coins")
	elif not licensed:
		return _fail("no_license")
	var cost := int(cfg["teleport_cost"])
	if will_at(now) < cost:
		return _fail("no_will")
	return {"ok": true, "will": cost, "coins": gold_cost}


func map_teleport(dest: String, level: int, now: float, licensed: bool, wallet: Dictionary, bureau := false, group_entrance := "") -> Dictionary:
	var quote := map_quote(dest, level, now, licensed, int(wallet.get("coins", 0)), bureau, group_entrance)
	if not quote.ok:
		return quote
	_spend_will(int(quote.will), now)
	if int(quote.coins) > 0:
		wallet["coins"] = int(wallet["coins"]) - int(quote.coins)
	zone_id = dest
	discovered[dest] = true
	return quote


## Телепорт к цели задания: прыгает в посещённый город, ближайший к цели по времени пути (сама цель, если это посещённый город),
## дальше игрок идёт пешком. Возвращает {"ok", "error", "town", "seconds_left"}; seconds_left это путь от города до цели.
func teleport_toward(dest: String, level: int, now: float) -> Dictionary:
	update(now)
	if traveling:
		return _fail("busy")
	if not graph.has_zone(dest):
		return _fail("unknown_zone")
	var best := ""
	var best_s := INF
	for t in discovered:
		if not GameData.is_settlement(graph.zone_type(str(t))) or graph.min_level(str(t)) > level:
			continue
		var s := 0.0
		if str(t) != dest:
			var r := graph.shortest_path(str(t), dest, level)
			if r.path.is_empty():
				continue
			s = float(r.seconds)
		if s < best_s:
			best_s = s
			best = str(t)
	if best == "":
		return _fail("no_town")
	if best == zone_id:
		return _fail("already_there")
	var res := teleport(best, level, now)
	if not res.ok:
		return res
	return {"ok": true, "error": "", "town": best, "seconds_left": int(best_s)}


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
