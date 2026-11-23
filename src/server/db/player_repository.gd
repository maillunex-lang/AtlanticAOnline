class_name PlayerRepository
extends RefCounted
## Серверный слой хранения. Снимок персонажа и его дочерних данных записывается одной транзакцией.

const PARTS := {"inventory": "inventories", "quests": "quest_logs", "squad": "squads"}
var _db: ServerDatabase


func _init(database: ServerDatabase) -> void:
	_db = database


func create_account(login: String) -> int:
	if not _db.execute("INSERT INTO accounts(login) VALUES (?) ON CONFLICT(login) DO NOTHING RETURNING id", [login.strip_edges()]):
		return 0
	return 0 if _db.rows.is_empty() else int(_db.rows[0]["id"])


func find_account(login: String) -> Dictionary:
	return _find("SELECT id, login FROM accounts WHERE login = ?", [login.strip_edges()])


func create_character(account_id: int, character_name: String, class_id: String) -> int:
	if not _db.execute("""INSERT INTO characters(account_id, name, class_id)
		VALUES (?, ?, ?) ON CONFLICT(name) DO NOTHING RETURNING id""", [account_id, character_name.strip_edges(), class_id]):
		return 0
	return 0 if _db.rows.is_empty() else int(_db.rows[0]["id"])


func load_named_character(account_id: int, character_name: String) -> Dictionary:
	var row := _find("SELECT id FROM characters WHERE account_id = ? AND name = ?", [account_id, character_name])
	return {} if row.is_empty() else load_character(account_id, int(row["id"]))


func load_character(account_id: int, character_id: int) -> Dictionary:
	var row := _find("""SELECT c.id, c.account_id, c.name, c.class_id, c.revision, c.progress,
		i.payload AS inventory, q.payload AS quests, s.payload AS squad
		FROM characters c
		LEFT JOIN inventories i ON i.character_id = c.id
		LEFT JOIN quest_logs q ON q.character_id = c.id
		LEFT JOIN squads s ON s.character_id = c.id
		WHERE c.id = ? AND c.account_id = ?""", [character_id, account_id])
	if row.is_empty():
		return {}
	for key in ["progress", "inventory", "quests", "squad"]:
		var stored: Variant = row[key]
		var decoded: Variant = {} if stored == null else bytes_to_var(stored)
		if not decoded is Dictionary:
			push_error("Повреждён снимок персонажа %d (%s)" % [character_id, key])
			return {}
		row[key] = decoded
	return row


## Returns the new revision, or -1 if the snapshot is stale or cannot be stored.
func save_character(account_id: int, character_id: int, revision: int, snapshot: Dictionary) -> int:
	for key in ["progress", "inventory", "quests", "squad"]:
		if not snapshot.get(key) is Dictionary:
			return -1
	if not _db.execute("BEGIN IMMEDIATE"):
		return -1
	if _save_parts(account_id, character_id, revision, snapshot) and _db.execute("COMMIT"):
		return revision + 1
	_db.execute("ROLLBACK")
	return -1


func _save_parts(account_id: int, character_id: int, revision: int, snapshot: Dictionary) -> bool:
	if not _db.execute("""UPDATE characters SET progress = ?, revision = revision + 1
		WHERE id = ? AND account_id = ? AND revision = ? RETURNING revision""",
		[var_to_bytes(snapshot["progress"]), character_id, account_id, revision]) or _db.rows.is_empty():
		return false
	for key: String in PARTS:
		var sql := """INSERT INTO %s(character_id, payload) VALUES (?, ?)
			ON CONFLICT(character_id) DO UPDATE SET payload = excluded.payload""" % PARTS[key]
		if not _db.execute(sql, [character_id, var_to_bytes(snapshot[key])]):
			return false
	return true


func _find(statement: String, bindings: Array) -> Dictionary:
	if not _db.execute(statement, bindings) or _db.rows.is_empty():
		return {}
	return _db.rows[0].duplicate()
