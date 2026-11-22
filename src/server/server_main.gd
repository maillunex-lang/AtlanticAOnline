class_name ServerMain
extends Node
## Авторитетный сервер (Godot headless), владеющий серверным хранилищем.

const DEFAULT_DB_PATH := "user://atlantic-server.db"

var database: ServerDatabase
var players: PlayerRepository
var peer: ENetMultiplayerPeer


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
	print("Серверная SQLite готова, схема v%d" % ServerDatabase.MIGRATIONS.size())
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetConfig.MAX_CLIENTS)
	if err != OK:
		push_error("Сервер не запущен, порт %d, ошибка %s" % [port, error_string(err)])
		_close_database()
		return err
	var scene_network := multiplayer as SceneMultiplayer
	scene_network.auth_callback = _check_protocol
	scene_network.peer_authenticating.connect(_send_protocol)
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
	print("Игрок отключился: %d" % id)
