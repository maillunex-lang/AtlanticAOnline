extends GdUnitTestSuite

var db: ServerDatabase
var path: String


func before_test() -> void:
	db = ServerDatabase.new()
	path = "user://wp01-%d-%d.db" % [OS.get_process_id(), Time.get_ticks_usec()]


func after_test() -> void:
	db.close()
	DirAccess.remove_absolute(path)


func test_player_snapshot_survives_reopening_and_rejects_stale_writes() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("Test'Player")
	assert_int(account).is_greater(0)
	assert_int(repo.create_account("test'player")).is_equal(0)
	var other := repo.create_account("Other")
	var character := repo.create_character(account, "Guardian", "warden")
	assert_int(character).is_greater(0)
	assert_int(repo.create_character(account, "guardian", "warden")).is_equal(0)
	var snapshot := {
		"progress": {"level": 12, "xp": 123, "zone": "z_ruins"},
		"inventory": {"materials": {"key_ruins": 2}, "items": []},
		"quests": {"completed": {"m05_old_key": true}, "active": {"m06_ruins": [0]}},
		"squad": {"formation": {0: 0, 12: 4}},
	}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_int(int(repo.find_account("TEST'PLAYER")["id"])).is_equal(account)
	assert_dict(repo.load_character(other, character)).is_empty()
	var loaded := repo.load_character(account, character)
	for part in snapshot:
		assert_dict(loaded[part]).is_equal(snapshot[part])
	var catalog := GameData.load_dir()
	var quest_log := QuestLog.new(catalog)
	quest_log.load_dict(loaded["quests"])
	var inventory := Inventory.new(catalog)
	assert_str(quest_log.state("m06_ruins", inventory, 12, 0.0)).is_equal("active")
	quest_log.on_event({"type": "dungeon_clear", "zone": "z_ruins"})
	assert_str(quest_log.state("m06_ruins", inventory, 12, 0.0)).is_equal("ready")
	assert_int(int(loaded["revision"])).is_equal(1)
	snapshot["progress"]["xp"] = 456
	assert_int(repo.save_character(other, character, 1, snapshot)).is_equal(-1)
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(-1)
	assert_int(int(repo.load_character(account, character)["progress"]["xp"])).is_equal(123)
	assert_int(repo.save_character(account, character, 1, snapshot)).is_equal(2)


func test_migration_preserves_existing_player_rows() -> void:
	# Open a version-one fixture directly, then let the application migrate it.
	var sqlite: Object = ClassDB.instantiate(&"SQLite")
	sqlite.set("path", path)
	assert_bool(sqlite.call("open_db")).is_true()
	for migration: String in ServerDatabase.MIGRATIONS[0]:
		assert_bool(sqlite.call("query", migration)).is_true()
	assert_bool(sqlite.call("query", "INSERT INTO accounts(id, login) VALUES (42, 'existing')")).is_true()
	assert_bool(sqlite.call("query", "INSERT INTO characters(id, account_id, name, class_id) VALUES (9, 42, 'Old', 'warden')")).is_true()
	assert_bool(sqlite.call("query", "PRAGMA user_version = 1")).is_true()
	assert_bool(sqlite.call("close_db")).is_true()
	assert_int(db.open(path)).is_equal(OK)
	assert_bool(db.execute("PRAGMA user_version")).is_true()
	assert_int(int(db.rows[0]["user_version"])).is_equal(ServerDatabase.MIGRATIONS.size())
	var repo := PlayerRepository.new(db)
	var old := repo.load_character(42, 9)
	assert_str(old["class_id"]).is_equal("warden")
	assert_dict(old["inventory"]).is_empty()
	assert_int(int(repo.find_account("existing")["id"])).is_equal(42)


func test_south_route_restores_voyage_and_commits_quest_reward_once() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("south")
	var character := repo.create_character(account, "Navigator", "warden")
	var gd := GameData.load_dir()
	var service := SouthRouteService.new(repo, gd)
	var snapshot := {
		"progress": {"level": 20, "zone": "z_harbor", "coins": 70},
		"inventory": {"materials": {"cloth_scrap": 4}, "items": []},
		"quests": {"completed": {"m06_ruins": true}, "chains_cleared": {"main_03": 1}},
		"squad": {},
	}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_str(service.perform(account, character, "depart", "", 0).error).is_equal("no_pass")
	assert_str(service.perform(account, character, "accept", "m07_south", 0).error).is_equal("wrong_zone")
	# Player was already travelling with an active quest in the legacy format.
	snapshot.quests["active"] = {"m07_south": [0, 0]}
	assert_int(repo.save_character(account, character, 1, snapshot)).is_equal(2)
	assert_bool(service.perform(account, character, "depart", "", 1).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_str(service.perform(account, character, "tick", "", 120).error).is_equal("busy")
	assert_str(service.perform(account, character, "tick", "", 121).arrived).is_equal("z_oasis")
	assert_bool(service.perform(account, character, "turn_in", "m07_south", 121).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "m07_south", 122).error).is_equal("not_active")
	var saved := repo.load_character(account, character)
	assert_int(int(saved.progress.coins)).is_equal(1970)
	assert_str(saved.inventory.items[0].def_id).is_equal("h_helm")
	assert_bool(saved.quests.completed.has("m07_south")).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_water_marks", 122).ok).is_true()
	assert_str(service.perform(account, character, "inspect", "npc_said", 122).error).is_equal("not_available")
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 122).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_said", 122).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_water_marks", 122).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_clear_way", 122).ok).is_true()
	var battle := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 17)
	assert_bool(service.register_battle(account, character, "enc_dunes_drifters", 122, battle).ok).is_true()
	assert_str(service.record_victory(account, character, "enc_dunes_drifters", 122, battle).error).is_equal("not_victorious")
	battle.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_dunes_drifters", 122, battle).ok).is_true()
	assert_str(service.record_victory(account, character, "enc_dunes_drifters", 500, battle).error).is_equal("unknown_battle")
	assert_bool(service.perform(account, character, "walk_arrived", "z_oasis", 123).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_clear_way", 123).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_cistern_cloth", 123).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_cistern_cloth", 123).ok).is_true()
	saved = repo.load_character(account, character)
	assert_bool(saved.inventory.materials.is_empty()).is_true()
	assert_int(int(saved.progress.coins)).is_equal(2920)


func test_echo_canyon_restores_inspection_and_awards_one_tomb_key() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("echo")
	var character := repo.create_character(account, "Scout", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 25, "zone": "z_dunes"},
		"inventory": {"materials": {"key_tomb": 2}}, "squad": {},
		"quests": {"completed": {"q_se_water_marks": true, "q_se_clear_way": true,
			"q_se_echo_pass": true, "q_se_echo_road": true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 0).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_echo_seal", 0).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_echo_seal", 0).error).is_equal("not_done")
	assert_bool(service.perform(account, character, "inspect", "npc_salih", 0).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_bool(service.perform(account, character, "turn_in", "q_se_echo_seal", 1).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_echo_seal", 2).error).is_equal("not_active")
	var saved := repo.load_character(account, character)
	assert_int(int(saved.inventory.materials.key_tomb)).is_equal(3)
	assert_bool(saved.quests.completed.has("q_se_echo_seal")).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 3).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_oasis", 4).ok).is_true()


func test_tomb_key_and_stage_survive_database_restart() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("tomb")
	var character := repo.create_character(account, "Keeper", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 25, "zone": "z_tomb"},
		"inventory": {"materials": {}}, "squad": {},
		"quests": {"active": {"q_se_tomb_archive": [0]}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_str(service.perform(account, character, "enter_tomb", "", 0).error).is_equal("no_key")
	assert_int(int(repo.load_character(account, character).revision)).is_equal(1)
	snapshot.inventory.materials["key_tomb"] = 1
	assert_int(repo.save_character(account, character, 1, snapshot)).is_equal(2)
	assert_bool(service.perform(account, character, "enter_tomb", "", 0).ok).is_true()
	assert_bool(service.perform(account, character, "enter_tomb", "", 0).resumed).is_true()
	assert_dict(repo.load_character(account, character).inventory.materials).is_empty()
	var fight := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 7)
	assert_str(service.register_battle(account, character, "enc_tomb_boss", 0, fight).error).is_equal("tomb_stage_locked")
	assert_bool(service.register_battle(account, character, "enc_tomb_1", 0, fight).ok).is_true()
	fight.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_tomb_1", 0, fight).ok).is_true()
	assert_str(service.perform(account, character, "tomb_mechanism", "tomb_tablet", 1).error).is_equal("mechanism_locked")
	assert_bool(service.perform(account, character, "tomb_mechanism", "tomb_wheels", 1).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_bool(service.perform(account, character, "enter_tomb", "", 2).resumed).is_true()
	assert_str(service.perform(account, character, "tomb_mechanism", "tomb_wheels", 2).error).is_equal("mechanism_locked")
	assert_bool(service.perform(account, character, "tomb_mechanism", "tomb_tablet", 2).ok).is_true()
	var boss := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 8)
	assert_bool(service.register_battle(account, character, "enc_tomb_boss", 2, boss).ok).is_true()
	boss.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_tomb_boss", 2, boss).ok).is_true()
	assert_str(service.record_victory(account, character, "enc_tomb_boss", 2, boss).error).is_equal("unknown_battle")
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 3).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_tomb_archive", 3).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_tomb_archive", 3).error).is_equal("not_active")
	assert_int(int(repo.load_character(account, character).inventory.materials.enhance_stone)).is_equal(3)


func test_market_route_purchase_and_rewards_survive_database_restart() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("market")
	var character := repo.create_character(account, "Trader", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 25, "zone": "z_oasis", "coins": 500},
		"inventory": {"materials": {"leather": 2}}, "squad": {},
		"quests": {"active": {"q_se_tomb_trade": [0]},
			"completed": {"q_se_clear_way": true, "q_se_tomb_archive": true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "talk", "npc_nadia", 0).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_tomb_trade", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 0).ok).is_true()
	assert_str(service.perform(account, character, "walk_arrived", "z_east_market", 0).error).is_equal("market_locked")
	var current := repo.load_character(account, character)
	current.progress.level = 27
	assert_int(repo.save_character(account, character, current.revision, current)).is_greater(0)
	assert_bool(service.perform(account, character, "walk_arrived", "z_east_market", 0).ok).is_true()
	assert_str(service.perform(account, character, "inspect", "npc_market_bridge", 0).error).is_equal("not_available")
	assert_bool(service.perform(account, character, "market_buy", "0", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_oasis", 0).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_market_bridge", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 0).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_east_market", 0).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_market_bridge", 0).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_market_bridge", 0).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_market_weights", 0).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_market_tala", 0).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_market_weights", 0).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_market_straps", 0).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_market_straps", 0).error).is_equal("not_done")
	assert_str(service.perform(account, character, "market_buy", "-1", 0).error).is_equal("bad_offer")
	assert_bool(service.perform(account, character, "market_buy", "1", 0).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	var paid := repo.load_character(account, character)
	assert_int(int(paid.inventory.materials.leather)).is_equal(4)
	assert_bool(service.perform(account, character, "turn_in", "q_se_market_straps", 1).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_market_straps", 1).error).is_equal("not_active")
	var rewarded := repo.load_character(account, character)
	assert_int(int(rewarded.inventory.materials.leather)).is_equal(3)
	assert_int(int(rewarded.progress.coins)).is_equal(int(paid.progress.coins) + 400)
	assert_bool(service.perform(account, character, "accept", "q_se_market_dispatch", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_canyon", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_dunes", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_oasis", 1).ok).is_true()
	assert_bool(service.perform(account, character, "talk", "npc_nadia", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_market_dispatch", 1).ok).is_true()



func test_lower_dock_persists_evidence_and_rewards() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("dock")
	var character := repo.create_character(account, "Reader", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 27, "zone": "z_east_market", "coins": 100},
		"inventory": {}, "squad": {}, "quests": {"completed": {"q_se_tomb_trade": true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_str(service.perform(account, character, "walk_arrived", "z_lower_dock", 0).error).is_equal("dock_locked")
	assert_str(service.perform(account, character, "accept", "q_se_dock_ledger", 0).error).is_equal("prereq")
	var current := repo.load_character(account, character)
	current.quests.completed["q_se_market_dispatch"] = true
	current.progress.level = 26
	assert_int(repo.save_character(account, character, current.revision, current)).is_greater(0)
	assert_str(service.perform(account, character, "walk_arrived", "z_lower_dock", 1).error).is_equal("dock_locked")
	current = repo.load_character(account, character)
	current.progress.level = 27
	assert_int(repo.save_character(account, character, current.revision, current)).is_greater(0)
	assert_bool(service.perform(account, character, "accept", "q_se_dock_ledger", 1).ok).is_true()
	assert_str(service.perform(account, character, "inspect", "npc_dock_ledger", 1).error).is_equal("not_available")
	assert_bool(service.perform(account, character, "walk_arrived", "z_lower_dock", 1).ok).is_true()
	assert_str(service.perform(account, character, "inspect", "npc_dock_post", 1).error).is_equal("not_available")
	assert_bool(service.perform(account, character, "inspect", "npc_dock_ledger", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_dock_ledger", 1).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_dock_proof", 1).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_dock_post", 1).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_bool(service.perform(account, character, "walk_arrived", "z_east_market", 2).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_dock_proof", 2).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_dock_proof", 2).error).is_equal("not_active")
	var rewarded := repo.load_character(account, character)
	assert_int(int(rewarded.quests.chains_cleared.ch_se_lower_dock)).is_equal(1)
	assert_int(int(rewarded.progress.coins)).is_equal(1680)


func test_sluice_finale_completes_from_a_lower_dock_save() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("sluice")
	var character := repo.create_character(account, "Courier", "warden")
	var data := GameData.load_dir()
	var service := SouthRouteService.new(repo, data)
	var snapshot := {"progress": {"level": 27, "zone": "z_east_market", "coins": 100},
		"inventory": {}, "squad": {}, "quests": {"completed": {
			"q_se_tomb_trade": true, "q_se_clear_way": true, "q_se_market_dispatch": true, "q_se_dock_proof": true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "accept", "q_se_river_survey", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_lower_dock", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_river_marsh", 1).ok).is_true()
	assert_str(service.perform(account, character, "walk_arrived", "z_sluice_town", 1).error).is_equal("sluice_locked")
	assert_bool(service.perform(account, character, "inspect", "npc_river_gauge", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_river_survey", 1).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_river_patrol", 1).ok).is_true()
	var fight := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 27)
	assert_bool(service.register_battle(account, character, "enc_marsh_roadblock", 1, fight).ok).is_true()
	fight.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_marsh_roadblock", 1, fight).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_sluice_town", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_river_patrol", 1).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_sluice_charter", 1).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_sluice_winch", 1).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	for zone in ["z_river_marsh", "z_lower_dock", "z_east_market", "z_canyon", "z_dunes", "z_oasis"]:
		assert_bool(service.perform(account, character, "walk_arrived", zone, 2).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_sluice_charter", 2).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_sluice_charter", 2).error).is_equal("not_active")
	var rewarded := repo.load_character(account, character)
	assert_int(int(rewarded.quests.chains_cleared.ch_se_river_route)).is_equal(1)
	assert_int(int(rewarded.progress.coins)).is_equal(3080)


func test_copper_cove_voyage_resumes_and_returns() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("cove")
	var character := repo.create_character(account, "Sailor", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 30, "zone": SeaFerry.SLUICE},
		"inventory": {}, "squad": {}, "quests": {"completed": {SeaFerry.CHARTER: true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "depart", "", 0).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_str(service.perform(account, character, "depart", "", 149).error).is_equal("busy")
	assert_str(service.perform(account, character, "depart", "", 150).arrived).is_equal(SeaFerry.COVE)
	assert_bool(service.perform(account, character, "accept", "q_sa_tide_survey", 150).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_fog_trail", 150).ok).is_true()
	assert_bool(service.perform(account, character, "inspect", "npc_fog_stake", 150).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", SeaFerry.COVE, 150).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_sa_tide_survey", 150).ok).is_true()
	assert_bool(service.perform(account, character, "depart", "", 150).ok).is_true()
	assert_str(service.perform(account, character, "depart", "", 300).arrived).is_equal(SeaFerry.SLUICE)


func test_convoy_bridges_level_27_to_30_without_battles() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("convoy")
	var character := repo.create_character(account, "Porter", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 27, "xp": 0, "zone": "z_oasis"},
		"inventory": {"materials": {"cloth_scrap": 1}}, "squad": {}, "quests": {"completed": {
			"q_se_clear_way": true, "q_se_tomb_trade": true, "q_se_market_dispatch": true,
			"q_se_dock_proof": true, "q_se_river_survey": true, "q_se_sluice_charter": true}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "accept", "q_se_convoy_orders", 1).ok).is_true()
	for zone in ["z_dunes", "z_canyon", "z_east_market", "z_lower_dock", "z_river_marsh", "z_sluice_town"]:
		assert_bool(service.perform(account, character, "walk_arrived", zone, 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_convoy_orders", 1).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_convoy_watch", 1).ok).is_true()
	assert_str(service.perform(account, character, "talk", "npc_marsh_ilan", 1).error).is_equal("wrong_contact")
	assert_bool(service.perform(account, character, "walk_arrived", "z_river_marsh", 1).ok).is_true()
	assert_bool(service.perform(account, character, "talk", "npc_marsh_ilan", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_convoy_watch", 1).ok).is_true()
	assert_bool(service.perform(account, character, "accept", "q_se_convoy_load", 1).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_sluice_town", 1).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_se_convoy_load", 1).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_se_convoy_load", 1).error).is_equal("not_active")
	var earned := repo.load_character(account, character)
	assert_int(int(earned.progress.level)).is_equal(30)
	assert_int(int(earned.progress.xp)).is_equal(796)
	assert_dict(earned.inventory.materials).is_empty()
	assert_bool(service.perform(account, character, "depart", "", 2).ok).is_true()


func test_cistern_resumes_second_hall_without_another_key() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("cistern")
	var character := repo.create_character(account, "Keeper", "warden")
	var service := SouthRouteService.new(repo, GameData.load_dir())
	var snapshot := {"progress": {"level": 44, "zone": "z_cistern_halls"},
		"inventory": {"materials": {"key_cistern": 1}}, "squad": {},
		"quests": {"completed": {"q_sa_pass_link": true}, "active": {"q_sa_cistern_clear": [0]}}}
	assert_int(repo.save_character(account, character, 0, snapshot)).is_equal(1)
	assert_bool(service.perform(account, character, "enter_cistern", "", 0).ok).is_true()
	assert_dict(repo.load_character(account, character).inventory.materials).is_empty()
	var first := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 40)
	assert_str(service.register_battle(account, character, "enc_cistern_keeper", 0, first).error).is_equal("cistern_stage_locked")
	assert_bool(service.register_battle(account, character, "enc_cistern_entry", 0, first).ok).is_true()
	first.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_cistern_entry", 0, first).ok).is_true()
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_bool(service.perform(account, character, "enter_cistern", "", 1).resumed).is_true()
	var last := BattleSim.new(BattleRules.new(), [BattleUnit.make(1, 0, 0), BattleUnit.make(2, 1, 0)], 41)
	assert_bool(service.register_battle(account, character, "enc_cistern_keeper", 1, last).ok).is_true()
	last.winner = BattleSim.Winner.SIDE_A
	assert_bool(service.record_victory(account, character, "enc_cistern_keeper", 1, last).ok).is_true()
	assert_bool(service.perform(account, character, "walk_arrived", "z_watershed", 2).ok).is_true()
	assert_bool(service.perform(account, character, "turn_in", "q_sa_cistern_clear", 2).ok).is_true()
	assert_str(service.perform(account, character, "turn_in", "q_sa_cistern_clear", 2).error).is_equal("not_active")


func test_failed_quest_snapshot_rolls_back_revision_and_all_parts() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("atomic")
	var character := repo.create_character(account, "Snapshot", "warden")
	var before := {"progress": {"coins": 15}, "inventory": {"materials": {"key_tomb": 1}},
		"quests": {"active": {}}, "squad": {"formation": {1: 0}}}
	assert_int(repo.save_character(account, character, 0, before)).is_equal(1)
	assert_bool(db.execute("""CREATE TEMP TRIGGER reject_quest_snapshot BEFORE UPDATE ON quest_logs
		BEGIN SELECT RAISE(ABORT, 'test rollback'); END""")).is_true()
	var after := {"progress": {"coins": 70}, "inventory": {"materials": {}},
		"quests": {"completed": {"q_se_tomb_archive": true}}, "squad": {"formation": {1: 2}}}
	assert_int(repo.save_character(account, character, 1, after)).is_equal(-1)
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	var persisted := repo.load_character(account, character)
	assert_int(int(persisted["revision"])).is_equal(1)
	for part: String in before:
		assert_dict(persisted[part]).is_equal(before[part])
	assert_int(repo.save_character(account, character, 1, after)).is_equal(2)


func test_dune_reserve_keeps_its_cooldown_when_population_drops() -> void:
	assert_int(db.open(":memory:")).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var account := repo.create_account("Dune pilot")
	var character := repo.create_character(account, "Dune guardian", "warden")
	var row := repo.load_character(account, character)
	row.progress = {"zone": "z_dunes", "level": 20}
	assert_int(repo.save_character(account, character, int(row.revision), row)).is_equal(1)
	var data := GameData.load_dir()
	var pilot := DunesSpawnPilot.new(data, repo, SouthRouteService.new(repo, data))
	var now := 1000.0
	var first := "dunes_pack_1"
	assert_str(pilot.begin(account, character, 2, now, first).outcome).is_equal("started")
	assert_int(pilot.snapshot(account, character, 2, now).available.size()).is_equal(4)
	assert_bool(pilot.expire(character, now + DunesSpawnPilot.IDLE_TIMEOUT)).is_true()
	assert_int(pilot.snapshot(account, character, 2, now).available.size()).is_equal(5)
	for _group in 5:
		var pack: String = pilot.snapshot(account, character, 2, now).available[0]
		var setup: Dictionary = pilot.begin(account, character, 2, now, pack).setup
		var sim := DunesBattle.build(data, setup["class"], setup["level"])
		var outcome := ""
		for _step in 100:
			var index := sim.active_ids.find_custom(func(id): return sim.can_act(id).is_empty())
			var action := {"type": "end_turn"} if index < 0 else BattleAI.choose(sim, sim.active_ids[index])
			var update := pilot.command(account, character, now, action)
			for replay: Dictionary in update.get("commands", []):
				var result := sim.end_turn() if replay["type"] == "end_turn" else sim.submit(replay)
				assert_bool(result.ok).is_true()
			outcome = update.outcome
			if not outcome.is_empty():
				break
		assert_str(outcome).is_equal("shared_victory")
	assert_array(pilot.snapshot(account, character, 2, now).available).is_empty()
	assert_int(pilot.snapshot(account, character, 1, now).capacity).is_equal(3)
	assert_array(pilot.snapshot(account, character, 2, now).available).is_empty()
	var respawn := float(data.encounters[DunesSpawnPilot.ENCOUNTER]["respawn_seconds"])
	assert_array(pilot.snapshot(account, character, 2, now + respawn - 1.0).available).is_empty()
	assert_int(pilot.snapshot(account, character, 1, now + respawn).available.size()).is_equal(3)
	assert_int(pilot.snapshot(account, character, 2, now + respawn).available.size()).is_equal(5)


func test_auction_preserves_equipment_and_transfers_coins_once() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var seller := repo.create_account("seller")
	var buyer := repo.create_account("buyer")
	var seller_id := repo.create_character(seller, "Seller hero", "warden")
	var buyer_id := repo.create_character(buyer, "Buyer hero", "warden")
	var item := {"uid": 1, "def_id": "w_sword_2", "plus": 7, "wear": 45, "star_stone": "star_attack_3", "seal_opened": false}
	var bound := {"uid": 2, "def_id": "w_sword_2", "plus": 7, "seal_opened": true}
	assert_int(repo.save_character(seller, seller_id, 0, {"progress": {"zone": "z_rome", "coins": 0},
		"inventory": {"items": [item, bound], "next_uid": 3}, "quests": {}, "squad": {}})).is_equal(1)
	assert_int(repo.save_character(buyer, buyer_id, 0, {"progress": {"zone": "z_rome", "coins": 500},
		"inventory": {"items": [], "next_uid": 12}, "quests": {}, "squad": {}})).is_equal(1)
	var auction := RomeAuction.new(db, repo, GameData.load_dir())
	assert_str(auction.perform(seller, seller_id, "list", 2, 150).error).is_equal("bound_item")
	var result := auction.perform(seller, seller_id, "list", 1, 600)
	var lot_id := int(result.lots[0].id)
	assert_str(auction.perform(buyer, buyer_id, "buy", lot_id).error).is_equal("no_coins")
	assert_str(auction.perform(buyer, buyer_id, "cancel", lot_id).error).is_equal("ownership")
	assert_str(auction.perform(seller, seller_id, "cancel", lot_id).error).is_empty()
	assert_str(auction.perform(seller, seller_id, "claim", lot_id).error).is_empty()
	result = auction.perform(seller, seller_id, "list", 1, 150)
	lot_id = int(result.lots[0].id)
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_str(auction.perform(buyer, buyer_id, "buy", lot_id).error).is_empty()
	assert_str(auction.perform(buyer, buyer_id, "buy", lot_id).error).is_equal("missing_lot")
	var receipt := repo.load_character(buyer, buyer_id)
	assert_int(int(receipt.progress.coins)).is_equal(350)
	item.uid = 12
	assert_dict(receipt.inventory.items[0]).is_equal(item)
	assert_int(int(repo.load_character(seller, seller_id).progress.coins)).is_equal(150)


func test_auction_expiry_preserves_return_until_inventory_has_space() -> void:
	assert_int(db.open(path)).is_equal(OK)
	var repo := PlayerRepository.new(db)
	var seller := repo.create_account("return seller")
	var buyer := repo.create_account("return buyer")
	var seller_id := repo.create_character(seller, "Return seller", "warden")
	var buyer_id := repo.create_character(buyer, "Return buyer", "warden")
	var item := {"uid": 1, "def_id": "w_sword_2", "plus": 4, "wear": 22}
	var snapshot := {"progress": {"zone": "z_rome", "coins": 250},
		"inventory": {"items": [item], "next_uid": 2}, "quests": {}, "squad": {}}
	assert_int(repo.save_character(seller, seller_id, 0, snapshot)).is_equal(1)
	snapshot.inventory = {"items": [], "next_uid": 1}
	assert_int(repo.save_character(buyer, buyer_id, 0, snapshot)).is_equal(1)
	var clock := {"now": 100000}
	var gd := GameData.load_dir()
	var auction := RomeAuction.new(db, repo, gd, func(): return clock.now)
	var listing := auction.perform(seller, seller_id, "list", 1, 100)
	var lot_id := int(listing.lots[0].id)
	assert_int(int(listing.lots[0].seconds_left)).is_equal(RomeAuction.LOT_DURATION)
	clock.now += RomeAuction.LOT_DURATION
	db.close()
	assert_int(db.open(path)).is_equal(OK)
	assert_str(auction.perform(buyer, buyer_id, "buy", lot_id).error).is_equal("missing_lot")
	assert_str(auction.perform(buyer, buyer_id, "claim", lot_id).error).is_equal("ownership")
	assert_array(auction.snapshot(buyer, buyer_id).returns).is_empty()
	var row := repo.load_character(seller, seller_id)
	for i in auction.inventory_capacity():
		row.inventory.items.append({"uid": i + 2, "def_id": "w_sword_1"})
	assert_int(repo.save_character(seller, seller_id, int(row.revision), row)).is_greater(0)
	var full := auction.perform(seller, seller_id, "claim", lot_id)
	assert_str(full.error).is_equal("inventory_full")
	assert_dict(full.returns[0].item).is_equal(item)
	row = repo.load_character(seller, seller_id)
	row.inventory.items.pop_back()
	assert_int(repo.save_character(seller, seller_id, int(row.revision), row)).is_greater(0)
	assert_array(auction.perform(seller, seller_id, "claim", lot_id).returns).is_empty()
	assert_dict(repo.load_character(seller, seller_id).inventory.items.back()).is_equal(item)
	assert_str(auction.perform(seller, seller_id, "claim", lot_id).error).is_equal("missing_lot")
