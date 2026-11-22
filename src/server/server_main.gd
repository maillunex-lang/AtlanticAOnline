class_name ServerMain
extends Node
## Авторитетный сервер (Godot headless), владеющий серверным хранилищем.

const DEFAULT_DB_PATH := "user://atlantic-server.db"
const RECONNECT_MS := 120_000

var database: ServerDatabase
var players: PlayerRepository
var south_route: SouthRouteService
var peer: ENetMultiplayerPeer

var _login_digest := PackedByteArray()
var _account_id := 0
var _session := PackedByteArray()
var _session_peer := 0
var _resume_until := 0
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
	south_route = SouthRouteService.new(players, GameData.load_dir())
	print("Серверная SQLite готова, схема v%d" % ServerDatabase.MIGRATIONS.size())
	var key := OS.get_environment("ATLANTIC_LOCAL_LOGIN_KEY")
	if not key.is_empty():
		if key.length() != NetConfig.SECRET_BYTES * 2 or not key.is_valid_hex_number(false):
			push_error("ATLANTIC_LOCAL_LOGIN_KEY: ожидается 32-байтовый ключ в hex")
			_close_database()
			return ERR_INVALID_PARAMETER
		var account := players.find_account("local-playtest")
		_account_id = players.create_account("local-playtest") if account.is_empty() else int(account["id"])
		if _account_id <= 0:
			_close_database()
			return ERR_CANT_CREATE
		_login_digest = _digest(key.hex_decode())
	peer = ENetMultiplayerPeer.new()
	if not _login_digest.is_empty():
		peer.set_bind_ip(NetConfig.DEFAULT_HOST)
	var err := peer.create_server(port, NetConfig.MAX_CLIENTS)
	if err != OK:
		push_error("Сервер не запущен, порт %d, ошибка %s" % [port, error_string(err)])
		_close_database()
		return err
	var scene_network := multiplayer as SceneMultiplayer
	if _login_digest.is_empty():
		scene_network.auth_callback = _check_protocol
		scene_network.peer_authenticating.connect(_send_protocol)
	else:
		scene_network.auth_callback = _check_session
		scene_network.peer_authentication_failed.connect(_forget_peer)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Сервер слушает порт %d, протокол v%d" % [port, NetConfig.PROTOCOL_VERSION])
	return OK


func _exit_tree() -> void:
	if peer != null and multiplayer.multiplayer_peer == peer:
		(multiplayer as SceneMultiplayer).auth_callback = Callable()
		multiplayer.multiplayer_peer = null
		peer.close()
	_close_database()


func _close_database() -> void:
	south_route = null
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


## Use the engine-assigned peer ID when authorizing future gameplay RPCs.
func account_for_peer(id: int) -> int:
	return _account_id if id > 0 and id == _session_peer and id in multiplayer.get_peers() else 0


func _check_session(id: int, packet: PackedByteArray) -> void:
	var login := NetConfig.decode_session(packet, NetConfig.LOGIN_KEY)
	var resume := NetConfig.decode_session(packet, NetConfig.RESUME_SESSION)
	var valid_login := not login.is_empty() and _crypto.constant_time_compare(_digest(login), _login_digest)
	var valid_resume := not resume.is_empty() and Time.get_ticks_msec() < _resume_until \
		and _crypto.constant_time_compare(resume, _session)
	if _session_peer != 0 or not (valid_login or valid_resume):
		peer.disconnect_peer(id)
		return
	var token := _crypto.generate_random_bytes(NetConfig.SECRET_BYTES)
	var network := multiplayer as SceneMultiplayer
	if token.size() != NetConfig.SECRET_BYTES \
		or network.send_auth(id, NetConfig.encode_session(NetConfig.SESSION_GRANTED, token)) != OK \
		or network.complete_auth(id) != OK:
		peer.disconnect_peer(id)
		return
	_session = token
	_session_peer = id
	_resume_until = 0


func _forget_peer(id: int) -> void:
	if id == _session_peer:
		_session_peer = 0
		_resume_until = Time.get_ticks_msec() + RECONNECT_MS


func _digest(secret: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(secret)
	return hash.finish()
