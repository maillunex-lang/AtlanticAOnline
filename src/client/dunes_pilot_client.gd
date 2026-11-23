class_name DunesPilotClient
extends Node
## Закрытый режим обычного клиента. Карта и экран боя используются из основной игры.

const DUNES := "z_dunes"
const ENCOUNTER := "enc_dunes_drifters"
const PACK_TILES := [Vector2i(85, 110), Vector2i(85, 104), Vector2i(85, 116),
	Vector2i(79, 104), Vector2i(79, 116), Vector2i(78, 110)]
const WORLD := preload("res://scenes/world/world.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const INFO := preload("res://scenes/ui/info_panel.tscn")
const BATTLE := preload("res://scenes/battle/battle_view.tscn")
const SPAWN := preload("res://scenes/world/enemy_spawn.tscn")

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
var _last_position := Vector2.ZERO
var _pending := false
var _ready_to_play := false
var _engaging: EnemySpawn
var _status_elapsed := 0.0


func start(port: int, key: PackedByteArray) -> void:
	_setup_view()
	if key.size() != NetConfig.SECRET_BYTES:
		_stop("Для закрытого пилота нужен локальный ключ.")
		return
	_channel = WorldPresenceChannel.new()
	_channel.name = "WorldPresence"
	get_tree().root.add_child(_channel)
	_channel.snapshot.connect(_on_presence)
	_channel.dunes_snapshot.connect(_on_dunes)
	_channel.battle_updated.connect(_on_battle)
	_network = multiplayer as SceneMultiplayer
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
	else:
		_stop("Локальный сервер недоступен.")


func _setup_view() -> void:
	_data = GameData.load_dir()
	map = WORLD.instantiate()
	map.configure(_data)
	map.show_map_enemies = false
	map.frozen = true
	map.zone_access = func(zone): return zone in [SeaFerry.OASIS, DUNES]
	add_child(map)
	map.set_hero_animation("warden")
	map.setup_content(_data)
	map.enemy_contact.connect(_on_pack_contact)
	map.zone_changed.connect(_request_travel)
	map.npc_contact.connect(_on_npc)
	map.interaction_changed.connect(func(npc):
		hud.interact_button.visible = npc != null and npc.npc_id == "npc_said"
		hud.interact_button.text = "Поговорить · Саид")
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	hud = HUD.instantiate()
	_hud_layer.add_child(hud)
	hud.menu_button.hide()
	hud.joystick.visible = OS.has_feature("mobile")
	if hud.joystick.visible:
		hud.hint_label.offset_left = 290.0
	hud.xp_bar.hide()
	hud.interact_button.hide()
	hud.info_label.text = "Поющие дюны · подключение"
	hud.hint_label.text = "Закрытый сетевой пилот"
	hud.minimap.provider = map
	hud.interact_button.pressed.connect(map.interact)
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	for i in PACK_TILES.size():
		var pack := "personal" if i == PACK_TILES.size() - 1 else "dunes_pack_%d" % (i + 1)
		var spawn: EnemySpawn = SPAWN.instantiate()
		spawn.encounter_id = ENCOUNTER
		spawn.position = _point(PACK_TILES[i])
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
	if not map.frozen and map.zone_id == _zone:
		_last_position = map.hero.position
	if not _pending and _zone == DUNES:
		_status_elapsed += delta
		if _status_elapsed >= 2.0:
			_status_elapsed = 0.0
			_request("dunes_status")


func _point(tile: Vector2) -> Vector2:
	return (tile + Vector2(0.5, 0.5)) * map.grid.tile_px


func _request(action: String, target := "") -> void:
	_channel.request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, action, target)


func _request_travel(zone: String, _name: String) -> void:
	if zone == _zone or not _ready_to_play:
		return
	_pending = true
	map.frozen = true
	_request("travel", zone)


func _on_presence(zone: String, count: int, error: String) -> void:
	if not error.is_empty():
		if _zone.is_empty():
			_stop("Не удалось войти в мир.")
			return
		if _pending and map.zone_id != _zone:
			map.arrive_at(_last_position, _zone, false)
			_unfreeze()
			hud.toast("Переход недоступен.", Color("ff9b7d"))
		return
	if _zone.is_empty():
		var tile := Vector2i(32, 111) if zone == DUNES else Vector2i(28, 111)
		map.arrive_at(_point(tile), zone, false)
		_last_position = map.hero.position
		_ready_to_play = true
		_unfreeze()
	elif _zone != zone:
		_unfreeze()
		_state.clear()
	_zone = zone
	hud.info_label.text = "%s · Игроков в зоне %d" % [map.zone_name_of(zone), count]
	_update_packs()


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
	_engaging = spawn
	_pending = true
	map.frozen = true
	_request("dunes_begin", str(spawn.get_meta("pilot_pack")))


func _on_npc(id: String) -> void:
	if id == "npc_said" and not _pending:
		_show_said()


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
	if is_instance_valid(_engaging):
		# Return to the approach so fleeing does not immediately start the same fight.
		var step := (_last_position - _engaging.position).normalized()
		if step == Vector2.ZERO:
			step = Vector2.LEFT
		for direction in [step, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var away: Vector2 = _engaging.position + direction * (_engaging.contact_radius + 18.0)
			if not map._blocked(away):
				map.arrive_at(away, _zone, false)
				break
	_engaging = null


func _unfreeze() -> void:
	_pending = false
	map.frozen = false
	map.has_target = false


func _stop(message: String) -> void:
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
