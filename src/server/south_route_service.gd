class_name SouthRouteService
extends RefCounted
## Internal server commands. Time, movement and battle results come from server systems.

const QUEST_IDS := ["m07_south", "s04_scorpions", "q_se_water_marks", "q_se_clear_way", "q_se_cistern_cloth",
	"q_se_echo_pass", "q_se_echo_road", "q_se_echo_seal", "q_se_echo_bandages", "q_se_echo_watch", "q_se_tomb_archive", "q_se_tomb_trade",
	"q_se_market_bridge", "q_se_market_weights", "q_se_market_dispatch", "q_se_market_straps",
	"q_se_dock_ledger", "q_se_dock_proof", "q_se_dock_rope",
	"q_se_river_survey", "q_se_river_patrol", "q_se_sluice_charter",
	"q_sa_tide_survey", "q_sa_fog_watch", "q_sa_ridge_survey", "q_sa_ridge_signal",
	"q_se_convoy_orders", "q_se_convoy_watch", "q_se_convoy_load",
	"q_sa_missing_watch", "q_sa_reed_route", "q_sa_east_watch", "q_sa_watch_report",
	"q_sa_pass_road", "q_sa_pass_contact", "q_sa_pass_recovery", "q_sa_pass_manifest", "q_sa_pass_link",
	"q_sa_terrace_road", "q_sa_terrace_marks", "q_sa_terrace_cloth", "q_sa_terrace_seal",
	"q_sa_terrace_guard", "q_sa_cistern_clear", "q_sa_water_dispatch", "q_sa_expedition_end",
	"q_se_dune_notice", "q_se_dune_water_list", "q_se_canyon_account", "q_se_canyon_witness",
	"q_se_canyon_return", "q_se_archive_copy", "q_se_market_receipt",
	"q_eu_first_manifest", "q_eu_causeway_watch", "q_eu_forum_copy", "q_eu_market_record",
	"q_eu_salt_dispatch", "q_eu_salt_road", "q_eu_salt_manifest", "q_eu_salt_invoice", "q_eu_salt_return", "q_eu_salt_ambush", "q_eu_salt_receipt", "q_eu_salt_registry",
	"q_pve_dune_seals", "q_pve_canyon_evidence", "q_pve_sluice_tokens",
	"q_pve_cove_cargo", "q_pve_crossing_tokens", "q_pve_pass_orders", "q_pve_terrace_stamp",
	"q_pve_eu_quay_seals", "q_pve_eu_road_orders", "q_pve_eu_salt_tags", "q_pve_eu_daily_seals",
	"q_drop_dunes", "q_drop_canyon", "q_drop_fog", "q_drop_causeway"]
const ENCOUNTERS := ["enc_dunes_scorpions", "enc_dunes_drifters", "enc_canyon_mummies", "enc_canyon_sentries", "enc_tomb_1", "enc_tomb_boss",
	"enc_marsh_roadblock", "enc_fog_road_robbers", "enc_copper_ridge_raiders", "enc_crossing_raiders", "enc_pass_supply_raiders", "enc_terrace_guard", "enc_cistern_entry", "enc_cistern_keeper", "enc_causeway_watch", "enc_salt_road_raiders", "enc_ostia_road_ambush",
	"enc_dunes_bow_post", "enc_dunes_salt_captain", "enc_canyon_shield_post", "enc_sluice_reserve",
	"enc_fog_cargo_lookouts", "enc_crossing_rope_post", "enc_pass_signal_watch", "enc_terrace_seal_watch",
	"enc_eu_quay_archers", "enc_eu_causeway_shields", "enc_eu_signal_reserve", "enc_eu_ostia_captain"]

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
			result = SeaFerry.depart(world, log, level, now, target)
			if not result.ok:
				return result
			progress["south_voyage"] = {"destination": world.destination, "arrive_at": world.arrive_at}
		"walk_arrived":
			# Caller is the server movement handler after validating the character's position.
			if level < 18 or target.is_empty() or target not in _nearby_zones(world.zone_id):
				return _fail("invalid_route")
			var canyon_pilot_access := bool(progress.get("dunes_pilot", false)) and log.completed.has(DunesMap.quest(DunesMap.DUNES))
			if target == DunesMap.CANYON and world.zone_id == DunesMap.DUNES and not log.can_enter_echo_canyon(level) and not canyon_pilot_access:
				return _fail("canyon_locked")
			if target == "z_tomb" and (level < 25 or not log.completed.has("q_se_echo_seal")):
				return _fail("tomb_locked")
			if target == "z_east_market" and not log.can_enter_east_market(level):
				return _fail("market_locked")
			if target == "z_lower_dock" and not log.can_enter_lower_dock(level):
				return _fail("dock_locked")
			if target == "z_river_marsh" and not log.can_enter_river_marsh(level):
				return _fail("marsh_locked")
			if target == "z_sluice_town" and not log.can_enter_sluice_town(level):
				return _fail("sluice_locked")
			if target in ["z_river_crossing", "z_reed_camp"] and not log.can_enter_reed_route(level):
				return _fail("reed_route_locked")
			if target in ["z_pass_foothills", "z_pass_settlement"] and not log.can_enter_pass_route(level):
				return _fail("pass_route_locked")
			if target in ["z_watershed", "z_cistern_halls"] and not log.can_enter_watershed(level):
				return _fail("watershed_locked")
			var pilot_rome_route := bool(progress.get("rome_route_pilot", progress.get("auction_pilot_grant", false))) \
				and world.zone_id in DunesTerrain.ROME_ROUTE and target in DunesTerrain.ROME_ROUTE
			if target in ["z_north_quay", "z_europe_causeway"] and not pilot_rome_route \
					and (level < 48 or not log.completed.has(SeaFerry.EXPEDITION_COMPLETE)):
				return _fail("north_locked")
			if target in ["z_salt_road", "z_ostia"] and (level < 52 or not log.completed.has("q_eu_market_record")):
				return _fail("ostia_locked")
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
				var replay := log.completed.has("q_se_tomb_archive")
				if not replay and log.state("q_se_tomb_archive", null, level, now) != "active":
					return _fail("quest_required")
				var inv := Inventory.new(_data)
				inv.materials = row["inventory"].get("materials", {}).duplicate()
				var wallet := {"coins": int(progress.get("coins", 0))} if replay else {}
				var entrance := DungeonRun.enter(world, inv, level, now, wallet, progress.get("dungeon_cleared_at", {}))
				if not entrance.ok:
					return entrance
				run = entrance.run
				if replay:
					progress["coins"] = wallet["coins"]
				row["inventory"]["materials"] = inv.materials
			elif run == null or not run.solve(target):
				return _fail("mechanism_locked")
			progress["tomb_run"] = run.snapshot()
			result = {"ok": true}
		"enter_cistern":
			if world.zone_id != "z_cistern_halls" or not log.can_enter_watershed(level):
				return _fail("wrong_zone")
			if DungeonRun.restore(_data, progress.get("cistern_run", {})) != null:
				return {"ok": true, "resumed": true}
			var replay := log.completed.has("q_sa_cistern_clear")
			if not replay and log.state("q_sa_cistern_clear", null, level, now) != "active":
				return _fail("quest_required")
			var inv := Inventory.new(_data)
			inv.materials = row["inventory"].get("materials", {}).duplicate()
			var wallet := {"coins": int(progress.get("coins", 0))} if replay else {}
			var entrance := DungeonRun.enter(world, inv, level, now, wallet, progress.get("dungeon_cleared_at", {}))
			if not entrance.ok:
				return entrance
			row["inventory"]["materials"] = inv.materials
			if replay:
				progress["coins"] = wallet["coins"]
			progress["cistern_run"] = entrance.run.snapshot()
			result = {"ok": true}
		"inspect":
			var inspection: Array = {
				"npc_said": ["q_se_water_marks", "se_water_mark"],
				"npc_amina": ["q_se_echo_pass", "se_echo_survey"],
				"npc_salih": ["q_se_echo_seal", "se_echo_seal"],
				"npc_market_bridge": ["q_se_market_bridge", "se_market_bridge"],
				"npc_market_tala": ["q_se_market_weights", "se_market_weights"],
				"npc_dock_ledger": ["q_se_dock_ledger", "se_dock_ledger"],
				"npc_dock_post": ["q_se_dock_proof", "se_dock_post"],
				"npc_river_gauge": ["q_se_river_survey", "se_river_gauge"],
				"npc_sluice_winch": ["q_se_sluice_charter", "se_sluice_winch"],
				"npc_fog_stake": ["q_sa_tide_survey", "sa_fog_stake"],
				"npc_pass_cargo": ["q_sa_pass_manifest", "sa_pass_cargo"],
				"npc_terrace_gauge": ["q_sa_terrace_marks", "sa_terrace_gauge"],
			}.get(target, [])
			if inspection.is_empty() or world.zone_id != _data.npcs[target]["zone"] \
					or not log.can_perform_activity(inspection[0], inspection[1], null, level):
				return _fail("not_available")
			log.on_event({"type": "activity", "target": inspection[1]})
			result = {"ok": true}
		"talk":
			if target not in ["npc_nadia", "npc_marsh_ilan", "npc_pass_bruno", "npc_said", "npc_salih", "npc_yara", "npc_market_ren", "npc_rome_fabius", "npc_ostia_paolo"] or world.zone_id != _data.npcs[target]["zone"]:
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
func register_battle(account: int, character: int, encounter: String, now: float, battle: BattleSim, shared_spawn := false) -> Dictionary:
	if encounter not in ENCOUNTERS or battle == null or battle.winner != BattleSim.Winner.NONE:
		return _fail("invalid_battle")
	var row := _repo.load_character(account, character)
	var key := "" if shared_spawn else encounter
	var access := _battle_access(row, encounter, now, key)
	if not access.ok:
		return access
	_battles[character] = {"account": account, "encounter": encounter, "battle": weakref(battle), "key": key}
	return {"ok": true}


func record_victory(account: int, character: int, encounter: String, now: float, battle: BattleSim) -> Dictionary:
	var registered: Dictionary = _battles.get(character, {})
	if registered.is_empty() or registered["account"] != account or registered["encounter"] != encounter \
			or registered["battle"].get_ref() != battle or battle == null:
		return _fail("unknown_battle")
	if battle.winner != BattleSim.Winner.SIDE_A:
		return _fail("not_victorious")
	var row := _repo.load_character(account, character)
	var key: String = registered["key"]
	var access := _battle_access(row, encounter, now, key)
	if not access.ok:
		return access
	var progress: Dictionary = row["progress"]
	if not key.is_empty():
		var next: Dictionary = progress.get("south_encounter_ready", {})
		next[key] = now + float(_data.encounters[encounter]["respawn_seconds"])
		progress["south_encounter_ready"] = next
	var log := QuestLog.new(_data)
	log.load_dict(row["quests"])
	log.on_event({"type": "kill", "encounter": encounter})
	var zone: String = _data.encounters[encounter]["zone"]
	var run_key := _run_key(zone)
	if not run_key.is_empty():
		var run := DungeonRun.restore(_data, progress[run_key])
		if run.complete_stage():
			log.on_event({"type": "dungeon_clear", "zone": zone})
			progress.erase(run_key)
			var cleared: Dictionary = progress.get("dungeon_cleared_at", {})
			cleared[zone] = now
			progress["dungeon_cleared_at"] = cleared
		else:
			progress[run_key] = run.snapshot()
	var result := _save(row, log, {"ok": true})
	if result.ok:
		_battles.erase(character)
	return result


func _battle_access(row: Dictionary, encounter: String, now: float, key: String) -> Dictionary:
	if row.is_empty():
		return _fail("unknown_character")
	var progress: Dictionary = row["progress"]
	if progress.get("zone") != _data.encounters[encounter]["zone"] or progress.has("south_voyage"):
		return _fail("wrong_zone")
	var run_key := _run_key(str(progress["zone"]))
	if not run_key.is_empty():
		var run := DungeonRun.restore(_data, progress.get(run_key, {}))
		if run == null or run.current_encounter() != encounter or not run.can_fight():
			return _fail("tomb_stage_locked" if run_key == "tomb_run" else "cistern_stage_locked")
	var next: Dictionary = progress.get("south_encounter_ready", {})
	if not key.is_empty() and now < float(next.get(key, 0.0)):
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


func _run_key(zone: String) -> String:
	match zone:
		"z_tomb":
			return "tomb_run"
		"z_cistern_halls":
			return "cistern_run"
	return ""


func _nearby_zones(zone: String) -> Array:
	match zone:
		"z_oasis":
			return ["z_dunes"]
		"z_dunes":
			return ["z_oasis", "z_canyon"]
		"z_canyon":
			return ["z_dunes", "z_tomb", "z_east_market"]
		"z_east_market":
			return ["z_canyon", "z_lower_dock"]
		"z_lower_dock":
			return ["z_east_market", "z_river_marsh"]
		"z_river_marsh":
			return ["z_lower_dock", "z_sluice_town"]
		"z_sluice_town":
			return ["z_river_marsh"]
		"z_tomb":
			return ["z_canyon"]
		"z_copper_cove":
			return ["z_fog_trail"]
		"z_fog_trail":
			return ["z_copper_cove", "z_copper_ridge"]
		"z_copper_ridge":
			return ["z_fog_trail", "z_river_crossing"]
		"z_river_crossing":
			return ["z_copper_ridge", "z_reed_camp"]
		"z_reed_camp":
			return ["z_river_crossing", "z_pass_foothills"]
		"z_pass_foothills":
			return ["z_reed_camp", "z_pass_settlement"]
		"z_pass_settlement":
			return ["z_pass_foothills", "z_watershed"]
		"z_watershed":
			return ["z_pass_settlement", "z_cistern_halls"]
		"z_cistern_halls":
			return ["z_watershed"]
		"z_north_quay":
			return ["z_europe_causeway"]
		"z_europe_causeway":
			return ["z_north_quay", "z_rome"]
		"z_rome":
			return ["z_europe_causeway", "z_salt_road"]
		"z_salt_road":
			return ["z_rome", "z_ostia"]
		"z_ostia":
			return ["z_salt_road"]
	return []


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
