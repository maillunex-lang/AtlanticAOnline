extends SceneTree
## Два независимых ENet-клиента подключаются к одному локальному серверу.

class PilotClient extends Node:
	var api := SceneMultiplayer.new()
	var transport := ENetMultiplayerPeer.new()
	var channel := WorldPresenceChannel.new()
	var connected := false
	var last: Array = []

	func setup(tree: SceneTree, port: int, key: PackedByteArray) -> Error:
		tree.root.add_child(self)
		tree.set_multiplayer(api, get_path())
		channel.name = "WorldPresence"
		add_child(channel)
		channel.snapshot.connect(func(zone: String, count: int, error: String): last = [zone, count, error])
		api.peer_authenticating.connect(func(id: int):
			api.send_auth(id, NetConfig.encode_session(NetConfig.LOGIN_KEY, key)))
		api.auth_callback = func(id: int, packet: PackedByteArray):
			if not NetConfig.decode_session(packet, NetConfig.SESSION_GRANTED).is_empty():
				api.complete_auth(id)
		api.connected_to_server.connect(func(): connected = true)
		var result := transport.create_client(NetConfig.DEFAULT_HOST, port)
		if result == OK:
			api.multiplayer_peer = transport
		return result

	func send(action: String, target := "") -> void:
		channel.request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action, target)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var first := PilotClient.new()
	var second := PilotClient.new()
	if first.setup(self, port, OS.get_environment("ATLANTIC_SMOKE_SECRET").hex_decode()) != OK \
			or second.setup(self, port, OS.get_environment("ATLANTIC_SMOKE_SECRET_SECOND").hex_decode()) != OK:
		_fail("Подключение")
		return
	if not await _wait_for(func(): return first.connected and second.connected, "Две одновременные сессии"):
		return
	first.send("travel", "z_dunes")
	if not await _wait_for(func(): return first.last == ["", 0, "not_in_world"], "Переход до входа в мир"):
		return
	first.send("enter")
	second.send("enter")
	if not await _wait_for(func(): return first.last == ["z_oasis", 2, ""] and second.last == first.last, "Два героя в оазисе"):
		return
	first.send("enter")
	first.send("travel", "z_rome")
	if not await _wait_for(func(): return first.last == ["z_oasis", 2, "invalid_route"], "Повторный вход и запрещённый переход"):
		return
	first.send("travel", "z_dunes")
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""] and second.last == ["z_oasis", 1, ""], "Игроки в разных зонах"):
		return
	second.send("travel", "z_dunes")
	if not await _wait_for(func(): return first.last == ["z_dunes", 2, ""] and second.last == first.last, "Два героя в дюнах"):
		return
	second.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""], "Отключение убирает героя из зоны"):
		return
	var reconnected := PilotClient.new()
	if reconnected.setup(self, port, OS.get_environment("ATLANTIC_SMOKE_SECRET_SECOND").hex_decode()) != OK:
		_fail("Повторное подключение")
		return
	if not await _wait_for(func(): return reconnected.connected, "Повторная сессия"):
		return
	reconnected.send("enter")
	if not await _wait_for(func(): return first.last == ["z_dunes", 2, ""] and reconnected.last == first.last, "Восстановление сохранённой зоны"):
		return
	reconnected.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""], "Отключение повторной сессии"):
		return
	first.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	await create_timer(0.3).timeout
	print("WP-70 presence PASS: enter, travel, disconnect and saved zone")
	quit()


func _wait_for(predicate: Callable, step: String) -> bool:
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	_fail(step)
	return false


func _fail(step: String) -> void:
	printerr("WP-70 presence FAIL: ", step)
	quit(1)
