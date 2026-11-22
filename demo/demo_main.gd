class_name DemoMain
extends Node
## Демо-версия: бегаем по карте, берём задание у капитана, нападаем на врагов, играем пошаговый бой,
## получаем опыт и добычу. Использует настоящую игровую логику (BattleSim, Squad, QuestLog, LootTable).
## Интерфейс собран из сцен scenes/ui/*.tscn и scenes/battle/*.tscn (их можно править в редакторе Godot).

const RESPAWN_SECONDS := 25.0
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MENU_SCENE := preload("res://scenes/ui/menu.tscn")
const INFO_SCENE := preload("res://scenes/ui/info_panel.tscn")
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

var hud: Hud
var _hud_layer: CanvasLayer
var _layer: CanvasLayer
var _menu: MenuScreen
var _info: InfoPanel
var _busy_ui := false
var _last_tab := "squad"
var _shots_dir := ""


func _ready() -> void:
	rng.randomize()
	settings.load_file()
	gd = GameData.load_dir()
	pve = PvePolicy.new(gd.rules["pve"])
	_setup_party()
	log = QuestLog.new(gd)
	world = PlayerWorld.new(gd, 0.0)
	runner = DialogueRunner.new(gd, log, world)

	map = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	add_child(map)
	map.hero_sprite.texture = Art.character(Art.merc_sprite(squad.hero.def_id, "sword"))
	map.setup_content(gd)
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
	hud.menu_button.pressed.connect(func(): open_menu(_last_tab))
	refresh_hud()
	apply_settings()
	for a in OS.get_cmdline_user_args():
		if a == "--smoke-tactics" or a.begins_with("--smoke-tactics="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/tactical_shots"
			_smoke_tactics.call_deferred()
		elif a == "--smoke" or a.begins_with("--smoke="):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/demo_shots"
			_smoke.call_deferred()


func _process(delta: float) -> void:
	now += delta
	map.respawn_ready(now)
	map.joystick = hud.joystick.value if (hud.joystick.visible and not _busy_ui) else Vector2.ZERO
	if now > 14.0:
		hud.hint_label.modulate.a = maxf(0.0, hud.hint_label.modulate.a - delta * 0.5)


# ---------- подготовка отряда ----------

func _setup_party() -> void:
	squad = Squad.new(gd)
	inv = Inventory.new(gd)
	var hero := squad.create_hero("sword")
	hero.set_level(5, gd)
	hero.grant_hero_level_points()
	hero.learn_skill("sword_guard", gd)
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
	hero.equip(inv.add_equipment("w_sword_1"), inv)
	hero.equip(inv.add_equipment("a_cloth"), inv)
	archer.equip(inv.add_equipment("w_bow_1"), inv)
	adept.equip(inv.add_equipment("w_staff_1"), inv)
	for id in ["h_cap", "x_ring", "x_amulet", "a_chain", "w_sword_2"]:
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
	if squad.room_of(m.uid) >= 0:
		return
	var old := int(formation.get(m.uid, 0))
	var occ := member_at_slot(slot)
	if occ != null and occ != m:
		formation[occ.uid] = old
	formation[m.uid] = slot


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
		var unit := BattleUnit.from_mercenary(merc, gd, merc.uid + 1, BattleRules.SIDE_A, int(formation.get(merc.uid, 0)))
		unit.formation_ap_bonus = ap_bonus
		unit.reserve_room = room
		unit.participated = room < 0
		out.append(unit)
	return out


# ---------- интерфейс карты ----------

func _hero_level() -> int:
	return squad.hero.level


func refresh_hud() -> void:
	var h := squad.hero
	var need := Progression.xp_to_next(h.level, gd)
	hud.info_label.text = "Герой   Ур. %d     Монеты: %d     Зона: %s" % [h.level, int(wallet["coins"]), map.zone_name_of(map.zone_id)]
	hud.xp_bar.max_value = maxf(1.0, float(need))
	hud.xp_bar.value = float(h.xp)
	var lines: Array[String] = []
	for qid in log.active:
		var q: Dictionary = gd.quests[qid]
		var st := log.state(qid, inv, h.level, now)
		if st == "ready":
			lines.append("  [!] %s: сдать капитану Орвину" % q["name"])
			continue
		lines.append("  * %s" % q["name"])
		var objs: Array = q["objectives"]
		for i in objs.size():
			lines.append("      %s  %d/%d" % [objs[i]["text"], log.objective_count(qid, i, inv, h.level), int(objs[i]["count"])])
	hud.quest_label.text = "\n".join(lines)
	hud.quest_label.visible = not lines.is_empty()
	var marker := not log.available_from("npc_orvin", h.level, now).is_empty() or not log.ready_at("npc_orvin", inv, h.level, now).is_empty()
	map.set_quest_marker("npc_orvin", marker)
	hud.menu_dot.visible = not log.ready_at("npc_orvin", inv, h.level, now).is_empty()


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


func _on_zone_changed(zone_id: String, zone_name: String) -> void:
	world.zone_id = zone_id
	log.on_event({"type": "visit", "zone": zone_id})
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


func _on_npc_contact(npc_id: String) -> void:
	if _busy_ui or battle != null:
		return
	var r := runner.start(npc_id, _ctx())
	if not r.ok:
		return
	_open_info()
	_show_dialogue(r["view"])


func _show_dialogue(view: Dictionary) -> void:
	_info.clear()
	_info.set_title(str(gd.npcs[view["npc"]]["name"]))
	_info.add_text(str(view["text"]))
	for c in view["choices"]:
		_info.add_choice(str(c["text"]), _dialogue_choose.bind(int(c["index"])), 58.0)
	if view["npc"] == "npc_orvin" and not gd.tactical_missions.is_empty():
		_info.add_choice("Тактические бои", _show_tactical_missions, 64.0)


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
	if str(r["accepted"]) != "":
		hud.toast("Задание принято: %s" % gd.quests[r["accepted"]]["name"], Color("7dff9b"))
	if str(r["turned_in"]) != "":
		hud.toast("Задание выполнено! %s" % rewards_text(r["rewards"]), Color("7dff9b"))
	if str(r["service"]) != "":
		hud.toast("В демо эта служба недоступна", Color("ffd24d"))
	refresh_hud()
	if (r["view"] as Dictionary).is_empty():
		_close_info()
	else:
		_show_dialogue(r["view"])


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
	battle.setup(gd, sim, names, kinds, str(enc["name"]))
	battle.finished.connect(_on_battle_finished.bind(spawn))
	_hud_layer.visible = false
	map.visible = false


func _on_battle_finished(result: String, spawn: EnemySpawn) -> void:
	var enc: Dictionary = gd.encounters[spawn.encounter_id]
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
		map.mark_defeated(spawn, now + RESPAWN_SECONDS)
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
	var border_x := float(map.chunks[1].world_rect().end.x)
	map.hero.position = Vector2(border_x - 260.0, 1100.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("w1_meadow_forest_border")
	map.hero.position = Vector2(border_x + 200.0, 1100.0)
	await get_tree().create_timer(0.8).timeout
	await _shot("w2_forest")
	print("SMOKE zone after crossing: ", map.zone_id)
	map.hero.position = map.chunks[0].get_node("PlayerStart").global_position
	await get_tree().create_timer(0.4).timeout
	await _smoke_menus()
	map.hero.position = map.npcs[0].global_position + Vector2(-70, 40)
	await get_tree().create_timer(0.6).timeout
	await _shot("02_dialogue")
	_dialogue_choose(0)
	await get_tree().create_timer(0.4).timeout
	if _info != null:
		_close_info()
	await get_tree().create_timer(0.3).timeout
	await _shot("03_quest_taken")
	map.hero.position = map.spawns[0].global_position + Vector2(-400, 0)
	await get_tree().create_timer(0.5).timeout
	await _shot("04_near_enemy")
	map.hero.position = map.spawns[0].global_position + Vector2(-55, 0)
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


func _smoke_reinforcements() -> void:
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
