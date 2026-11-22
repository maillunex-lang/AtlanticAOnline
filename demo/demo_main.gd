class_name DemoMain
extends Node
## Демо-версия: бегаем по карте, берём задание у капитана, нападаем на врагов, играем пошаговый бой,
## получаем опыт и добычу. Использует настоящую игровую логику (BattleSim, Squad, QuestLog, LootTable).
## Интерфейс собран из сцен scenes/ui/*.tscn и scenes/battle/*.tscn (их можно править в редакторе Godot).

const RESPAWN_SECONDS := 25.0
const SOUTH_ROUTE_CHECKPOINT_ZONES := ["z_east_market", "z_lower_dock", "z_river_marsh", "z_sluice_town", "z_copper_cove", "z_fog_trail"]

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MENU_SCENE := preload("res://scenes/ui/menu.tscn")
const INFO_SCENE := preload("res://scenes/ui/info_panel.tscn")
const TOWN_SCENE := preload("res://scenes/ui/town_screen.tscn")
const TACTICAL_SCENE := preload("res://scenes/battle/tactical_view.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle_view.tscn")

var gd: GameData
var squad: Squad
var inv: Inventory
var jackpot_bank := {}
var wallet := {"coins": 150}
var log: QuestLog
var world: PlayerWorld
var runner: DialogueRunner
var map: WorldView
var tactical: TacticalView
var battle: BattleView
var now := 0.0
var rng := RandomNumberGenerator.new()
var settings := DemoSettings.new()
var pve: PvePolicy
## Расстановка: uid бойца (у героя 0) -> слот 0..8 на своей стороне.
var formation: Dictionary = {}
## Класс героя этой игры (выбирается на экране создания героя и запоминается в настройках).
var hero_class := "warden"

var hud: Hud
var _hud_layer: CanvasLayer
var _layer: CanvasLayer
var town_services: TownServices
var town_guilds: GuildService
var town_screen: TownScreen
var _menu: MenuScreen
var _info: InfoPanel
var _busy_ui := false
var _last_tab := "squad"
var _shots_dir := ""
var _dungeon_run: DungeonRun


func _ready() -> void:
	rng.randomize()
	settings.load_file()
	gd = GameData.load_dir()
	town_services = TownServices.new(gd)
	town_guilds = GuildService.new(gd)
	pve = PvePolicy.new(gd.rules["pve"])
	var smoke_run := false
	for a in OS.get_cmdline_user_args():
		smoke_run = smoke_run or a.begins_with("--smoke")
	if settings.hero_class != "" and gd.class_status(settings.hero_class) == "":
		hero_class = settings.hero_class
	elif not smoke_run:
		hero_class = await _choose_class()
		settings.hero_class = hero_class
		settings.save_file()
	_setup_party(smoke_run)
	log = QuestLog.new(gd)
	world = PlayerWorld.new(gd, 0.0)
	runner = DialogueRunner.new(gd, log, world)

	map = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	map.configure(gd)
	add_child(map)
	map.hero_sprite.texture = Art.character(Art.merc_sprite(squad.hero.def_id, str(gd.classes[hero_class]["weapon"])))
	map.set_hero_animation(hero_class)
	map.setup_content(gd)
	map.zone_access = func(zone: String):
		if zone == "z_canyon":
			return log.can_enter_echo_canyon(_hero_level())
		if zone == "z_tomb":
			return _hero_level() >= 25 and log.completed.has("q_se_echo_seal")
		if zone == "z_east_market":
			return log.can_enter_east_market(_hero_level())
		if zone == "z_lower_dock":
			return log.can_enter_lower_dock(_hero_level())
		if zone == "z_river_marsh":
			return log.can_enter_river_marsh(_hero_level())
		if zone == "z_sluice_town":
			return log.can_enter_sluice_town(_hero_level())
		return true
	map.zone_changed.connect(_on_zone_changed)
	map.enemy_contact.connect(_on_enemy_contact)
	map.npc_contact.connect(_on_npc_contact)

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	hud = HUD_SCENE.instantiate()
	_hud_layer.add_child(hud)
	hud.minimap.provider = map
	map.interaction_changed.connect(_show_interaction)
	hud.interact_button.pressed.connect(map.interact)
	hud.quest_pressed.connect(run_to_quest)
	hud.menu_button.pressed.connect(func(): open_menu(_last_tab))
	if not smoke_run:
		TombCheckpoint.restore(self, settings.tomb_checkpoint)
	refresh_hud()
	apply_settings()
	for a in OS.get_cmdline_user_args():
		if a == "--smoke-town" or a.begins_with("--smoke-town="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/town_shots"
			_smoke_town.call_deferred()
		elif a == "--smoke-map" or a.begins_with("--smoke-map="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/world_map_shots"
			_smoke_world_map.call_deferred()
		elif a == "--smoke-tactics" or a.begins_with("--smoke-tactics="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/tactical_shots"
			_smoke_tactics.call_deferred()
		elif a == "--smoke" or a.begins_with("--smoke="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/demo_shots"
			_smoke.call_deferred()


func _process(delta: float) -> void:
	if hud == null:
		return
	now += delta
	if world.traveling:
		_finish_ferry_if_due()
		if world.traveling:
			map.frozen = true
			hud.info_label.text = "Переправа · до причала %d с" % ceili(world.arrive_at - now)
			return
	if battle == null and tactical == null:
		var crafting := Crafter.tick(delta, inv, wallet)
		if not crafting.is_empty() and crafting.ok:
			refresh_hud()
		if not crafting.is_empty() and _menu != null and _menu.tab == "forge":
			if crafting.ok:
				_menu.message = "Автокрафт: создано %s · +%d XP" % [gd.items[crafting.item.def_id].name, crafting.xp]
			elif inv.crafting.auto_recipe == "":
				_menu.message = "Автокрафт остановлен: " + str(TabForge.CRAFT_ERRORS.get(crafting.error, crafting.error))
			_menu.rebuild()
	map.respawn_ready(now)
	map.joystick = hud.joystick.value if (hud.joystick.visible and not _busy_ui) else Vector2.ZERO
	if now > 14.0:
		hud.hint_label.modulate.a = maxf(0.0, hud.hint_label.modulate.a - delta * 0.5)


# ---------- создание героя ----------

## Экран выбора класса героя поверх пустого фона; возвращает id выбранного доступного класса.
func _choose_class() -> String:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var screen := (load("res://scenes/ui/hero_create.tscn") as PackedScene).instantiate() as HeroCreate
	layer.add_child(screen)
	screen.setup(gd, hero_class)
	var picked: String = await screen.chosen
	layer.queue_free()
	return picked


# ---------- подготовка отряда ----------

func _setup_party(smoke_run := false) -> void:
	squad = Squad.new(gd)
	inv = Inventory.new(gd)
	var hero := squad.create_hero(hero_class)
	var hero_weapon := str(gd.classes[hero_class]["weapon"])
	hero.equip(inv.add_equipment("w_%s_1" % hero_weapon), inv)
	hero.equip(inv.add_equipment("a_cloth"), inv)
	formation = {0: 0}
	if smoke_run:
		hero.set_level(5, gd)
		hero.grant_hero_level_points()
		hero.learn_skill(str(gd.classes[hero_class]["skills"]["base"][1]), gd)
		_add_smoke_roster()


func _add_smoke_roster() -> void:
	var hero_weapon := str(gd.classes[hero_class]["weapon"])
	var w := {"coins": 5000}
	var archer: Mercenary = squad.recruit("archer", "coins", w).merc
	archer.set_level(7, gd)
	archer.grant_hero_level_points()
	archer.learn_skill("bow_volley", gd)
	var adept: Mercenary = squad.recruit("adept", "coins", w).merc
	adept.set_level(4, gd)
	adept.grant_hero_level_points()
	adept.learn_skill("staff_heal", gd)
	adept.grant_hero_level_points()
	adept.learn_skill("staff_revive", gd)
	squad.recruit("spearman", "coins", w)
	var axeman: Mercenary = squad.recruit("axeman", "coins", w).merc
	axeman.set_level((gd.skills["axe_sunder"] as SkillDef).unlock_level, gd)
	axeman.grant_hero_level_points()
	axeman.learn_skill("axe_sunder", gd)
	for id in ["gunner", "cannoneer"]:
		squad.recruit(id, "coins", w)
	archer.equip(inv.add_equipment("w_bow_1"), inv)
	adept.equip(inv.add_equipment("w_staff_1"), inv)
	for id in ["h_cap", "x_ring", "x_amulet", "a_chain", "w_%s_2" % hero_weapon]:
		inv.add_equipment(id)
	inv.add_material("enhance_stone", 14)
	inv.add_material("iron_ore", 24)
	inv.add_material("leather", 12)
	inv.add_material("cloth_scrap", 12)
	formation = {0: 0}
	var slots := [4, 5, 7, 8, 3, 6, 1]
	for i in squad.mercs.size():
		formation[squad.mercs[i].uid] = slots[i]
	squad.claim_starter_guards()


func members() -> Array[Mercenary]:
	var out: Array[Mercenary] = [squad.hero]
	out.append_array(squad.all_mercenaries())
	return out


func member_name(m: Mercenary) -> String:
	return (gd.mercs[m.def_id] as MercenaryDef).name


func member_at_slot(slot: int) -> Mercenary:
	for m in members():
		if squad.room_of(m.uid) < 0 and int(formation.get(m.uid, -1)) == slot:
			return m
	return null


## Поставить бойца в клетку. Если она занята, бойцы меняются местами.
func place_member(m: Mercenary, slot: int) -> void:
	if squad.room_of(m.uid) >= 0 or slot < 0 or slot >= BattleRules.SLOTS_PER_SIDE:
		return
	var old := int(formation.get(m.uid, -1))
	if old == slot:
		return
	var occ := member_at_slot(slot)
	if occ != null and occ != m:
		formation[occ.uid] = old
	formation[m.uid] = slot
	log.on_event({"type": "activity", "target": "formation"})
	refresh_hud()


func equip_member(member: Mercenary, item: Item) -> String:
	var error := member.equip(item, inv)
	if error.is_empty():
		log.on_event({"type": "activity", "target": "equip"})
	return error


func send_to_room(m: Mercenary, room: int) -> String:
	var incoming: Mercenary = squad.rooms.get(room)
	var slot := int(formation.get(m.uid, -1))
	var error := squad.move_to_room(m.uid, room)
	if error == "":
		formation.erase(m.uid)
		if incoming != null:
			formation[incoming.uid] = slot
	return error


func return_from_room(room: int) -> String:
	var incoming: Mercenary = squad.rooms.get(room)
	var error := squad.restore_from_room(room)
	if error != "":
		return error
	for slot in BattleRules.SLOTS_PER_SIDE:
		if member_at_slot(slot) == null:
			formation[incoming.uid] = slot
			break
	return ""


func _player_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var ap_bonus := squad.formation_ap_bonus()
	for merc in members():
		if not merc.enabled:
			continue
		var room := squad.room_of(merc.uid)
		var unit := BattleUnit.from_mercenary(merc, gd, merc.uid + 1, BattleRules.SIDE_A, int(formation.get(merc.uid, 0)), squad.formation_bonus())
		unit.formation_ap_bonus = ap_bonus
		unit.reserve_room = room
		unit.participated = room < 0
		out.append(unit)
	return out


# ---------- интерфейс карты ----------

func _hero_level() -> int:
	return squad.hero.level


func refresh_hud() -> void:
	map.set_story_progress(log.completed.has("m04_mine_survey"), log.completed.has("m15_lit_beacons"))
	var h := squad.hero
	var need := h.xp_to_next(gd)
	hud.info_label.text = "Герой   Ур. %d     Монеты: %d     Зона: %s" % [h.level, int(wallet["coins"]), map.zone_name_of(map.zone_id)]
	hud.xp_bar.max_value = maxf(1.0, float(need))
	hud.xp_bar.value = float(h.xp)
	var quests: Array[Dictionary] = []
	for qid in log.hud_quests():
		var q: Dictionary = gd.quests[qid]
		var entry := {"id": qid, "title": str(q["name"]), "details": [], "done": 0}
		if log.state(qid, inv, h.level, now) == "ready":
			entry["title"] += " · Сдать: " + str(gd.npcs[q["turn_in"]]["name"])
		else:
			var objectives := log.objectives_for(qid)
			for i in objectives.size():
				var count := log.objective_count(qid, i, inv, h.level)
				var required := int(objectives[i]["count"])
				entry["details"].append("%s  %d/%d" % [objectives[i]["text"], count, required])
				if count >= required:
					entry["done"] += 1
		quests.append(entry)
	hud.set_quest_rows(quests)
	var has_ready := false
	var story_contacts := {
		"npc_marek": "m04_mine_survey" if log.can_perform_activity("m04_mine_survey", "cargo_manifest", inv, h.level) else "",
		"npc_liska": "m13_citadel_signal" if log.can_perform_activity("m13_citadel_signal", "signal_test", inv, h.level) else "",
		"npc_amina": "q_se_echo_pass" if log.can_perform_activity("q_se_echo_pass", "se_echo_survey", inv, h.level) else "",
		"npc_salih": "q_se_echo_seal" if log.can_perform_activity("q_se_echo_seal", "se_echo_seal", inv, h.level) else "",
		"npc_market_bridge": "q_se_market_bridge" if log.can_perform_activity("q_se_market_bridge", "se_market_bridge", inv, h.level) else "",
		"npc_market_tala": "q_se_market_weights" if log.can_perform_activity("q_se_market_weights", "se_market_weights", inv, h.level) else "",
		"npc_dock_ledger": "q_se_dock_ledger" if log.can_perform_activity("q_se_dock_ledger", "se_dock_ledger", inv, h.level) else "",
		"npc_dock_post": "q_se_dock_proof" if log.can_perform_activity("q_se_dock_proof", "se_dock_post", inv, h.level) else "",
		"npc_river_gauge": "q_se_river_survey" if log.can_perform_activity("q_se_river_survey", "se_river_gauge", inv, h.level) else "",
		"npc_sluice_winch": "q_se_sluice_charter" if log.can_perform_activity("q_se_sluice_charter", "se_sluice_winch", inv, h.level) else "",
		"npc_fog_stake": "q_sa_tide_survey" if log.can_perform_activity("q_sa_tide_survey", "sa_fog_stake", inv, h.level) else "",
	}
	for npc_id in gd.npcs:
		var ready := log.ready_at(npc_id, inv, h.level, now)
		var kinds := {}
		var quests_at_npc := ready + log.available_from(npc_id, h.level, now)
		var story: String = story_contacts.get(npc_id, "")
		if not story.is_empty():
			quests_at_npc.append(story)
		for qid in quests_at_npc:
			kinds[NpcMarker.quest_marker_kind(gd.quests[qid]["kind"])] = true
		var ordered := NpcMarker.QUEST_COLORS.keys().filter(func(kind): return kinds.has(kind))
		map.set_quest_marker(npc_id, ordered)
		has_ready = has_ready or not ready.is_empty()
	hud.menu_dot.visible = has_ready


func run_to_quest(qid: String) -> void:
	if battle != null or tactical != null or world.traveling or (_busy_ui and _menu == null):
		return
	var goals := log.route_goals(qid, inv, _hero_level())
	if qid == "q_se_tomb_archive" and _dungeon_run != null and _dungeon_run.zone_id == "z_tomb":
		if _dungeon_run.can_fight():
			goals.assign([{"kind": "enemy", "id": _dungeon_run.current_encounter()}])
		else:
			var marker := "npc_tomb_tablet" if _dungeon_run.findings.has("tomb_wheels") else "npc_tomb_wheels"
			goals.assign([{"kind": "npc", "id": marker}])
	if map.start_quest_route(goals):
		close_menu()
		return
	var current_region := world.region()
	for goal in goals:
		var zone: String = goal.id
		if goal.kind == "enemy":
			zone = gd.encounters.get(goal.id, {}).get("zone", "")
		elif goal.kind == "npc":
			zone = gd.npcs.get(goal.id, {}).get("zone", "")
		var other_region := gd.region_of_zone(zone)
		if other_region.is_empty() or other_region == current_region:
			continue
		var port_npc := SeaFerry.contact_toward(world, zone)
		if not port_npc.is_empty() and map.start_quest_route([{"kind": "npc", "id": port_npc}]):
			close_menu()
			hud.toast("Цель за морем. Сначала к переправе.")
			return
	close_menu()
	hud.toast("Нет доступного пешего маршрута к цели задания.", Color("ffb36b"))


func apply_settings() -> void:
	hud.joystick.visible = settings.joystick
	hud.hint_label.visible = settings.hints
	hud.hint_label.offset_left = 290.0 if settings.joystick else 20.0


func open_menu(tab: String) -> void:
	if _menu != null or battle != null or _busy_ui:
		return
	_last_tab = tab
	_busy_ui = true
	map.frozen = true
	_menu = MENU_SCENE.instantiate()
	_layer.add_child(_menu)
	_menu.setup(self, tab)
	_menu.closed.connect(close_menu)


func close_menu() -> void:
	if _menu == null:
		return
	_last_tab = _menu.tab
	_menu.queue_free()
	_menu = null
	_busy_ui = false
	map.frozen = false
	map.has_target = false
	refresh_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		if _menu != null and _menu.tab == "map":
			close_menu()
		elif _menu != null:
			_menu.set_tab("map")
		else:
			open_menu("map")
		get_viewport().set_input_as_handled()


func map_teleport(destination: String, bureau: bool) -> String:
	var quote := world.map_quote(destination, _hero_level(), now, settings.teleport_license, int(wallet["coins"]), bureau)
	if not quote.ok:
		return str(quote.error)
	var point := map.arrival_point(destination)
	if point == Vector2.INF:
		return "no_scene"
	var result := world.map_teleport(destination, _hero_level(), now, settings.teleport_license, wallet, bureau)
	if not result.ok:
		return str(result.error)
	map.arrive_at(point, destination)
	log.on_event({"type": "activity", "target": "map_route"})
	refresh_hud()
	close_menu()
	return ""


func _on_zone_changed(zone_id: String, zone_name: String) -> void:
	var save_route := world.zone_id in SOUTH_ROUTE_CHECKPOINT_ZONES or zone_id in SOUTH_ROUTE_CHECKPOINT_ZONES
	world.zone_id = zone_id
	world.discovered[zone_id] = true
	log.on_event({"type": "visit", "zone": zone_id})
	if save_route:
		_save_tomb_checkpoint()
	hud.toast("Вы вошли: %s" % zone_name, Color("ffe9a8"))
	refresh_hud()


# ---------- нижняя панель: диалог и итог боя ----------

func _open_info() -> InfoPanel:
	_busy_ui = true
	map.frozen = true
	if _info == null:
		_info = INFO_SCENE.instantiate()
		_layer.add_child(_info)
	_info.clear()
	return _info


func _close_info() -> void:
	if _info != null:
		_info.queue_free()
		_info = null
	_busy_ui = false
	map.frozen = false
	map.has_target = false


# ---------- диалог с капитаном ----------

func _ctx() -> Dictionary:
	return {"inv": inv, "squad": squad, "wallet": wallet, "level": _hero_level(), "now": now}


func _show_interaction(npc: NpcMarker) -> void:
	hud.interact_button.visible = npc != null
	if npc != null:
		var action := "Осмотреть" if npc.is_prop() else "Поговорить"
		hud.interact_button.text = "%s · %s" % [action, npc.display_name]


func _on_npc_contact(npc_id: String) -> void:
	if _busy_ui or battle != null:
		return
	var r := runner.start(npc_id, _ctx())
	if not r.ok:
		return
	_open_info()
	_show_dialogue(r["view"])


const DIALOGUE_QUEST_GROUPS := {
	"turn_in": "Готово к сдаче",
	"offer": "Задания",
	"recruit": "Испытания вербовки",
	"progress": "Обсудить активные задания",
}
const DIALOGUE_PAGE_SIZE := 4


func _show_dialogue(view: Dictionary, fallback_line := "") -> void:
	_info.clear()
	_info.set_title(str(gd.npcs[view["npc"]]["name"]))
	_info.add_text(str(view["text"]))
	var quest_line := str(view.get("quest_line", fallback_line))
	if not quest_line.is_empty():
		_info.add_text(quest_line)
	var grouped := {}
	var quest_count := 0
	for choice in view["choices"]:
		var group := str(choice["group"])
		if not group.is_empty():
			if not grouped.has(group):
				grouped[group] = []
			grouped[group].append(choice)
			quest_count += 1
	var use_groups := quest_count > 3 or grouped.has("recruit")
	if use_groups:
		for group in DIALOGUE_QUEST_GROUPS:
			if grouped.has(group):
				var label := str(DIALOGUE_QUEST_GROUPS[group])
				var choices: Array = grouped[group]
				_info.add_choice("%s (%d)" % [label, choices.size()],
					_show_dialogue_quest_group.bind(view, fallback_line, label, choices, 0), 52.0)
	for choice in view["choices"]:
		if not use_groups or choice["group"] == "":
			_add_dialogue_choice(choice)
	if view["npc"] == "npc_orvin" and not gd.tactical_missions.is_empty():
		_info.add_choice("Тактические бои", _show_tactical_missions, 64.0)


func _add_dialogue_choice(choice: Dictionary) -> void:
	var text := str(choice["text"])
	var kind := str(choice.get("quest_kind", ""))
	var button := _info.add_choice(("!  " if not kind.is_empty() else "") + text,
		_dialogue_choose.bind(int(choice["index"])), 52.0)
	if not kind.is_empty():
		var color: Color = NpcMarker.QUEST_COLORS[NpcMarker.quest_marker_kind(kind)]
		for style in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(style, color)


func _show_dialogue_quest_group(view: Dictionary, fallback_line: String, label: String, choices: Array, page: int) -> void:
	_info.clear()
	_info.set_title(label)
	var start := page * DIALOGUE_PAGE_SIZE
	for choice in choices.slice(start, start + DIALOGUE_PAGE_SIZE):
		_add_dialogue_choice(choice)
	if page > 0:
		_info.add_choice("Предыдущая страница", _show_dialogue_quest_group.bind(view, fallback_line, label, choices, page - 1), 48.0)
	if start + DIALOGUE_PAGE_SIZE < choices.size():
		_info.add_choice("Следующая страница", _show_dialogue_quest_group.bind(view, fallback_line, label, choices, page + 1), 48.0)
	_info.add_choice("Назад к разговору", _show_dialogue.bind(view, fallback_line), 48.0)


func _show_tactical_missions() -> void:
	var panel := _open_info()
	panel.set_title("Тактические бои")
	panel.add_text("Выберите бой для учебного отряда.")
	for id in gd.tactical_missions:
		panel.add_choice(str(gd.tactical_missions[id]["title"]), _start_tactical.bind(id), 64.0)
	panel.add_choice("Вернуться к капитану", func():
		_close_info()
		_on_npc_contact("npc_orvin"), 64.0)


func _start_tactical(id: String) -> void:
	if tactical != null or battle != null or not gd.tactical_missions.has(id):
		return
	_close_info()
	_busy_ui = true
	map.frozen = true
	map.visible = false
	_hud_layer.visible = false
	var mission: Dictionary = gd.tactical_missions[id]
	tactical = TACTICAL_SCENE.instantiate()
	_layer.add_child(tactical)
	tactical.setup(mission, gd)
	tactical.finished.connect(_finish_tactical.bind(mission))


func _finish_tactical(result: String, mission: Dictionary) -> void:
	tactical.queue_free()
	tactical = null
	map.visible = true
	_hud_layer.visible = true
	if result == "flee":
		_close_info()
		return
	var panel := _open_info()
	panel.set_title("Миссия выполнена" if result == "win" else "Миссия не выполнена")
	panel.add_text(str(mission["result"]) if result == "win" else "Поговорите с капитаном, чтобы попробовать снова.")
	panel.add_choice("Продолжить", _close_info, 66.0)


func _dialogue_choose(index: int) -> void:
	var r := runner.choose(index, _ctx())
	if not r.ok:
		hud.toast("Нельзя: %s" % r.error, Color("ff9f6b"))
		return
	var accepted_description := ""
	if str(r["accepted"]) != "":
		var quest: Dictionary = gd.quests[r["accepted"]]
		hud.toast("Задание принято: %s" % quest["name"], Color("7dff9b"))
		accepted_description = str(quest.get("description", ""))
	if str(r["turned_in"]) != "":
		hud.toast("Задание выполнено! %s" % rewards_text(r["rewards"]), Color("7dff9b"))
	if str(r["service"]).begins_with("tomb_"):
		_resolve_tomb_mechanism(str(r["service"]))
		return
	if world.zone_id in SOUTH_ROUTE_CHECKPOINT_ZONES or str(r["accepted"]).begins_with("q_se_tomb_") \
			or str(r["turned_in"]).begins_with("q_se_tomb_") or str(r["accepted"]).begins_with("q_se_market_") \
			or str(r["turned_in"]).begins_with("q_se_market_") or r["turned_in"] == "q_se_sluice_charter":
		_save_tomb_checkpoint()
	if r["service"] == "sea_ferry":
		_depart_ferry()
		return
	if str(r["service"]) != "" and _open_town(str(r["service"])):
		return
	refresh_hud()
	if (r["view"] as Dictionary).is_empty():
		_close_info()
	else:
		_show_dialogue(r["view"], accepted_description)


func _ferry_landing(zone: String) -> Vector2:
	var tile: Array = gd.chunk_manifest["ferry_landings"][zone]
	return (Vector2(tile[0], tile[1]) + Vector2(0.5, 0.5)) * map.grid.tile_px


func _depart_ferry() -> void:
	_close_info()
	if not map.has_zone_scene(SeaFerry.destination(world.zone_id)):
		hud.toast("Рейс отсюда недоступен.", Color("ffb36b"))
		return
	var result := SeaFerry.depart(world, log, _hero_level(), now)
	if not result.ok:
		var message := "Сначала получи у Савы дорожный лист после завершения истории маяков."
		if SeaFerry.is_expedition_port(world.zone_id):
			message = "Сначала получи у Надии разрешение в задании «Первый проход»."
		if result.error == "level_too_low":
			message = "Для переправы нужен %d-й уровень." % SeaFerry.required_level(world, world.zone_id)
		hud.toast(message, Color("ffb36b"))
		return
	_busy_ui = true
	map.frozen = true
	hud.toast("Судно отчалило. Рейс займёт %d с." % result.seconds, Color("ffe9a8"))
	if SeaFerry.is_expedition_port(world.zone_id):
		_save_tomb_checkpoint()


func _finish_ferry_if_due() -> void:
	if not SeaFerry.arrive(world, log, now):
		return
	_busy_ui = false
	map.frozen = false
	map.arrive_at(_ferry_landing(world.zone_id), world.zone_id, false)
	if SeaFerry.is_expedition_port(world.zone_id):
		_save_tomb_checkpoint()
	refresh_hud()


func buy_at_shop(index: int) -> String:
	var error := town_services.buy(world, wallet, inv, index, log)
	if error.is_empty() and world.zone_id == "z_east_market":
		_save_tomb_checkpoint()
	return error


func _open_town(service: String) -> bool:
	var zone: Dictionary = world.graph.zones.get(world.zone_id, {})
	if gd.town_services.is_empty() or town_screen != null or TownServices.profile(zone).is_empty():
		return false
	if service != "town_directory" and not town_services.available(world, service):
		return false
	_close_info()
	_busy_ui = true
	map.frozen = true
	town_screen = TOWN_SCENE.instantiate()
	_layer.add_child(town_screen)
	town_screen.setup(self, service)
	town_screen.closed.connect(_close_town)
	town_screen.menu_requested.connect(func(tab: String):
		_close_town()
		open_menu(tab))
	return true


func _close_town() -> void:
	town_screen.queue_free()
	town_screen = null
	_busy_ui = false
	map.frozen = false
	map.has_target = false


func rewards_text(rew: Dictionary) -> String:
	var parts: Array[String] = []
	if int(rew.get("coins", 0)) > 0:
		parts.append("%d монет" % int(rew["coins"]))
	if int(rew.get("xp", 0)) > 0:
		parts.append("%d опыта" % int(rew["xp"]))
	for id in rew.get("items", {}):
		parts.append(str(gd.items[id].name))
	return ", ".join(parts)


# ---------- бой ----------

func _on_enemy_contact(spawn: EnemySpawn) -> void:
	if battle != null or _busy_ui:
		return
	var enc: Dictionary = gd.encounters[spawn.encounter_id]
	var zone: Dictionary = world.graph.zones[enc["zone"]]
	if zone["type"] == "dungeon":
		_show_dungeon_entry(spawn, zone)
	else:
		_start_encounter(spawn, spawn.encounter_id)


func _save_tomb_checkpoint() -> void:
	settings.tomb_checkpoint = TombCheckpoint.capture(self)
	settings.save_file()


func _resolve_tomb_mechanism(mechanism: String) -> void:
	_close_info()
	if world.zone_id != "z_tomb":
		return
	if mechanism == "tomb_wrong_wheel":
		hud.toast("Лунное колесо упёрлось в засов. Начните с солнечного.", Color("ffb36b"))
		return
	if _dungeon_run == null or not _dungeon_run.solve(mechanism):
		hud.toast("Сначала пройдите предыдущий зал или проверьте, что уже открыто.", Color("ffb36b"))
		return
	var message := "Засов открыт. Проверьте погребальную табличку." if mechanism == "tomb_wheels" else "Оттиск снят. Можно идти к Хранителю."
	hud.toast(message)
	_save_tomb_checkpoint()


func _exit_tomb() -> void:
	_close_info()
	map.arrive_at(Vector2(158.5, 110.5) * map.grid.tile_px, "z_canyon")
	_save_tomb_checkpoint()


func _show_tomb_gate(spawn: EnemySpawn, zone: Dictionary) -> void:
	var panel := _open_info()
	panel.set_title(str(zone["name"]))
	if _dungeon_run != null and _dungeon_run.zone_id == "z_tomb":
		if _dungeon_run.current_encounter() == spawn.encounter_id and _dungeon_run.can_fight():
			panel.add_choice("Начать бой", _continue_dungeon.bind(spawn), 58.0)
		else:
			panel.add_text("Продолжайте по залам. К Хранителю открывает путь оттиск из галереи.")
	elif log.completed.has("q_se_tomb_archive") or log.state("q_se_tomb_archive", inv, _hero_level(), now) == "ready":
		panel.add_text("Хранитель повержен. Отнесите находку Салиху.")
	elif spawn.encounter_id == "enc_tomb_1":
		panel.add_text("Вход с 25-го уровня по ключу. Сначала возьмите поручение Салиха.")
		panel.add_choice("Открыть ключом", _enter_dungeon.bind(spawn), 58.0)
	else:
		panel.add_text("Хранитель ждёт в последнем зале. Вход расположен у западных ворот.")
	panel.add_choice("Выйти в Каньон Эха", _exit_tomb, 58.0)
	panel.add_choice("Отойти", _leave_dungeon_gate.bind(spawn), 58.0)


func _show_dungeon_entry(spawn: EnemySpawn, zone: Dictionary) -> void:
	if zone["id"] == "z_tomb":
		_show_tomb_gate(spawn, zone)
		return
	if _dungeon_run != null and _dungeon_run.zone_id == zone["id"]:
		_start_encounter(spawn, _dungeon_run.current_encounter())
		return
	var panel := _open_info()
	panel.set_title(str(zone["name"]), Color("ffe9a8"))
	panel.add_text("Уровень входа: %d. Для входа нужен ключ." % int(zone["min_level"]))
	panel.add_choice("Войти", _enter_dungeon.bind(spawn), 66.0)
	panel.add_choice("Назад", _leave_dungeon_gate.bind(spawn), 66.0)


func _leave_dungeon_gate(spawn: EnemySpawn) -> void:
	_close_info()
	_push_hero_away(spawn)


func _enter_dungeon(spawn: EnemySpawn) -> void:
	if battle != null:
		return
	var entrance: Dictionary = gd.encounters[spawn.encounter_id]
	if world.zone_id != entrance["zone"]:
		_leave_dungeon_gate(spawn)
		return
	if world.zone_id == "z_ruins" and not log.active.has("m06_ruins") and not log.completed.has("m06_ruins"):
		hud.toast("Сначала возьмите у Тавии задание на Руины Стража.", Color("ffb36b"))
		_leave_dungeon_gate(spawn)
		return
	if world.zone_id == "z_tomb" and (_dungeon_run != null or spawn.encounter_id != "enc_tomb_1"
			or log.state("q_se_tomb_archive", inv, _hero_level(), now) != "active"):
		_show_tomb_gate(spawn, world.graph.zones["z_tomb"])
		return
	var entry := DungeonRun.enter(world, inv, _hero_level(), now)
	if not entry.ok:
		var text := "Нужен ключ от подземелья." if entry.error == "no_key" else "Вход недоступен на текущем уровне."
		hud.toast(text, Color("ffb36b"))
		_leave_dungeon_gate(spawn)
		return
	_dungeon_run = entry.run
	if _dungeon_run.zone_id == "z_tomb":
		_save_tomb_checkpoint()
	if _dungeon_run.zone_id == "z_ruins":
		log.on_event({"type": "activity", "target": "key_ruins"})
	_close_info()
	_start_encounter(spawn, _dungeon_run.current_encounter())


func _continue_dungeon(spawn: EnemySpawn) -> void:
	if battle == null and _dungeon_run != null and _dungeon_run.can_fight() and (
			_dungeon_run.zone_id != "z_tomb" or spawn.encounter_id == _dungeon_run.current_encounter()):
		_close_info()
		_start_encounter(spawn, _dungeon_run.current_encounter())


func _start_encounter(spawn: EnemySpawn, encounter_id: String) -> void:
	var enc: Dictionary = gd.encounters[encounter_id]
	map.frozen = true
	var units := _player_units()
	var names: Dictionary = {}
	var kinds: Dictionary = {}
	for unit in units:
		var merc := squad.hero if unit.is_hero else squad.by_uid(unit.id - 1)
		names[unit.id] = member_name(merc)
		var def: MercenaryDef = gd.mercs[merc.def_id]
		kinds[unit.id] = Art.merc_sprite(def.id, def.weapon)
	var foes := EncounterFactory.build_units(enc, gd, squad.hero.level)
	var enemy_entries := EncounterFactory.enemy_entries(enc)
	for i in foes.size():
		names[foes[i].id] = str(gd.monsters[enemy_entries[i]["monster"]]["name"])
		kinds[foes[i].id] = Art.monster_sprite(str(enemy_entries[i]["monster"]))
	var all: Array[BattleUnit] = []
	all.append_array(units)
	all.append_array(foes)
	var cfg: Dictionary = gd.rules["formation"]
	var rules := BattleRules.new()
	rules.battle_rooms = int(cfg["battle_rooms"])
	rules.reserve_swap_limit = int(cfg["pve_swaps"])
	var sim := BattleSim.new(rules, all, rng.randi(), gd.skills)
	sim.configure_loot(gd.rules["battle_loot"], LootTable.find(gd, str(enc["loot"])), settings.loot_robots, rng.randi())
	battle = BATTLE_SCENE.instantiate()
	_layer.add_child(battle)
	battle.speed = settings.battle_speed if _shots_dir == "" else 3.0
	pve.begin_battle()
	battle.pve = pve
	battle.settings = settings
	battle.setup(gd, sim, names, kinds, str(enc["name"]), hero_class)
	battle.finished.connect(_on_battle_finished.bind(spawn, encounter_id))
	_hud_layer.visible = false
	map.visible = false


func _on_battle_finished(result: String, spawn: EnemySpawn, encounter_id: String) -> void:
	var enc: Dictionary = gd.encounters[encounter_id]
	var in_dungeon := _dungeon_run != null and _dungeon_run.current_encounter() == encounter_id
	var next_stage := false
	var completed := battle.sim
	var battle_units := completed.units
	battle.queue_free()
	battle = null
	_hud_layer.visible = true
	map.visible = true
	var lines: Array[String] = []
	var title := ""
	pve.finish_battle(result)
	var losses := pve.apply_losses(squad, wallet, completed, result, settings.blessing)
	if result == "win":
		log.record_battle_practice(completed, str(enc["zone"]))
		title = "Победа!"
		var coins := int(enc["coins"])
		wallet["coins"] = int(wallet["coins"]) + coins
		var before: Dictionary = {}
		for m in members():
			before[m.uid] = m.level
		var uids: Array = []
		for unit in battle_units:
			if unit.side == BattleRules.SIDE_A and not unit.is_hero and unit.participated:
				uids.append(unit.id - 1)
		inv.crafting.add_workload(int(gd.rules["crafting"]["battle_workload"]), gd.rules["crafting"])
		var xp := pve.victory_xp(int(enc["xp"]) + completed.loot_xp, settings.blessing)
		var disabled_count := squad.disabled_count()
		var res := squad.award_formation_battle_xp(xp, uids, disabled_count)
		var loot_cfg: Dictionary = gd.rules["battle_loot"]
		var drops := LootTable.apply_jackpot(completed.collected_loot, settings.jackpot_item, jackpot_bank, loot_cfg)
		var overflow := inv.add_drops(drops)
		if not overflow.is_empty():
			lines.append("Часть трофеев не поместилась в сумку.")
		if settings.jackpot_item in loot_cfg["jackpot_items"]:
			lines.append("Джекпот: %d/%d" % [jackpot_bank.get(settings.jackpot_item, 0), loot_cfg["jackpot_threshold"]])
		lines.append("Опыт: +%d     Монеты: +%d" % [squad.formation_battle_xp(xp, disabled_count), coins])
		if int(res["hero_levels"]) > 0:
			lines.append("Герой получил уровень! Теперь %d. Каждый наёмник получает очко навыка и очко характеристик." % squad.hero.level)
		for m in squad.all_mercenaries():
			if m.level > int(before[m.uid]):
				lines.append("%s: уровень %d" % [member_name(m), m.level])
		if drops.is_empty():
			lines.append("Добыча: ничего")
		else:
			var totals := {}
			for drop in drops:
				totals[drop["item"]] = int(totals.get(drop["item"], 0)) + int(drop["count"])
			var d: Array[String] = []
			for item in totals:
				d.append("%s x%d" % [gd.items[item].name, totals[item]])
			lines.append("Добыча: " + ", ".join(d))
		log.on_event({"type": "kill", "encounter": str(enc["id"])})
		if in_dungeon:
			if _dungeon_run.complete_stage():
				log.on_event({"type": "dungeon_clear", "zone": _dungeon_run.zone_id})
				lines.append("Подземелье пройдено.")
				_dungeon_run = null
			else:
				next_stage = true
				lines.append("Зал пройден. Следующий зал: %d из %d." % [_dungeon_run.stage + 1, _dungeon_run.stages.size()])
		if not in_dungeon or _dungeon_run == null:
			map.mark_defeated(spawn, now + RESPAWN_SECONDS)
		if not in_dungeon:
			lines.append("")
			lines.append("Враги вернутся через %d сек." % int(RESPAWN_SECONDS))
	elif result == "draw":
		title = "Ничья"
		_push_hero_away(spawn)
	elif result == "flee":
		title = "Вы отступили"
		lines.append("Враги остались на месте. Вы можете вернуться, когда будете готовы.")
		_push_hero_away(spawn)
	else:
		title = "Отряд разбит"
		lines.append("Бойцов унесли с поля боя. Отряд отдохнёт и вернётся в строй.")
		_push_hero_away(spawn)
	if int(losses.coins) > 0 or int(losses.xp) > 0:
		lines.append("Потери: %d монет и %d опыта отряда." % [losses.coins, losses.xp])
	elif settings.blessing and result in ["lose", "flee"]:
		lines.append("Благословение защитило от потерь.")
	lines.append("Очки автобоя: %d/%d" % [pve.auto_points, pve.config["auto_points_cap"]])
	refresh_hud()
	var panel := _open_info()
	panel.set_title(title, Color("7dff9b") if result == "win" else Color("ffb36b"))
	for l in lines:
		panel.add_text(l)
	if enc["zone"] in ["z_river_marsh", "z_fog_trail"] and result == "win":
		_save_tomb_checkpoint()
	if in_dungeon and enc["zone"] == "z_tomb":
		_save_tomb_checkpoint()
		panel.add_choice("Продолжить осмотр", _leave_dungeon_gate.bind(spawn), 58.0)
		panel.add_choice("Выйти в Каньон Эха", _exit_tomb, 58.0)
	elif next_stage:
		panel.add_choice("Следующий зал", _continue_dungeon.bind(spawn), 66.0)
		panel.add_choice("Вернуться на карту", _leave_dungeon_gate.bind(spawn), 66.0)
	else:
		panel.add_choice("Продолжить", _close_info, 66.0)


func _push_hero_away(spawn: EnemySpawn) -> void:
	var dir: Vector2 = (map.hero.global_position - spawn.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	map.hero.position += dir * 140.0
	map.has_target = false


# ---------- автопроверка со скриншотами ----------

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots_dir, shot_name])
	print("SMOKE shot ", shot_name)


func _smoke_menus() -> void:
	open_menu("squad")
	await get_tree().create_timer(0.3).timeout
	await _shot("m1_squad")
	var archer := squad.mercs[0]
	var disable_error := squad.set_enabled(archer.uid, false)
	assert(disable_error == "")
	_menu.sel_member = members().find(archer)
	_menu.rebuild()
	await _shot("m1b_disabled")
	var enable_error := squad.set_enabled(archer.uid, true)
	assert(enable_error == "")
	_menu.sel_member = members().find(squad.rooms[0])
	_menu.rebuild()
	await _shot("m1c_room")
	_menu.sel_member = 0
	var hero := squad.hero
	var before := int(formation[hero.uid])
	place_member(hero, 3)
	assert(int(formation[hero.uid]) == 3)
	_menu.rebuild()
	await get_tree().create_timer(0.2).timeout
	await _shot("m2_formation_changed")
	place_member(hero, before)
	var ring: Item = null
	for it in inv.items:
		if it.def_id == "x_ring":
			ring = it
	var err := hero.equip(ring, inv)
	print("SMOKE equip ring: ", "ok" if err == "" else err)
	_menu.sel_slot = "helm"
	_menu.rebuild()
	await get_tree().create_timer(0.2).timeout
	await _shot("m3_slot_picker")
	_menu.set_tab("bag")
	_menu.sel_item = inv.items[0].uid
	_menu.rebuild()
	await get_tree().create_timer(0.2).timeout
	await _shot("m4_bag")
	_menu.set_tab("forge")
	_menu.sel_forge_item = hero.equipped["weapon"].uid
	var sword: Item = hero.equipped["weapon"]
	for i in 6:
		Enhancer.try_enhance(sword, inv, wallet, rng)
	wallet["coins"] = int(wallet["coins"]) + 500
	var res := Crafter.craft("craft_h_helm", inv, wallet)
	print("SMOKE sword plus=", sword.plus, " craft=", res.ok, " coins=", wallet["coins"])
	_menu.rebuild()
	await get_tree().create_timer(0.2).timeout
	await _shot("m5_forge")
	_menu.set_tab("quests")
	log.accept("m01_first_steps", 1, now)
	_menu.rebuild()
	await get_tree().create_timer(0.2).timeout
	await _shot("m6_quests")
	_menu.set_tab("settings")
	await get_tree().create_timer(0.2).timeout
	await _shot("m7_settings")
	settings.joystick = true
	apply_settings()
	close_menu()
	await get_tree().create_timer(0.3).timeout
	await _shot("m8_joystick_map")
	settings.joystick = false
	apply_settings()
	log.abandon("m01_first_steps")
	refresh_hud()


func _smoke() -> void:
	settings.auto_start = false
	settings.auto_disabled_units = {}
	await get_tree().create_timer(0.8).timeout
	await _shot("01_field")
	# бесшовность: границы кусков мира без загрузки
	var border_x := 3.0 * map.grid.chunk_px()  # граница лугов и леса
	var road_y := 2100.0
	map.hero.position = Vector2(border_x - 260.0, road_y)
	await get_tree().create_timer(0.6).timeout
	await _shot("w1_meadow_forest_border")
	map.hero.position = Vector2(border_x + 200.0, road_y)
	await get_tree().create_timer(0.8).timeout
	await _shot("w2_forest")
	print("SMOKE zone after crossing: ", map.zone_id)
	var st: Array = map.manifest["start"]
	map.hero.position = Vector2(float(st[0]) + 0.5, float(st[1]) + 0.5) * map.grid.tile_px
	await get_tree().create_timer(1.0).timeout  # чанки догружаются вокруг героя
	await _smoke_menus()
	var hc_layer := CanvasLayer.new()
	hc_layer.layer = 50
	add_child(hc_layer)
	var hc := (load("res://scenes/ui/hero_create.tscn") as PackedScene).instantiate() as HeroCreate
	hc_layer.add_child(hc)
	hc.setup(gd, "warden")
	await get_tree().create_timer(0.4).timeout
	await _shot("h1_hero_create")
	hc.select("sawyer")
	await get_tree().create_timer(0.3).timeout
	await _shot("h2_hero_create_locked")
	hc_layer.queue_free()
	map.hero.position = _smoke_npc("npc_orvin").global_position + Vector2(-70, 40)
	await get_tree().create_timer(0.6).timeout
	await _shot("02_dialogue")
	_dialogue_choose(0)
	await get_tree().create_timer(0.4).timeout
	if _info != null:
		_close_info()
	await get_tree().create_timer(0.3).timeout
	await _shot("03_quest_taken")
	map.hero.position = Vector2(40.0, 20.0) * map.grid.tile_px  # луга, рядом первые слизни
	await get_tree().create_timer(1.2).timeout
	var slimes := _smoke_spawn("enc_meadow_slimes")
	map.hero.position = slimes.global_position + Vector2(-400, 0)
	await get_tree().create_timer(0.5).timeout
	await _shot("04_near_enemy")
	map.hero.position = slimes.global_position + Vector2(-55, 0)
	await get_tree().create_timer(1.2).timeout
	await _shot("05_battle_start")
	if battle != null:
		battle._on_unit_clicked(1)
		await get_tree().create_timer(0.4).timeout
		await _shot("06_actions")
		battle._choose_attack()
		await get_tree().create_timer(0.2).timeout
		await _shot("07_pick_target")
		battle._on_unit_clicked(1000)
		await _shot("07b_attack_area")
		battle.sim.unit_by_id(1000).hp = 1
		battle._on_unit_clicked(1000)
		await get_tree().create_timer(0.35).timeout
		await _shot("08_attack_anim")
		await get_tree().create_timer(2.0).timeout
		await _shot("09_enemy_turn")
		assert(battle.sim.corpses.has(1000))
		battle._on_unit_clicked(2)
		await battle._open_trophy_menu()
		await _shot("09a_trophy_menu")
		(battle.action_list.get_child(0) as ActionButton).pressed.emit()
		await _shot("09a_trophy_target")
		battle._on_unit_clicked(1000)
		await get_tree().create_timer(0.45).timeout
		assert(not battle.sim.corpses.has(1000))
		battle._on_unit_clicked(4)
		assert(battle.sim.reserve_targets(4).has(8))
		await battle._open_reserve_picker()
		await _shot("09b_reserve_picker")
		(battle.action_list.get_child(0) as ActionButton).pressed.emit()
		await get_tree().create_timer(0.4).timeout
		assert(battle.sim.reserve_swaps == 1)
		await _shot("09c_reserve_swapped")
		settings.auto_license = true
		settings.auto_mercs_only = false
		var points_before_auto := pve.auto_points
		battle._toggle_auto()
		assert(pve.auto_points == points_before_auto - int(pve.config["auto_cost"]))
		var waited := 0.0
		while battle != null and waited < 60.0:
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
			if waited == 3.0:
				await _shot("10_auto_battle")
	await get_tree().create_timer(0.6).timeout
	await _shot("11_result")
	_close_info()
	await get_tree().create_timer(0.3).timeout
	await _shot("12_back_on_map")
	await _smoke_reinforcements()
	print("SMOKE done, coins=", wallet["coins"], " hero_xp=", squad.hero.xp, " level=", squad.hero.level)
	get_tree().quit()


func _smoke_spawn(enc_id: String) -> EnemySpawn:
	for sp in map.spawns:
		if sp.encounter_id == enc_id:
			return sp
	assert(false, "в загруженных чанках нет врага " + enc_id)
	return null


func _smoke_npc(npc_id: String) -> NpcMarker:
	for n in map.npcs:
		if n.npc_id == npc_id:
			return n
	assert(false, "в загруженных чанках нет NPC " + npc_id)
	return null


func _smoke_reinforcements() -> void:
	map.hero.position = Vector2(126.0, 44.0) * map.grid.tile_px  # лес, чанки с разбойниками подгружаются рядом
	await get_tree().create_timer(1.5).timeout
	var bandits: EnemySpawn
	for spawn in map.spawns:
		if spawn.encounter_id == "enc_forest_bandits":
			bandits = spawn
			break
	assert(bandits != null)
	_on_enemy_contact(bandits)
	assert(battle.enemy_group_count == 3)
	var sim := battle.sim
	for unit in sim.units:
		if unit.side == BattleRules.SIDE_B:
			unit.hp = 1
	await _shot("13_first_group")
	battle._toggle_auto()
	var elapsed := 0.0
	while sim.enemy_wave < 2 and battle != null and elapsed < 30.0:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	assert(sim.enemy_wave == 2)
	await _shot("14_reinforcements")
	while battle != null and elapsed < 60.0:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	assert(sim.winner == BattleSim.Winner.SIDE_A)
	print("SMOKE reinforcements: 3 groups defeated")


func _smoke_tactics() -> void:
	await get_tree().process_frame
	_on_npc_contact("npc_orvin")
	await _shot("01_orvin")
	(_info.choice_list.get_child(-1) as Button).pressed.emit()
	(_info.choice_list.get_child(0) as Button).pressed.emit()
	assert(tactical != null)
	await _shot("02_mission")
	_tactical_step(1, tactical.move_button, Vector2i(5, 3))
	_tactical_step(2, tactical.move_button, Vector2i(3, 2))
	_tactical_step(2, tactical.ability_button, Vector2i(7, 2))
	assert(tactical.board.area_cells.size() == 25)
	await _shot("03_area_5x5")
	tactical.select_cell(Vector2i(7, 2))
	_tactical_step(3, tactical.move_button, Vector2i(3, 5))
	_tactical_step(3, tactical.ability_button, Vector2i(6, 4))
	assert(tactical.board.area_cells.size() == 42)
	await _shot("04_area_7x7")
	tactical.select_cell(Vector2i(6, 4))
	tactical.end_button.pressed.emit()
	_tactical_step(1, tactical.attack_button, Vector2i(5, 2))
	_tactical_step(2, tactical.move_button, Vector2i(4, 3))
	_tactical_step(2, tactical.attack_button, Vector2i(7, 4))
	tactical.end_button.pressed.emit()
	_tactical_step(1, tactical.move_button, Vector2i(8, 4))
	_tactical_step(1, tactical.attack_button, Vector2i(9, 4))
	assert(tactical.sim.objective().get("type") == "occupy")
	await _shot("05_capture")
	tactical.end_button.pressed.emit()
	_tactical_step(1, tactical.move_button, Vector2i(10, 3))
	assert(tactical.sim.winner == BattleSim.Winner.SIDE_A)
	await _shot("06_victory")
	tactical.exit_button.pressed.emit()
	assert(tactical == null and map.visible)
	await _shot("07_return")
	print("SMOKE tactics: victory and return to map")
	get_tree().quit()


func _tactical_step(id: int, button: Button, at: Vector2i) -> void:
	tactical.select_cell(tactical.sim.positions[id])
	assert(not button.disabled)
	button.pressed.emit()
	tactical.select_cell(at)


func _smoke_world_map() -> void:
	await get_tree().process_frame
	var meadow := map.arrival_point("z_meadow")
	assert(meadow != Vector2.INF)
	map.arrive_at(meadow, "z_meadow")
	settings.teleport_license = true
	open_menu("map")
	var screen := _menu.pages_node.get_node("TabMap") as WorldMapScreen
	var port_index := screen.zone_ids.find("z_harbor")
	assert(port_index >= 0)
	screen.zones.select(port_index)
	screen.zones.item_selected.emit(port_index)
	assert(not screen.teleport.disabled)
	screen.favorite.pressed.emit()
	assert(world.favorites.has("z_harbor"))
	await _shot("01_world_map")
	screen.favorites_only.set_pressed(true)
	assert(screen.zone_ids.size() == 1)
	await _shot("02_favorites")
	screen.teleport.pressed.emit()
	assert(_menu == null and world.zone_id == "z_harbor" and map.zone_id == "z_harbor")
	assert(world.will_at(now) == world.will_max() - int(gd.rules["world"]["teleport_cost"]))
	await _shot("03_arrived")
	print("SMOKE world map: destination reached and will deducted")
	get_tree().quit()


func _smoke_town() -> void:
	await get_tree().process_frame
	_on_npc_contact("npc_orvin")
	assert(_info != null)
	for choice in _info.choice_list.get_children():
		if choice.text == "Городские службы":
			choice.pressed.emit()
			break
	assert(town_screen != null)
	await _shot("01_services")
	for choice in town_screen.choices.get_children():
		if choice.text == "Банк":
			choice.pressed.emit()
			break
	assert(town_screen.service == "bank")
	var before := int(wallet["coins"])
	(town_screen.content.get_child(2) as Button).pressed.emit()
	assert(int(wallet["coins"]) < before and town_services.bank_coins > 0)
	await _shot("02_bank")
	town_screen.closed.emit()
	_on_npc_contact("npc_tobin")
	assert(_info != null)
	for choice in _info.choice_list.get_children():
		if choice.text == "Открыть лавку":
			choice.pressed.emit()
			if town_screen != null:
				break
	assert(town_screen != null and town_screen.service == "shop")
	await _shot("03_shop")
	var ore := inv.material_count("iron_ore")
	(town_screen.content.get_child(1) as Button).pressed.emit()
	assert(inv.material_count("iron_ore") > ore)
	print("SMOKE town: city directory, bank and shop opened through dialogue")
	get_tree().quit()
