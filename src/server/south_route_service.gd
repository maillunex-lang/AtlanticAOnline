class_name SouthRouteService
extends RefCounted
## Internal server commands. Time, movement and battle results come from server systems.

const QUEST_IDS := ["m07_south", "s04_scorpions", "q_se_water_marks", "q_se_clear_way", "q_se_cistern_cloth"]
const ENCOUNTERS := ["enc_dunes_scorpions", "enc_dunes_drifters"]

var _repo: PlayerRepository
var _data: GameData
var _battles: Dictionary = {}


func _init(repo: PlayerRepository, data: GameData) -> void:
	_repo = repo
	_data = data


func perform(account: int, character: int, action: String, target: String, now: float) -> Dictionary:
	var row := _repo.load_character(account, character)
	if row.is_empty():
		return _fail("unknown_character")
	var progress: Dictionary = row["progress"]
	var world := PlayerWorld.new(_data, now)
	world.zone_id = str(progress.get("zone", SeaFerry.HARBOR))
	if not world.graph.has_zone(world.zone_id):
		return _fail("invalid_saved_zone")
	var log := QuestLog.new(_data)
	log.load_dict(row["quests"])
	var level := int(progress.get("level", 1))
	var voyage: Dictionary = progress.get("south_voyage", {})
	if not voyage.is_empty():
		world.traveling = true
		world.destination = str(voyage["destination"])
		world.arrive_at = float(voyage["arrive_at"])
		if not SeaFerry.arrive(world, log, now):
			return _fail("busy")
		progress.erase("south_voyage")
		progress["zone"] = world.zone_id
		var discovered: Dictionary = progress.get("discovered", {})
		discovered[world.zone_id] = true
		progress["discovered"] = discovered
		# Commit arrival independently. The requested interaction can be retried.
		return _save(row, log, {"arrived": world.zone_id})

	var result: Dictionary
	match action:
		"depart":
			result = SeaFerry.depart(world, log, level, now)
			if not result.ok:
				return result
			progress["south_voyage"] = {"destination": world.destination, "arrive_at": world.arrive_at}
		"walk_arrived":
			# Caller is the server movement handler after validating the character's position.
			if level < 18 or target.is_empty() or target != _nearby_zone(world.zone_id):
				return _fail("invalid_route")
			progress["zone"] = target
			var discovered: Dictionary = progress.get("discovered", {})
			discovered[target] = true
			progress["discovered"] = discovered
			log.on_event({"type": "visit", "zone": target})
			result = {"ok": true}
		"inspect":
			if target != "npc_said" or world.zone_id != "z_dunes" \
					or not log.can_perform_activity("q_se_water_marks", "se_water_mark", null, level):
				return _fail("not_available")
			log.on_event({"type": "activity", "target": "se_water_mark"})
			result = {"ok": true}
		"accept", "turn_in":
			if target not in QUEST_IDS:
				return _fail("unknown_quest")
			var quest: Dictionary = _data.quests[target]
			var npc := str(quest["giver" if action == "accept" else "turn_in"])
			if world.zone_id != _data.npcs[npc]["zone"]:
				return _fail("wrong_zone")
			if action == "accept":
				result = log.accept(target, level, now)
			else:
				result = _turn_in(row, log, target, npc, level, now)
		_:
			return _fail("unknown_action")
	return _save(row, log, result) if result.ok else result


## Called by the server combat setup, with the simulation created for this character.
func register_battle(account: int, character: int, encounter: String, now: float, battle: BattleSim) -> Dictionary:
	if encounter not in ENCOUNTERS or battle == null or battle.winner != BattleSim.Winner.NONE:
		return _fail("invalid_battle")
	var row := _repo.load_character(account, character)
	var access := _battle_access(row, encounter, now)
	if not access.ok:
		return access
	_battles[character] = {"account": account, "encounter": encounter, "battle": weakref(battle)}
	return {"ok": true}


func record_victory(account: int, character: int, encounter: String, now: float, battle: BattleSim) -> Dictionary:
	var registered: Dictionary = _battles.get(character, {})
	if registered.is_empty() or registered["account"] != account or registered["encounter"] != encounter \
			or registered["battle"].get_ref() != battle or battle == null:
		return _fail("unknown_battle")
	if battle.winner != BattleSim.Winner.SIDE_A:
		return _fail("not_victorious")
	var row := _repo.load_character(account, character)
	var access := _battle_access(row, encounter, now)
	if not access.ok:
		return access
	var progress: Dictionary = row["progress"]
	var next: Dictionary = progress.get("south_encounter_ready", {})
	next[encounter] = now + float(_data.encounters[encounter]["respawn_seconds"])
	progress["south_encounter_ready"] = next
	var log := QuestLog.new(_data)
	log.load_dict(row["quests"])
	log.on_event({"type": "kill", "encounter": encounter})
	var result := _save(row, log, {"ok": true})
	if result.ok:
		_battles.erase(character)
	return result


func _battle_access(row: Dictionary, encounter: String, now: float) -> Dictionary:
	if row.is_empty():
		return _fail("unknown_character")
	var progress: Dictionary = row["progress"]
	if progress.get("zone") != _data.encounters[encounter]["zone"] or progress.has("south_voyage"):
		return _fail("wrong_zone")
	var next: Dictionary = progress.get("south_encounter_ready", {})
	if now < float(next.get(encounter, 0.0)):
		return _fail("cooldown")
	return {"ok": true}


func _turn_in(row: Dictionary, log: QuestLog, qid: String, npc: String, level: int, now: float) -> Dictionary:
	var inv := Inventory.new(_data)
	var stored: Dictionary = row["inventory"]
	inv.materials = stored.get("materials", {}).duplicate(true)
	var equipment: Array = stored.get("items", [])
	var next_uid := int(stored.get("next_uid", 1))
	for data in equipment:
		if not data is Dictionary or not data.has("uid") or not data.has("def_id"):
			return _fail("invalid_saved_inventory")
		var uid := int(data["uid"])
		inv.items.append(Item.new(uid, str(data["def_id"])))
		next_uid = maxi(next_uid, uid + 1)
	var progress: Dictionary = row["progress"]
	var wallet := {"coins": int(progress.get("coins", 0))}
	var result := log.turn_in(qid, {"inv": inv, "wallet": wallet, "level": level, "now": now}, npc)
	if not result.ok:
		return result
	for i in range(equipment.size(), inv.items.size()):
		equipment.append({"uid": next_uid, "def_id": inv.items[i].def_id, "plus": 0, "fail_streak": 0})
		next_uid += 1
	stored["items"] = equipment
	stored["materials"] = inv.materials
	stored["next_uid"] = next_uid
	progress["coins"] = wallet["coins"]
	var experience := int(progress.get("xp", 0)) + int(result.rewards.get("xp", 0))
	var needed := Progression.xp_to_next(level, _data)
	while needed > 0 and experience >= needed:
		experience -= needed
		level += 1
		needed = Progression.xp_to_next(level, _data)
	if needed == 0:
		experience = 0
	progress["xp"] = experience
	progress["level"] = level
	return result


func _save(row: Dictionary, log: QuestLog, result: Dictionary) -> Dictionary:
	row["quests"] = log.to_dict()
	if _repo.save_character(row["account_id"], row["id"], row["revision"], row) < 0:
		return _fail("retry")
	result["ok"] = true
	return result


func _nearby_zone(zone: String) -> String:
	match zone:
		"z_oasis":
			return "z_dunes"
		"z_dunes":
			return "z_oasis"
	return ""


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
