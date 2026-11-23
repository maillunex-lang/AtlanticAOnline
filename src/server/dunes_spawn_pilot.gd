class_name DunesSpawnPilot
extends RefCounted
## Закрытые автоматические бои с дозорными. Только сервер выбирает противника и определяет исход.

const ZONE := "z_dunes"
const QUEST := "q_drop_dunes"
const ENCOUNTER := "enc_dunes_drifters"
const BASE_PACKS := 3
const MAX_RESERVE := 2

var _data: GameData
var _repo: PlayerRepository
var _route: SouthRouteService
var _respawn: Dictionary = {}


func _init(data: GameData, repo: PlayerRepository, route: SouthRouteService) -> void:
	_data = data
	_repo = repo
	_route = route


func snapshot(account: int, character: int, population: int, now: float) -> Dictionary:
	var row := _repo.load_character(account, character)
	var log := QuestLog.new(_data)
	log.load_dict(row.get("quests", {}))
	var level := int(row.get("progress", {}).get("level", 1))
	var status := log.state(QUEST, null, level, now)
	return {
		"capacity": _capacity(population),
		"available": _available(population, now),
		"trophies": log.objective_count(QUEST, 0, null, level) if log.active.has(QUEST) else 0,
		"quest": status,
	}


func fight(account: int, character: int, population: int, now: float) -> String:
	var open := _available(population, now)
	var personal := open.is_empty()
	if personal and snapshot(account, character, population, now).quest != "active":
		return "no_pack"
	var key := "" if personal else open[0]
	var sim := _make_battle(account, character)
	var access := _route.register_battle(account, character, ENCOUNTER, now, sim, not personal)
	if not access.ok:
		return str(access.error)
	# A request resolves synchronously, so another peer cannot start this pack mid-fight.
	for _step in 400:
		if sim.winner != BattleSim.Winner.NONE:
			break
		var actor := sim.active_ids.find_custom(func(id): return sim.can_act(id).is_empty())
		if actor == -1:
			sim.end_turn()
		elif not sim.submit(BattleAI.choose(sim, sim.active_ids[actor])).ok:
			return "battle_action_failed"
	if sim.winner != BattleSim.Winner.SIDE_A:
		return "defeat"
	var result := _route.record_victory(account, character, ENCOUNTER, now, sim)
	if not result.ok:
		return str(result.error)
	if not personal:
		_respawn[key] = now + float(_data.encounters[ENCOUNTER]["respawn_seconds"])
	return "personal_victory" if personal else "shared_victory"


func _capacity(population: int) -> int:
	return 0 if population <= 0 else BASE_PACKS + mini((population - 1) * 2, MAX_RESERVE)


func _available(population: int, now: float) -> Array[String]:
	var open: Array[String] = []
	for index in _capacity(population):
		var key := "dunes_pack_%d" % (index + 1)
		if now >= float(_respawn.get(key, 0.0)):
			open.append(key)
	return open


func _make_battle(account: int, character: int) -> BattleSim:
	var row := _repo.load_character(account, character)
	var level := int(row["progress"]["level"])
	# A fixed training roster is used by the two seeded pilot characters.
	var units: Array[BattleUnit] = []
	var hero := Squad.new(_data).create_hero(str(row["class_id"]))
	hero.set_level(level, _data)
	units.append(BattleUnit.from_mercenary(hero, _data, 1, BattleRules.SIDE_A, 1))
	var support := ["swordsman", "spearman", "archer", "adept", "axeman", "gunner"]
	var slots := [0, 2, 3, 4, 5, 7]
	for index in support.size():
		var merc := Mercenary.new(index + 1, support[index], _data)
		merc.set_level(level, _data)
		units.append(BattleUnit.from_mercenary(merc, _data, index + 2, BattleRules.SIDE_A, slots[index]))
	units.append_array(EncounterFactory.build_units(_data.encounters[ENCOUNTER], _data, level))
	return BattleSim.new(BattleRules.new(), units, 409, _data.skills)
