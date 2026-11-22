class_name ClientMain
extends Control
## Клиент (Android, горизонтальная ориентация). Заготовка GDD-02.

@onready var status: Label = $Status


func _ready() -> void:
	status.text = "Atlantic Online (клиент, протокол v%d)" % NetConfig.PROTOCOL_VERSION


func connect_to_server(host: String = NetConfig.DEFAULT_HOST, port: int = NetConfig.DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err
