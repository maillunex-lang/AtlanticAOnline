extends SceneTree
## Два независимых ENet-клиента подключаются к одному локальному серверу.

class PilotClient extends Node:
	var api := SceneMultiplayer.new()
	var transport := ENetMultiplayerPeer.new()
	var channel := WorldPresenceChannel.new()
	var connected := false
	var last: Array = []
	var dunes: Dictionary = {}
	var outcome := ""
	var update: Dictionary = {}

	func setup(tree: SceneTree, port: int, key: PackedByteArray) -> Error:
		tree.root.add_child(self)
		tree.set_multiplayer(api, get_path())
		channel.name = "WorldPresence"
		add_child(channel)
		channel.snapshot.connect(func(zone: String, count: int, error: String): last = [zone, count, error])
		channel.dunes_snapshot.connect(func(state: Dictionary, result: String):
			dunes = state
			if not result.is_empty():
				outcome = result)
		channel.battle_updated.connect(func(value): update = value)
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
		update = {}
		outcome = ""
		channel.request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action, target)


	func command(action: Dictionary) -> void:
		update = {}
		channel.battle_command.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action)


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
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""] and first.dunes.get("capacity") == 3 and second.last == ["z_oasis", 1, ""] and first.dunes.get("capacity") == 3, "Игроки в разных зонах"):
		return
	second.send("travel", "z_dunes")
	if not await _wait_for(func(): return first.last == ["z_dunes", 2, ""] and second.last == first.last and second.dunes.get("capacity") == 5, "Два героя в дюнах"):
		return
	second.send("dunes_begin", "dunes_pack_5")
	if not await _wait_for(func(): return second.update.get("outcome") == "started" and "dunes_pack_5" not in first.dunes.available, "Резервный дозор занят"):
		return
	second.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""] and first.dunes.get("capacity") == 3, "Отключение убирает героя из зоны"):
		return
	var reconnected := PilotClient.new()
	if reconnected.setup(self, port, OS.get_environment("ATLANTIC_SMOKE_SECRET_SECOND").hex_decode()) != OK:
		_fail("Повторное подключение")
		return
	if not await _wait_for(func(): return reconnected.connected, "Повторная сессия"):
		return
	reconnected.send("enter")
	if not await _wait_for(func(): return first.last == ["z_dunes", 2, ""] and reconnected.last == first.last and "dunes_pack_5" in reconnected.dunes.get("available", []), "Сохранённая зона и освобождённый дозор"):
		return
	if not await _check_dunes(first, reconnected):
		return
	reconnected.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if not await _wait_for(func(): return first.last == ["z_dunes", 1, ""] and first.dunes.get("capacity") == 3, "Отключение повторной сессии"):
		return
	first.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	await create_timer(0.3).timeout
	print("WP-70 presence PASS: enter, travel, disconnect and saved zone")
	quit()


func _check_dunes(first: PilotClient, second: PilotClient) -> bool:
	first.send("dunes_accept")
	second.send("dunes_accept")
	if not await _wait_for(func(): return first.outcome == "accept" and second.outcome == "accept", "Оба приняли поручение Саида"):
		return false
	var first_pack: String = second.dunes.available[0]
	second.send("dunes_begin", first_pack)
	if not await _wait_for(func(): return second.update.get("outcome") == "started" and first_pack not in first.dunes.available, "Общий дозор забронирован"):
		return false
	var setup: Dictionary = second.update.setup
	first.send("dunes_begin", first_pack)
	if not await _wait_for(func(): return first.update.get("outcome") == "no_pack", "Дозор уже занят другим героем"):
		return false
	second.command({"type": "attack", "actor": "не боец", "target": 100})
	if not await _wait_for(func(): return second.update.get("outcome") == "bad_action", "Сервер отклонил неверную команду"):
		return false
	if not await _win_battle(second, setup, "shared_victory"):
		return false
	if not await _wait_for(func(): return second.dunes.trophies == 1 and first.dunes.trophies == 0, "Трофей принадлежит победителю"):
		return false
	for step in 4:
		first.send("dunes_begin", str(first.dunes.available[0]))
		if not await _wait_for(func(): return first.update.get("outcome") == "started", "Общие и резервные дозорные"):
			return false
		if not await _win_battle(first, first.update.setup, "shared_victory"):
			return false
		if not await _wait_for(func(): return first.dunes.available.size() == 3 - step, "Дозор ждёт возрождения"):
			return false
	if first.dunes.quest != "ready" or first.dunes.trophies != 2:
		_fail("У первого героя два трофея")
		return false
	first.send("dunes_begin", "personal")
	if not await _wait_for(func(): return first.update.get("outcome") == "no_pack", "Личный отряд только для незавершённой цели"):
		return false
	second.send("dunes_begin", "personal")
	if not await _wait_for(func(): return second.update.get("outcome") == "started", "Личный дозор для второго героя"):
		return false
	if not await _win_battle(second, second.update.setup, "personal_victory"):
		return false
	if not await _wait_for(func(): return second.dunes.quest == "ready", "Оба клейма у второго героя"):
		return false
	first.send("dunes_turn_in")
	second.send("dunes_turn_in")
	if not await _wait_for(func(): return first.outcome == "turn_in" and second.outcome == "turn_in" and first.dunes.quest == "done" and second.dunes.quest == "done", "Оба сдали поручение"):
		return false
	second.send("dunes_turn_in")
	if not await _wait_for(func(): return second.outcome != "" and second.outcome != "turn_in" and second.dunes.quest == "done", "Повторная сдача отклонена"):
		return false
	print("WP-70 dunes PASS: 3 to 5 shared packs, personal fallback, both turn-ins")
	return true


func _win_battle(client: PilotClient, setup: Dictionary, expected: String) -> bool:
	var sim := DunesBattle.build(GameData.load_dir(), setup["class"], setup["level"])
	for _step in 100:
		var index := sim.active_ids.find_custom(func(id): return sim.can_act(id).is_empty())
		client.command({"type": "end_turn"} if index < 0 else BattleAI.choose(sim, sim.active_ids[index]))
		if not await _wait_for(func(): return not client.update.is_empty(), "Ответ сервера на ход"):
			return false
		for command: Dictionary in client.update.get("commands", []):
			var result := sim.end_turn() if command["type"] == "end_turn" else sim.submit(command)
			if not result.ok:
				_fail("У клиента и сервера разные ходы")
				return false
		var outcome: String = client.update["outcome"]
		if not outcome.is_empty():
			if outcome != expected or sim.winner != BattleSim.Winner.SIDE_A:
				_fail("Результат боя: " + outcome)
				return false
			return true
	_fail("Бой превысил лимит команд")
	return false


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
