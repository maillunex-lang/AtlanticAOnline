class_name TabSquad
extends Control
## Вкладка «Отряд»: бойцы, статы, навыки, слоты снаряжения и формация 3x3.

const LIST_BUTTON := preload("res://scenes/ui/list_button.tscn")
const ITEM_CELL := preload("res://scenes/ui/item_cell.tscn")
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Броня", "helm": "Шлем", "accessory": "Аксессуар"}

var menu: MenuScreen

@onready var member_list: VBoxContainer = %MemberList
@onready var name_label: Label = %NameLabel
@onready var stats_label: Label = %StatsLabel
@onready var xp_label: Label = %XpLabel
@onready var skills_label: Label = %SkillsLabel
@onready var points_label: Label = %PointsLabel
@onready var slot_grid: GridContainer = %SlotGrid
@onready var picker_panel: PanelContainer = %PickerPanel
@onready var picker_title: Label = %PickerTitle
@onready var picker_list: VBoxContainer = %PickerList
@onready var message_label: Label = %MessageLabel
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
		b.setup("%s\nур. %d" % [main.member_name(mem), mem.level], Art.character(Art.merc_sprite(d.id, d.weapon)), 84.0)
		b.pressed.connect(func(): menu.sel_member = i; menu.sel_slot = ""; menu.message = ""; menu.rebuild())
	var cur := members[menu.sel_member]
	var cd := main.gd.mercs[cur.def_id] as MercenaryDef
	name_label.text = "%s   (ур. %d, %s)" % [main.member_name(cur), cur.level, str(main.gd.weapons[cd.weapon]["name"])]
	var st := cur.compute_stats(main.gd)
	stats_label.text = "Здоровье %d    Атака %d    Защита %d    ОД за ход %d" % [st.hp, st.atk, st.def, st.ap_regen]
	xp_label.text = "Опыт: %d / %d" % [cur.xp, Progression.xp_to_next(cur.level, main.gd)]
	var skills: Array[String] = []
	for sid in cur.skill_levels:
		skills.append("%s (ур. %d)" % [(main.gd.skills[sid] as SkillDef).name, int(cur.skill_levels[sid])])
	skills_label.text = "Навыки: " + ", ".join(skills)
	points_label.text = "Очки: характеристики %d, навыки %d" % [cur.bonus_points, cur.skill_points]
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
	_build_formation(cur)


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
				tip = main.member_name(occ)
			cell.setup(icon, "", occ == cur or c == 0, tip)
			cell.pressed.connect(func(): main.place_member(cur, slot_i); menu.rebuild())


static func equip_block(main: DemoMain, m: Mercenary, it: Item) -> String:
	var idef := main.gd.items[it.def_id] as ItemDef
	var d := main.gd.mercs[m.def_id] as MercenaryDef
	if m.level < idef.level_req:
		return "нужен ур. %d" % idef.level_req
	if idef.slot == "weapon" and idef.weapon != d.weapon:
		return "не то оружие"
	return ""
