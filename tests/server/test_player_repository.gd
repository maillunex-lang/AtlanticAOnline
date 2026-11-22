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
