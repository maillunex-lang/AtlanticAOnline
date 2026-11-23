class_name DunesSpawnPilot
extends RefCounted
## Сервер резервирует дозор и проверяет команды боя.

const ZONE := "z_dunes"
const QUEST := "q_drop_dunes"
const ENCOUNTER := "enc_dunes_drifters"
const BASE_PACKS := 3
const MAX_RESERVE := 2
const IDLE_TIMEOUT := 90.0

var _data: GameData
var _repo: PlayerRepository
var _route: SouthRouteService
var _respawn: Dictionary = {}
var _fights: Dictionary = {}
var _reserved: Dictionary = {}


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
	var open := _available(population, now)
	var cooldown: Dictionary = row.get("progress", {}).get("south_encounter_ready", {})
	return {
		"capacity": _capacity(population),
		"available": open,
		"personal": open.is_empty() and status == "active" and now >= float(cooldown.get(ENCOUNTER, 0.0)),
		"trophies": log.objective_count(QUEST, 0, null, level) if log.active.has(QUEST) else 0,
		"quest": status,
	}


func begin(account: int, character: int, population: int, now: float, pack: String) -> Dictionary:
	if in_battle(character):
		return {"outcome": "already_in_battle"}
	var open := _available(population, now)
	var personal := pack == "personal"
	if (personal and (not open.is_empty() or snapshot(account, character, population, now).quest != "active")) \
			or (not personal and pack not in open):
		return {"outcome": "no_pack"}
	var row := _repo.load_character(account, character)
	if row.is_empty():
		return {"outcome": "unknown_character"}
	var setup := {"class": row["class_id"], "level": int(row["progress"]["level"])}
	var sim := DunesBattle.build(_data, setup["class"], setup["level"])
	var access := _route.register_battle(account, character, ENCOUNTER, now, sim, not personal)
	if not access.ok:
		return {"outcome": str(access.error)}
	_fights[character] = {"sim": sim, "pack": pack, "until": now + IDLE_TIMEOUT}
	if not personal:
		_reserved[pack] = true
	return {"setup": setup, "outcome": "started"}


func in_battle(character: int) -> bool:
	return _fights.has(character)


func cancel(character: int) -> void:
	if in_battle(character):
		_reserved.erase(_fights[character]["pack"])
		_fights.erase(character)


func expire(character: int, now: float) -> bool:
	if not in_battle(character) or now < float(_fights[character]["until"]):
		return false
	cancel(character)
	return true


func command(account: int, character: int, now: float, action: Dictionary) -> Dictionary:
	if not in_battle(character):
		return {"outcome": "no_battle"}
	if expire(character, now):
		return {"outcome": "expired"}
	var kind: Variant = action.get("type")
	if kind == "flee":
		cancel(character)
		return {"outcome": "fled"}
	var fight: Dictionary = _fights[character]
	var sim: BattleSim = fight["sim"]
	if sim.current_side != BattleRules.SIDE_A or not _valid_command(action):
		return {"outcome": "bad_action"}
	var result := sim.end_turn() if kind == "end_turn" else sim.submit(action)
	if not result.ok:
		return {"outcome": str(result.error)}
	fight["until"] = now + IDLE_TIMEOUT
	var commands: Array = [action]
	while sim.winner == BattleSim.Winner.NONE and sim.current_side == BattleRules.SIDE_B:
		var actor := sim.active_ids.find_custom(func(id): return sim.can_act(id).is_empty())
		if actor < 0:
			sim.end_turn()
			commands.append({"type": "end_turn"})
		else:
			var actor_id := sim.active_ids[actor]
			var choice := BattleAI.choose(sim, actor_id)
			if not sim.submit(choice).ok:
				choice = {"type": "wait", "actor": actor_id}
				sim.submit(choice)
			commands.append(choice)
	if sim.winner == BattleSim.Winner.NONE:
		return {"commands": commands, "outcome": ""}
	var outcome := "defeat"
	if sim.winner == BattleSim.Winner.SIDE_A:
		var saved := _route.record_victory(account, character, ENCOUNTER, now, sim)
		var pack: String = fight["pack"]
		if saved.ok:
			if pack != "personal":
				_respawn[pack] = now + float(_data.encounters[ENCOUNTER]["respawn_seconds"])
			outcome = "personal_victory" if pack == "personal" else "shared_victory"
		else:
			outcome = "reward_failed"
	cancel(character)
	return {"commands": commands, "outcome": outcome}


func _valid_command(action: Dictionary) -> bool:
	var kind: Variant = action.get("type")
	if kind == "end_turn":
		return action.size() == 1
	if kind not in ["attack", "skill", "move", "guard", "wait"] or not action.get("actor") is int:
		return false
	for key in action:
		match key:
			"type":
				pass
			"actor", "target", "slot":
				if not action[key] is int:
					return false
			"skill":
				if not action[key] is String or (action[key] as String).length() > 64:
					return false
			_:
				return false
	return true


func _capacity(population: int) -> int:
	return 0 if population <= 0 else BASE_PACKS + mini((population - 1) * 2, MAX_RESERVE)


func _available(population: int, now: float) -> Array[String]:
	var open: Array[String] = []
	for index in _capacity(population):
		var key := "dunes_pack_%d" % (index + 1)
		if not _reserved.has(key) and now >= float(_respawn.get(key, 0.0)):
			open.append(key)
	return open
