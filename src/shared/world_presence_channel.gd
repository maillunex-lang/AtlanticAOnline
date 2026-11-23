class_name WorldPresenceChannel
extends Node
## Протокол закрытого пилота. Сервер определяет персонажа по сессии.

signal requested(peer_id: int, action: String, target: String)
signal snapshot(zone: String, population: int, error: String)
signal dunes_snapshot(state: Dictionary, outcome: String)
signal battle_requested(peer_id: int, action: Dictionary)
signal battle_updated(update: Dictionary)
signal move_requested(peer_id: int, destination: Vector2)
signal positions_received(position: Vector2, neighbors: Dictionary)
signal auction_updated(state: Dictionary)

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


@rpc("any_peer", "call_remote", "reliable")
func battle_command(action: Dictionary) -> void:
	if multiplayer.is_server():
		battle_requested.emit(multiplayer.get_remote_sender_id(), action)


@rpc("authority", "call_remote", "reliable")
func receive_battle(update: Dictionary) -> void:
	battle_updated.emit(update)


@rpc("any_peer", "call_remote", "reliable")
func move_toward(destination: Vector2) -> void:
	if multiplayer.is_server():
		move_requested.emit(multiplayer.get_remote_sender_id(), destination)


@rpc("authority", "call_remote", "reliable")
func receive_positions(position: Vector2, neighbors: Dictionary) -> void:
	positions_received.emit(position, neighbors)


@rpc("authority", "call_remote", "reliable")
func receive_auction(state: Dictionary) -> void:
	auction_updated.emit(state)
