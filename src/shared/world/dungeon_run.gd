class_name DungeonRun
extends RefCounted
## Прохождение подземелья: вход по ключу, цепочка столкновений, награда в конце.
## Лимит игроков (max_players) задан в данных, группы появятся с социальными системами (GDD-08).

var zone_id := ""
var stages: Array[String] = []
var stage := 0
var max_players := 3
var reward_loot := ""
## Игроки, вошедшие в подземелье (для группового входа).
var participants: Array[String] = []


## Войти в подземелье: нужно стоять у его входа, иметь уровень и ключ (ключ расходуется).
## Возвращает {"ok", "error", "run"}.
static func enter(world: PlayerWorld, inv: Inventory, level: int, now: float) -> Dictionary:
	world.update(now)
	if world.traveling:
		return {"ok": false, "error": "busy"}
	var z: Dictionary = world.graph.zones[world.zone_id]
	if z["type"] != "dungeon":
		return {"ok": false, "error": "not_dungeon"}
	if level < int(z["min_level"]):
		return {"ok": false, "error": "level_too_low"}
	var cfg: Dictionary = z["dungeon"]
	if not inv.take_material(str(cfg["key"]), 1):
		return {"ok": false, "error": "no_key"}
	var run := DungeonRun.new()
	run.zone_id = world.zone_id
	for s in cfg["stages"]:
		run.stages.append(str(s))
	run.max_players = int(cfg["max_players"])
	run.reward_loot = str(cfg["reward_loot"])
	return {"ok": true, "error": "", "run": run}


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
	for pid in party.members:
		run.participants.append(pid)
	return {"ok": true, "error": "", "run": run}


func current_encounter() -> String:
	return "" if finished() else stages[stage]


func finished() -> bool:
	return stage >= stages.size()


## Победа в текущем столкновении. Возвращает true, если подземелье пройдено.
func complete_stage() -> bool:
	if not finished():
		stage += 1
	return finished()
