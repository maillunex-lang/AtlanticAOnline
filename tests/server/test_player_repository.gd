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
