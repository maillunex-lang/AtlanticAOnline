class_name ServerMain
extends Node
## Авторитетный сервер (Godot headless), владеющий серверным хранилищем.

const DEFAULT_DB_PATH := "user://atlantic-server.db"
const RECONNECT_MS := 120_000

var database: ServerDatabase
var players: PlayerRepository
var south_route: SouthRouteService
var _auction: RomeAuction
var peer: ENetMultiplayerPeer

var _accounts: Dictionary = {}
var _peer_accounts: Dictionary = {}
var _zones: Dictionary = {}
var _presence: WorldPresenceChannel
var _dunes: DunesSpawnPilot
var _terrain: DunesTerrain
var _positions: Dictionary = {}
var _destinations: Dictionary = {}
var _position_elapsed := 0.0
var _crypto := Crypto.new()


func start(port: int = NetConfig.DEFAULT_PORT, db_path := DEFAULT_DB_PATH) -> Error:
	if database != null:
		return ERR_ALREADY_IN_USE
	database = ServerDatabase.new()
	var db_error := database.open(db_path)
	if db_error != OK:
		push_error("Серверная SQLite недоступна: %s" % error_string(db_error))
		database = null
		return db_error
	players = PlayerRepository.new(database)
	var data := GameData.load_dir()
	south_route = SouthRouteService.new(players, data)
	_auction = RomeAuction.new(database, players, data)
	print("Серверная SQLite готова, схема v%d" % ServerDatabase.MIGRATIONS.size())
	if not _load_local_accounts():
		push_error("Некорректная конфигурация локальных аккаунтов пилота.")
		_close_database()
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	if not _accounts.is_empty():
		peer.set_bind_ip(NetConfig.DEFAULT_HOST)
	var err := peer.create_server(port, NetConfig.MAX_CLIENTS)
	if err != OK:
		push_error("Сервер не запущен, порт %d, ошибка %s" % [port, error_string(err)])
		_close_database()
		return err
	var scene_network := multiplayer as SceneMultiplayer
	if _accounts.is_empty():
		scene_network.auth_callback = _check_protocol
		scene_network.peer_authenticating.connect(_send_protocol)
	else:
		scene_network.auth_callback = _check_session
		scene_network.peer_authentication_failed.connect(_forget_peer)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not _accounts.is_empty():
		_terrain = DunesTerrain.new(data)
		_dunes = DunesSpawnPilot.new(data, players, south_route)
		_presence = WorldPresenceChannel.new()
		_presence.name = "WorldPresence"
		get_tree().root.add_child.call_deferred(_presence)
		_presence.requested.connect(_handle_presence)
		_presence.move_requested.connect(_handle_move)
		_presence.battle_requested.connect(_handle_battle)
		var expiry := Timer.new()
		expiry.wait_time = 1.0
		expiry.autostart = true
		expiry.timeout.connect(_expire_battles)
		add_child(expiry)
	print("Сервер слушает порт %d, протокол v%d" % [port, NetConfig.PROTOCOL_VERSION])
	return OK


func _exit_tree() -> void:
	if peer != null and multiplayer.multiplayer_peer == peer:
		(multiplayer as SceneMultiplayer).auth_callback = Callable()
		multiplayer.multiplayer_peer = null
		peer.close()
	_close_database()


func _close_database() -> void:
	if is_instance_valid(_presence):
		_presence.queue_free()
	_accounts.clear()
	_peer_accounts.clear()
	_zones.clear()
	_positions.clear()
	_destinations.clear()
	_terrain = null
	_dunes = null
	south_route = null
	_auction = null
	players = null
	if database != null:
		database.close()
		database = null


func _send_protocol(id: int) -> void:
	var scene_network := multiplayer as SceneMultiplayer
	if scene_network.send_auth(id, NetConfig.encode_version(NetConfig.PROTOCOL_VERSION)) != OK:
		peer.disconnect_peer(id)


func _check_protocol(id: int, packet: PackedByteArray) -> void:
	var version := NetConfig.decode_version(packet)
	if not NetConfig.is_compatible(version):
		print("Несовместимый протокол: ожидался v%d, получен v%d" % [NetConfig.PROTOCOL_VERSION, version])
		peer.disconnect_peer(id)
		return
	var scene_network := multiplayer as SceneMultiplayer
	if scene_network.complete_auth(id) != OK:
		peer.disconnect_peer(id)


func _on_peer_connected(id: int) -> void:
	print("Игрок подключился: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	_forget_peer(id)
	print("Игрок отключился: %d" % id)


func account_for_peer(id: int) -> int:
	return int(_peer_accounts.get(id, 0)) if id in multiplayer.get_peers() else 0


func _load_local_accounts() -> bool:
	var path := OS.get_environment("ATLANTIC_LOCAL_ACCOUNTS_FILE")
	var key := OS.get_environment("ATLANTIC_LOCAL_LOGIN_KEY")
	var second := OS.get_environment("ATLANTIC_LOCAL_LOGIN_KEY_SECOND")
	if path.is_empty():
		return (key.is_empty() or _add_local_account(key, "local-playtest")) \
			and (second.is_empty() or (not key.is_empty() and _add_local_account(second, "local-playtest-second")))
	if not key.is_empty() or not second.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return false
	var rows: Variant = JSON.parse_string(file.get_as_text())
	if not rows is Array or rows.is_empty() or rows.size() > NetConfig.MAX_CLIENTS:
		return false
	var names := {}
	var keys := {}
	var name_pattern := RegEx.create_from_string("^[a-z0-9][a-z0-9_-]{0,31}$")
	for row in rows:
		if not row is Dictionary or not row.get("name") is String or not row.get("key") is String:
			return false
		var name: String = row["name"]
		var secret := NetConfig.parse_login_key(row["key"])
		var normalized := secret.hex_encode()
		if name_pattern.search(name) == null or names.has(name) or secret.is_empty() or keys.has(normalized):
			return false
		names[name] = true
		keys[normalized] = true
	for row in rows:
		if not _add_local_account(row["key"], row["name"]):
			return false
	return true


func _add_local_account(key: String, account_name: String) -> bool:
	var secret := NetConfig.parse_login_key(key)
	if secret.is_empty():
		return false
	var digest := _digest(secret)
	for session: Dictionary in _accounts.values():
		if _crypto.constant_time_compare(digest, session.digest):
			return false
	var row := players.find_account(account_name)
	var id := players.create_account(account_name) if row.is_empty() else int(row["id"])
	if id <= 0:
		return false
	_accounts[id] = {"digest": digest, "token": PackedByteArray(), "peer": 0, "until": 0, "name": account_name}
	return true


func _check_session(id: int, packet: PackedByteArray) -> void:
	var login := NetConfig.decode_session(packet, NetConfig.LOGIN_KEY)
	var resume := NetConfig.decode_session(packet, NetConfig.RESUME_SESSION)
	for account: int in _accounts:
		var session: Dictionary = _accounts[account]
		var valid_login := not login.is_empty() and _crypto.constant_time_compare(_digest(login), session.digest)
		var valid_resume := not resume.is_empty() and Time.get_ticks_msec() < int(session.until) \
			and _crypto.constant_time_compare(resume, session.token)
		if session.peer != 0 or not (valid_login or valid_resume):
			continue
		var token := _crypto.generate_random_bytes(NetConfig.SECRET_BYTES)
		var network := multiplayer as SceneMultiplayer
		if token.size() == NetConfig.SECRET_BYTES \
				and network.send_auth(id, NetConfig.encode_session(NetConfig.SESSION_GRANTED, token)) == OK \
				and network.complete_auth(id) == OK:
			session.token = token
			session.peer = id
			session.until = 0
			_peer_accounts[id] = account
			return
		break
	peer.disconnect_peer(id)


func _forget_peer(id: int) -> void:
	var account := int(_peer_accounts.get(id, 0))
	if account != 0:
		var session: Dictionary = _accounts[account]
		if _dunes != null:
			_dunes.cancel(int(session.get("character", 0)))
		session.peer = 0
		session.until = Time.get_ticks_msec() + RECONNECT_MS
		_peer_accounts.erase(id)
	_positions.erase(id)
	_destinations.erase(id)
	if _zones.erase(id):
		_send_presence.call_deferred()


func _handle_presence(id: int, action: String, target: String) -> void:
	var account := account_for_peer(id)
	if account == 0:
		return
	var session: Dictionary = _accounts[account]
	var error := ""
	match action:
		"enter":
			if not _zones.has(id):
				var row := players.load_named_character(account, str(session.name))
				if row.is_empty():
					var character := players.create_character(account, str(session.name), "warden")
					row = players.load_character(account, character)
				if not row.is_empty() and not row.progress.get("dunes_pilot", false):
					if (row.progress as Dictionary).is_empty():
						row.progress = {"zone": SeaFerry.OASIS, "level": 20}
					row.progress["dunes_pilot"] = true
					var completed: Dictionary = row.quests.get("completed", {})
					completed["q_se_clear_way"] = true
					row.quests["completed"] = completed
					if players.save_character(account, int(row.id), int(row.revision), row) < 0:
						row = {}
				if row.is_empty():
					error = "character_unavailable"
				else:
					session["character"] = int(row.id)
					_zones[id] = str(row.progress.get("zone", SeaFerry.OASIS))
					_positions[id] = _terrain.entrance(_zones[id])
		"auction_travel":
			error = _travel_auction(id, account, int(session.get("character", 0)))
		"auction_status", "auction_list", "auction_buy", "auction_cancel":
			_handle_auction(id, account, int(session.get("character", 0)), action.trim_prefix("auction_"), target)
			return
		"dunes_status", "dunes_accept", "dunes_begin", "dunes_turn_in":
			_handle_dunes(id, account, int(session.get("character", 0)), action, target)
			return
		_:
			error = "unknown_action"
	if error.is_empty():
		_send_presence()
		_send_positions()
	else:
		_reply_presence(id, error)


func _travel_auction(id: int, account: int, character: int) -> String:
	var zone := str(_zones.get(id, ""))
	if zone not in [SeaFerry.OASIS, RomeAuction.ZONE] or _dunes.in_battle(character):
		return "wrong_zone"
	var row := players.load_character(account, character)
	if row.is_empty():
		return "character_unavailable"
	var target := RomeAuction.ZONE if zone == SeaFerry.OASIS else SeaFerry.OASIS
	if target == RomeAuction.ZONE and not row.progress.get("auction_pilot_grant", false):
		var items: Array = row.inventory.get("items", [])
		if items.size() < _auction.inventory_capacity():
			var uid := int(row.inventory.get("next_uid", 1))
			for item: Dictionary in items:
				uid = maxi(uid, int(item.uid) + 1)
			items.append({"uid": uid, "def_id": "w_sword_2", "plus": 0})
			row.inventory["items"] = items
			row.inventory["next_uid"] = uid + 1
			row.progress["auction_pilot_grant"] = true
			row.progress["coins"] = int(row.progress.get("coins", 0)) + 1000
	row.progress["zone"] = target
	if players.save_character(account, character, int(row.revision), row) < 0:
		return "storage"
	_zones[id] = target
	_positions[id] = _terrain.entrance(target)
	_destinations.erase(id)
	return ""


func _handle_auction(peer_id: int, account: int, character: int, action: String, target: String) -> void:
	if _zones.get(peer_id) != RomeAuction.ZONE or not _positions.has(peer_id) \
			or (_positions[peer_id] as Vector2).distance_to(_terrain.auctioneer()) > 152.0:
		_presence.receive_auction.rpc_id(peer_id, {"error": "wrong_zone"})
		return
	var args := target.split(":", false, 2) if target.length() <= 48 else PackedStringArray()
	var id := int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 0
	var price := int(args[1]) if args.size() == 2 and args[1].is_valid_int() else 0
	_presence.receive_auction.rpc_id(peer_id, _auction.perform(account, character, action, id, price))


func _handle_move(id: int, destination: Vector2) -> void:
	var account := account_for_peer(id)
	if account == 0 or not _positions.has(id) or _dunes.in_battle(int(_accounts[account].character)):
		return
	if destination.is_finite() and not _terrain.zone_at(destination).is_empty():
		_destinations[id] = destination


func _physics_process(delta: float) -> void:
	if _terrain == null:
		return
	var zone_changed := false
	for id: int in _destinations.keys():
		var position: Vector2 = _positions[id]
		var destination: Vector2 = _destinations[id]
		var next := _terrain.walk(position, destination, delta)
		var zone := _terrain.zone_at(next)
		if zone != _zones[id]:
			var account := account_for_peer(id)
			if account == 0:
				continue
			var result := south_route.perform(account, int(_accounts[account].character),
				"walk_arrived", zone, Time.get_ticks_msec() / 1000.0)
			if not result.ok:
				_destinations.erase(id)
				continue
			_zones[id] = zone
			zone_changed = true
		_positions[id] = next
		if next.is_equal_approx(destination) or next.is_equal_approx(position):
			_destinations.erase(id)
	if zone_changed:
		_send_presence()
	_position_elapsed += delta
	if _position_elapsed >= 0.1 or zone_changed:
		_position_elapsed = 0.0
		_send_positions()


func _send_positions() -> void:
	for id: int in _positions:
		if id not in multiplayer.get_peers() or peer.get_peer(id).get_state() != ENetPacketPeer.STATE_CONNECTED:
			continue
		var neighbors := {}
		for other: int in _positions:
			if other != id and _zones[other] == _zones[id]:
				neighbors[other] = _positions[other]
		_presence.receive_positions.rpc_id(id, _positions[id], neighbors)


func _send_presence() -> void:
	for id: int in _zones:
		if id in multiplayer.get_peers() and peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED:
			_reply_presence(id, "")
			if _zones[id] == DunesSpawnPilot.ZONE:
				_reply_dunes(id, "")


func zone_population(zone: String) -> int:
	return _zones.values().count(zone)


func _reply_presence(id: int, error: String) -> void:
	var zone := str(_zones.get(id, ""))
	_presence.receive.rpc_id(id, zone, zone_population(zone), error)


func _handle_dunes(id: int, account: int, character: int, action: String, target: String) -> void:
	if _zones.get(id, "") != DunesSpawnPilot.ZONE:
		_presence.receive_dunes.rpc_id(id, {}, "wrong_zone")
		return
	var now := Time.get_unix_time_from_system()
	var result := ""
	match action:
		"dunes_begin":
			var pack_pos := _terrain.pack_position(target)
			var update := {"outcome": "too_far"}
			if (_positions[id] as Vector2).distance_to(pack_pos) <= 70.0:
				update = _dunes.begin(account, character, zone_population(DunesSpawnPilot.ZONE), now, target)
				if update.has("setup"):
					_destinations.erase(id)
			_presence.receive_battle.rpc_id(id, update)
			_send_presence()
			return
		"dunes_accept", "dunes_turn_in":
			if _dunes.in_battle(character):
				result = "battle_active"
			elif (_positions[id] as Vector2).distance_to(_terrain.point(DunesMap.SAID_TILE)) > 90.0:
				result = "too_far"
			else:
				var command := "accept" if action == "dunes_accept" else "turn_in"
				var quest := south_route.perform(account, character, command, DunesSpawnPilot.QUEST, now)
				result = command if quest.ok else str(quest.error)
	_reply_dunes(id, result)


func _handle_battle(id: int, action: Dictionary) -> void:
	var account := account_for_peer(id)
	if account == 0 or _zones.get(id, "") != DunesSpawnPilot.ZONE:
		return
	var character := int(_accounts[account].character)
	var update := _dunes.command(account, character, Time.get_unix_time_from_system(), action)
	_presence.receive_battle.rpc_id(id, update)
	if not _dunes.in_battle(character):
		_send_presence()


func _expire_battles() -> void:
	var changed := false
	var now := Time.get_unix_time_from_system()
	for id: int in _zones:
		var account := account_for_peer(id)
		if account != 0 and _dunes.expire(int(_accounts[account].character), now):
			_presence.receive_battle.rpc_id(id, {"outcome": "expired"})
			changed = true
	if changed:
		_send_presence()


func _reply_dunes(id: int, result: String) -> void:
	var account := account_for_peer(id)
	var state := _dunes.snapshot(account, int(_accounts[account].character),
		zone_population(DunesSpawnPilot.ZONE), Time.get_unix_time_from_system())
	_presence.receive_dunes.rpc_id(id, state, result)


func _digest(secret: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(secret)
	return hash.finish()
