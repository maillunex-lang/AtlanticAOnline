class_name BattleView
extends Control
## Экран боя. Вид собран в сцене scenes/battle/battle_view.tscn (якоря, контейнеры), поэтому растягивается под любой экран.
## Внизу плитки бойцов, коснитесь плитки (или бойца на поле), чтобы открыть меню действий: атака, умения, смещение, ожидание.
## Вся логика боя в BattleSim, здесь только отображение и ввод.

signal finished(result: String)

enum Mode { IDLE, PICK_ACTION, PICK_TARGET, PICK_CELL, BUSY, OVER }

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
var speed := 1.0
var title := ""
var cells_highlight: Array[int] = []

var _log_lines: Array[String] = []
var _result := ""

@onready var background: BattleBackground = %Background
@onready var field: Control = %Field
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
@onready var action_list: VBoxContainer = %ActionList
@onready var banner: Label = %Banner


func setup(p_gd: GameData, p_sim: BattleSim, p_names: Dictionary, p_sprites: Dictionary, p_title: String) -> void:
	gd = p_gd
	sim = p_sim
	names = p_names
	sprites = p_sprites
	title = p_title
	background.view = self
	for u in sim.units:
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
	if auto:
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
	end_button.visible = m == Mode.IDLE or m == Mode.PICK_ACTION
	flee_button.visible = m == Mode.IDLE or m == Mode.PICK_ACTION
	auto_button.visible = m != Mode.OVER
	auto_button.text = "Стоп" if auto else "Авто"
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
	var mv: ActionButton = _action_entry(Art.icon("arrow"), "Сместиться", "Поменять позицию в формации", "%d ОД" % sim.rules.move_cost, not u.moved and u.ap >= sim.rules.ap_act_threshold)
	mv.pressed.connect(_choose_move)
	var gd_btn: ActionButton = _action_entry(Art.icon("shield"), "Защита", "+%d%% к защите до вашего следующего хода" % sim.rules.guard_def_pct, "%d ОД" % sim.rules.guard_cost, true)
	gd_btn.pressed.connect(func(): _perform({"type": "guard", "actor": selected}))
	var wt: ActionButton = _action_entry(Art.icon("backpack"), "Ждать", "Пропустить действие бойца", "0", true)
	wt.pressed.connect(func(): _perform({"type": "wait", "actor": selected}))
	popup.visible = true
	popup.reset_size()
	await get_tree().process_frame
	_place_popup()


func _action_entry(icon: Texture2D, t: String, detail: String, cost: String, enabled: bool) -> ActionButton:
	var b: ActionButton = ACTION_BUTTON.instantiate()
	action_list.add_child(b)
	b.setup(icon, t, detail, cost, enabled)
	return b


func _place_popup() -> void:
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
		SkillDef.Effect.HEAL:
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
			return "Урон %d%%, %s" % [power, tg]
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
	_set_mode(Mode.BUSY)
	var r := sim.end_turn()
	await _play_events(r.events)
	_begin_phase()


func _toggle_auto() -> void:
	auto = not auto
	if auto and (mode == Mode.IDLE or mode == Mode.PICK_ACTION):
		_set_mode(Mode.BUSY)
		_auto_turn()
	elif not auto:
		_log_add("Автобой выключен")
		auto_button.text = "Авто"
		if mode == Mode.BUSY and sim.current_side == BattleRules.SIDE_A:
			pass
		elif mode != Mode.BUSY:
			_set_mode(Mode.IDLE)


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
		for u in sim.units:
			if u.side == side and sim.can_act(u.id) == "":
				actor_id = u.id
				break
		if actor_id < 0:
			var r := sim.end_turn()
			await _play_events(r.events)
			return
		var action := BattleAI.choose(sim, actor_id)
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
					bool(ev["crit"]), bool(ev["killed"]), bool(ev.get("primary", true)))
			"skill":
				var sk: SkillDef = sim.skills[str(ev["skill"])]
				_log_add("%s: %s" % [_name(int(ev["actor"])), sk.name])
				_float_text(int(ev["actor"]), sk.name, Color("ffe066"), -64.0)
				await _lunge(int(ev["actor"]), (ev["targets"] as Array)[0] if not (ev["targets"] as Array).is_empty() else -1)
			"damage":
				await _hit(int(ev["target"]), int(ev["damage"]), bool(ev["crit"]), bool(ev["killed"]))
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


func _anim_attack(actor: int, target: int, dmg: int, crit: bool, killed: bool, primary: bool) -> void:
	_log_add("%s бьёт %s: -%d%s" % [_name(actor), _name(target), dmg, " (крит!)" if crit else ""])
	if primary:
		await _lunge(actor, target)
	await _hit(target, dmg, crit, killed)


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
		v.refresh(u)
		v.set_selected(u.id == selected)
		if chips.has(u.id):
			var can := (mode == Mode.IDLE or mode == Mode.PICK_ACTION) and sim.can_act(u.id) == ""
			(chips[u.id] as HeroChip).refresh(u, can, u.id == selected)
	var side_text := "Ваш ход" if sim.current_side == BattleRules.SIDE_A else "Ход врага"
	title_label.text = "%s   |   Раунд %d   |   %s (ходят %d из %d)" % [title, sim.round_number, side_text, sim.acted_count, sim.active_count]


func _end_battle() -> void:
	if mode == Mode.OVER:
		return
	_set_mode(Mode.OVER)
	var win := sim.winner == BattleSim.Winner.SIDE_A
	_result = "win" if win else ("draw" if sim.winner == BattleSim.Winner.DRAW else "lose")
	_show_banner("ПОБЕДА!" if win else ("Ничья" if _result == "draw" else "Поражение"), Color("7dff9b") if win else Color("ff6b6b"))
	await get_tree().create_timer(1.4).timeout
	finished.emit(_result)
