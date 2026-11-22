class_name SouthRouteService
extends RefCounted
## Internal server commands. Time, movement and battle results come from server systems.

const QUEST_IDS := ["m07_south", "s04_scorpions", "q_se_water_marks", "q_se_clear_way", "q_se_cistern_cloth",
	"q_se_echo_pass", "q_se_echo_road", "q_se_echo_seal", "q_se_echo_bandages", "q_se_echo_watch", "q_se_tomb_archive", "q_se_tomb_trade",
	"q_se_market_bridge", "q_se_market_weights", "q_se_market_dispatch", "q_se_market_straps"]
const ENCOUNTERS := ["enc_dunes_scorpions", "enc_dunes_drifters", "enc_canyon_mummies", "enc_canyon_sentries", "enc_tomb_1", "enc_tomb_boss"]

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
			if level < 18 or target.is_empty() or target not in _nearby_zones(world.zone_id):
				return _fail("invalid_route")
			if target == "z_canyon" and world.zone_id == "z_dunes" and not log.can_enter_echo_canyon(level):
				return _fail("canyon_locked")
			if target == "z_tomb" and (level < 25 or not log.completed.has("q_se_echo_seal")):
				return _fail("tomb_locked")
			if target == "z_east_market" and not log.can_enter_east_market(level):
				return _fail("market_locked")
			progress["zone"] = target
			var discovered: Dictionary = progress.get("discovered", {})
			discovered[target] = true
			progress["discovered"] = discovered
			log.on_event({"type": "visit", "zone": target})
			result = {"ok": true}
		"enter_tomb", "tomb_mechanism":
			if world.zone_id != "z_tomb" or level < 25:
				return _fail("wrong_zone")
			var run := DungeonRun.restore(_data, progress.get("tomb_run", {}))
			if action == "enter_tomb":
				if run != null:
					return {"ok": true, "resumed": true}
				if log.state("q_se_tomb_archive", null, level, now) != "active":
					return _fail("quest_required")
				var inv := Inventory.new(_data)
				inv.materials = row["inventory"].get("materials", {}).duplicate()
				var entrance := DungeonRun.enter(world, inv, level, now)
				if not entrance.ok:
					return entrance
				run = entrance.run
				row["inventory"]["materials"] = inv.materials
			elif run == null or not run.solve(target):
				return _fail("mechanism_locked")
			progress["tomb_run"] = run.snapshot()
			result = {"ok": true}
		"inspect":
			var inspection: Array = {
				"npc_said": ["q_se_water_marks", "se_water_mark"],
				"npc_amina": ["q_se_echo_pass", "se_echo_survey"],
				"npc_salih": ["q_se_echo_seal", "se_echo_seal"],
				"npc_market_bridge": ["q_se_market_bridge", "se_market_bridge"],
				"npc_market_tala": ["q_se_market_weights", "se_market_weights"],
			}.get(target, [])
			if inspection.is_empty() or world.zone_id != _data.npcs[target]["zone"] \
					or not log.can_perform_activity(inspection[0], inspection[1], null, level):
				return _fail("not_available")
			log.on_event({"type": "activity", "target": inspection[1]})
			result = {"ok": true}
		"talk":
			if target != "npc_nadia" or world.zone_id != _data.npcs[target]["zone"]:
				return _fail("wrong_contact")
			log.on_event({"type": "talk", "npc": target})
			result = {"ok": true}
		"market_buy":
			if world.zone_id != "z_east_market" or not target.is_valid_int():
				return _fail("not_available")
			var inv := Inventory.new(_data)
			inv.materials = row["inventory"].get("materials", {}).duplicate()
			var wallet := {"coins": int(progress.get("coins", 0))}
			var error := TownServices.new(_data).buy(world, wallet, inv, target.to_int(), log)
			if not error.is_empty():
				return _fail(error)
			row["inventory"]["materials"] = inv.materials
			progress["coins"] = wallet["coins"]
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
	if _data.encounters[encounter]["zone"] == "z_tomb":
		var run := DungeonRun.restore(_data, progress["tomb_run"])
		if run.complete_stage():
			log.on_event({"type": "dungeon_clear", "zone": "z_tomb"})
			progress.erase("tomb_run")
		else:
			progress["tomb_run"] = run.snapshot()
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
	if progress["zone"] == "z_tomb":
		var run := DungeonRun.restore(_data, progress.get("tomb_run", {}))
		if run == null or run.current_encounter() != encounter or not run.can_fight():
			return _fail("tomb_stage_locked")
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


func _nearby_zones(zone: String) -> Array:
	match zone:
		"z_oasis":
			return ["z_dunes"]
		"z_dunes":
			return ["z_oasis", "z_canyon"]
		"z_canyon":
			return ["z_dunes", "z_tomb", "z_east_market"]
		"z_east_market":
			return ["z_canyon"]
		"z_tomb":
			return ["z_canyon"]
	return []


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
