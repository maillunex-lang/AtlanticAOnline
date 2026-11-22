extends SceneTree
## Генератор сцен боя: scenes/battle/*.tscn и theme/pixel_theme.tres. Запуск (после импорта):
##   godot --headless --path . -s tools/gen_battle.gd
## Сцены создаются один раз и дальше правятся в редакторе. Повторный запуск перезапишет ваши правки.

const TH := "res://theme/pixel_theme.tres"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://theme")
	DirAccess.make_dir_recursive_absolute("res://scenes/battle")
	ResourceSaver.save(UiKit.theme(), TH)
	var theme: Theme = load(TH)
	_unit_view()
	_hero_chip(theme)
	_action_button(theme)
	_battle_view(theme)
	quit()


func _unit_view() -> void:
	var r := Control.new()
	r.set_script(load("res://demo/battle/unit_view.gd"))
	r.name = "UnitView"
	GenLib.rect(r, 0, 0, 112, 132)
	r.custom_minimum_size = Vector2(112, 132)
	r.pivot_offset = Vector2(56, 66)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	var team := TextureRect.new()
	team.texture = load("res://demo/assets/atlas/shadow.png")
	team.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	team.stretch_mode = TextureRect.STRETCH_SCALE
	GenLib.rect(team, 6, 62, 100, 34)
	GenLib.add(r, team, "TeamMark", r, true)
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GenLib.rect(sprite, 16, 2, 80, 80)
	GenLib.add(r, sprite, "Sprite", r, true)
	var ring := TextureRect.new()
	ring.texture = load("res://demo/assets/atlas/ring.png")
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	GenLib.rect(ring, 4, 20, 104, 88)
	ring.visible = false
	GenLib.add(r, ring, "Ring", r, true)
	var name_l := GenLib.label("", 15, Color.WHITE, 4)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.rect(name_l, 0, 84, 112, 20)
	GenLib.add(r, name_l, "NameLabel", r, true)
	var hp := ProgressBar.new()
	hp.show_percentage = false
	hp.max_value = 100
	hp.value = 100
	var bg := GenLib.flat(Color(0, 0, 0, 0.7), 2)
	var fill := GenLib.flat(Color("3fae55"), 2)
	fill.resource_local_to_scene = true
	hp.add_theme_stylebox_override("background", bg)
	hp.add_theme_stylebox_override("fill", fill)
	GenLib.rect(hp, 10, 106, 92, 14)
	GenLib.add(r, hp, "HpBar", r, true)
	var hpl := GenLib.label("0", 12, Color.WHITE, 3)
	hpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.anchors(hpl, 0, 0, 1, 1)
	GenLib.add(hp, hpl, "HpLabel", r, true)
	var ap := GenLib.label("", 11, Color("9ad0ff"), 3)
	GenLib.rect(ap, 10, 120, 92, 12)
	GenLib.add(r, ap, "ApLabel", r, true)
	var buff := GenLib.label("1", 13, Color.BLACK)
	buff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff.add_theme_stylebox_override("normal", GenLib.flat(Color("f1c40f"), 10))
	GenLib.rect(buff, 84, 4, 20, 20)
	buff.visible = false
	GenLib.add(r, buff, "BuffBadge", r, true)
	for c in r.get_children():
		GenLib.ignore_mouse(c)
	GenLib.save(r, "res://scenes/battle/unit_view.tscn")


func _hero_chip(theme: Theme) -> void:
	var r := Button.new()
	r.set_script(load("res://demo/battle/hero_chip.gd"))
	r.name = "HeroChip"
	r.theme = theme
	r.custom_minimum_size = Vector2(118, 124)
	r.focus_mode = Control.FOCUS_NONE
	r.add_theme_stylebox_override("normal", UiKit.slot(false))
	r.add_theme_stylebox_override("hover", UiKit.slot(true))
	r.add_theme_stylebox_override("pressed", UiKit.slot(true))
	r.add_theme_stylebox_override("disabled", UiKit.box("slot", Color(0.45, 0.48, 0.55), 6.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	GenLib.anchors(vb, 0, 0, 1, 1, 8, 6, -8, -6)
	GenLib.add(r, vb, "Box", r)
	var sp := TextureRect.new()
	sp.custom_minimum_size = Vector2(0, 58)
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GenLib.add(vb, sp, "Sprite", r, true)
	var nm := GenLib.label("", 15, Color.WHITE, 4)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.add(vb, nm, "NameLabel", r, true)
	var hp := ProgressBar.new()
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 10)
	hp.add_theme_stylebox_override("background", GenLib.flat(Color(0, 0, 0, 0.7), 2))
	var fill := GenLib.flat(Color("3fae55"), 2)
	fill.resource_local_to_scene = true
	hp.add_theme_stylebox_override("fill", fill)
	GenLib.add(vb, hp, "HpBar", r, true)
	var ap := GenLib.label("", 13, Color("9ad0ff"), 3)
	ap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.add(vb, ap, "ApLabel", r, true)
	var done := GenLib.label("ХОДИЛ", 14, Color("ffe066"), 4)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.anchors(done, 0, 0, 1, 0, 0, 30, 0, 52)
	done.visible = false
	GenLib.add(r, done, "DoneLabel", r, true)
	GenLib.ignore_mouse(vb)
	GenLib.ignore_mouse(done)
	GenLib.save(r, "res://scenes/battle/hero_chip.tscn")


func _action_button(theme: Theme) -> void:
	var r := Button.new()
	r.set_script(load("res://demo/battle/action_button.gd"))
	r.name = "ActionButton"
	r.theme = theme
	r.custom_minimum_size = Vector2(420, 78)
	r.focus_mode = Control.FOCUS_NONE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	GenLib.anchors(h, 0, 0, 1, 1, 14, 8, -14, -8)
	GenLib.add(r, h, "Row", r)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(52, 52)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GenLib.add(h, ic, "Icon", r, true)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	GenLib.add(h, v, "Texts", r)
	var t := GenLib.label("Название", 22, Color.WHITE, 4)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GenLib.add(v, t, "TitleLabel", r, true)
	var d := GenLib.label("описание", 14, Color(0.9, 0.92, 1.0), 3)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GenLib.add(v, d, "DetailLabel", r, true)
	var cost := GenLib.label("", 20, Color("9ad0ff"), 4)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.custom_minimum_size = Vector2(84, 0)
	GenLib.add(h, cost, "CostLabel", r, true)
	GenLib.ignore_mouse(h)
	GenLib.save(r, "res://scenes/battle/action_button.tscn")


func _battle_view(theme: Theme) -> void:
	var r := Control.new()
	r.set_script(load("res://demo/battle/battle_view.gd"))
	r.name = "BattleView"
	r.theme = theme
	GenLib.anchors(r, 0, 0, 1, 1)
	var bg := Control.new()
	bg.set_script(load("res://demo/battle/battle_background.gd"))
	GenLib.anchors(bg, 0, 0, 1, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GenLib.add(r, bg, "Background", r, true)
	var field := Control.new()
	GenLib.anchors(field, 0, 0, 1, 1)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GenLib.add(r, field, "Field", r, true)
	# верхняя полоса
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.box("panel_dark", Color(1, 1, 1, 0.92), 10.0))
	GenLib.anchors(top, 0.5, 0, 0.5, 0, -380, 8, 380, 62)
	GenLib.add(r, top, "TopBar", r, true)
	var title := GenLib.label("", 24, Color.WHITE, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.add(top, title, "TitleLabel", r, true)
	var lg := GenLib.label("", 15, Color(1, 1, 1, 0.85), 4)
	lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GenLib.rect(lg, 18, 70, 330, 150)
	GenLib.add(r, lg, "LogLabel", r, true)
	# нижняя панель
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiKit.box("panel_dark", Color(1, 1, 1, 0.97), 10.0))
	GenLib.anchors(bar, 0, 1, 1, 1, 0, -158, 0, 0)
	GenLib.add(r, bar, "BottomBar", r, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	GenLib.add(bar, row, "Row", r)
	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 8)
	GenLib.add(row, heroes, "HeroBar", r, true)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GenLib.add(row, sp, "Spacer", r)
	var hint := GenLib.label("Коснитесь бойца внизу или на поле", 20, Color(0.95, 0.95, 0.97), 3)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(240, 0)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GenLib.add(row, hint, "HintLabel", r, true)
	var btns := GridContainer.new()
	btns.columns = 2
	btns.add_theme_constant_override("h_separation", 8)
	btns.add_theme_constant_override("v_separation", 8)
	GenLib.add(row, btns, "Buttons", r)
	for spec in [["EndTurnButton", "Закончить ход"], ["AutoButton", "Авто"], ["FleeButton", "Бежать"], ["CancelButton", "Отмена"]]:
		var b := Button.new()
		b.text = str(spec[1])
		b.custom_minimum_size = Vector2(170, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		GenLib.add(btns, b, str(spec[0]), r, true)
	# меню действий
	var pop := PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UiKit.box("panel_dark", Color.WHITE, 14.0))
	pop.custom_minimum_size = Vector2(460, 0)
	pop.visible = false
	GenLib.add(r, pop, "ActionPopup", r, true)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	GenLib.add(pop, pv, "Box", r)
	var pt := GenLib.label("Действие", 24, Color("ffe9a8"), 4)
	GenLib.add(pv, pt, "PopupTitle", r, true)
	var al := VBoxContainer.new()
	al.add_theme_constant_override("separation", 8)
	GenLib.add(pv, al, "ActionList", r, true)
	var banner := GenLib.label("", 54, Color.WHITE, 8)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GenLib.anchors(banner, 0, 0.36, 1, 0.36, 0, 0, 0, 80)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GenLib.add(r, banner, "Banner", r, true)
	GenLib.save(r, "res://scenes/battle/battle_view.tscn")
