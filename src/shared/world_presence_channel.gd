class_name WorldPresenceChannel
extends Node
## Протокол закрытого пилота. Сервер определяет персонажа по сессии.

signal requested(peer_id: int, action: String, target: String)
signal snapshot(zone: String, population: int, error: String)
signal dunes_snapshot(state: Dictionary, outcome: String)

@rpc("any_peer", "call_remote", "reliable")
func request(action: String, target: String) -> void:
	if multiplayer.is_server():
		requested.emit(multiplayer.get_remote_sender_id(), action, target)


@rpc("authority", "call_remote", "reliable")
func receive(zone: String, population: int, error: String) -> void:
	snapshot.emit(zone, population, error)


@rpc("authority", "call_remote", "reliable")
func receive_dunes(state: Dictionary, outcome: String) -> void:
	dunes_snapshot.emit(state, outcome)
