extends SceneTree
## Проверяет режим обычного клиента через реальные элементы карты и экрана боя.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var client := DunesPilotClient.new()
	root.add_child(client)
	client.start(port, OS.get_environment("ATLANTIC_SMOKE_SECRET").hex_decode())
	if not await _wait_for(func(): return client._zone == SeaFerry.OASIS, "Вход в Оазис"):
		return
	client.map.arrive_at(client._point(Vector2i(31, 111)), SeaFerry.OASIS, false)
	if not client.map._move(Vector2(64, 0)):
		_fail("Проход из Оазиса в Дюны")
		return
	if not await _wait_for(func(): return client._zone == DunesPilotClient.DUNES and client._state.get("capacity") == 3, "Сервер подтвердил переход"):
		return
	for pack: EnemySpawn in client._packs.values():
		client.map.streamer.prime(pack.position)
		if client.map._blocked(pack.position):
			_fail("Непроходимая точка дозора " + str(pack.position / 64.0))
			return
	var location := Vector2(76.5, 110.5) * client.map.grid.tile_px
	client.map.arrive_at(location, DunesPilotClient.DUNES, false)
	var said: NpcMarker
	for npc in client.map.npcs:
		if npc.npc_id == "npc_said":
			said = npc
			break
	if said == null:
		_fail("Саид присутствует на карте")
		return
	client.map.arrive_at(said.global_position, DunesPilotClient.DUNES, false)
	if not await _wait_for(func(): return client.hud.interact_button.visible, "Кнопка разговора с Саидом"):
		return
	client.hud.interact_button.pressed.emit()
	if client._info == null:
		_fail("Диалог с Саидом")
		return
	(client._info.choice_list.get_child(0) as Button).pressed.emit()
	if not await _wait_for(func(): return client._state.get("quest") == "active", "Принятие поручения в диалоге"):
		return
	(client._info.choice_list.get_child(-1) as Button).pressed.emit()
	var troop: EnemySpawn = client._packs["dunes_pack_1"]
	if not troop.alive:
		_fail("Дозор виден на карте")
		return
	client.map.arrive_at(troop.position, DunesPilotClient.DUNES, false)
	if not await _wait_for(func(): return client.battle != null, "Контакт открывает экран боя"):
		return
	client.battle.speed = 25.0
	var sim := client.battle.sim
	var actor: int = sim.active_ids[0]
	client.battle._on_unit_clicked(actor)
	if client.battle.mode != BattleView.Mode.PICK_ACTION:
		_fail("Можно выбрать бойца")
		return
	client.battle._perform({"type": "guard", "actor": actor})
	if not await _wait_for(func(): return sim.unit_by_id(actor).guarding and client.battle.mode == BattleView.Mode.IDLE, "Сервер подтвердил защиту"):
		return
	client.battle.end_button.pressed.emit()
	if not await _wait_for(func(): return sim.current_side == BattleRules.SIDE_A and sim.round_number > 1 and client.battle.mode == BattleView.Mode.IDLE, "Сервер выполнил ход врага"):
		return
	client.battle.flee_button.pressed.emit()
	if not await _wait_for(func(): return client.battle == null and troop.alive and client.map.visible, "Отступление освободило дозор"):
		return
	client._transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	await create_timer(0.3).timeout
	print("WP-70 client PASS: map, Said dialogue, guard, end turn and flee")
	quit()


func _wait_for(predicate: Callable, step: String) -> bool:
	var deadline := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	_fail(step)
	return false


func _fail(step: String) -> void:
	printerr("WP-70 client FAIL: ", step)
	quit(1)
