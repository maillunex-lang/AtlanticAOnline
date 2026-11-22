class_name TabSquad
extends Control
## Вкладка «Отряд»: бойцы, статы, навыки, слоты снаряжения и формация 3x3.

const LIST_BUTTON := preload("res://scenes/ui/list_button.tscn")
const ITEM_CELL := preload("res://scenes/ui/item_cell.tscn")
const ATTRIBUTE_NAMES := {"strength": "Сила", "dexterity": "Ловкость", "vitality": "Живучесть", "intelligence": "Интеллект"}
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Броня", "helm": "Шлем", "accessory": "Аксессуар"}

var menu: MenuScreen
var selected_room := 0

@onready var member_list: VBoxContainer = %MemberList
@onready var name_label: Label = %NameLabel
@onready var stats_label: Label = %StatsLabel
@onready var xp_label: Label = %XpLabel
@onready var auto_skills: MenuButton = %AutoSkills
@onready var skills_label: Label = %SkillsLabel
@onready var points_label: Label = %PointsLabel
@onready var attribute_row: HBoxContainer = %AttributeRow
@onready var formation_controls: HBoxContainer = %FormationControls
@onready var slot_grid: GridContainer = %SlotGrid
@onready var picker_panel: PanelContainer = %PickerPanel
@onready var picker_title: Label = %PickerTitle
@onready var picker_list: VBoxContainer = %PickerList
@onready var message_label: Label = %MessageLabel
@onready var formation_note: Label = %FormationNote
@onready var formation_grid: GridContainer = %FormationGrid


func rebuild(m: MenuScreen) -> void:
	menu = m
	var main := menu.main
	var members := main.members()
	menu.sel_member = clampi(menu.sel_member, 0, members.size() - 1)
	MenuScreen.clear(member_list)
	for i in members.size():
		var mem: Mercenary = members[i]
		var d := main.gd.mercs[mem.def_id] as MercenaryDef
		var b: ListButton = LIST_BUTTON.instantiate()
		member_list.add_child(b)
		b.disabled = i == menu.sel_member
		var room := main.squad.room_of(mem.uid)
		var status := " · комн. %d" % (room + 1) if room >= 0 else (" · вне боя" if not mem.enabled else "")
		var portrait := Art.character(Art.merc_sprite(d.id, d.weapon))
		if mem == main.squad.hero:
			portrait = Art.hero_portrait(main.hero_class, portrait)
		b.setup("%s\nур. %d%s" % [main.member_name(mem), mem.level, status], portrait, 64.0)
		b.pressed.connect(func(): menu.sel_member = i; menu.sel_slot = ""; menu.message = ""; menu.rebuild())
	var cur := members[menu.sel_member]
	var cd := main.gd.mercs[cur.def_id] as MercenaryDef
	name_label.text = "%s   (ур. %d, %s)" % [main.member_name(cur), cur.level, str(main.gd.weapons[cd.weapon]["name"])]
	if cd.display_rank() != "":
		name_label.text += " · ранг " + cd.display_rank()
	var st := cur.compute_stats(main.gd)
	stats_label.text = "Здоровье %d   Мана %d   Атака %d   Защита %d   ОД/ход %d" % [st.hp, st.mp, st.atk, st.def, st.ap_regen]
	xp_label.text = "Опыт: %d / %d" % [cur.xp, cur.xp_to_next(main.gd)]
	if cur.level >= cur.max_level(main.gd):
		xp_label.text = "Достигнут максимум уровня"
	formation_note.text = "Бонус строю: +%d ОД за ход и +%d%% опыта. Комнаты: %d/%d." % [
		main.squad.formation_ap_bonus(), main.squad.disabled_count() * int(main.gd.rules["formation"]["xp_pct_per_disabled"]),
		main.squad.rooms.size(), int(main.gd.rules["formation"]["rooms"]),
	]
	var skills: Array[String] = []
	for sid in cur.skill_levels:
		var sk: SkillDef = main.gd.skills[sid]
		skills.append("%s%s (ур. %d)" % [sk.name, " [пассивный]" if sk.passive else "", int(cur.skill_levels[sid])])
	skills_label.text = "Навыки: " + ", ".join(skills)
	_build_auto_skills(cur)
	points_label.text = "Очки: характеристики %d, навыки %d" % [cur.bonus_points, cur.skill_points]
	MenuScreen.clear(attribute_row)
	for stat in ATTRIBUTE_NAMES:
		var button := Button.new()
		button.text = "%s %d%s" % [ATTRIBUTE_NAMES[stat], int(st.get(stat, 0)), " +" if cur.bonus_points > 0 else ""]
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = cur.bonus_points == 0
		button.pressed.connect(_allocate_attribute.bind(cur, stat))
		attribute_row.add_child(button)
	MenuScreen.clear(slot_grid)
	for slot in ItemDef.SLOTS:
		var it: Item = cur.equipped.get(slot)
		var text := "%s\n%s" % [SLOT_NAMES[slot], "пусто"]
		var icon: Texture2D = null
		if it != null:
			text = "%s\n%s%s" % [SLOT_NAMES[slot], main.gd.items[it.def_id].name, (" +%d" % it.plus) if it.plus > 0 else ""]
			icon = UiKit.item_icon(it.def_id)
		var b: ListButton = LIST_BUTTON.instantiate()
		slot_grid.add_child(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = slot == menu.sel_slot
		b.setup(text, icon, 80.0, 18)
		b.pressed.connect(func(): menu.sel_slot = slot; menu.rebuild())
	picker_panel.visible = menu.sel_slot != ""
	if menu.sel_slot != "":
		_build_picker(cur)
	message_label.text = menu.message
	message_label.visible = menu.message != ""
	_build_formation_controls(cur)
	_build_formation(cur)


func _build_auto_skills(merc: Mercenary) -> void:
	var settings := menu.main.settings
	var popup := auto_skills.get_popup()
	for connection in popup.id_pressed.get_connections():
		popup.id_pressed.disconnect(connection["callable"])
	popup.clear()
	popup.add_check_item("Участие бойца", 0)
	popup.set_item_checked(0, not settings.auto_disabled_units.has(merc.uid))
	var skill_ids: Array = merc.skill_levels.keys().filter(func(sid) -> bool: return not (menu.main.gd.skills[sid] as SkillDef).passive)
	var blocked: Array = settings.auto_blocked_skills.get(merc.uid, [])
	for i in skill_ids.size():
		popup.add_check_item((menu.main.gd.skills[skill_ids[i]] as SkillDef).name, i + 1)
		popup.set_item_checked(i + 1, skill_ids[i] not in blocked)
	popup.id_pressed.connect(func(id: int):
		if id == 0:
			if settings.auto_disabled_units.has(merc.uid):
				settings.auto_disabled_units.erase(merc.uid)
			else:
				settings.auto_disabled_units[merc.uid] = true
		else:
			var skill_id = skill_ids[id - 1]
			if skill_id in blocked:
				blocked.erase(skill_id)
			else:
				blocked.append(skill_id)
			settings.auto_blocked_skills[merc.uid] = blocked
		settings.save_file()
		_build_auto_skills(merc))


func _build_formation_controls(merc: Mercenary) -> void:
	var main := menu.main
	MenuScreen.clear(formation_controls)
	if merc == main.squad.hero:
		return
	var room := main.squad.room_of(merc.uid)
	if room >= 0:
		_add_formation_button("В строй из комнаты %d" % (room + 1), func():
			_finish_formation_change(merc, main.return_from_room(room)))
		return
	_add_formation_button("Отключить" if merc.enabled else "Включить", func():
		_finish_formation_change(merc, main.squad.set_enabled(merc.uid, not merc.enabled)))
	var rooms := OptionButton.new()
	rooms.custom_minimum_size.y = 64
	rooms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cfg: Dictionary = main.gd.rules["formation"]
	for index in int(cfg["rooms"]):
		var occupant: Mercenary = main.squad.rooms.get(index)
		var occupant_name := main.member_name(occupant) if occupant != null else "пусто"
		rooms.add_item("%d · %s" % [index + 1, occupant_name])
	rooms.select(selected_room)
	formation_controls.add_child(rooms)
	var transfer := _add_formation_button("Обменять" if main.squad.rooms.has(selected_room) else "В комнату", func():
		_finish_formation_change(merc, main.send_to_room(merc, selected_room)))
	rooms.item_selected.connect(func(index: int):
		selected_room = index
		transfer.text = "Обменять" if main.squad.rooms.has(index) else "В комнату")


func _add_formation_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	formation_controls.add_child(button)
	return button


func _finish_formation_change(merc: Mercenary, error: String) -> void:
	var labels := {"squad_full": "В формации нет свободной клетки", "empty_room": "Комната пуста"}
	menu.message = labels.get(error, error)
	menu.sel_member = menu.main.members().find(merc)
	menu.sel_slot = ""
	menu.rebuild()


func _allocate_attribute(mercenary: Mercenary, stat: String) -> void:
	if mercenary.allocate(stat, menu.main.gd) == "":
		menu.rebuild()


func _build_picker(cur: Mercenary) -> void:
	var main := menu.main
	picker_title.text = "Выберите предмет: %s" % SLOT_NAMES[menu.sel_slot]
	MenuScreen.clear(picker_list)
	var any := false
	for it in main.inv.items:
		var idef := main.gd.items[it.def_id] as ItemDef
		if idef.slot != menu.sel_slot:
			continue
		any = true
		var why := equip_block(main, cur, it)
		var b: ListButton = LIST_BUTTON.instantiate()
		picker_list.add_child(b)
		b.disabled = why != ""
		b.setup("%s%s  (ур. %d)%s" % [idef.name, (" +%d" % it.plus) if it.plus > 0 else "", idef.level_req, ("  - " + why) if why != "" else ""], UiKit.item_icon(it.def_id), 52.0, 17)
		b.pressed.connect(func():
			var err := cur.equip(it, main.inv)
			menu.message = "" if err == "" else "Нельзя надеть: %s" % err
			menu.sel_slot = ""
			main.refresh_hud()
			menu.rebuild())
	if not any:
		var l := Label.new()
		l.text = "В сумке нет подходящих предметов."
		picker_list.add_child(l)
	if cur.equipped.has(menu.sel_slot):
		var off: ListButton = LIST_BUTTON.instantiate()
		picker_list.add_child(off)
		off.setup("Снять надетое", null, 48.0, 17)
		off.pressed.connect(func():
			var err := cur.unequip(menu.sel_slot, main.inv)
			menu.message = "" if err == "" else "Нельзя снять: %s" % ("сумка полна" if err == "inventory_full" else err)
			menu.sel_slot = ""
			menu.rebuild())


const FORMATION_CELL_FREE := preload("res://assets/ui/fantasy/elements/grid_cell_free.png")
const FORMATION_CELL_SELECTED := preload("res://assets/ui/fantasy/elements/grid_cell_selected.png")
const FORMATION_CELL_OUT := preload("res://assets/ui/fantasy/elements/grid_cell_out_of_battle.png")


func _build_formation(cur: Mercenary) -> void:
	var main := menu.main
	MenuScreen.clear(formation_grid)
	for r in 3:
		for c in [2, 1, 0]:
			var slot_i: int = r * 3 + c
			var occ := main.member_at_slot(slot_i)
			var cell: ItemCell = ITEM_CELL.instantiate()
			formation_grid.add_child(cell)
			cell.custom_minimum_size = Vector2(96, 96)
			var icon: Texture2D = null
			var tip := ""
			if occ != null:
				var od := main.gd.mercs[occ.def_id] as MercenaryDef
				icon = Art.character(Art.merc_sprite(od.id, od.weapon))
				if occ == main.squad.hero:
					icon = Art.hero_formation_sprite(main.hero_class, icon)
				tip = main.member_name(occ)
			var out_of_battle := occ != null and not occ.enabled
			cell.setup(icon, "Вне боя" if out_of_battle else "", occ == cur or c == 0, tip)
			var frame := StyleBoxTexture.new()
			frame.texture = FORMATION_CELL_OUT if out_of_battle else (FORMATION_CELL_SELECTED if occ == cur else FORMATION_CELL_FREE)
			cell.add_theme_stylebox_override("normal", frame)
			cell.disabled = main.squad.room_of(cur.uid) >= 0
			cell.pressed.connect(func(): main.place_member(cur, slot_i); menu.rebuild())


static func equip_block(main: DemoMain, m: Mercenary, it: Item) -> String:
	var idef := main.gd.items[it.def_id] as ItemDef
	var d := main.gd.mercs[m.def_id] as MercenaryDef
	if m.level < idef.level_req:
		return "нужен ур. %d" % idef.level_req
	if idef.slot == "weapon" and idef.weapon != d.weapon:
		return "не то оружие"
	return ""
