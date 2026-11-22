class_name MenuScreen
extends Control
## Главное меню на весь экран: Отряд (бойцы, снаряжение, формация), Сумка, Кузница (улучшение и крафт), Задания, Настройки.
## Всё состояние живёт в DemoMain, меню только показывает его и вызывает общую игровую логику.

signal closed

const TABS := [["squad", "Отряд"], ["bag", "Сумка"], ["forge", "Кузница"], ["quests", "Задания"], ["settings", "Настройки"]]
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Броня", "helm": "Шлем", "accessory": "Аксессуар"}
const STAT_NAMES := {"hp": "Здоровье", "atk": "Атака", "def": "Защита", "ap_regen": "ОД за ход"}

var main: DemoMain
var tab := "squad"
var sel_member := 0
var sel_slot := ""
var sel_item := -1
var sel_forge_item := -1
var message := ""

var _content: Control
var _tab_buttons: Dictionary = {}
var _coins: Label


func setup(p_main: DemoMain, start_tab: String) -> void:
	main = p_main
	tab = start_tab
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var win := PanelContainer.new()
	win.position = Vector2(40, 24)
	win.size = Vector2(1200, 672)
	win.add_theme_stylebox_override("panel", UiKit.window())
	add_child(win)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	win.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	for t in TABS:
		var b := UiKit.button(str(t[1]), Vector2(150, 62), 22)
		b.pressed.connect(_set_tab.bind(str(t[0])))
		head.add_child(b)
		_tab_buttons[t[0]] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_coins = UiKit.label("", 24, Color("ffe066"))
	_coins.custom_minimum_size = Vector2(190, 0)
	_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_coins)
	var close := UiKit.button("Закрыть", Vector2(150, 62), 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(1130, 540)
	vb.add_child(_content)
	_rebuild()


func _set_tab(t: String) -> void:
	tab = t
	message = ""
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).disabled = (k == tab)
	_coins.text = "Монеты: %d" % int(main.wallet["coins"])
	match tab:
		"squad": _build_squad()
		"bag": _build_bag()
		"forge": _build_forge()
		"quests": _build_quests()
		"settings": _build_settings()


func _msg(text: String) -> void:
	message = text
	_rebuild()


# ---------- Отряд ----------

func _build_squad() -> void:
	var members := main.members()
	sel_member = clampi(sel_member, 0, members.size() - 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	# список бойцов
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(UiKit.label("Бойцы отряда", 22, Color("ffe9a8")))
	for i in members.size():
		var m: Mercenary = members[i]
		var d: MercenaryDef = main.gd.mercs[m.def_id]
		var b := UiKit.button("%s\nур. %d" % [main.member_name(m), m.level], Vector2(290, 84), 20)
		b.icon = Art.character(Art.merc_sprite(d.id, d.weapon))
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = i == sel_member
		b.pressed.connect(func(): sel_member = i; sel_slot = ""; message = ""; _rebuild())
		left.add_child(b)
	# сведения
	var m := members[sel_member]
	var d := main.gd.mercs[m.def_id] as MercenaryDef
	var mid := UiKit.inner_panel(Vector2(500, 0))
	row.add_child(mid)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	mid.add_child(mv)
	mv.add_child(UiKit.label("%s   (ур. %d, %s)" % [main.member_name(m), m.level, str(main.gd.weapons[d.weapon]["name"])], 24, Color("ffe9a8")))
	var st := m.compute_stats(main.gd)
	mv.add_child(UiKit.label("Здоровье %d    Атака %d    Защита %d    ОД за ход %d" % [st.hp, st.atk, st.def, st.ap_regen], 20))
	mv.add_child(UiKit.label("Опыт: %d / %d" % [m.xp, Progression.xp_to_next(m.level, main.gd)], 18, Color(0.8, 0.85, 1.0)))
	var skills: Array[String] = []
	for sid in m.skill_levels:
		skills.append("%s (ур. %d)" % [(main.gd.skills[sid] as SkillDef).name, int(m.skill_levels[sid])])
	mv.add_child(UiKit.label("Навыки: " + ", ".join(skills), 18))
	mv.add_child(UiKit.label("Очки: характеристики %d, навыки %d" % [m.bonus_points, m.skill_points], 18, Color(0.8, 0.85, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	mv.add_child(grid)
	for slot in ItemDef.SLOTS:
		var it: Item = m.equipped.get(slot)
		var text := "%s\n%s" % [SLOT_NAMES[slot], "пусто"]
		if it != null:
			text = "%s\n%s%s" % [SLOT_NAMES[slot], main.gd.items[it.def_id].name, (" +%d" % it.plus) if it.plus > 0 else ""]
		var b := UiKit.button(text, Vector2(240, 80), 18)
		if it != null:
			b.icon = UiKit.item_icon(it.def_id)
			b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = slot == sel_slot
		b.pressed.connect(func(): sel_slot = slot; _rebuild())
		grid.add_child(b)
	if sel_slot != "":
		_build_slot_picker(mv, m)
	if message != "":
		mv.add_child(UiKit.label(message, 18, Color("ffb36b")))
	# формация
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	right.add_child(UiKit.label("Формация", 22, Color("ffe9a8")))
	right.add_child(UiKit.label("Выберите бойца слева, затем клетку. Передняя линия справа.", 16, Color(0.8, 0.85, 1.0)))
	var fg := GridContainer.new()
	fg.columns = 3
	fg.add_theme_constant_override("h_separation", 6)
	fg.add_theme_constant_override("v_separation", 6)
	right.add_child(fg)
	for r in 3:
		for c in [2, 1, 0]:
			var slot_i: int = r * 3 + c
			var occ := main.member_at_slot(slot_i)
			var b := Button.new()
			b.custom_minimum_size = Vector2(92, 92)
			b.add_theme_stylebox_override("normal", UiKit.slot(c == 0))
			b.add_theme_stylebox_override("hover", UiKit.slot(true))
			b.add_theme_stylebox_override("pressed", UiKit.slot(true))
			if occ != null:
				var od := main.gd.mercs[occ.def_id] as MercenaryDef
				b.icon = Art.character(Art.merc_sprite(od.id, od.weapon))
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 72)
				b.tooltip_text = main.member_name(occ)
				if occ == m:
					b.add_theme_stylebox_override("normal", UiKit.slot(true))
			b.pressed.connect(func(): main.place_member(m, slot_i); _rebuild())
			fg.add_child(b)
	right.add_child(UiKit.label("Ходят бойцы в порядке, который выберете вы. Ближние бьют только по передней линии врага.", 15, Color(0.75, 0.8, 0.9)))


func _build_slot_picker(parent: Control, m: Mercenary) -> void:
	var box := UiKit.inner_panel()
	parent.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	v.add_child(UiKit.label("Выберите предмет: %s" % SLOT_NAMES[sel_slot], 18, Color("ffe9a8")))
	var any := false
	for it in main.inv.items:
		var idef := main.gd.items[it.def_id] as ItemDef
		if idef.slot != sel_slot:
			continue
		any = true
		var why := _equip_block(m, it)
		var b := UiKit.button("%s%s  (ур. %d)%s" % [idef.name, (" +%d" % it.plus) if it.plus > 0 else "", idef.level_req, ("  - " + why) if why != "" else ""], Vector2(0, 50), 17)
		b.icon = UiKit.item_icon(it.def_id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = why != ""
		b.pressed.connect(func():
			var err := m.equip(it, main.inv)
			message = "" if err == "" else "Нельзя надеть: %s" % err
			sel_slot = ""
			main.refresh_hud()
			_rebuild())
		v.add_child(b)
	if not any:
		v.add_child(UiKit.label("В сумке нет подходящих предметов.", 16))
	if m.equipped.has(sel_slot):
		var off := UiKit.button("Снять надетое", Vector2(0, 48), 17)
		off.pressed.connect(func():
			var err := m.unequip(sel_slot, main.inv)
			message = "" if err == "" else "Нельзя снять: %s" % ("сумка полна" if err == "inventory_full" else err)
			sel_slot = ""
			_rebuild())
		v.add_child(off)


func _equip_block(m: Mercenary, it: Item) -> String:
	var idef := main.gd.items[it.def_id] as ItemDef
	var d := main.gd.mercs[m.def_id] as MercenaryDef
	if m.level < idef.level_req:
		return "нужен ур. %d" % idef.level_req
	if idef.slot == "weapon" and idef.weapon != d.weapon:
		return "не то оружие"
	return ""


# ---------- Сумка ----------

func _build_bag() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(640, 0)
	row.add_child(left)
	left.add_child(UiKit.label("Сумка: предметов %d из %d" % [main.inv.items.size(), main.inv.capacity()], 22, Color("ffe9a8")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var items := main.inv.items.duplicate()
	items.sort_custom(func(a: Item, b: Item): return a.def_id < b.def_id)
	for it in items:
		grid.add_child(_item_cell(it.def_id, "+%d" % it.plus if it.plus > 0 else "", it.uid == sel_item, func(): sel_item = it.uid; _rebuild()))
	for id in main.inv.materials:
		grid.add_child(_item_cell(id, "x%d" % int(main.inv.materials[id]), sel_item == -1 and sel_slot == id, func(): sel_item = -1; sel_slot = id; _rebuild()))
	# подробности
	var right := UiKit.inner_panel(Vector2(440, 0))
	row.add_child(right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	right.add_child(v)
	var it := main.inv.item_by_uid(sel_item)
	if it != null:
		var idef := main.gd.items[it.def_id] as ItemDef
		v.add_child(UiKit.label("%s%s" % [idef.name, (" +%d" % it.plus) if it.plus > 0 else ""], 26, UiKit.rarity_color(idef.rarity)))
		var kind: String = str(SLOT_NAMES[idef.slot]) + ((", " + str(main.gd.weapons[idef.weapon]["name"])) if idef.weapon != "" else "")
		v.add_child(UiKit.label("%s. Требуется уровень %d" % [kind, idef.level_req], 18))
		for s in idef.stats:
			v.add_child(UiKit.label("%s: %d" % [STAT_NAMES.get(s, s), it.stat(s, main.gd)], 20, Color("9ee6a4")))
		v.add_child(UiKit.label("Надеть на:", 18, Color("ffe9a8")))
		for m in main.members():
			var why := _equip_block(m, it)
			var b := UiKit.button("%s%s" % [main.member_name(m), ("  (" + why + ")") if why != "" else ""], Vector2(0, 52), 18)
			b.disabled = why != ""
			b.pressed.connect(func():
				m.equip(it, main.inv)
				sel_item = -1
				main.refresh_hud()
				_rebuild())
			v.add_child(b)
		var forge := UiKit.button("В кузницу", Vector2(0, 52), 18)
		forge.pressed.connect(func(): sel_forge_item = it.uid; _set_tab("forge"))
		v.add_child(forge)
	elif sel_slot != "" and main.gd.items.has(sel_slot):
		var md := main.gd.items[sel_slot] as ItemDef
		v.add_child(UiKit.label(md.name, 26, Color("ffe9a8")))
		v.add_child(UiKit.label("Материал. В сумке: %d" % main.inv.material_count(sel_slot), 20))
		v.add_child(UiKit.label(_material_hint(sel_slot), 18, Color(0.8, 0.85, 1.0)))
	else:
		v.add_child(UiKit.label("Выберите предмет в сумке.", 20))
		v.add_child(UiKit.label("Экипировку можно надеть на бойца или улучшить в кузнице. Материалы идут на улучшение и крафт.", 17, Color(0.8, 0.85, 1.0)))


func _material_hint(id: String) -> String:
	match id:
		"enhance_stone": return "Нужен для улучшения предметов в кузнице."
		"iron_ore": return "Идёт на крафт оружия, брони и шлемов."
		"leather": return "Идёт на крафт брони и шлемов."
		"cloth_scrap": return "Идёт на крафт аксессуаров."
		"key_ruins", "key_tomb": return "Открывает подземелье."
		_: return ""


func _item_cell(def_id: String, badge: String, selected: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(98, 98)
	b.add_theme_stylebox_override("normal", UiKit.slot(selected))
	b.add_theme_stylebox_override("hover", UiKit.slot(true))
	b.add_theme_stylebox_override("pressed", UiKit.slot(true))
	b.icon = UiKit.item_icon(def_id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 64)
	b.tooltip_text = str(main.gd.items[def_id].name)
	b.pressed.connect(cb)
	if badge != "":
		var l := UiKit.label(badge, 20, Color("ffe066"))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size = Vector2(84, 28)
		l.position = Vector2(8, 64)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	return b


# ---------- Кузница ----------

func _all_equipment() -> Array[Item]:
	var out: Array[Item] = []
	for m in main.members():
		for s in m.equipped:
			out.append(m.equipped[s])
	out.append_array(main.inv.items)
	return out


func wallet_coins() -> int:
	return int(main.wallet["coins"])


func _is_equipped(it: Item) -> bool:
	return main.inv.item_by_uid(it.uid) == null


func _build_forge() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	# улучшение
	var up := UiKit.inner_panel(Vector2(560, 0))
	row.add_child(up)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 6)
	up.add_child(uv)
	uv.add_child(UiKit.label("Улучшение", 24, Color("ffe9a8")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	uv.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var chosen: Item = null
	for it in _all_equipment():
		if it.uid == sel_forge_item:
			chosen = it
		var idef := main.gd.items[it.def_id] as ItemDef
		var b := UiKit.button("%s +%d%s" % [idef.name, it.plus, "  (надето)" if _is_equipped(it) else ""], Vector2(500, 48), 18)
		b.icon = UiKit.item_icon(it.def_id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = it.uid == sel_forge_item
		b.pressed.connect(func(): sel_forge_item = it.uid; message = ""; _rebuild())
		list.add_child(b)
	if chosen != null:
		var idef := main.gd.items[chosen.def_id] as ItemDef
		var maxed := chosen.plus >= int(main.gd.rules["enhance"]["max_plus"])
		uv.add_child(UiKit.label("%s +%d   ->   +%d" % [idef.name, chosen.plus, chosen.plus + 1], 22, UiKit.rarity_color(idef.rarity)))
		if maxed:
			uv.add_child(UiKit.label("Максимальный уровень улучшения.", 18))
		else:
			var cost := Enhancer.cost(chosen, main.gd)
			var ch := Enhancer.chance(chosen, main.gd)
			uv.add_child(UiKit.label("Шанс успеха: %d%%%s" % [ch, ("  (серия неудач: +%d%%)" % (chosen.fail_streak * int(main.gd.rules["enhance"]["fail_streak_bonus_pct"]))) if chosen.fail_streak > 0 else ""], 20, Color("9ee6a4")))
			uv.add_child(UiKit.label("Цена: %d монет и %d камней закалки (есть %d)" % [cost.coins, cost.stones, main.inv.material_count("enhance_stone")], 18))
			uv.add_child(UiKit.label("При неудаче предмет не ломается: теряются монеты и половина камней.", 15, Color(0.8, 0.85, 1.0)))
			var go := UiKit.button("Улучшить", Vector2(0, 62), 24)
			go.disabled = int(main.wallet["coins"]) < int(cost.coins) or main.inv.material_count("enhance_stone") < int(cost.stones)
			go.pressed.connect(func():
				var r := Enhancer.try_enhance(chosen, main.inv, main.wallet, main.rng)
				if r.ok:
					message = ("Успех! Теперь +%d" % r.plus) if r.success else "Неудача. Предмет цел, шанс следующей попытки выше."
				else:
					message = "Нельзя: %s" % r.error
				main.refresh_hud()
				_rebuild())
			uv.add_child(go)
	else:
		uv.add_child(UiKit.label("Выберите предмет из списка.", 18))
	if message != "":
		uv.add_child(UiKit.label(message, 20, Color("ffe066")))
	# крафт
	var cr := UiKit.inner_panel(Vector2(540, 0))
	row.add_child(cr)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cr.add_child(cv)
	cv.add_child(UiKit.label("Крафт", 24, Color("ffe9a8")))
	var cs := ScrollContainer.new()
	cs.custom_minimum_size = Vector2(500, 470)
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(cs)
	var rl := VBoxContainer.new()
	rl.add_theme_constant_override("separation", 6)
	cs.add_child(rl)
	for r in main.gd.recipes:
		var out := main.gd.items[r["output"]] as ItemDef
		var need: Array[String] = []
		var ok := int(main.wallet["coins"]) >= int(r["coins"])
		for mid in r["materials"]:
			var have := main.inv.material_count(mid)
			need.append("%s %d/%d" % [main.gd.items[mid].name, have, int(r["materials"][mid])])
			if have < int(r["materials"][mid]):
				ok = false
		var lack := "" if int(wallet_coins()) >= int(r["coins"]) else "   (не хватает монет)"
		var b := UiKit.button("%s%s\n%s, %d монет" % [out.name, lack, ", ".join(need), int(r["coins"])], Vector2(500, 74), 16)
		b.icon = UiKit.item_icon(out.id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not ok
		b.pressed.connect(func():
			var res := Crafter.craft(str(r["id"]), main.inv, main.wallet)
			message = ("Создано: %s" % out.name) if res.ok else "Нельзя: %s" % res.error
			main.refresh_hud()
			_rebuild())
		rl.add_child(b)


# ---------- Задания ----------

func _build_quests() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(1100, 0)
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	var lvl := main.squad.hero.level
	v.add_child(UiKit.label("Активные задания (%d из %d)" % [main.log.active.size(), int(main.gd.rules["quests"]["max_active"])], 24, Color("ffe9a8")))
	if main.log.active.is_empty():
		v.add_child(UiKit.label("Нет активных заданий. Поговорите с капитаном Орвином в порту (знак «!» над ним).", 20))
	for qid in main.log.active:
		var q: Dictionary = main.gd.quests[qid]
		var state := main.log.state(qid, main.inv, lvl, main.now)
		var p := UiKit.inner_panel()
		v.add_child(p)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 4)
		p.add_child(pv)
		var kind: String = {"main": "Основное", "side": "Побочное", "daily": "Ежедневное", "recruit": "Вербовка"}.get(str(q["kind"]), "")
		pv.add_child(UiKit.label("%s  [%s]%s" % [q["name"], kind, "   ГОТОВО" if state == "ready" else ""], 22, Color("7dff9b") if state == "ready" else Color.WHITE))
		if str(q["description"]) != "":
			pv.add_child(UiKit.label(str(q["description"]), 16, Color(0.8, 0.85, 1.0)))
		var objs: Array = q["objectives"]
		for i in objs.size():
			pv.add_child(UiKit.label("  - %s: %d/%d" % [objs[i]["text"], main.log.objective_count(qid, i, main.inv, lvl), int(objs[i]["count"])], 18))
		var giver := str(main.gd.npcs[q["turn_in"]]["name"])
		pv.add_child(UiKit.label("Награда: %s. Сдать: %s" % [main.rewards_text(q["rewards"]), giver], 17, Color("9ee6a4")))
		var drop := UiKit.button("Бросить", Vector2(150, 52), 18)
		drop.pressed.connect(func(): main.log.abandon(qid); main.refresh_hud(); _rebuild())
		pv.add_child(drop)
	var done: Array = main.log.completed_ids()
	v.add_child(UiKit.label("Выполнено заданий: %d. Ежедневных взято сегодня: %d из %d." % [done.size(), main.log.daily_accepted_count(main.now), int(main.gd.rules["quests"]["max_daily"])], 18, Color(0.8, 0.85, 1.0)))


# ---------- Настройки ----------

func _build_settings() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	_content.add_child(v)
	var s := main.settings
	v.add_child(UiKit.label("Настройки", 26, Color("ffe9a8")))
	v.add_child(UiKit.label("Скорость боя", 20))
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 8)
	v.add_child(sp)
	for val in [1.0, 2.0, 3.0]:
		var b := UiKit.button("x%d" % int(val), Vector2(120, 62), 22)
		b.disabled = is_equal_approx(s.battle_speed, val)
		b.pressed.connect(func(): s.battle_speed = val; s.save_file(); _rebuild())
		sp.add_child(b)
	v.add_child(UiKit.label("Управление героем на карте", 20))
	var ct := HBoxContainer.new()
	ct.add_theme_constant_override("separation", 8)
	v.add_child(ct)
	for opt in [[false, "Касание карты"], [true, "Экранный джойстик"]]:
		var b := UiKit.button(str(opt[1]), Vector2(260, 62), 20)
		b.disabled = s.joystick == bool(opt[0])
		b.pressed.connect(func(): s.joystick = bool(opt[0]); s.save_file(); main.apply_settings(); _rebuild())
		ct.add_child(b)
	v.add_child(_toggle("Подсказки на карте", s.hints, func(on: bool): s.hints = on; s.save_file(); main.apply_settings()))
	v.add_child(_toggle("Автобой с начала боя", s.auto_start, func(on: bool): s.auto_start = on; s.save_file()))
	v.add_child(UiKit.label("Демо-версия. Графика временная (Kenney, CC0). Прогресс не сохраняется, настройки сохраняются.", 16, Color(0.75, 0.8, 0.9)))


func _toggle(text: String, value: bool, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var b := UiKit.button("Вкл" if value else "Выкл", Vector2(120, 58), 20)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): cb.call(not value); _rebuild())
	h.add_child(b)
	var l := UiKit.label(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(420, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h
