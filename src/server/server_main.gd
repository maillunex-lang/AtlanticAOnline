class_name ServerMain
extends Node
## Авторитетный сервер (Godot headless). Заготовка GDD-02: только приём подключений.

var peer: ENetMultiplayerPeer


func start(port: int = NetConfig.DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetConfig.MAX_CLIENTS)
	if err != OK:
		push_error("Сервер не запущен, порт %d, ошибка %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Сервер слушает порт %d, протокол v%d" % [port, NetConfig.PROTOCOL_VERSION])
	return OK


func _on_peer_connected(id: int) -> void:
	print("Игрок подключился: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	print("Игрок отключился: %d" % id)
