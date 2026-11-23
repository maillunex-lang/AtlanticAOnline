class_name RomeAuction
extends RefCounted

const ZONE := "z_rome"
const NPC := "npc_rome_auctioneer"
const MAX_PRICE := 100000000
const MAX_LOTS := 50
const MAX_OWN_LOTS := 5
const LOT_DURATION := 86400

var _db: ServerDatabase
var _players: PlayerRepository
var _data: GameData
var _clock: Callable


func _init(db: ServerDatabase, players: PlayerRepository, data: GameData, clock := Callable()) -> void:
	_db = db
	_players = players
	_data = data
	_clock = clock if clock.is_valid() else Time.get_unix_time_from_system


func perform(account: int, character: int, action: String, id := 0, price := 0) -> Dictionary:
	var now := int(_clock.call())
	if not _settle_due_at(now) or not _db.execute("BEGIN IMMEDIATE"):
		return {"error": "storage"}
	var error := _perform(account, character, action, id, price, now)
	if not error.is_empty() or not _db.execute("COMMIT"):
		_db.execute("ROLLBACK")
		var current := snapshot(account, character)
		current["error"] = error if not error.is_empty() else "storage"
		return current
	return snapshot(account, character)


func _perform(account: int, character: int, action: String, id: int, price: int, now: int) -> String:
	var player := _players.load_character(account, character)
	if player.is_empty() or player.progress.get("zone", "") != ZONE:
		return "wrong_zone"
	match action:
		"status":
			return ""
		"list", "list_bid":
			return _list_item(player, id, price, now, action == "list_bid")
		"bid":
			return _bid(player, id, price, now)
		"buy", "cancel", "claim":
			return _transfer_lot(player, id, action, now)
	return "unknown_action"


func _list_item(player: Dictionary, uid: int, price: int, now: int, bidding: bool) -> String:
	if price < 1 or price > MAX_PRICE:
		return "invalid_price"
	var items: Array = player.inventory.get("items", [])
	for index in items.size():
		var item: Dictionary = items[index]
		if int(item.get("uid", 0)) != uid:
			continue
		if not _tradable(item):
			return "bound_item"
		if not _db.execute("SELECT COUNT(*) AS total, COUNT(CASE WHEN seller_id = ? THEN 1 END) AS own FROM auction_lots WHERE expires_at > ?", [player.id, now]):
			return "storage"
		if int(_db.rows[0].total) >= MAX_LOTS or int(_db.rows[0].own) >= MAX_OWN_LOTS:
			return "lot_limit"
		if not _db.execute("INSERT INTO auction_lots(seller_id, price, item, expires_at, bidding) VALUES (?, ?, ?, ?, ?)", [player.id, price, var_to_bytes(item), now + LOT_DURATION, int(bidding)]):
			return "storage"
		items.remove_at(index)
		return "" if _save(player) else "storage"
	return "missing_item"


func _transfer_lot(player: Dictionary, id: int, action: String, now: int) -> String:
	var buy := action == "buy"
	if not _db.execute("""SELECT l.*, c.account_id AS seller_account FROM auction_lots l
		JOIN characters c ON c.id = l.seller_id WHERE l.id = ?""", [id]):
		return "storage"
	if _db.rows.is_empty():
		return "missing_lot"
	var lot: Dictionary = _db.rows[0].duplicate()
	var expired := bool(lot.settled) or int(lot.expires_at) <= now
	if expired != (action == "claim"):
		return "missing_lot"
	var has_bid := int(lot.bid) > 0
	var won := action == "claim" and has_bid
	if won and not bool(lot.settled):
		return "missing_lot"
	var owner := int(lot.bidder_id) if won else int(lot.seller_id)
	if (int(lot.seller_account) == int(player.account_id) if buy else owner != int(player.id)):
		return "ownership"
	if buy and bool(lot.bidding):
		return "bids_only"
	if action == "cancel" and has_bid:
		return "has_bid"
	if action == "cancel":
		return "" if _db.execute("UPDATE auction_lots SET expires_at = 0 WHERE id = ?", [id]) else "storage"
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
	if buy or won:
		var uid := int(player.inventory.get("next_uid", 1))
		for owned: Dictionary in items:
			uid = maxi(uid, int(owned.uid) + 1)
		item.uid = uid
		player.inventory["next_uid"] = uid + 1
	items.append(item)
	player.inventory["items"] = items
	if not _save(player) or (buy and not _credit(int(lot.seller_id), int(lot.price))) or not _db.execute("DELETE FROM auction_lots WHERE id = ?", [id]):
		return "storage"
	return ""


func _bid(player: Dictionary, id: int, amount: int, now: int) -> String:
	if not _db.execute("""SELECT l.*, c.account_id AS seller_account FROM auction_lots l
		JOIN characters c ON c.id = l.seller_id WHERE l.id = ? AND l.bidding = 1 AND l.settled = 0 AND l.expires_at > ?""", [id, now]):
		return "storage"
	if _db.rows.is_empty():
		return "missing_lot"
	var lot: Dictionary = _db.rows[0].duplicate()
	if int(lot.seller_account) == int(player.account_id):
		return "ownership"
	var previous := int(lot.bid)
	if amount < maxi(int(lot.price), previous + 1) or amount > MAX_PRICE:
		return "bid_too_low" if amount <= MAX_PRICE else "invalid_price"
	var raising := previous > 0 and int(lot.bidder_id) == int(player.id)
	var cost := amount - previous if raising else amount
	var coins := int(player.progress.get("coins", 0))
	if coins < cost:
		return "no_coins"
	player.progress["coins"] = coins - cost
	if (previous > 0 and not raising and not _credit(int(lot.bidder_id), previous)) or not _save(player) \
			or not _db.execute("UPDATE auction_lots SET bidder_id = ?, bid = ? WHERE id = ?", [player.id, amount, id]):
		return "storage"
	return ""


func settle_due() -> void:
	_settle_due_at(int(_clock.call()))


func _settle_due_at(now: int) -> bool:
	if not _db.execute("SELECT 1 FROM auction_lots WHERE bidding = 1 AND settled = 0 AND bid > 0 AND expires_at <= ? LIMIT 1", [now]):
		return false
	if _db.rows.is_empty():
		return true
	if not _db.execute("BEGIN IMMEDIATE"):
		return false
	if _settle_expired(now) and _db.execute("COMMIT"):
		return true
	_db.execute("ROLLBACK")
	return false


func _settle_expired(now: int) -> bool:
	if not _db.execute("SELECT id, seller_id, bid FROM auction_lots WHERE bidding = 1 AND settled = 0 AND bid > 0 AND expires_at <= ?", [now]):
		return false
	var due := _db.rows.duplicate(true)
	for lot: Dictionary in due:
		if not _credit(int(lot.seller_id), int(lot.bid)) or not _db.execute("UPDATE auction_lots SET settled = 1 WHERE id = ?", [lot.id]):
			return false
	return true


func _credit(character: int, amount: int) -> bool:
	var account := _players._find("SELECT account_id FROM characters WHERE id = ?", [character])
	if account.is_empty():
		return false
	var row := _players.load_character(int(account.account_id), character)
	if row.is_empty():
		return false
	row.progress["coins"] = int(row.progress.get("coins", 0)) + amount
	return _save(row)


func _save(player: Dictionary) -> bool:
	return _players._save_parts(int(player.account_id), int(player.id), int(player.revision), player)


func _tradable(item: Dictionary) -> bool:
	var definition: ItemDef = _data.items.get(str(item.get("def_id", "")))
	return definition != null and definition.is_equip() and not item.get("seal_opened", false)


func snapshot(account: int, character: int) -> Dictionary:
	var player := _players.load_character(account, character)
	if player.is_empty() or player.progress.get("zone", "") != ZONE:
		return {"error": "wrong_zone"}
	var now := int(_clock.call())
	if not _db.execute("""SELECT * FROM auction_lots
		WHERE (settled = 0 AND expires_at > ?) OR (bid = 0 AND seller_id = ?) OR (settled = 1 AND bidder_id = ?) ORDER BY id""", [now, character, character]):
		return {"error": "storage"}
	var lots: Array = []
	var returns: Array = []
	for row: Dictionary in _db.rows:
		var item: Variant = bytes_to_var(row.item)
		if not item is Dictionary:
			continue
		if bool(row.settled) or int(row.expires_at) <= now:
			returns.append({"id": int(row.id), "item": item})
		else:
			lots.append({"id": int(row.id), "own": int(row.seller_id) == character,
				"price": int(row.price), "item": item, "seconds_left": int(row.expires_at) - now,
				"bidding": bool(row.bidding), "bid": int(row.bid), "leading": row.bidder_id != null and int(row.bidder_id) == character})
	var items: Array = []
	for item: Dictionary in player.inventory.get("items", []):
		if _tradable(item):
			items.append(item)
	return {"error": "", "lots": lots, "returns": returns, "items": items, "coins": int(player.progress.get("coins", 0))}


func inventory_capacity() -> int:
	return int(_data.rules["inventory_capacity"])
