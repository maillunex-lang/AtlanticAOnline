class_name DungeonRun
extends RefCounted
## Прохождение подземелья: вход по ключу, цепочка столкновений, награда в конце.
## Лимит игроков (max_players) задан в данных, группы появятся с социальными системами (GDD-08).

var zone_id := ""
var stages: Array[String] = []
var stage := 0
var max_players := 3
var reward_loot := ""


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


func current_encounter() -> String:
	return "" if finished() else stages[stage]


func finished() -> bool:
	return stage >= stages.size()


## Победа в текущем столкновении. Возвращает true, если подземелье пройдено.
func complete_stage() -> bool:
	if not finished():
		stage += 1
	return finished()
