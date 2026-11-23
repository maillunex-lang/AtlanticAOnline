class_name DungeonRun
extends RefCounted
## Прохождение подземелья: вход по ключу, цепочка столкновений, награда в конце.
## Лимит игроков (max_players) задан в данных, группы появятся с социальными системами (GDD-08).

var zone_id := ""
var stages: Array[String] = []
var stage := 0
var max_players := 3
var reward_loot := ""
var mechanisms: Dictionary = {}
var findings: Dictionary = {}
## Игроки, вошедшие в подземелье (для группового входа).
var participants: Array[String] = []


## Войти в подземелье: нужно стоять у его входа, иметь уровень и ключ (ключ расходуется).
## Возвращает {"ok", "error", "run"}.
static func enter(world: PlayerWorld, inv: Inventory, level: int, now: float, replay_wallet: Dictionary = {}, cleared_at: Dictionary = {}, replay_now := -1.0) -> Dictionary:
	world.update(now)
	if world.traveling:
		return {"ok": false, "error": "busy"}
	var z: Dictionary = world.graph.zones[world.zone_id]
	if z["type"] != "dungeon":
		return {"ok": false, "error": "not_dungeon"}
	if level < int(z["min_level"]):
		return {"ok": false, "error": "level_too_low"}
	var cfg: Dictionary = z["dungeon"]
	if not replay_wallet.is_empty():
		var replay: Dictionary = cfg.get("replay", {})
		if replay.is_empty():
			return {"ok": false, "error": "no_replay"}
		if replay_remaining(z, cleared_at, now if replay_now < 0.0 else replay_now) > 0:
			return {"ok": false, "error": "cooldown"}
		var price := int(replay["coins"])
		if int(replay_wallet.get("coins", 0)) < price:
			return {"ok": false, "error": "no_coins"}
		replay_wallet["coins"] = int(replay_wallet["coins"]) - price
	elif not inv.take_material(str(cfg["key"]), 1):
		return {"ok": false, "error": "no_key"}
	var run := DungeonRun.new()
	run.zone_id = world.zone_id
	for s in cfg["stages"]:
		run.stages.append(str(s))
	run.max_players = int(cfg["max_players"])
	run.reward_loot = str(cfg["reward_loot"])
	run.mechanisms = cfg.get("mechanisms", {}).duplicate(true)
	return {"ok": true, "error": "", "run": run}


static func replay_remaining(zone: Dictionary, cleared_at: Dictionary, now: float) -> int:
	var rules: Dictionary = zone.get("dungeon", {}).get("replay", {})
	if rules.is_empty() or not cleared_at.has(zone["id"]):
		return 0
	return maxi(0, ceili(float(cleared_at[zone["id"]]) + float(rules["cooldown_seconds"]) - now))


## Групповой вход: все участники у входа в подземелье, не в пути, достаточного уровня, группа не больше лимита.
## Ключ расходуется один раз из сумки лидера. worlds и levels: id игрока -> PlayerWorld и уровень.
static func enter_party(party: Party, worlds: Dictionary, levels: Dictionary, leader_inv: Inventory, now: float) -> Dictionary:
	var lw: PlayerWorld = worlds[party.leader]
	var z: Dictionary = lw.graph.zones[lw.zone_id]
	if z["type"] != "dungeon":
		return {"ok": false, "error": "not_dungeon"}
	var cfg: Dictionary = z["dungeon"]
	if party.members.size() > int(cfg["max_players"]):
		return {"ok": false, "error": "party_too_big"}
	for pid in party.members:
		var w: PlayerWorld = worlds[pid]
		w.update(now)
		if w.traveling or w.zone_id != lw.zone_id:
			return {"ok": false, "error": "member_not_here", "player": pid}
		if int(levels[pid]) < int(z["min_level"]):
			return {"ok": false, "error": "member_level_too_low", "player": pid}
	if not leader_inv.take_material(str(cfg["key"]), 1):
		return {"ok": false, "error": "no_key"}
	var run := DungeonRun.new()
	run.zone_id = lw.zone_id
	for s in cfg["stages"]:
		run.stages.append(str(s))
	run.max_players = int(cfg["max_players"])
	run.reward_loot = str(cfg["reward_loot"])
	run.mechanisms = cfg.get("mechanisms", {}).duplicate(true)
	for pid in party.members:
		run.participants.append(pid)
	return {"ok": true, "error": "", "run": run}


func solve(mechanism: String) -> bool:
	var rule: Dictionary = mechanisms.get(mechanism, {})
	if rule.is_empty() or finished() or stage != int(rule["stage"]) or findings.has(mechanism):
		return false
	var prior := str(rule.get("requires", ""))
	if not prior.is_empty() and not findings.has(prior):
		return false
	findings[mechanism] = true
	return true


func can_fight() -> bool:
	if finished():
		return false
	for id in mechanisms:
		if int(mechanisms[id]["stage"]) == stage and not findings.has(id):
			return false
	return true


func snapshot() -> Dictionary:
	return {"zone": zone_id, "stage": stage, "findings": findings.duplicate()}


static func restore(gd: GameData, saved: Dictionary) -> DungeonRun:
	var zone := str(saved.get("zone", ""))
	var graph := WorldGraph.new(gd.world)
	var cfg: Dictionary = graph.zones.get(zone, {}).get("dungeon", {})
	if cfg.is_empty():
		return null
	var index := int(saved.get("stage", -1))
	if index < 0 or index > (cfg["stages"] as Array).size():
		return null
	var run := DungeonRun.new()
	run.zone_id = zone
	run.stage = index
	run.stages.assign(cfg["stages"])
	run.max_players = int(cfg["max_players"])
	run.reward_loot = str(cfg["reward_loot"])
	run.mechanisms = cfg.get("mechanisms", {}).duplicate(true)
	for id in run.mechanisms:
		if saved.get("findings", {}).get(id, false) and int(run.mechanisms[id]["stage"]) <= index:
			run.findings[id] = true
	return run


func current_encounter() -> String:
	return "" if finished() else stages[stage]


func finished() -> bool:
	return stage >= stages.size()


## Победа в текущем столкновении. Возвращает true, если подземелье пройдено.
func complete_stage() -> bool:
	if can_fight():
		stage += 1
	return finished()
