class_name DunesPilotClient
extends Node
## Закрытый режим обычного клиента. Карта и экран боя используются из основной игры.

signal entered_world
signal connection_stopped(message: String)
signal exit_requested

const DUNES := DunesMap.DUNES
const ENCOUNTER := "enc_dunes_drifters"
const WORLD := preload("res://scenes/world/world.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const INFO := preload("res://scenes/ui/info_panel.tscn")
const BATTLE := preload("res://scenes/battle/battle_view.tscn")
const SPAWN := preload("res://scenes/world/enemy_spawn.tscn")

var allow_return := false

var _data: GameData
var _channel: WorldPresenceChannel
var _transport: ENetMultiplayerPeer
var _network: SceneMultiplayer
var map: WorldView
var hud: Hud
var battle: BattleView
var _hud_layer: CanvasLayer
var _overlay: CanvasLayer
var _info: InfoPanel
var _packs: Dictionary = {}
var _zone := ""
var _state: Dictionary = {}
var _position_received := false
var _last_sent := Vector2.INF
var _next_move_at := 0
var _remote_heroes: Dictionary = {}
var _remote_points: Dictionary = {}
var _ignored_pack: EnemySpawn
var _pending := false
var _ready_to_play := false
var _engaging: EnemySpawn
var _status_elapsed := 0.0
var _stopped := false
var _travel_button: Button
var _auction_open := false
var _auction_state: Dictionary = {}
var _auction_page := 0
var _auction_selling := false


func start(port: int, key: PackedByteArray) -> void:
	_setup_view()
	if key.size() != NetConfig.SECRET_BYTES:
		_stop("Для закрытого пилота нужен локальный ключ.")
		return
	_channel = WorldPresenceChannel.new()
	_channel.name = "WorldPresence"
	_network = SceneMultiplayer.new()
	get_tree().set_multiplayer(_network, get_path())
	add_child(_channel)
	_channel.snapshot.connect(_on_presence)
	_channel.auction_updated.connect(_on_auction)
	_channel.positions_received.connect(_on_positions)
	_channel.dunes_snapshot.connect(_on_dunes)
	_channel.battle_updated.connect(_on_battle)
	_network.auth_callback = func(peer: int, packet: PackedByteArray):
		if not NetConfig.decode_session(packet, NetConfig.SESSION_GRANTED).is_empty():
			_network.complete_auth(peer)
	_network.peer_authenticating.connect(func(peer: int):
		_network.send_auth(peer, NetConfig.encode_session(NetConfig.LOGIN_KEY, key)))
	_network.connected_to_server.connect(func(): _request("enter"))
	_network.connection_failed.connect(func(): _stop("Локальный сервер недоступен."))
	_network.peer_authentication_failed.connect(func(_id): _stop("Сервер отклонил вход в пилот."))
	_network.server_disconnected.connect(func(): _stop("Связь с сервером прервана."))
	_transport = ENetMultiplayerPeer.new()
	if _transport.create_client(NetConfig.DEFAULT_HOST, port) == OK:
		_network.multiplayer_peer = _transport
		var deadline := Timer.new()
		deadline.wait_time = 8.0
		deadline.one_shot = true
		deadline.autostart = true
		deadline.timeout.connect(func():
			if not _position_received:
				_stop("Сервер не открыл мир. Проверьте, что запущен локальный пилот.")
			deadline.queue_free())
		add_child(deadline)
	else:
		_stop("Локальный сервер недоступен.")


func _exit_tree() -> void:
	if _network != null:
		_network.multiplayer_peer = null
		get_tree().set_multiplayer(null, get_path())
	if _transport != null:
		_transport.close()


func _setup_view() -> void:
	_data = GameData.load_dir()
	map = WORLD.instantiate()
	map.configure(_data)
	map.show_map_enemies = false
	map.frozen = true
	map.zone_access = func(zone): return zone in [SeaFerry.OASIS, DUNES, RomeAuction.ZONE]
	add_child(map)
	map.set_hero_animation("warden")
	map.setup_content(_data)
	map.enemy_contact.connect(_on_pack_contact)
	map.movement_intent = _move_toward
	map.can_contact_enemy = func(spawn): return spawn != _ignored_pack
	map.npc_contact.connect(_on_npc)
	map.interaction_changed.connect(func(npc):
		hud.interact_button.visible = npc != null and npc.npc_id in ["npc_said", RomeAuction.NPC]
		if hud.interact_button.visible:
			hud.interact_button.text = "Поговорить · %s" % ("Квинт" if npc.npc_id == RomeAuction.NPC else "Саид"))
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	hud = HUD.instantiate()
	_hud_layer.add_child(hud)
	hud.menu_button.visible = allow_return
	hud.menu_button.text = "Выйти"
	hud.menu_button.pressed.connect(func(): exit_requested.emit())
	hud.joystick.visible = OS.has_feature("mobile")
	if hud.joystick.visible:
		hud.hint_label.offset_left = 290.0
	hud.xp_bar.hide()
	hud.interact_button.hide()
	hud.info_label.text = "Поющие дюны · подключение"
	hud.hint_label.text = "Закрытый сетевой пилот"
	_travel_button = Button.new()
	hud.add_child(_travel_button)
	_travel_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_travel_button.offset_left = -264
	_travel_button.offset_right = -14
	_travel_button.offset_top = 161
	_travel_button.offset_bottom = 225
	_travel_button.hide()
	_travel_button.pressed.connect(func():
		if _ready_to_play and not map.frozen:
			_stop_walking()
			_request("auction_travel"))
	hud.minimap.provider = map
	hud.interact_button.pressed.connect(map.interact)
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	for i in DunesMap.PACK_TILES.size():
		var pack := "personal" if i == DunesMap.PACK_TILES.size() - 1 else "dunes_pack_%d" % (i + 1)
		var spawn: EnemySpawn = SPAWN.instantiate()
		spawn.encounter_id = ENCOUNTER
		spawn.position = _point(DunesMap.PACK_TILES[i])
		spawn.set_meta("pilot_pack", pack)
		map.add_child(spawn)
		spawn.setup(_data.encounters[ENCOUNTER], _data.monsters)
		if pack == "personal":
			(spawn.get_node("NameLabel") as Label).text = "Личный дозор"
		spawn.set_alive(false)
		map.spawns.append(spawn)
		_packs[pack] = spawn


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	map.joystick = hud.joystick.value if not map.frozen else Vector2.ZERO
	if is_instance_valid(_ignored_pack) and map.hero.position.distance_to(_ignored_pack.position) >= _ignored_pack.contact_radius:
		_ignored_pack = null
	for id in _remote_heroes:
		var hero: Node2D = _remote_heroes[id]
		var target: Vector2 = _remote_points[id]
		var displacement := target - hero.position
		var animation := hero.get_node_or_null("Animation") as HeroAnimation
		if animation != null:
			if displacement.length_squared() > 4.0:
				hero.set_meta("direction", HeroAnimation.facing(displacement))
				animation.play(StringName("walk_" + str(hero.get_meta("direction"))))
			else:
				animation.play(StringName("idle_" + str(hero.get_meta("direction", "south"))))
		hero.position = hero.position.lerp(target, minf(delta * 15.0, 1.0))
	if not _pending and _zone == DUNES:
		_status_elapsed += delta
		if _status_elapsed >= 2.0:
			_status_elapsed = 0.0
			_request("dunes_status")


func _point(tile: Vector2) -> Vector2:
	return (tile + Vector2(0.5, 0.5)) * map.grid.tile_px


func _request(action: String, target := "") -> void:
	_channel.request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action, target)


func _move_toward(destination: Vector2) -> void:
	if not _ready_to_play or destination.is_equal_approx(_last_sent):
		return
	var now := Time.get_ticks_msec()
	if now >= _next_move_at:
		_next_move_at = now + 65
		_last_sent = destination
		_channel.move_toward.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, destination)


func _stop_walking() -> void:
	map.has_target = false
	_last_sent = map.hero.position
	_channel.move_toward.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, map.hero.position)


func _on_presence(zone: String, count: int, error: String) -> void:
	if _stopped:
		return
	if not error.is_empty():
		if _zone.is_empty():
			_stop("Не удалось войти в мир.")
		return
	if _zone != zone:
		_state.clear()
	if _zone != zone and (zone == RomeAuction.ZONE or _zone == RomeAuction.ZONE):
		_last_sent = Vector2.INF
		map.has_target = false
	_zone = zone
	_travel_button.visible = zone in [SeaFerry.OASIS, RomeAuction.ZONE]
	_travel_button.text = "В Оазис" if zone == RomeAuction.ZONE else "В Рим"
	hud.info_label.text = "%s · Игроков в зоне %d" % [map.zone_name_of(zone), count]
	_update_packs()


func _on_positions(position: Vector2, neighbors: Dictionary) -> void:
	if _stopped or _zone.is_empty():
		return
	if not _position_received:
		map.arrive_at(position, _zone, false)
		_position_received = true
		_ready_to_play = true
		_unfreeze()
		entered_world.emit()
	else:
		if map.zone_id != _zone and RomeAuction.ZONE in [map.zone_id, _zone]:
			map.arrive_at(position, _zone, false)
		else:
			map.apply_network_position(position)
			map.zone_id = _zone
	for id in _remote_heroes.keys():
		if not neighbors.has(id):
			_remote_heroes[id].queue_free()
			_remote_heroes.erase(id)
	for id in neighbors:
		if not _remote_heroes.has(id):
			var hero := Node2D.new()
			hero.position = neighbors[id]
			var animation := HeroAnimation.create_for("warden")
			if animation != null:
				animation.name = "Animation"
				hero.add_child(animation)
				animation.play(&"idle_south")
			else:
				var sprite := Sprite2D.new()
				sprite.texture = map.hero_sprite.texture
				sprite.scale = map.hero_sprite.scale
				sprite.position = map.hero_sprite.position
				hero.add_child(sprite)
			var label := Label.new()
			label.text = "Другой игрок"
			label.position = Vector2(-53, -105)
			label.add_theme_color_override("font_color", Color("84d8ff"))
			label.add_theme_color_override("font_outline_color", Color("0d2130"))
			label.add_theme_constant_override("outline_size", 4)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero.add_child(label)
			map.add_child(hero)
			_remote_heroes[id] = hero
	_remote_points = neighbors


func _on_dunes(state: Dictionary, result: String) -> void:
	_state = state
	if result == "wrong_zone" and _pending and _engaging != null:
		_release_pack()
		_unfreeze()
	_update_packs()
	if result in ["accept", "turn_in"]:
		if _info != null:
			_show_said()
	elif not result.is_empty() and result != "wrong_zone":
		hud.toast("Поручение пока недоступно.", Color("ff9b7d"))
	var quest := str(state.get("quest", "none"))
	hud.hint_label.text = ("Клейма для Саида · %d/2" % int(state.get("trophies", 0))) if quest in ["active", "ready"] else "Закрытый сетевой пилот"


func _update_packs() -> void:
	var open: Array = _state.get("available", [])
	for pack in _packs:
		(_packs[pack] as EnemySpawn).set_alive(_zone == DUNES and
			(pack in open or (pack == "personal" and _state.get("personal", false))))
	map.set_quest_marker("npc_said", ["side"] if _zone == DUNES and _state.get("quest", "none") in ["none", "ready"] else [])


func _on_pack_contact(spawn: EnemySpawn) -> void:
	if _pending or _info != null or battle != null:
		return
	_stop_walking()
	_engaging = spawn
	_pending = true
	map.frozen = true
	_request("dunes_begin", str(spawn.get_meta("pilot_pack")))


func _on_npc(id: String) -> void:
	if id == "npc_said" and not _pending:
		_stop_walking()
		_show_said()
	elif id == RomeAuction.NPC and not _pending:
		_stop_walking()
		map.frozen = true
		_auction_open = true
		_auction_page = 0
		_auction_selling = false
		_request("auction_status")


func _on_auction(state: Dictionary) -> void:
	if not _auction_open:
		return
	var error := str(state.get("error", ""))
	if state.has("lots"):
		_auction_state = state
	if not error.is_empty():
		var messages := {"no_coins": "Не хватает монет.", "missing_lot": "Лот уже недоступен.",
			"wrong_zone": "Подойдите к Квинту.", "inventory_full": "В сумке нет места.",
			"lot_limit": "Достигнут лимит лотов.", "invalid_price": "Укажите цену от 1 до 100 000 000 монет."}
		hud.toast(str(messages.get(error, "Действие недоступно.")))
	_show_auction()


func _show_auction() -> void:
	if _info == null:
		_info = INFO.instantiate()
		_overlay.add_child(_info)
	_info.clear()
	_info.set_title("Квинт · Аукцион снаряжения")
	_info.add_text("Монеты: %d" % int(_auction_state.get("coins", 0)))
	var rows: Array = _auction_state.get("items" if _auction_selling else "lots", [])
	var last_page := maxi(0, (rows.size() - 1) / 2)
	_auction_page = clampi(_auction_page, 0, last_page)
	if rows.is_empty():
		_info.add_text("В сумке нет вещей для продажи." if _auction_selling else "Лотов пока нет.")
	for row in rows.slice(_auction_page * 2, _auction_page * 2 + 2):
		if _auction_selling:
			_info.add_choice(_auction_item_label(row), _show_listing.bind(row))
		else:
			_info.add_choice(_auction_item_label(row.item) + " · %d монет" % int(row.price), _show_lot.bind(row))
	if _auction_page > 0:
		_info.add_choice("Предыдущая страница", _auction_turn_page.bind(-1))
	if _auction_page < last_page:
		_info.add_choice("Следующая страница", _auction_turn_page.bind(1))
	_info.add_choice("К лотам" if _auction_selling else "Выставить из сумки", func():
		_auction_selling = not _auction_selling
		_auction_page = 0
		_request("auction_status"))
	_info.add_choice("Обновить", func(): _request("auction_status"))
	_info.add_choice("Закрыть", _close_auction)


func _auction_turn_page(direction: int) -> void:
	_auction_page += direction
	_show_auction()


func _auction_item_label(row: Dictionary) -> String:
	var definition: ItemDef = _data.items[str(row.def_id)]
	return "%s +%d" % [definition.name, int(row.get("plus", 0))]


func _show_lot(row: Dictionary) -> void:
	_info.clear()
	_info.set_title(_auction_item_label(row.item))
	var item := Item.new(int(row.item.uid), str(row.item.def_id))
	item.plus = int(row.item.get("plus", 0))
	item.wear = int(row.item.get("wear", 0))
	var stone: ItemDef = _data.items.get(str(row.item.get("star_stone", "")))
	_info.add_text("Цена: %d монет · %s" % [int(row.price), item.condition_text(_data)])
	_info.add_text("Камень: %s" % (stone.name if stone != null else "пусто"))
	_info.add_choice("Снять лот" if row.own else "Купить", func():
		_request("auction_cancel" if row.own else "auction_buy", str(row.id)))
	_info.add_choice("Назад", _show_auction)


func _show_listing(row: Dictionary) -> void:
	_info.clear()
	_info.set_title(_auction_item_label(row))
	var price := LineEdit.new()
	price.placeholder_text = "Цена в монетах"
	price.max_length = 9
	price.custom_minimum_size.y = 64
	_info.choice_list.add_child(price)
	_info.add_choice("Выставить лот", func(): _request("auction_list", "%d:%s" % [int(row.uid), price.text]))
	_info.add_choice("Назад", _show_auction)


func _close_auction() -> void:
	_auction_open = false
	_auction_state.clear()
	_info.queue_free()
	_info = null
	_unfreeze()


func _show_said() -> void:
	map.frozen = true
	if _info == null:
		_info = INFO.instantiate()
		_overlay.add_child(_info)
	_info.clear()
	_info.set_title("Саид · Клейма с Поющих дюн")
	match str(_state.get("quest", "none")):
		"none":
			_info.add_text("Принеси два медных клейма от местных дозорных.")
			_info.add_choice("Принять поручение", func(): _request("dunes_accept"))
		"ready":
			_info.add_text("Два клейма собраны.")
			_info.add_choice("Передать клейма", func(): _request("dunes_turn_in"))
		"done":
			_info.add_text("Клейма приняты. Спасибо за помощь.")
		_:
			_info.add_text("Собрано %d из 2 медных клейм." % int(_state.get("trophies", 0)))
	_info.add_choice("До встречи", func():
		_info.queue_free()
		_info = null
		_unfreeze())


func _on_battle(update: Dictionary) -> void:
	if update.has("setup"):
		_open_battle(update["setup"])
	elif battle != null:
		battle.apply_server_commands(update.get("commands", []), str(update.get("outcome", "")))
	elif _engaging != null:
		_release_pack()
		_unfreeze()
		hud.toast("Дозор уже недоступен.", Color("ff9b7d"))


func _open_battle(setup: Dictionary) -> void:
	var hero_class := str(setup["class"])
	var sim := DunesBattle.build(_data, hero_class, int(setup["level"]))
	var names := {}
	var sprites := {}
	var encounter: Dictionary = _data.encounters[ENCOUNTER]
	for unit in sim.units:
		if unit.side == BattleRules.SIDE_A:
			var id: String = _data.hero_def_id(hero_class) if unit.is_hero else DunesBattle.SUPPORT[unit.id - 2]
			var def: MercenaryDef = _data.mercs[id]
			names[unit.id] = def.name
			sprites[unit.id] = Art.merc_sprite(id, def.weapon)
		else:
			var index := unit.id - int(_data.rules["world"]["enemy_id_base"])
			var monster: String = encounter["enemies"][index]["monster"]
			names[unit.id] = _data.monsters[monster]["name"]
			sprites[unit.id] = Art.monster_sprite(monster)
	battle = BATTLE.instantiate()
	battle.server_controlled = true
	_overlay.add_child(battle)
	battle.online_command.connect(func(action):
		_channel.battle_command.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action))
	battle.replay_failed.connect(func():
		_channel.battle_command.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, {"type": "flee"})
		_stop("Не удалось синхронизировать бой."))
	battle.finished.connect(_close_battle)
	map.hide()
	_hud_layer.hide()
	battle.background.biome = BattleBackground.biome_for(DUNES, _data.chunk_manifest)
	battle.setup(_data, sim, names, sprites, str(encounter["name"]), hero_class)


func _close_battle(result: String) -> void:
	battle.queue_free()
	battle = null
	_release_pack()
	map.show()
	_hud_layer.show()
	_unfreeze()
	if result == "expired":
		hud.toast("Бой завершён из-за бездействия.", Color("ff9b7d"))
	elif result == "reward_failed":
		hud.toast("Сервер не сохранил результат боя.", Color("ff9b7d"))


func _release_pack() -> void:
	_ignored_pack = _engaging
	_engaging = null


func _unfreeze() -> void:
	_pending = false
	map.frozen = false
	map.has_target = false


func _stop(message: String) -> void:
	if _stopped:
		return
	_stopped = true
	_ready_to_play = false
	map.frozen = true
	if _info != null:
		_info.queue_free()
		_info = null
	if battle != null:
		battle.queue_free()
		battle = null
	map.show()
	_hud_layer.show()
	hud.info_label.text = message
	connection_stopped.emit(message)
