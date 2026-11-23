class_name RomeAuction
extends RefCounted

const ZONE := "z_rome"
const NPC := "npc_rome_auctioneer"
const MAX_PRICE := 100000000
const MAX_LOTS := 50
const MAX_OWN_LOTS := 5

var _db: ServerDatabase
var _players: PlayerRepository
var _data: GameData


func _init(db: ServerDatabase, players: PlayerRepository, data: GameData) -> void:
	_db = db
	_players = players
	_data = data


func perform(account: int, character: int, action: String, id := 0, price := 0) -> Dictionary:
	if not _db.execute("BEGIN IMMEDIATE"):
		return {"error": "storage"}
	var error := _perform(account, character, action, id, price)
	if not error.is_empty() or not _db.execute("COMMIT"):
		_db.execute("ROLLBACK")
		var current := snapshot(account, character)
		current["error"] = error if not error.is_empty() else "storage"
		return current
	return snapshot(account, character)


func _perform(account: int, character: int, action: String, id: int, price: int) -> String:
	var player := _players.load_character(account, character)
	if player.is_empty() or player.progress.get("zone", "") != ZONE:
		return "wrong_zone"
	match action:
		"status":
			return ""
		"list":
			return _list_item(player, id, price)
		"buy", "cancel":
			return _transfer_lot(player, id, action == "buy")
	return "unknown_action"


func _list_item(player: Dictionary, uid: int, price: int) -> String:
	if price < 1 or price > MAX_PRICE:
		return "invalid_price"
	var items: Array = player.inventory.get("items", [])
	for index in items.size():
		var item: Dictionary = items[index]
		if int(item.get("uid", 0)) != uid:
			continue
		if not _tradable(item):
			return "bound_item"
		if not _db.execute("SELECT COUNT(*) AS total, COUNT(CASE WHEN seller_id = ? THEN 1 END) AS own FROM auction_lots", [player.id]):
			return "storage"
		if int(_db.rows[0].total) >= MAX_LOTS or int(_db.rows[0].own) >= MAX_OWN_LOTS:
			return "lot_limit"
		if not _db.execute("INSERT INTO auction_lots(seller_id, price, item) VALUES (?, ?, ?)", [player.id, price, var_to_bytes(item)]):
			return "storage"
		items.remove_at(index)
		return "" if _save(player) else "storage"
	return "missing_item"


func _transfer_lot(player: Dictionary, id: int, buy: bool) -> String:
	if not _db.execute("""SELECT l.*, c.account_id AS seller_account FROM auction_lots l
		JOIN characters c ON c.id = l.seller_id WHERE l.id = ?""", [id]):
		return "storage"
	if _db.rows.is_empty():
		return "missing_lot"
	var lot: Dictionary = _db.rows[0].duplicate()
	if (int(lot.seller_account) == int(player.account_id) if buy else int(lot.seller_id) != int(player.id)):
		return "ownership"
	var items: Array = player.inventory.get("items", [])
	if items.size() >= inventory_capacity():
		return "inventory_full"
	var item: Variant = bytes_to_var(lot.item)
	if not item is Dictionary:
		return "storage"
	if buy:
		var price := int(lot.price)
		var coins := int(player.progress.get("coins", 0))
		if coins < price:
			return "no_coins"
		player.progress["coins"] = coins - price
		var uid := int(player.inventory.get("next_uid", 1))
		for owned: Dictionary in items:
			uid = maxi(uid, int(owned.uid) + 1)
		item.uid = uid
		player.inventory["next_uid"] = uid + 1
	items.append(item)
	player.inventory["items"] = items
	if not _save(player) or (buy and not _save_seller(lot)) or not _db.execute("DELETE FROM auction_lots WHERE id = ?", [id]):
		return "storage"
	return ""


func _save_seller(lot: Dictionary) -> bool:
	var seller := _players.load_character(int(lot.seller_account), int(lot.seller_id))
	if seller.is_empty():
		return false
	seller.progress["coins"] = int(seller.progress.get("coins", 0)) + int(lot.price)
	return _save(seller)


func _save(player: Dictionary) -> bool:
	return _players._save_parts(int(player.account_id), int(player.id), int(player.revision), player)


func _tradable(item: Dictionary) -> bool:
	var definition: ItemDef = _data.items.get(str(item.get("def_id", "")))
	return definition != null and definition.is_equip() and not item.get("seal_opened", false)


func snapshot(account: int, character: int) -> Dictionary:
	var player := _players.load_character(account, character)
	if player.is_empty() or player.progress.get("zone", "") != ZONE:
		return {"error": "wrong_zone"}
	if not _db.execute("SELECT id, seller_id, price, item FROM auction_lots ORDER BY id LIMIT ?", [MAX_LOTS]):
		return {"error": "storage"}
	var lots: Array = []
	for row: Dictionary in _db.rows:
		var item: Variant = bytes_to_var(row.item)
		if item is Dictionary:
			lots.append({"id": int(row.id), "own": int(row.seller_id) == character, "price": int(row.price), "item": item})
	var items: Array = []
	for item: Dictionary in player.inventory.get("items", []):
		if _tradable(item):
			items.append(item)
	return {"error": "", "lots": lots, "items": items, "coins": int(player.progress.get("coins", 0))}


func inventory_capacity() -> int:
	return int(_data.rules["inventory_capacity"])
