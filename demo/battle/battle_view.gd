class_name BattleView
extends Control
## Экран боя. Вид собран в сцене scenes/battle/battle_view.tscn (якоря, контейнеры), поэтому растягивается под любой экран.
## Внизу плитки бойцов, коснитесь плитки (или бойца на поле), чтобы открыть меню действий: атака, умения, смещение, ожидание.
## Вся логика боя в BattleSim, здесь только отображение и ввод.

signal finished(result: String)

enum Mode { IDLE, PICK_ACTION, PICK_TARGET, PICK_CELL, BUSY, LOOT, OVER }

const UNIT_VIEW := preload("res://scenes/battle/unit_view.tscn")
const HERO_CHIP := preload("res://scenes/battle/hero_chip.tscn")
const ACTION_BUTTON := preload("res://scenes/battle/action_button.tscn")

## Раскладка формаций: расстояние от центра экрана до передней линии, шаги между клетками, поля сверху и снизу.
@export var front_gap := 150.0
@export var col_step := 140.0
@export var row_step_max := 140.0
@export var top_margin := 96.0
@export var bottom_margin := 176.0

var sim: BattleSim
var gd: GameData
var names: Dictionary = {}
var sprites: Dictionary = {}
var views: Dictionary = {}
var chips: Dictionary = {}
var mode := Mode.BUSY
var selected := -1
var pending: Dictionary = {}
var preview_target := -1
var auto := false
var pve: PvePolicy
var settings: DemoSettings
var enemy_group_count := 1
var speed := 1.0
var title := ""
var cells_highlight: Array[int] = []

var _log_lines: Array[String] = []
var _result := ""

@onready var background: BattleBackground = %Background
@onready var field: Control = %Field
@onready var collector_row: HBoxContainer = %CollectorRow
@onready var title_label: Label = %TitleLabel
@onready var log_label: Label = %LogLabel
@onready var hero_bar: HBoxContainer = %HeroBar
@onready var hint_label: Label = %HintLabel
@onready var end_button: Button = %EndTurnButton
@onready var auto_button: Button = %AutoButton
@onready var flee_button: Button = %FleeButton
@onready var cancel_button: Button = %CancelButton
@onready var popup: PanelContainer = %ActionPopup
@onready var popup_title: Label = %PopupTitle
@onready var action_scroll: ScrollContainer = %ActionScroll
@onready var action_list: VBoxContainer = %ActionList
@onready var banner: Label = %Banner


func setup(p_gd: GameData, p_sim: BattleSim, p_names: Dictionary, p_sprites: Dictionary, p_title: String) -> void:
	gd = p_gd
	sim = p_sim
	names = p_names
	sprites = p_sprites
	title = p_title
	background.view = self
	collector_row.visible = sim.loot_robots > 0
	for i in sim.loot_robots:
		var slot := Label.new()
		slot.text = "▣ %d" % (i + 1)
		slot.add_theme_color_override("font_color", Color("ffe0a0"))
		slot.custom_minimum_size.x = 38
		collector_row.add_child(slot)
	for u in sim.units:
		enemy_group_count = maxi(enemy_group_count, u.enemy_wave + 1)
		var v: UnitView = UNIT_VIEW.instantiate()
		field.add_child(v)
		v.setup(u, str(names.get(u.id, "?")), str(sprites.get(u.id, "")))
		v.clicked.connect(_on_unit_clicked)
		views[u.id] = v
		if u.side == BattleRules.SIDE_A:
			var chip: HeroChip = HERO_CHIP.instantiate()
			hero_bar.add_child(chip)
			chip.setup(u, str(names.get(u.id, "?")), str(sprites.get(u.id, "")))
			chip.chosen.connect(_on_unit_clicked)
			chips[u.id] = chip
	end_button.pressed.connect(_end_turn_pressed)
	auto_button.pressed.connect(_toggle_auto)
	flee_button.pressed.connect(_flee)
	cancel_button.pressed.connect(_cancel)
	resized.connect(_layout)
	_layout()
	_log_add("Бой начался: %s" % title)
	if settings != null and settings.auto_start:
		_enable_auto()
	_begin_phase()


func cell_center(side: int, slot: int) -> Vector2:
	var row := slot / BattleRules.GRID_COLS
	var col := slot % BattleRules.GRID_COLS
	var area := maxf(size.y - top_margin - bottom_margin, 240.0)
	var step := minf(row_step_max, area / 3.0)
	var y := top_margin + step * (row + 0.5) + 24.0
	var mid := size.x * 0.5
	var x := mid - front_gap - col * col_step if side == BattleRules.SIDE_A else mid + front_gap + col * col_step
	return Vector2(x, y)


func _layout() -> void:
	if sim == null:
		return
	for u in sim.units:
		var v: UnitView = views[u.id]
		v.position = cell_center(u.side, u.slot) - UnitView.FEET
		if sim.corpses.has(u.id) and u.enemy_wave < sim.enemy_wave:
			v.position += Vector2(-32 * (sim.enemy_wave - u.enemy_wave), 25)
			v.z_index = 1
	background.queue_redraw()
	if popup.visible and selected >= 0:
		_place_popup()


# ---------- ход игрока ----------

func _begin_phase() -> void:
	if sim.winner != BattleSim.Winner.NONE:
		_end_battle()
		return
	if sim.current_side == BattleRules.SIDE_B:
		_enemy_turn()
		return
	_show_banner("Ваш ход", Color("7fd1ff"))
	if auto and _auto_actor() >= 0:
		_auto_turn()
		return
	selected = -1
	_set_mode(Mode.IDLE)


func _set_mode(m: Mode) -> void:
	if mode == Mode.PICK_TARGET and m != Mode.PICK_TARGET:
		_mark_targets([])
		_clear_attack_preview()
	mode = m
	popup.visible = false
	cancel_button.visible = m == Mode.PICK_TARGET or m == Mode.PICK_CELL
	end_button.visible = m in [Mode.IDLE, Mode.PICK_ACTION, Mode.LOOT]
	end_button.text = "Завершить бой" if m == Mode.LOOT else "Закончить ход"
	flee_button.visible = m == Mode.IDLE or m == Mode.PICK_ACTION
	auto_button.visible = m != Mode.OVER
	auto_button.text = "Поиск всех" if m == Mode.LOOT else ("Стоп" if auto else "Авто")
	if m != Mode.LOOT and not auto and pve != null and not settings.auto_mercs_only:
		auto_button.text = "Авто · %d" % pve.auto_points
	auto_button.disabled = m == Mode.LOOT and not sim.any_searcher()
	match m:
		Mode.IDLE:
			hint_label.text = "Коснитесь готового бойца (ходили %d из %d)" % [sim.acted_count, sim.active_count]
		Mode.PICK_ACTION:
			hint_label.text = "Выберите действие"
			_open_popup()
		Mode.PICK_TARGET:
			hint_label.text = "Выберите цель"
		Mode.PICK_CELL:
			hint_label.text = "Выберите клетку"
		Mode.BUSY:
			hint_label.text = "Автобой" if auto else "Ход идёт..."
		Mode.LOOT:
			hint_label.text = "Победа. Соберите трофеи или завершите бой."
		Mode.OVER:
			hint_label.text = ""
	_refresh_all()


func _on_unit_clicked(id: int) -> void:
	var u := sim.unit_by_id(id)
	if mode == Mode.PICK_TARGET:
		if views[id].targetable:
			if pending.get("type") == "attack" and id != preview_target:
				_preview_attack(id)
				return
			var a := pending.duplicate()
			a["target"] = id
			_perform(a)
		else:
			_toast_at(id, "Нельзя")
		return
	if mode != Mode.IDLE and mode != Mode.PICK_ACTION:
		return
	if u.side != BattleRules.SIDE_A:
		return
	var why := sim.can_act(id)
	if why != "":
		_toast_at(id, _reason(why))
		return
	selected = id
	_set_mode(Mode.PICK_ACTION)


func _reason(code: String) -> String:
	match code:
		"already_acted": return "Уже ходил"
		"not_active": return "Не готов (мало ОД)"
		"no_ap": return "Мало ОД"
		"no_mp": return "Мало МП"
		"already_moved": return "Уже менял позицию"
		"on_cooldown": return "Перезарядка"
		"unreachable": return "Недоступно"
		"bad_target": return "Нет цели"
		_: return code


# ---------- меню действий ----------

func _open_popup() -> void:
	for c in action_list.get_children():
		c.queue_free()
		action_list.remove_child(c)
	var u := sim.unit_by_id(selected)
	if u == null:
		popup.visible = false
		return
	popup_title.text = "%s: ОД %d, МП %d" % [str(names.get(u.id, "?")), u.ap, u.mp]
	var atk: ActionButton = _action_entry(Art.icon("sword"), "Атака", "Обычный удар по доступной цели", "%d ОД" % sim.rules.attack_cost,
		sim.can_afford(selected) == "" and not sim.legal_targets(selected).is_empty())
	atk.pressed.connect(_choose_attack)
	for sid in u.skill_ids:
		var sk: SkillDef = sim.skills[sid]
		var why := sim.can_afford(selected, sid)
		var usable := why == ""
		if usable and sim.skill_needs_target(sid) and sim.legal_targets(selected, sid).is_empty():
			usable = false
		var cost := "%d ОД" % sk.cost_ap
		if sk.cost_mp > 0:
			cost += " %d МП" % sk.cost_mp
		if why == "on_cooldown":
			cost = "пер. %d" % int(u.cooldowns.get(sid, 0))
		var b: ActionButton = _action_entry(Art.icon(_skill_icon(sk)), sk.name, _skill_detail(sk, int(u.skill_levels.get(sid, 1))), cost, usable)
		b.pressed.connect(_choose_skill.bind(sid))
	if sim.can_search(selected):
		var trophies := _action_entry(Art.icon("backpack"), "Трофеи", "Обыскать поверженных врагов", "%d ОД" % sim.loot_rules["search_cost"], true)
		trophies.pressed.connect(_open_trophy_menu)
	var mv: ActionButton = _action_entry(Art.icon("arrow"), "Сместиться", "Поменять позицию в формации", "%d ОД" % sim.rules.move_cost, not u.moved and u.ap >= sim.rules.ap_act_threshold)
	mv.pressed.connect(_choose_move)
	if not sim.reserve_targets(selected).is_empty():
		var swaps_left := sim.rules.reserve_swap_limit - sim.reserve_swaps
		var reserve: ActionButton = _action_entry(Art.icon("arrow"), "Замена из резерва", "Осталось замен: %d" % swaps_left,
			"%d ОД" % sim.rules.move_cost, true)
		reserve.pressed.connect(_open_reserve_picker)
	var gd_btn: ActionButton = _action_entry(Art.icon("shield"), "Защита", "+%d%% к защите до вашего следующего хода" % sim.rules.guard_def_pct, "%d ОД" % sim.rules.guard_cost, true)
	gd_btn.pressed.connect(func(): _perform({"type": "guard", "actor": selected}))
	var wt: ActionButton = _action_entry(Art.icon("backpack"), "Ждать", "Пропустить действие бойца", "0", true)
	wt.pressed.connect(func(): _perform({"type": "wait", "actor": selected}))
	popup.visible = true
	popup.reset_size()
	await get_tree().process_frame
	action_scroll.scroll_vertical = 0
	_place_popup()


func _open_trophy_menu() -> void:
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	popup_title.text = "Сбор трофеев"
	var one := _action_entry(Art.icon("backpack"), "Обыскать тело", "Выбрать трофей на поле", "", true)
	one.pressed.connect(func():
		pending = {"type": "search", "actor": selected}
		_set_mode(Mode.PICK_TARGET)
		hint_label.text = "Выберите тело для обыска"
		_mark_targets(sim.searchable_corpses()))
	var all := _action_entry(Art.icon("backpack"), "Поиск всех", "Готовые бойцы обыщут по одному телу", "", true)
	all.pressed.connect(_search_all)
	_action_entry(Art.icon("arrow"), "Назад", "", "", true).pressed.connect(_open_popup)
	popup.reset_size()
	await get_tree().process_frame
	action_scroll.scroll_vertical = 0
	_place_popup()


func _search_all() -> void:
	var after_victory := sim.winner == BattleSim.Winner.SIDE_A
	_set_mode(Mode.BUSY)
	await _play_events(sim.search_all())
	if after_victory:
		_set_mode(Mode.LOOT)
	else:
		_begin_phase()


func _open_reserve_picker() -> void:
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	popup_title.text = "Кого вывести из резерва?"
	for id in sim.reserve_targets(selected):
		var unit := sim.unit_by_id(id)
		var button := _action_entry(Art.icon("arrow"), _name(id), "Комната %d · здоровье %d/%d" % [unit.reserve_room + 1, unit.hp, unit.max_hp], "", true)
		button.pressed.connect(func(): _perform({"type": "swap_reserve", "actor": selected, "target": id}))
	var back := _action_entry(Art.icon("arrow"), "Назад", "", "", true)
	back.pressed.connect(_open_popup)
	popup.reset_size()
	await get_tree().process_frame
	action_scroll.scroll_vertical = 0
	_place_popup()


func _action_entry(icon: Texture2D, t: String, detail: String, cost: String, enabled: bool) -> ActionButton:
	var b: ActionButton = ACTION_BUTTON.instantiate()
	action_list.add_child(b)
	b.setup(icon, t, detail, cost, enabled)
	return b


func _place_popup() -> void:
	action_scroll.custom_minimum_size.y = minf(action_list.get_combined_minimum_size().y, maxf(84.0, size.y - 226.0))
	popup.reset_size()
	var chip: Control = chips.get(selected)
	var bar_top := size.y - 158.0
	var x := 12.0
	if chip != null:
		x = chip.global_position.x - global_position.x
	x = clampf(x, 8.0, maxf(8.0, size.x - popup.size.x - 8.0))
	popup.position = Vector2(x, maxf(8.0, bar_top - popup.size.y - 8.0))


func _skill_icon(sk: SkillDef) -> String:
	match sk.effect:
		SkillDef.Effect.HEAL, SkillDef.Effect.REVIVE:
			return "potion_red"
		SkillDef.Effect.MODIFY:
			if sk.mod_stat == "def":
				return "shield" if sk.mod_value > 0 else "axe"
			return "sword2" if sk.mod_value > 0 else "potion_blue"
		_:
			if sk.target in [SkillDef.Target.ENEMY_ALL, SkillDef.Target.ENEMY_COLUMN]:
				return "bomb"
			return "bow" if sk.ranged else "sword"


func _skill_detail(sk: SkillDef, level: int) -> String:
	var tg: String = {
		SkillDef.Target.ENEMY_ONE: "один враг", SkillDef.Target.ENEMY_COLUMN: "колонка врагов", SkillDef.Target.ENEMY_ALL: "все враги",
		SkillDef.Target.ALLY_ONE: "союзник", SkillDef.Target.ALLY_ALL: "весь отряд", SkillDef.Target.SELF: "на себя",
	}.get(sk.target, "")
	var power := sk.power_pct * (100 + (level - 1) * sim.rules.skill_power_per_level_pct) / 100
	match sk.effect:
		SkillDef.Effect.DAMAGE:
			var detail := "Урон %d%%, %s" % [power, tg]
			if sk.combo_from != "":
				detail += "\nПосле «%s»: +%d%%" % [sim.skills[sk.combo_from].name, sk.combo_bonus_pct]
			return detail
		SkillDef.Effect.REVIVE:
			return "Вернуть наёмника с %d%% здоровья" % mini(100, power)
		SkillDef.Effect.HEAL:
			return "Лечение %d%%, %s" % [power, tg]
		_:
			var stat: String = {"atk": "атаки", "def": "защиты", "ap_regen": "ОД"}.get(sk.mod_stat, sk.mod_stat)
			return "%+d%% %s, %d хода, %s" % [sk.mod_value, stat, sk.mod_turns, tg]


func _cancel() -> void:
	pending = {}
	cells_highlight = []
	background.queue_redraw()
	_mark_targets([])
	if mode == Mode.PICK_TARGET or mode == Mode.PICK_CELL:
		_set_mode(Mode.PICK_ACTION)
	elif mode == Mode.PICK_ACTION:
		selected = -1
		_set_mode(Mode.IDLE)


func _choose_attack() -> void:
	var t := sim.legal_targets(selected)
	if t.is_empty():
		return
	pending = {"type": "attack", "actor": selected}
	_set_mode(Mode.PICK_TARGET)
	hint_label.text = "Коснитесь цели, чтобы увидеть зону удара"
	_mark_targets(t)


func _preview_attack(id: int) -> void:
	preview_target = id
	var hits := sim.hit_set(selected, id)
	for unit_id in views:
		views[unit_id].set_in_attack_area(hits.has(unit_id))
	hint_label.text = "Коснитесь цели ещё раз для удара"


func _clear_attack_preview() -> void:
	preview_target = -1
	for v: UnitView in views.values():
		v.set_in_attack_area(false)


func _choose_skill(sid: String) -> void:
	if not sim.skill_needs_target(sid):
		_perform({"type": "skill", "actor": selected, "skill": sid})
		return
	var t := sim.legal_targets(selected, sid)
	if t.is_empty():
		return
	pending = {"type": "skill", "actor": selected, "skill": sid}
	_set_mode(Mode.PICK_TARGET)
	if (sim.skills[sid] as SkillDef).effect == SkillDef.Effect.REVIVE:
		hint_label.text = "Выберите павшего наёмника"
	_mark_targets(t)


func _choose_move() -> void:
	cells_highlight = []
	for s in BattleRules.SLOTS_PER_SIDE:
		if s != sim.unit_by_id(selected).slot:
			cells_highlight.append(s)
	_set_mode(Mode.PICK_CELL)
	background.queue_redraw()


func _mark_targets(ids: Array[int]) -> void:
	for id in views:
		views[id].set_targetable(ids.has(id))
	_refresh_all()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.PICK_CELL:
			for slot in cells_highlight:
				if event.position.distance_to(cell_center(BattleRules.SIDE_A, slot)) < 60.0:
					_perform({"type": "move", "actor": selected, "slot": slot})
					return
			_cancel()
		elif mode == Mode.PICK_TARGET or mode == Mode.PICK_ACTION:
			_cancel()


func _end_turn_pressed() -> void:
	if mode == Mode.LOOT:
		_finish_battle()
		return
	_set_mode(Mode.BUSY)
	var r := sim.end_turn()
	await _play_events(r.events)
	_begin_phase()


func _toggle_auto() -> void:
	if mode == Mode.LOOT:
		_search_all()
		return
	if auto:
		auto = false
		_log_add("Автобой выключен")
		if mode == Mode.BUSY:
			auto_button.text = "Авто"
		else:
			_set_mode(Mode.IDLE)
		return
	if mode not in [Mode.IDLE, Mode.PICK_ACTION]:
		return
	if _auto_actor() < 0:
		_log_add("Нет готовых бойцов с включённым автобоем")
		return
	if _enable_auto():
		_auto_turn()


func _enable_auto() -> bool:
	if pve != null and not settings.auto_mercs_only and not pve.enable_full_auto(settings.auto_license):
		_log_add("Нет лицензии или очков автобоя. Настройки позволяют включить авто только для наёмников.")
		return false
	auto = true
	return true


func _auto_actor() -> int:
	for unit in sim.alive_units(BattleRules.SIDE_A):
		var uid := unit.id - 1
		if settings != null and (settings.auto_disabled_units.has(uid) or (settings.auto_mercs_only and unit.is_hero)):
			continue
		if sim.can_act(unit.id) == "":
			return unit.id
	return -1


func _flee() -> void:
	_result = "flee"
	_set_mode(Mode.OVER)
	finished.emit("flee")


func _perform(action: Dictionary) -> void:
	_set_mode(Mode.BUSY)
	_mark_targets([])
	cells_highlight = []
	background.queue_redraw()
	var r := sim.submit(action)
	if not r.ok:
		_log_add("Нельзя: %s" % _reason(str(r.error)))
		selected = -1
		_set_mode(Mode.IDLE)
		return
	selected = -1
	await _play_events(r.events)
	_begin_phase()


# ---------- ход врага и автобой ----------

func _enemy_turn() -> void:
	_set_mode(Mode.BUSY)
	_show_banner("Ход врага", Color("ff7b6b"))
	await _wait(0.7)
	await _run_ai_side(BattleRules.SIDE_B)
	_begin_phase()


func _auto_turn() -> void:
	_set_mode(Mode.BUSY)
	await _wait(0.4)
	await _run_ai_side(BattleRules.SIDE_A)
	_begin_phase()


func _run_ai_side(side: int) -> void:
	var guard := 0
	while sim.winner == BattleSim.Winner.NONE and sim.current_side == side and guard < 30:
		guard += 1
		if side == BattleRules.SIDE_A and not auto:
			return
		var actor_id := -1
		if side == BattleRules.SIDE_A:
			actor_id = _auto_actor()
		else:
			for u in sim.alive_units(side):
				if sim.can_act(u.id) == "":
					actor_id = u.id
					break
		if actor_id < 0:
			if side == BattleRules.SIDE_A and sim.active_ids.any(func(id): return sim.can_act(id) == ""):
				return
			var r := sim.end_turn()
			await _play_events(r.events)
			return
		var permit_skills := true
		var blocked: Array = []
		if side == BattleRules.SIDE_A and settings != null:
			permit_skills = settings.auto_skills
			blocked = settings.auto_blocked_skills.get(actor_id - 1, [])
		if side == BattleRules.SIDE_A and pve != null:
			pve.any_auto_used = true
		var action := BattleAI.choose(sim, actor_id, permit_skills, blocked)
		if side == BattleRules.SIDE_A and sim.can_search(actor_id):
			action = {"type": "search", "actor": actor_id, "target": sim.searchable_corpses()[0]}
		var res := sim.submit(action)
		if not res.ok:
			res = sim.submit({"type": "wait", "actor": actor_id})
		await _play_events(res.events)
		await _wait(0.25)


# ---------- проигрывание событий ----------

func _play_events(events: Array) -> void:
	for e in events:
		var ev: Dictionary = e
		match str(ev["type"]):
			"attack":
				await _anim_attack(int(ev["actor"]), int(ev["target"]), int(ev["damage"]),
					bool(ev["crit"]), bool(ev["killed"]), bool(ev.get("primary", true)), bool(ev.get("missed", false)))
			"skill":
				var sk: SkillDef = sim.skills[str(ev["skill"])]
				_log_add("%s: %s" % [_name(int(ev["actor"])), sk.name])
				_float_text(int(ev["actor"]), sk.name, Color("ffe066"), -64.0)
				await _lunge(int(ev["actor"]), (ev["targets"] as Array)[0] if not (ev["targets"] as Array).is_empty() else -1)
			"damage":
				var target := int(ev["target"])
				if ev.get("combo", false):
					_float_text(target, "Комбо", Color("ffe066"), -64.0)
					_log_add("Комбо по цели «%s»" % _name(target))
				if ev.get("missed", false):
					_show_miss(target)
				else:
					await _hit(target, int(ev["damage"]), bool(ev["crit"]), bool(ev["killed"]))
			"reinforcements":
				_log_add("Подошла группа врагов %d" % (int(ev["wave"]) + 1))
				_show_banner("Подкрепление", Color("ff9b7d"))
				_layout()
				_refresh_all()
			"trophy_collected":
				var label := "Сборщик %d" % (int(ev["robot"]) + 1) if int(ev["robot"]) >= 0 else "Отряд"
				_log_add("%s: %s" % [label, "счастливая добыча" if ev["lucky"] else "трофей собран"])
				_refresh_all()
			"trophy_expired":
				_refresh_all()
			"reserve_swapped":
				_layout()
				_refresh_all()
				_log_add("%s выходит вместо %s" % [_name(int(ev["incoming"])), _name(int(ev["outgoing"]))])
			"revive":
				var target := int(ev["target"])
				_refresh_all()
				_float_text(target, "+%d" % int(ev["hp"]), Color("5df08a"), -40.0)
				_log_add("%s возвращается в бой" % _name(target))
				await _wait(0.45)
			"heal":
				_float_text(int(ev["target"]), "+%d" % int(ev["amount"]), Color("5df08a"), -40.0)
				_log_add("%s лечит %s на %d" % [_name(int(ev["source"])), _name(int(ev["target"])), int(ev["amount"])])
				_refresh_all()
				await _wait(0.45)
			"modify":
				var v := int(ev["value"])
				var stat_name: String = {"atk": "Атака", "def": "Защита", "ap_regen": "ОД"}.get(str(ev["stat"]), str(ev["stat"]))
				_float_text(int(ev["target"]), "%s %+d%%" % [stat_name, v], Color("7fd1ff") if v > 0 else Color("ff9f6b"), -40.0)
				_refresh_all()
				await _wait(0.3)
			"move":
				var uv: UnitView = views[int(ev["actor"])]
				var u := sim.unit_by_id(int(ev["actor"]))
				_log_add("%s меняет позицию" % _name(u.id))
				var tw := create_tween().set_parallel(true)
				tw.tween_property(uv, "position", cell_center(u.side, int(ev["to"])) - UnitView.FEET, 0.25 / speed)
				if int(ev["swapped"]) >= 0:
					var ov: UnitView = views[int(ev["swapped"])]
					tw.tween_property(ov, "position", cell_center(u.side, int(ev["from"])) - UnitView.FEET, 0.25 / speed)
				await tw.finished
			"guard":
				_log_add("%s в защите" % _name(int(ev["actor"])))
				_float_text(int(ev["actor"]), "Защита", Color("7fd1ff"), -40.0)
				_refresh_all()
				await _wait(0.3)
			"stunned":
				_log_add("%s оглушён" % _name(int(ev["unit"])))
				_float_text(int(ev["unit"]), "Оглушён!", Color("ffd24a"), -64.0)
				_refresh_all()
				await _wait(0.45)
			"stun_ended", "turn_skipped":
				_refresh_all()
			"wait":
				_log_add("%s ждёт" % _name(int(ev["actor"])))
				_refresh_all()
			"turn_started", "modifiers_expired":
				_refresh_all()
	_refresh_all()


func _anim_attack(actor: int, target: int, dmg: int, crit: bool, killed: bool, primary: bool, missed: bool) -> void:
	if primary:
		await _lunge(actor, target)
	if missed:
		_show_miss(target)
		return
	_log_add("%s бьёт %s: -%d%s" % [_name(actor), _name(target), dmg, " (крит!)" if crit else ""])
	await _hit(target, dmg, crit, killed)


func _show_miss(target: int) -> void:
	_float_text(target, "Промах", Color("a8ccff"), -40.0)
	_log_add("%s избегает удара" % _name(target))


func _lunge(actor: int, target: int) -> void:
	var v: UnitView = views[actor]
	if target < 0 or not views.has(target):
		await _wait(0.2)
		return
	var from := v.position
	var to: Vector2 = (views[target] as UnitView).position
	var dir := (to - from).normalized()
	v.z_index = 5
	var tw := create_tween()
	tw.tween_property(v, "position", from + dir * 44.0, 0.12 / speed)
	await tw.finished
	await _wait(0.04)
	var tw2 := create_tween()
	tw2.tween_property(v, "position", from, 0.14 / speed)
	v.z_index = 0


func _hit(target: int, dmg: int, crit: bool, killed: bool) -> void:
	var v: UnitView = views[target]
	_float_text(target, ("-%d!" if crit else "-%d") % dmg, Color("ffd24d") if crit else Color("ff6b5b"), -30.0, 34 if crit else 28)
	v.sprite.modulate = Color(1, 0.45, 0.45)
	var base := v.position
	var tw := create_tween()
	tw.tween_property(v, "position", base + Vector2(8, 0), 0.04)
	tw.tween_property(v, "position", base - Vector2(8, 0), 0.06)
	tw.tween_property(v, "position", base, 0.04)
	await tw.finished
	_refresh_all()
	if killed:
		_log_add("%s повержен" % _name(target))
	await _wait(0.2)


func _float_text(unit_id: int, text: String, color: Color, y_off: float, font_size := 26) -> void:
	var v: UnitView = views[unit_id]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(180, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = v.position + Vector2(UnitView.SIZE.x * 0.5 - 90.0, y_off + 10.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 20
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _toast_at(unit_id: int, text: String) -> void:
	_float_text(unit_id, text, Color.WHITE, -30.0, 20)


func _show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / speed).timeout


func _name(id: int) -> String:
	return str(names.get(id, "?"))


func _log_add(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 7:
		_log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(_log_lines)


func _refresh_all() -> void:
	for u in sim.units:
		var v: UnitView = views[u.id]
		v.visible = u.reserve_room < 0 and u.enemy_wave <= sim.enemy_wave and (u.side == BattleRules.SIDE_A or u.is_alive() or sim.corpses.has(u.id) or sim.loot_rules.is_empty())
		v.refresh(u)
		if mode == Mode.PICK_TARGET and pending.get("type") == "search" and not v.targetable:
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sim.corpses.has(u.id):
			v.ap_label.text = "Счастливая добыча" if sim.corpses[u.id]["lucky"] else "Трофей"
			v.modulate.a = 0.75 if not v.targetable else 1.0
		v.set_selected(u.id == selected)
		if chips.has(u.id):
			chips[u.id].visible = v.visible
			var can := (mode == Mode.IDLE or mode == Mode.PICK_ACTION) and sim.can_act(u.id) == ""
			(chips[u.id] as HeroChip).refresh(u, can, u.id == selected)
	var side_text := "Ваш ход" if sim.current_side == BattleRules.SIDE_A else "Ход врага"
	var encounter_title := title
	if enemy_group_count > 1:
		encounter_title += " · группа %d/%d" % [sim.enemy_wave + 1, enemy_group_count]
	title_label.text = "%s   |   Раунд %d   |   %s (ходят %d из %d)" % [encounter_title, sim.round_number, side_text, sim.acted_count, sim.active_count]


func _end_battle() -> void:
	if mode in [Mode.LOOT, Mode.OVER]:
		return
	var win := sim.winner == BattleSim.Winner.SIDE_A
	_result = "win" if win else ("draw" if sim.winner == BattleSim.Winner.DRAW else "lose")
	_show_banner("ПОБЕДА!" if win else ("Ничья" if _result == "draw" else "Поражение"), Color("7dff9b") if win else Color("ff6b6b"))
	if win and sim.any_searcher():
		if not auto:
			_set_mode(Mode.LOOT)
			return
		await _play_events(sim.search_all())
	await _finish_battle()


func _finish_battle() -> void:
	_set_mode(Mode.OVER)
	await get_tree().create_timer(1.4).timeout
	finished.emit(_result)
