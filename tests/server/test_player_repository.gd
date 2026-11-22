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
