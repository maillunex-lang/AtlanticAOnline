class_name BattleView
extends Control
## Экран боя: формации 3x3 друг против друга, выбор бойца, действия, цели, анимации, ход врага, автобой.
## Вся логика в BattleSim, здесь только отображение и ввод. Слева игрок, справа враг, передняя линия в центре.

signal finished(result: String)

enum Mode { IDLE, PICK_ACTION, PICK_TARGET, PICK_CELL, BUSY, OVER }

const SCREEN := Vector2(1280, 720)
const BASE_Y := 175.0
const ROW_STEP := 122.0
const COL_STEP := 132.0
const PLAYER_FRONT_X := 500.0
const ENEMY_FRONT_X := 780.0

var sim: BattleSim
var gd: GameData
var names: Dictionary = {}
var kinds: Dictionary = {}
var views: Dictionary = {}
var mode := Mode.BUSY
var selected := -1
var pending: Dictionary = {}
var auto := false
var speed := 1.0
var title := ""

var _top: Label
var _log: Label
var _bar: HBoxContainer
var _banner: Label
var _log_lines: Array[String] = []
var _cells_highlight: Array[int] = []
var _result := ""


func setup(p_gd: GameData, p_sim: BattleSim, p_names: Dictionary, p_kinds: Dictionary, p_title: String) -> void:
	gd = p_gd
	sim = p_sim
	names = p_names
	kinds = p_kinds
	title = p_title
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for u in sim.units:
		var v := UnitView.new()
		v.setup(u, str(names.get(u.id, "?")), str(kinds.get(u.id, "")))
		v.position = cell_center(u.side, u.slot) - UnitView.SIZE * 0.5
		v.clicked.connect(_on_unit_clicked)
		add_child(v)
		views[u.id] = v
	_build_ui()
	_refresh_all()
	_log_add("Бой начался: %s" % title)
	_begin_phase()


static func cell_center(side: int, slot: int) -> Vector2:
	var row := slot / BattleRules.GRID_COLS
	var col := slot % BattleRules.GRID_COLS
	var x := PLAYER_FRONT_X - col * COL_STEP if side == BattleRules.SIDE_A else ENEMY_FRONT_X + col * COL_STEP
	return Vector2(x, BASE_Y + row * ROW_STEP + 40)


func _build_ui() -> void:
	_top = Label.new()
	_top.position = Vector2(0, 12)
	_top.size = Vector2(SCREEN.x, 40)
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_theme_font_size_override("font_size", 26)
	add_child(_top)
	_log = Label.new()
	_log.position = Vector2(20, 66)
	_log.size = Vector2(300, 140)
	_log.add_theme_font_size_override("font_size", 15)
	_log.modulate = Color(1, 1, 1, 0.8)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_log)
	var panel := PanelContainer.new()
	panel.position = Vector2(0, 596)
	panel.size = Vector2(SCREEN.x, 124)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.92)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	scroll.add_child(_bar)
	_banner = Label.new()
	_banner.position = Vector2(0, 270)
	_banner.size = Vector2(SCREEN.x, 80)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 54)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("18222e"))
	draw_rect(Rect2(0, 430, SCREEN.x, 170), Color("1f2d3b"))
	draw_rect(Rect2(0, 410, SCREEN.x, 6), Color("2c3e50"))
	for side in [BattleRules.SIDE_A, BattleRules.SIDE_B]:
		for slot in BattleRules.SLOTS_PER_SIDE:
			var c := cell_center(side, slot)
			var col := Color(1, 1, 1, 0.06)
			if side == BattleRules.SIDE_A and _cells_highlight.has(slot):
				col = Color(0.4, 0.8, 1.0, 0.35)
			draw_set_transform(Vector2(c.x, c.y + 20), 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, 54, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(SCREEN.x * 0.5, 90), Vector2(SCREEN.x * 0.5, 560), Color(1, 1, 1, 0.08), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(110, 580), "ПЕРЕДНЯЯ ЛИНИЯ ->", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.25))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.PICK_CELL:
			for slot in _cells_highlight:
				if event.position.distance_to(cell_center(BattleRules.SIDE_A, slot) + Vector2(0, 30)) < 56.0:
					_perform({"type": "move", "actor": selected, "slot": slot})
					return
			_cancel()
		elif mode == Mode.PICK_TARGET or mode == Mode.PICK_ACTION:
			_cancel()


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
	_set_mode(Mode.IDLE)


func _set_mode(m: Mode) -> void:
	mode = m
	_rebuild_bar()
	_refresh_all()


func _on_unit_clicked(id: int) -> void:
	var u := sim.unit_by_id(id)
	if mode == Mode.PICK_TARGET:
		if views[id].targetable:
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
		"active_limit": return "Лимит ходящих"
		"no_ap": return "Мало ОД"
		"on_cooldown": return "Перезарядка"
		"unreachable": return "Недоступно"
		"bad_target": return "Нет цели"
		_: return code


func _rebuild_bar() -> void:
	for c in _bar.get_children():
		c.queue_free()
	if mode == Mode.OVER:
		return
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(14, 1)
	_bar.add_child(pad)
	if mode == Mode.PICK_ACTION and selected >= 0:
		var u := sim.unit_by_id(selected)
		_btn("Атака  -%d ОД" % sim.rules.attack_cost, func(): _choose_attack(), sim.can_afford(selected) == "" and not sim.legal_targets(selected).is_empty())
		for sid in u.skill_ids:
			var sk: SkillDef = sim.skills[sid]
			var ok := sim.can_afford(selected, sid)
			var label := "%s  -%d" % [sk.name, sk.cost_ap]
			if ok == "on_cooldown":
				label = "%s (пер. %d)" % [sk.name, int(u.cooldowns.get(sid, 0))]
			var usable := ok == ""
			if usable and sim.skill_needs_target(sid) and sim.legal_targets(selected, sid).is_empty():
				usable = false
			_btn(label, func(): _choose_skill(sid), usable)
		_btn("Сместиться  -%d" % sim.rules.move_cost, func(): _choose_move(), u.ap >= sim.rules.move_cost)
		_btn("Ждать", func(): _perform({"type": "wait", "actor": selected}), true)
		_btn("Отмена", func(): _cancel(), true)
	elif mode == Mode.PICK_TARGET or mode == Mode.PICK_CELL:
		var hint := Label.new()
		hint.text = "Выберите цель" if mode == Mode.PICK_TARGET else "Выберите клетку"
		hint.add_theme_font_size_override("font_size", 26)
		_bar.add_child(hint)
		_btn("Отмена", func(): _cancel(), true)
	elif mode == Mode.IDLE:
		var hint2 := Label.new()
		hint2.text = "Коснитесь своего бойца   (ходят: %d из %d)" % [sim.acted_count, sim.active_count]
		hint2.add_theme_font_size_override("font_size", 24)
		_bar.add_child(hint2)
		_btn("Закончить ход", func(): _end_turn_pressed(), true)
		_btn("Авто", func(): _toggle_auto(), true)
		_btn("Бежать", func(): _flee(), true)
	else:
		var wait := Label.new()
		wait.text = "..." if not auto else "Автобой"
		wait.add_theme_font_size_override("font_size", 26)
		_bar.add_child(wait)
		if auto:
			_btn("Стоп", func(): _toggle_auto(), true)


func _btn(text: String, cb: Callable, enabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 76)
	b.add_theme_font_size_override("font_size", 21)
	b.disabled = not enabled
	b.pressed.connect(cb)
	_bar.add_child(b)


func _cancel() -> void:
	pending = {}
	_cells_highlight = []
	if mode == Mode.PICK_TARGET or mode == Mode.PICK_CELL:
		_set_mode(Mode.PICK_ACTION)
	elif mode == Mode.PICK_ACTION:
		selected = -1
		_set_mode(Mode.IDLE)
	queue_redraw()


func _choose_attack() -> void:
	var t := sim.legal_targets(selected)
	if t.is_empty():
		return
	pending = {"type": "attack", "actor": selected}
	_set_mode(Mode.PICK_TARGET)
	_mark_targets(t)


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
	_cells_highlight = []
	for s in BattleRules.SLOTS_PER_SIDE:
		if s != sim.unit_by_id(selected).slot:
			_cells_highlight.append(s)
	_set_mode(Mode.PICK_CELL)
	queue_redraw()


func _mark_targets(ids: Array[int]) -> void:
	for id in views:
		views[id].set_targetable(ids.has(id))


func _end_turn_pressed() -> void:
	_set_mode(Mode.BUSY)
	var r := sim.end_turn()
	await _play_events(r.events)
	_begin_phase()


func _toggle_auto() -> void:
	auto = not auto
	if auto and mode == Mode.IDLE:
		_set_mode(Mode.BUSY)
		_auto_turn()
	elif not auto:
		_log_add("Автобой выключен")
		if mode != Mode.BUSY:
			_set_mode(Mode.IDLE)


func _flee() -> void:
	_result = "flee"
	_set_mode(Mode.OVER)
	finished.emit("flee")


func _perform(action: Dictionary) -> void:
	_set_mode(Mode.BUSY)
	_mark_targets([])
	_cells_highlight = []
	queue_redraw()
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


## Все действующие бойцы стороны ходят по подсказке ИИ, затем ход закрывается.
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
				await _anim_attack(int(ev["actor"]), int(ev["target"]), int(ev["damage"]), bool(ev["crit"]), bool(ev["killed"]))
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
				tw.tween_property(uv, "position", cell_center(u.side, int(ev["to"])) - UnitView.SIZE * 0.5, 0.25 / speed)
				if int(ev["swapped"]) >= 0:
					var ov: UnitView = views[int(ev["swapped"])]
					tw.tween_property(ov, "position", cell_center(u.side, int(ev["from"])) - UnitView.SIZE * 0.5, 0.25 / speed)
				await tw.finished
			"wait":
				_log_add("%s ждёт" % _name(int(ev["actor"])))
				_refresh_all()
			"turn_started":
				_refresh_all()
			"modifiers_expired":
				_refresh_all()
	_refresh_all()


func _anim_attack(actor: int, target: int, dmg: int, crit: bool, killed: bool) -> void:
	_log_add("%s бьёт %s: -%d%s" % [_name(actor), _name(target), dmg, " (крит!)" if crit else ""])
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
	v.modulate = Color(1, 0.45, 0.45)
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
	l.size = Vector2(160, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = v.position + Vector2(UnitView.SIZE.x * 0.5 - 80.0, y_off + 10.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 20
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _toast_at(unit_id: int, text: String) -> void:
	_float_text(unit_id, text, Color("ffffff"), -30.0, 20)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / speed).timeout


func _name(id: int) -> String:
	return str(names.get(id, "?"))


func _log_add(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 7:
		_log_lines.pop_front()
	if _log != null:
		_log.text = "\n".join(_log_lines)


func _refresh_all() -> void:
	for u in sim.units:
		var v: UnitView = views[u.id]
		v.refresh(u)
		v.modulate = Color(1, 1, 1, v.modulate.a)
		v.set_selected(u.id == selected)
	if _top != null:
		var side_text := "Ваш ход" if sim.current_side == BattleRules.SIDE_A else "Ход врага"
		_top.text = "%s    |    Раунд %d    |    %s (ходят %d из %d)" % [title, sim.round_number, side_text, sim.acted_count, sim.active_count]


func _end_battle() -> void:
	if mode == Mode.OVER:
		return
	_set_mode(Mode.OVER)
	var win := sim.winner == BattleSim.Winner.SIDE_A
	_result = "win" if win else ("draw" if sim.winner == BattleSim.Winner.DRAW else "lose")
	_show_banner("ПОБЕДА!" if win else ("Ничья" if _result == "draw" else "Поражение"), Color("7dff9b") if win else Color("ff6b6b"))
	await get_tree().create_timer(1.4).timeout
	finished.emit(_result)
