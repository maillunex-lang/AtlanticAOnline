extends SceneTree
## Проверяет режим обычного клиента через реальные элементы карты и экрана боя.

const PRESENCE := preload("res://tools/smoke_zone_presence.gd")
const WALK := preload("res://tools/dunes_smoke_walk.gd")

var _walker := WALK.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var client := DunesPilotClient.new()
	root.add_child(client)
	client.start(port, OS.get_environment("ATLANTIC_SMOKE_SECRET").hex_decode())
	if not await _wait_for(func(): return client._zone == SeaFerry.OASIS and client._ready_to_play, "Вход в Оазис"):
		return
	var other := PRESENCE.PilotClient.new()
	if other.setup(self, port, OS.get_environment("ATLANTIC_SMOKE_SECRET_SECOND").hex_decode()) != OK:
		_fail("Подключение второго героя")
		return
	if not await _wait_for(func(): return other.connected, "Сессия второго героя"):
		return
	other.send("enter")
	if not await _wait_for(func(): return client._remote_heroes.has(other.api.get_unique_id()), "Второй герой виден на карте"):
		return
	var sprite: Node2D = client._remote_heroes[other.api.get_unique_id()]
	var start := sprite.position
	other.move(start + Vector2(64, 0))
	if not await _wait_for(func(): return sprite.position.distance_to(start) >= 32.0, "Спрайт второго героя движется"):
		return
	if not await _walk(client, Vector2i(32, 111)):
		return
	if not await _wait_for(func(): return client._zone == DunesPilotClient.DUNES and client._state.get("capacity") == 3 and client._remote_heroes.is_empty(), "Сервер подтвердил переход"):
		return
	if not await _walk(client, DunesMap.SAID_TILE):
		return
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
	if not await _walk(client, DunesMap.PACK_TILES[0], 69.0):
		return
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
	other.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	await create_timer(0.2).timeout
	client._transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	await create_timer(0.3).timeout
	print("WP-70 client PASS: peer rendering, zone boundary, Said dialogue, guard, end turn and flee")
	quit()


func _walk(client: DunesPilotClient, tile: Vector2i, reach := 0.1) -> bool:
	var read := func(): return client.map.hero.position
	var move := func(destination: Vector2):
		client.map.target = destination
		client.map.has_target = true
	if await _walker.walk(self, read, move, tile, reach, func(): return client.battle != null):
		return true
	_fail("Герой не дошёл до %s, позиция %s" % [tile, read.call()])
	return false


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
