class_name ServerDatabase
extends RefCounted
## Владеет соединением SQLite и последовательно применяет миграции схемы.

const MIGRATIONS := [
	[
		"CREATE TABLE accounts (id INTEGER PRIMARY KEY, login TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(login)) > 0))",
		"""CREATE TABLE characters (
			id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
			name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
			class_id TEXT NOT NULL CHECK (length(trim(class_id)) > 0), revision INTEGER NOT NULL DEFAULT 0,
			progress BLOB
		)""",
		"CREATE INDEX characters_account ON characters(account_id)",
	],
	[
		"CREATE TABLE inventories (character_id INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE, payload BLOB NOT NULL)",
		"CREATE TABLE quest_logs (character_id INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE, payload BLOB NOT NULL)",
		"CREATE TABLE squads (character_id INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE, payload BLOB NOT NULL)",
	],
	[
		"""CREATE TABLE auction_lots (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			seller_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
			price INTEGER NOT NULL CHECK (price > 0),
			item BLOB NOT NULL
		)""",
	],
]

var _connection: Object
var rows: Array:
	get:
		return _connection.get("query_result") if _connection != null else []


func open(path: String) -> Error:
	if _connection != null or path.is_empty():
		return ERR_INVALID_PARAMETER
	if not ClassDB.class_exists(&"SQLite"):
		return ERR_UNAVAILABLE
	_connection = ClassDB.instantiate(&"SQLite")
	_connection.set("path", path)
	_connection.set("foreign_keys", true)
	if not _connection.call("open_db"):
		_connection = null
		return ERR_CANT_OPEN
	if not execute("PRAGMA busy_timeout = 5000") or not _migrate():
		close()
		return ERR_INVALID_DATA
	return OK


func close() -> void:
	if _connection != null:
		_connection.call("close_db")
		_connection = null


func execute(statement: String, bindings: Array = []) -> bool:
	return _connection != null and bool(_connection.call("query_with_bindings", statement, bindings))


func _migrate() -> bool:
	# Serialize migrations with other processes opening the same database.
	if not execute("BEGIN IMMEDIATE"):
		return false
	if execute("PRAGMA user_version"):
		var version := int(rows[0]["user_version"])
		if version >= 0 and version <= MIGRATIONS.size():
			if _apply_migrations(version) and execute("COMMIT"):
				return true
	execute("ROLLBACK")
	return false


func _apply_migrations(version: int) -> bool:
	for index in range(version, MIGRATIONS.size()):
		for statement in MIGRATIONS[index]:
			if not execute(statement):
				return false
		if not execute("PRAGMA user_version = %d" % (index + 1)):
			return false
	return true
