class_name DemoMain
extends Node
## Демо-версия: бегаем по карте, берём задание у капитана, нападаем на врагов, играем пошаговый бой,
## получаем опыт и добычу. Использует настоящую игровую логику (BattleSim, Squad, QuestLog, LootTable),
## а не отдельную копию правил.

const RESPAWN_SECONDS := 25.0

var gd: GameData
var squad: Squad
var inv: Inventory
var wallet := {"coins": 150}
var log: QuestLog
var world: PlayerWorld
var runner: DialogueRunner
var field: DemoField
var battle: BattleView
var now := 0.0
var rng := RandomNumberGenerator.new()

var _hud: CanvasLayer
var _layer: CanvasLayer
var _info: Label
var _xp_bar: ProgressBar
var _quest: Label
var _hint: Label
var _toast: Label
var _squad_label: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _busy_ui := false
var _shots_dir := ""


func _ready() -> void:
	rng.randomize()
	gd = GameData.load_dir()
	_setup_party()
	log = QuestLog.new(gd)
	world = PlayerWorld.new(gd, 0.0)
	runner = DialogueRunner.new(gd, log, world)

	field = DemoField.new()
	add_child(field)
	field.setup(gd)
	field.zone_changed.connect(_on_zone_changed)
	field.enemy_contact.connect(_on_enemy_contact)
	field.npc_contact.connect(_on_npc_contact)

	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_build_hud()
	_refresh_hud()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--smoke"):
			_shots_dir = a.get_slice("=", 1) if "=" in a else "/tmp/demo_shots"
			_smoke.call_deferred()


func _process(delta: float) -> void:
	now += delta
	field.respawn_ready(now)
	if _hint != null and now > 14.0:
		_hint.modulate.a = maxf(0.0, _hint.modulate.a - delta * 0.5)


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
	hero.equip(inv.add_equipment("w_sword_1"), inv)
	hero.equip(inv.add_equipment("a_cloth"), inv)
	archer.equip(inv.add_equipment("w_bow_1"), inv)
	adept.equip(inv.add_equipment("w_staff_1"), inv)


func _player_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var members: Array[Mercenary] = [squad.hero]
	members.append_array(squad.mercs)
	var slots := [0, 4, 5, 7, 8, 3, 6, 1]
	for i in members.size():
		out.append(BattleUnit.from_mercenary(members[i], gd, i + 1, BattleRules.SIDE_A, slots[i]))
	return out


func _member_name(i: int) -> String:
	var members: Array[Mercenary] = [squad.hero]
	members.append_array(squad.mercs)
	return (gd.mercs[members[i].def_id] as MercenaryDef).name


# ---------- интерфейс карты ----------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var top := PanelContainer.new()
	top.position = Vector2(12, 10)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.72)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", sb)
	_hud.add_child(top)
	var vb := VBoxContainer.new()
	top.add_child(vb)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 20)
	vb.add_child(_info)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(320, 10)
	_xp_bar.show_percentage = false
	vb.add_child(_xp_bar)
	_quest = Label.new()
	_quest.add_theme_font_size_override("font_size", 16)
	_quest.modulate = Color(1, 1, 1, 0.9)
	vb.add_child(_quest)
	var mm := Minimap.new()
	mm.field = field
	mm.position = Vector2(1280 - mm.size.x - 14, 12)
	_hud.add_child(mm)
	_hint = Label.new()
	_hint.text = "Коснитесь карты, чтобы бежать (на ПК: стрелки или WASD). Подбегите к красным кольцам, чтобы напасть. У капитана Орвина (!) есть задание."
	_hint.position = Vector2(20, 628)
	_hint.custom_minimum_size = Vector2(1000, 0)
	_hint.size = Vector2(1000, 60)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_hint)
	var squad_btn := Button.new()
	squad_btn.text = "Отряд"
	squad_btn.custom_minimum_size = Vector2(130, 64)
	squad_btn.add_theme_font_size_override("font_size", 22)
	squad_btn.position = Vector2(1280 - 150, 720 - 84)
	squad_btn.pressed.connect(_toggle_squad)
	_hud.add_child(squad_btn)
	_squad_label = Label.new()
	_squad_label.position = Vector2(780, 190)
	_squad_label.size = Vector2(480, 420)
	_squad_label.add_theme_font_size_override("font_size", 16)
	var sq := StyleBoxFlat.new()
	sq.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	sq.set_corner_radius_all(10)
	sq.content_margin_left = 14
	sq.content_margin_top = 10
	_squad_label.add_theme_stylebox_override("normal", sq)
	_squad_label.visible = false
	_hud.add_child(_squad_label)
	_toast = Label.new()
	_toast.position = Vector2(240, 560)
	_toast.size = Vector2(800, 50)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)
	_panel = PanelContainer.new()
	_panel.position = Vector2(200, 330)
	_panel.size = Vector2(880, 360)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	pb.set_corner_radius_all(14)
	pb.content_margin_left = 22
	pb.content_margin_right = 22
	pb.content_margin_top = 16
	pb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", pb)
	_panel.visible = false
	_layer.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_box)


func _hero_level() -> int:
	return squad.hero.level


func _refresh_hud() -> void:
	var h := squad.hero
	var need := Progression.xp_to_next(h.level, gd)
	_info.text = "Герой   Ур. %d     Монеты: %d     Зона: %s" % [h.level, int(wallet["coins"]), DemoField.ZONES[field.zone_id]["name"]]
	_xp_bar.max_value = maxf(1.0, float(need))
	_xp_bar.value = float(h.xp)
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
	_quest.text = "\n".join(lines) if not lines.is_empty() else ""
	var marker := not log.available_from("npc_orvin", h.level, now).is_empty() or not log.ready_at("npc_orvin", inv, h.level, now).is_empty()
	field.quest_marker = marker


func _toggle_squad() -> void:
	_squad_label.visible = not _squad_label.visible
	if not _squad_label.visible:
		return
	var lines: Array[String] = ["ОТРЯД", ""]
	var members: Array[Mercenary] = [squad.hero]
	members.append_array(squad.mercs)
	for m in members:
		var d: MercenaryDef = gd.mercs[m.def_id]
		var st := m.compute_stats(gd)
		lines.append("%s  (ур. %d, %s)" % [d.name, m.level, str(gd.weapons[d.weapon]["name"])])
		lines.append("   ЗДР %d   АТК %d   ЗАЩ %d   ОД+ %d" % [st.hp, st.atk, st.def, st.ap_regen])
		var sk: Array[String] = []
		for sid in m.skill_levels:
			sk.append((gd.skills[sid] as SkillDef).name)
		lines.append("   Навыки: %s" % ", ".join(sk))
		var gear: Array[String] = []
		for slot in m.equipped:
			gear.append(str(gd.items[(m.equipped[slot] as Item).def_id].name))
		lines.append("   Снаряжение: %s" % (", ".join(gear) if not gear.is_empty() else "нет"))
		lines.append("")
	lines.append("В сумке: %d предм., материалы: %s" % [inv.items.size(), _materials_text()])
	_squad_label.text = "\n".join(lines)


func _materials_text() -> String:
	var parts: Array[String] = []
	for id in inv.materials:
		parts.append("%s x%d" % [gd.items[id].name, int(inv.materials[id])])
	return ", ".join(parts) if not parts.is_empty() else "нет"


func _toast_text(text: String, color := Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _on_zone_changed(zone_id: String) -> void:
	world.zone_id = zone_id
	log.on_event({"type": "visit", "zone": zone_id})
	_toast_text("Вы вошли: %s" % DemoField.ZONES[zone_id]["name"], Color("ffe9a8"))
	_refresh_hud()


# ---------- диалог с капитаном ----------

func _ctx() -> Dictionary:
	return {"inv": inv, "squad": squad, "wallet": wallet, "level": _hero_level(), "now": now}


func _on_npc_contact(npc_id: String) -> void:
	if _busy_ui or battle != null:
		return
	var r := runner.start(npc_id, _ctx())
	if not r.ok:
		return
	_open_panel()
	_show_dialogue(r["view"])


func _show_dialogue(view: Dictionary) -> void:
	_clear_panel()
	var title := Label.new()
	title.text = str(gd.npcs[view["npc"]]["name"])
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ffe9a8"))
	_panel_box.add_child(title)
	var txt := Label.new()
	txt.text = str(view["text"])
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(820, 70)
	txt.add_theme_font_size_override("font_size", 22)
	_panel_box.add_child(txt)
	for c in view["choices"]:
		var b := Button.new()
		b.text = str(c["text"])
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_dialogue_choose.bind(int(c["index"])))
		_panel_box.add_child(b)


func _dialogue_choose(index: int) -> void:
	var r := runner.choose(index, _ctx())
	if not r.ok:
		_toast_text("Нельзя: %s" % r.error, Color("ff9f6b"))
		return
	if str(r["accepted"]) != "":
		_toast_text("Задание принято: %s" % gd.quests[r["accepted"]]["name"], Color("7dff9b"))
	if str(r["turned_in"]) != "":
		_toast_text("Задание выполнено! %s" % _rewards_text(r["rewards"]), Color("7dff9b"))
	if str(r["service"]) != "":
		_toast_text("В демо эта служба недоступна", Color("ffd24d"))
	_refresh_hud()
	if (r["view"] as Dictionary).is_empty():
		_close_panel()
	else:
		_show_dialogue(r["view"])


func _rewards_text(rew: Dictionary) -> String:
	var parts: Array[String] = []
	if int(rew.get("coins", 0)) > 0:
		parts.append("%d монет" % int(rew["coins"]))
	if int(rew.get("xp", 0)) > 0:
		parts.append("%d опыта" % int(rew["xp"]))
	for id in rew.get("items", {}):
		parts.append(str(gd.items[id].name))
	return ", ".join(parts)


func _open_panel() -> void:
	_busy_ui = true
	field.frozen = true
	_panel.visible = true


func _close_panel() -> void:
	_panel.visible = false
	_busy_ui = false
	field.frozen = false
	field.has_target = false


func _clear_panel() -> void:
	for c in _panel_box.get_children():
		c.queue_free()


# ---------- бой ----------

func _on_enemy_contact(index: int) -> void:
	if battle != null or _busy_ui:
		return
	var g: Dictionary = field.groups[index]
	var enc: Dictionary = g["enc"]
	field.frozen = true
	var units := _player_units()
	var names: Dictionary = {}
	var kinds: Dictionary = {}
	for i in units.size():
		names[units[i].id] = _member_name(i)
		var members: Array[Mercenary] = [squad.hero]
		members.append_array(squad.mercs)
		kinds[units[i].id] = (gd.mercs[members[i].def_id] as MercenaryDef).weapon
	var foes := EncounterFactory.build_units(enc, gd)
	for i in foes.size():
		names[foes[i].id] = str(gd.monsters[enc["enemies"][i]["monster"]]["name"])
		kinds[foes[i].id] = ""
	var all: Array[BattleUnit] = []
	all.append_array(units)
	all.append_array(foes)
	var sim := BattleSim.new(BattleRules.new(), all, rng.randi(), gd.skills)
	battle = BattleView.new()
	battle.setup(gd, sim, names, kinds, str(enc["name"]))
	if _shots_dir != "":
		battle.speed = 3.0
	battle.finished.connect(_on_battle_finished.bind(index))
	_layer.add_child(battle)
	_hud.visible = false
	field.visible = false


func _on_battle_finished(result: String, index: int) -> void:
	var enc: Dictionary = field.groups[index]["enc"]
	var sim := battle.sim
	var survivors: Array[int] = []
	for u in sim.alive_units(BattleRules.SIDE_A):
		survivors.append(u.id)
	battle.queue_free()
	battle = null
	_hud.visible = true
	field.visible = true
	var lines: Array[String] = []
	var title := ""
	if result == "win":
		title = "Победа!"
		var coins := int(enc["coins"])
		wallet["coins"] = int(wallet["coins"]) + coins
		var before: Dictionary = {}
		var members: Array[Mercenary] = [squad.hero]
		members.append_array(squad.mercs)
		for m in members:
			before[m.uid] = m.level
		var uids: Array = []
		for m in squad.mercs:
			uids.append(m.uid)
		var res := squad.award_battle_xp(int(enc["xp"]), uids)
		var drops := LootTable.roll(LootTable.find(gd, str(enc["loot"])), rng)
		inv.add_drops(drops)
		lines.append("Опыт: +%d     Монеты: +%d" % [int(enc["xp"]), coins])
		if int(res["hero_levels"]) > 0:
			lines.append("Герой получил уровень! Теперь %d. Каждый наёмник получает очко навыка и очко характеристик." % squad.hero.level)
		for m in squad.mercs:
			if m.level > int(before[m.uid]):
				lines.append("%s: уровень %d" % [(gd.mercs[m.def_id] as MercenaryDef).name, m.level])
		if drops.is_empty():
			lines.append("Добыча: ничего")
		else:
			var d: Array[String] = []
			for x in drops:
				d.append("%s x%d" % [gd.items[x["item"]].name, int(x["count"])])
			lines.append("Добыча: " + ", ".join(d))
		log.on_event({"type": "kill", "encounter": str(enc["id"])})
		field.mark_defeated(index, now + RESPAWN_SECONDS)
		lines.append("")
		lines.append("Враги вернутся через %d сек." % int(RESPAWN_SECONDS))
	elif result == "flee":
		title = "Вы отступили"
		lines.append("Враги остались на месте. Вы можете вернуться, когда будете готовы.")
		_push_hero_away(index)
	else:
		title = "Отряд разбит"
		lines.append("Бойцов унесли с поля боя. Отряд отдохнёт и вернётся в строй.")
		_push_hero_away(index)
	_refresh_hud()
	_show_result(title, lines, result == "win")


func _push_hero_away(index: int) -> void:
	var g: Dictionary = field.groups[index]
	var dir: Vector2 = (field.hero_pos - (g["pos"] as Vector2)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	field.hero_pos += dir * 140.0
	field.has_target = false


func _show_result(title: String, lines: Array[String], win: bool) -> void:
	_open_panel()
	_clear_panel()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color("7dff9b") if win else Color("ffb36b"))
	_panel_box.add_child(t)
	for l in lines:
		var lab := Label.new()
		lab.text = l
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(820, 0)
		lab.add_theme_font_size_override("font_size", 22)
		_panel_box.add_child(lab)
	var b := Button.new()
	b.text = "Продолжить"
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(_close_panel)
	_panel_box.add_child(b)


# ---------- автопроверка со скриншотами ----------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots_dir, name])
	print("SMOKE shot ", name)


func _smoke() -> void:
	await get_tree().create_timer(0.8).timeout
	await _shot("01_field")
	field.hero_pos = DemoField.NPC_POS["npc_orvin"] + Vector2(-70, 40)
	await get_tree().create_timer(0.6).timeout
	await _shot("02_dialogue")
	_dialogue_choose(0)
	await get_tree().create_timer(0.4).timeout
	if _panel.visible:
		_close_panel()
	await get_tree().create_timer(0.3).timeout
	await _shot("03_quest_taken")
	field.hero_pos = (field.groups[0]["pos"] as Vector2) + Vector2(-400, 0)
	await get_tree().create_timer(0.5).timeout
	await _shot("04_near_enemy")
	field.hero_pos = (field.groups[0]["pos"] as Vector2) + Vector2(-55, 0)
	await get_tree().create_timer(1.2).timeout
	await _shot("05_battle_start")
	if battle != null:
		battle._on_unit_clicked(1)
		await get_tree().create_timer(0.2).timeout
		await _shot("06_actions")
		battle._choose_attack()
		await get_tree().create_timer(0.2).timeout
		await _shot("07_pick_target")
		var first_enemy := 1000
		battle._on_unit_clicked(first_enemy)
		await get_tree().create_timer(0.35).timeout
		await _shot("08_attack_anim")
		await get_tree().create_timer(2.0).timeout
		await _shot("09_enemy_turn")
		battle._toggle_auto()
		var waited := 0.0
		while battle != null and waited < 60.0:
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
			if waited == 3.0:
				await _shot("10_auto_battle")
	await get_tree().create_timer(0.6).timeout
	await _shot("11_result")
	_close_panel()
	await get_tree().create_timer(0.3).timeout
	await _shot("12_back_on_map")
	print("SMOKE done, coins=", wallet["coins"], " hero_xp=", squad.hero.xp, " level=", squad.hero.level)
	get_tree().quit()
