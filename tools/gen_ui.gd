extends SceneTree
## Генератор сцен интерфейса: HUD, меню (5 вкладок), панели диалога и результата, мелкие элементы списков.
## Запуск (после импорта и gen_battle.gd):  godot --headless --path . -s tools/gen_ui.gd
## Сцены создаются один раз и дальше правятся в редакторе. Повторный запуск перезапишет ваши правки.

var theme: Theme


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/ui")
	theme = load("res://theme/pixel_theme.tres")
	_list_button()
	_item_cell()
	_quest_card()
	_info_panel()
	_hud()
	_tab_squad()
	_tab_bag()
	_tab_forge()
	_tab_quests()
	_tab_settings()
	_menu()
	quit()


func _script(n: Node, path: String) -> void:
	n.set_script(load(path))


func _inner() -> StyleBoxTexture:
	return UiKit.inner()


func _btn(text: String, w := 150.0, h := 64.0, fs := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	return b


func _lbl(text: String, size := 20, color := Color(0.95, 0.95, 0.97)) -> Label:
	var l := GenLib.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _inner_panel(min_w := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _inner())
	p.custom_minimum_size = Vector2(min_w, 0)
	return p


func _list_button() -> void:
	var r := Button.new()
	_script(r, "res://demo/ui/list_button.gd")
	r.name = "ListButton"
	r.theme = theme
	r.custom_minimum_size = Vector2(0, 64)
	r.focus_mode = Control.FOCUS_NONE
	var h := _hbox(10)
	GenLib.anchors(h, 0, 0, 1, 1, 12, 6, -12, -6)
	GenLib.add(r, h, "Row", r)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GenLib.add(h, ic, "Icon", r, true)
	var t := GenLib.label("", 20, Color.WHITE, 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GenLib.add(h, t, "TextLabel", r, true)
	GenLib.ignore_mouse(h)
	GenLib.save(r, "res://scenes/ui/list_button.tscn")


func _item_cell() -> void:
	var r := Button.new()
	_script(r, "res://demo/ui/item_cell.gd")
	r.name = "ItemCell"
	r.theme = theme
	r.custom_minimum_size = Vector2(98, 98)
	r.focus_mode = Control.FOCUS_NONE
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GenLib.anchors(ic, 0, 0, 1, 1, 12, 12, -12, -12)
	GenLib.add(r, ic, "Icon", r, true)
	var b := GenLib.label("", 20, Color("ffe066"), 6)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	GenLib.anchors(b, 0, 1, 1, 1, 8, -30, 0, -2)
	GenLib.add(r, b, "BadgeLabel", r, true)
	GenLib.ignore_mouse(ic)
	GenLib.ignore_mouse(b)
	GenLib.save(r, "res://scenes/ui/item_cell.tscn")


func _quest_card() -> void:
	var r := PanelContainer.new()
	_script(r, "res://demo/ui/quest_card.gd")
	r.name = "QuestCard"
	r.theme = theme
	r.add_theme_stylebox_override("panel", _inner())
	var v := _vbox(4)
	GenLib.add(r, v, "Box", r)
	GenLib.add(v, _lbl("", 22), "TitleLabel", r, true)
	GenLib.add(v, _lbl("", 16, Color(0.8, 0.85, 1.0)), "DescLabel", r, true)
	GenLib.add(v, _lbl("", 18), "ObjectivesLabel", r, true)
	GenLib.add(v, _lbl("", 17, Color("9ee6a4")), "RewardLabel", r, true)
	var b := _btn("Бросить", 150, 52, 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	GenLib.add(v, b, "AbandonButton", r, true)
	GenLib.save(r, "res://scenes/ui/quest_card.tscn")


func _info_panel() -> void:
	var r := Control.new()
	_script(r, "res://demo/ui/info_panel.gd")
	r.name = "InfoPanel"
	r.theme = theme
	GenLib.anchors(r, 0, 0, 1, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box("panel_dark", Color(1, 1, 1, 0.97), 20.0))
	GenLib.anchors(p, 0.5, 1, 0.5, 1, -460, -400, 460, -24)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	GenLib.add(r, p, "Window", r, true)
	var v := _vbox(10)
	GenLib.add(p, v, "Box", r)
	GenLib.add(v, GenLib.label("", 32, Color("ffe9a8"), 4), "TitleLabel", r, true)
	GenLib.add(v, _vbox(6), "BodyList", r, true)
	GenLib.add(v, _vbox(8), "ChoiceList", r, true)
	GenLib.save(r, "res://scenes/ui/info_panel.tscn")


func _hud() -> void:
	var r := Control.new()
	_script(r, "res://demo/ui/hud.gd")
	r.name = "Hud"
	r.theme = theme
	GenLib.anchors(r, 0, 0, 1, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := PanelContainer.new()
	var sb := GenLib.flat(Color(0.04, 0.06, 0.1, 0.72), 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	tl.add_theme_stylebox_override("panel", sb)
	GenLib.anchors(tl, 0, 0, 0, 0, 12, 10, 12, 10)
	GenLib.add(r, tl, "TopLeft", r, true)
	var v := _vbox(2)
	GenLib.add(tl, v, "Box", r)
	GenLib.add(v, GenLib.label("", 20, Color.WHITE, 3), "InfoLabel", r, true)
	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(320, 10)
	xp.show_percentage = false
	GenLib.add(v, xp, "XpBar", r, true)
	var ql := GenLib.label("", 16, Color(1, 1, 1, 0.9), 3)
	GenLib.add(v, ql, "QuestLabel", r, true)
	var mm := Control.new()
	_script(mm, "res://demo/ui/minimap.gd")
	GenLib.anchors(mm, 1, 0, 1, 0, -264, 12, -14, 150)
	GenLib.add(r, mm, "Minimap", r, true)
	var hint := GenLib.label("Коснитесь карты, чтобы бежать (на ПК: стрелки или WASD).\nПодбегите к врагам, чтобы напасть. У капитана Орвина (!) есть задание.", 18, Color.WHITE, 6)
	GenLib.anchors(hint, 0, 1, 0, 1, 20, -84, 900, -20)
	GenLib.add(r, hint, "HintLabel", r, true)
	var mb := _btn("Меню", 150, 72, 26)
	GenLib.anchors(mb, 1, 1, 1, 1, -170, -92, -20, -20)
	GenLib.add(r, mb, "MenuButton", r, true)
	var dot := ColorRect.new()
	dot.color = Color("ffe066")
	GenLib.rect(dot, 126, -6, 20, 20)
	dot.visible = false
	GenLib.add(mb, dot, "MenuDot", r, true)
	var joy := Control.new()
	_script(joy, "res://demo/ui/joystick.gd")
	GenLib.anchors(joy, 0, 1, 0, 1, 40, -256, 256, -40)
	joy.visible = false
	GenLib.add(r, joy, "Joystick", r, true)
	var toast := GenLib.label("", 26, Color.WHITE, 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.anchors(toast, 0.5, 1, 0.5, 1, -400, -170, 400, -120)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GenLib.add(r, toast, "ToastLabel", r, true)
	GenLib.save(r, "res://scenes/ui/hud.tscn")


func _tab_root(script: String, nm: String) -> Control:
	var r := Control.new()
	_script(r, script)
	r.name = nm
	r.theme = theme
	GenLib.anchors(r, 0, 0, 1, 1)
	return r


func _tab_squad() -> void:
	var r := _tab_root("res://demo/ui/tab_squad.gd", "TabSquad")
	var row := _hbox(10)
	GenLib.anchors(row, 0, 0, 1, 1)
	GenLib.add(r, row, "Row", r)
	var left := _vbox(8)
	left.custom_minimum_size = Vector2(290, 0)
	GenLib.add(row, left, "MemberColumn", r)
	GenLib.add(left, GenLib.label("Бойцы отряда", 22, Color("ffe9a8")), "MembersTitle", r)
	GenLib.add(left, _vbox(8), "MemberList", r, true)
	var mid := _inner_panel(420)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(row, mid, "DetailPanel", r)
	var mv := _vbox(6)
	GenLib.add(mid, mv, "Box", r)
	GenLib.add(mv, GenLib.label("", 24, Color("ffe9a8")), "NameLabel", r, true)
	GenLib.add(mv, _lbl("", 20), "StatsLabel", r, true)
	GenLib.add(mv, _lbl("", 18, Color(0.8, 0.85, 1.0)), "XpLabel", r, true)
	GenLib.add(mv, _lbl("", 18), "SkillsLabel", r, true)
	GenLib.add(mv, _lbl("", 18, Color(0.8, 0.85, 1.0)), "PointsLabel", r, true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	GenLib.add(mv, grid, "SlotGrid", r, true)
	var pk := _inner_panel()
	pk.visible = false
	GenLib.add(mv, pk, "PickerPanel", r, true)
	var pv := _vbox(4)
	GenLib.add(pk, pv, "Box", r)
	GenLib.add(pv, GenLib.label("", 18, Color("ffe9a8")), "PickerTitle", r, true)
	GenLib.add(pv, _vbox(4), "PickerList", r, true)
	GenLib.add(mv, _lbl("", 18, Color("ffb36b")), "MessageLabel", r, true)
	var right := _vbox(6)
	right.custom_minimum_size = Vector2(330, 0)
	GenLib.add(row, right, "FormationColumn", r)
	GenLib.add(right, GenLib.label("Формация", 22, Color("ffe9a8")), "FormationTitle", r)
	GenLib.add(right, _lbl("Выберите бойца слева, затем клетку. Передняя линия справа.", 16, Color(0.8, 0.85, 1.0)), "FormationHint", r)
	var fg := GridContainer.new()
	fg.columns = 3
	fg.add_theme_constant_override("h_separation", 6)
	fg.add_theme_constant_override("v_separation", 6)
	GenLib.add(right, fg, "FormationGrid", r, true)
	GenLib.add(right, _lbl("Ходят бойцы в порядке, который выберете вы. Ближние бьют только по передней линии врага.", 15, Color(0.75, 0.8, 0.9)), "FormationNote", r)
	GenLib.save(r, "res://scenes/ui/tab_squad.tscn")


func _tab_bag() -> void:
	var r := _tab_root("res://demo/ui/tab_bag.gd", "TabBag")
	var row := _hbox(12)
	GenLib.anchors(row, 0, 0, 1, 1)
	GenLib.add(r, row, "Row", r)
	var left := _vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(row, left, "ItemsColumn", r)
	GenLib.add(left, GenLib.label("", 22, Color("ffe9a8")), "CapacityLabel", r, true)
	var sc := _scroll()
	GenLib.add(left, sc, "ItemScroll", r, true)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	GenLib.add(sc, grid, "ItemGrid", r, true)
	var rp := _inner_panel(440)
	GenLib.add(row, rp, "DetailPanel", r)
	var v := _vbox(8)
	GenLib.add(rp, v, "Box", r)
	GenLib.add(v, GenLib.label("", 26, Color.WHITE), "DetailName", r, true)
	GenLib.add(v, _lbl("", 18), "DetailInfo", r, true)
	GenLib.add(v, _vbox(2), "DetailStats", r, true)
	GenLib.add(v, GenLib.label("Надеть на:", 18, Color("ffe9a8")), "EquipTitle", r, true)
	GenLib.add(v, _vbox(6), "EquipList", r, true)
	GenLib.add(v, _btn("В кузницу", 150, 52, 18), "ForgeButton", r, true)
	GenLib.add(v, _lbl("", 17, Color(0.8, 0.85, 1.0)), "DetailHint", r, true)
	GenLib.save(r, "res://scenes/ui/tab_bag.tscn")


func _tab_forge() -> void:
	var r := _tab_root("res://demo/ui/tab_forge.gd", "TabForge")
	var row := _hbox(12)
	GenLib.anchors(row, 0, 0, 1, 1)
	GenLib.add(r, row, "Row", r)
	var up := _inner_panel(500)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(row, up, "UpgradePanel", r)
	var uv := _vbox(6)
	GenLib.add(up, uv, "Box", r)
	GenLib.add(uv, GenLib.label("Улучшение", 24, Color("ffe9a8")), "UpgradeTitle", r)
	var sc := _scroll()
	sc.size_flags_vertical = Control.SIZE_FILL
	sc.custom_minimum_size = Vector2(0, 170)
	GenLib.add(uv, sc, "UpgradeScroll", r)
	GenLib.add(sc, _vbox(4), "UpgradeList", r, true)
	GenLib.add(uv, GenLib.label("", 22, Color.WHITE), "ChosenLabel", r, true)
	GenLib.add(uv, _lbl("", 20, Color("9ee6a4")), "ChanceLabel", r, true)
	GenLib.add(uv, _lbl("", 18), "CostLabel", r, true)
	GenLib.add(uv, _lbl("При неудаче предмет не ломается: теряются монеты и половина камней.", 15, Color(0.8, 0.85, 1.0)), "NoteLabel", r, true)
	GenLib.add(uv, _btn("Улучшить", 150, 62, 24), "GoButton", r, true)
	GenLib.add(uv, _lbl("", 20, Color("ffe066")), "MessageLabel", r, true)
	var cr := _inner_panel(500)
	cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(row, cr, "CraftPanel", r)
	var cv := _vbox(6)
	GenLib.add(cr, cv, "Box", r)
	GenLib.add(cv, GenLib.label("Крафт", 24, Color("ffe9a8")), "CraftTitle", r)
	var cs := _scroll()
	GenLib.add(cv, cs, "CraftScroll", r)
	GenLib.add(cs, _vbox(6), "CraftList", r, true)
	GenLib.save(r, "res://scenes/ui/tab_forge.tscn")


func _tab_quests() -> void:
	var r := _tab_root("res://demo/ui/tab_quests.gd", "TabQuests")
	var sc := _scroll()
	GenLib.anchors(sc, 0, 0, 1, 1)
	GenLib.add(r, sc, "Scroll", r)
	var v := _vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(sc, v, "Box", r)
	GenLib.add(v, GenLib.label("", 24, Color("ffe9a8")), "TitleLabel", r, true)
	GenLib.add(v, _lbl("", 20), "EmptyLabel", r, true)
	GenLib.add(v, _vbox(10), "QuestList", r, true)
	GenLib.add(v, _lbl("", 18, Color(0.8, 0.85, 1.0)), "SummaryLabel", r, true)
	GenLib.save(r, "res://scenes/ui/tab_quests.tscn")


func _tab_settings() -> void:
	var r := _tab_root("res://demo/ui/tab_settings.gd", "TabSettings")
	var v := _vbox(14)
	GenLib.anchors(v, 0, 0, 1, 1)
	GenLib.add(r, v, "Box", r)
	GenLib.add(v, GenLib.label("Настройки", 26, Color("ffe9a8")), "TitleLabel", r)
	GenLib.add(v, GenLib.label("Скорость боя", 20), "SpeedLabel", r)
	var sp := _hbox(8)
	GenLib.add(v, sp, "SpeedRow", r)
	for spec in [["Speed1", "x1"], ["Speed2", "x2"], ["Speed3", "x3"]]:
		GenLib.add(sp, _btn(str(spec[1]), 120, 62, 22), str(spec[0]), r, true)
	GenLib.add(v, GenLib.label("Управление героем на карте", 20), "ControlLabel", r)
	var ct := _hbox(8)
	GenLib.add(v, ct, "ControlRow", r)
	GenLib.add(ct, _btn("Касание карты", 260, 62, 20), "ControlTouch", r, true)
	GenLib.add(ct, _btn("Экранный джойстик", 280, 62, 20), "ControlStick", r, true)
	for spec in [["HintsToggle", "Подсказки на карте"], ["AutoToggle", "Автобой с начала боя"]]:
		var h := _hbox(12)
		GenLib.add(v, h, str(spec[0]) + "Row", r)
		GenLib.add(h, _btn("Вкл", 120, 58, 20), str(spec[0]), r, true)
		var l := GenLib.label(str(spec[1]), 20)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		GenLib.add(h, l, str(spec[0]) + "Label", r)
	GenLib.add(v, _lbl("Демо-версия. Графика временная (Kenney, CC0). Прогресс не сохраняется, настройки сохраняются.", 16, Color(0.75, 0.8, 0.9)), "InfoLabel", r)
	GenLib.save(r, "res://scenes/ui/tab_settings.tscn")


func _menu() -> void:
	var r := Control.new()
	_script(r, "res://demo/ui/menu_screen.gd")
	r.name = "MenuScreen"
	r.theme = theme
	GenLib.anchors(r, 0, 0, 1, 1)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	GenLib.anchors(dim, 0, 0, 1, 1)
	GenLib.add(r, dim, "Dim", r)
	var win := PanelContainer.new()
	win.add_theme_stylebox_override("panel", UiKit.window())
	GenLib.anchors(win, 0, 0, 1, 1, 40, 24, -40, -24)
	GenLib.add(r, win, "Window", r)
	var vb := _vbox(10)
	GenLib.add(win, vb, "Box", r)
	var head := _hbox(8)
	GenLib.add(vb, head, "Header", r)
	for spec in [["TabSquadButton", "Отряд"], ["TabBagButton", "Сумка"], ["TabForgeButton", "Кузница"], ["TabQuestsButton", "Задания"], ["TabSettingsButton", "Настройки"]]:
		GenLib.add(head, _btn(str(spec[1]), 150, 62, 22), str(spec[0]), r, true)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(head, sp, "Spacer", r)
	var coins := GenLib.label("", 24, Color("ffe066"))
	coins.custom_minimum_size = Vector2(190, 0)
	coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GenLib.add(head, coins, "CoinsLabel", r, true)
	GenLib.add(head, _btn("Закрыть", 150, 62, 22), "CloseButton", r, true)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(vb, pages, "Pages", r, true)
	for spec in [["TabSquad", "tab_squad"], ["TabBag", "tab_bag"], ["TabForge", "tab_forge"], ["TabQuests", "tab_quests"], ["TabSettings", "tab_settings"]]:
		var inst: Node = (load("res://scenes/ui/%s.tscn" % spec[1]) as PackedScene).instantiate()
		inst.name = str(spec[0])
		pages.add_child(inst)
		inst.owner = r
		inst.unique_name_in_owner = true
	GenLib.save(r, "res://scenes/ui/menu.tscn")
