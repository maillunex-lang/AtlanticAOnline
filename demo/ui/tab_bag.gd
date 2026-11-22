class_name TabBag
extends Control
## Вкладка «Сумка»: сетка предметов и материалов, подробности, «Надеть на».

const LIST_BUTTON := preload("res://scenes/ui/list_button.tscn")
const ITEM_CELL := preload("res://scenes/ui/item_cell.tscn")
const STAT_NAMES := {"hp": "Здоровье", "atk": "Атака", "def": "Защита", "ap_regen": "ОД за ход"}
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Броня", "helm": "Шлем", "accessory": "Аксессуар"}

var menu: MenuScreen

@onready var capacity_label: Label = %CapacityLabel
@onready var item_scroll: ScrollContainer = %ItemScroll
@onready var item_grid: GridContainer = %ItemGrid
@onready var detail_name: Label = %DetailName
@onready var detail_info: Label = %DetailInfo
@onready var detail_stats: VBoxContainer = %DetailStats
@onready var equip_title: Label = %EquipTitle
@onready var equip_list: VBoxContainer = %EquipList
@onready var forge_button: Button = %ForgeButton
@onready var detail_hint: Label = %DetailHint


func rebuild(m: MenuScreen) -> void:
	menu = m
	var main := menu.main
	capacity_label.text = "Сумка: предметов %d из %d" % [main.inv.items.size(), main.inv.capacity()]
	item_grid.columns = maxi(3, int((item_scroll.size.x - 12.0) / 106.0))
	MenuScreen.clear(item_grid)
	var items := main.inv.items.duplicate()
	items.sort_custom(func(a: Item, b: Item): return a.def_id < b.def_id)
	for it in items:
		var cell: ItemCell = ITEM_CELL.instantiate()
		item_grid.add_child(cell)
		cell.setup(UiKit.item_icon(it.def_id, main.gd.items[it.def_id]), "+%d" % it.plus if it.plus > 0 else "", it.uid == menu.sel_item, str(main.gd.items[it.def_id].name))
		cell.pressed.connect(func(): menu.sel_item = it.uid; menu.sel_slot = ""; menu.rebuild())
	for id in main.inv.materials:
		var cell: ItemCell = ITEM_CELL.instantiate()
		item_grid.add_child(cell)
		cell.setup(UiKit.item_icon(id, main.gd.items[id]), "x%d" % int(main.inv.materials[id]), menu.sel_item == -1 and menu.sel_slot == id, str(main.gd.items[id].name))
		cell.pressed.connect(func(): menu.sel_item = -1; menu.sel_slot = id; menu.rebuild())
	_details()


func _details() -> void:
	var main := menu.main
	MenuScreen.clear(detail_stats)
	MenuScreen.clear(equip_list)
	var it := main.inv.item_by_uid(menu.sel_item)
	equip_title.visible = it != null
	forge_button.visible = it != null
	detail_info.visible = true
	if it != null:
		var idef := main.gd.items[it.def_id] as ItemDef
		detail_name.text = "%s%s" % [idef.name, (" +%d" % it.plus) if it.plus > 0 else ""]
		detail_name.add_theme_color_override("font_color", UiKit.rarity_color(idef.rarity))
		var kind: String = str(SLOT_NAMES[idef.slot]) + ((", " + str(main.gd.weapons[idef.weapon]["name"])) if idef.weapon != "" else "")
		detail_info.text = "%s. Требуется уровень %d" % [kind, idef.level_req]
		if idef.set_id != "":
			var equipment_set: Dictionary = main.gd.equipment_sets[idef.set_id]
			detail_info.text += "\nКомплект «%s» · бонусы за 2 и %d вещи" % [
				equipment_set.name, equipment_set.pieces,
			]
		for s in idef.stats:
			var l := Label.new()
			l.text = "%s: %d" % [STAT_NAMES.get(s, s), it.stat(s, main.gd)]
			l.add_theme_color_override("font_color", Color("9ee6a4"))
			l.add_theme_font_size_override("font_size", 20)
			detail_stats.add_child(l)
		for mem in main.members():
			var why := TabSquad.equip_block(main, mem, it)
			var b: ListButton = LIST_BUTTON.instantiate()
			equip_list.add_child(b)
			b.disabled = why != ""
			b.setup("%s%s" % [main.member_name(mem), ("  (" + why + ")") if why != "" else ""], null, 52.0, 18)
			b.pressed.connect(func():
				main.equip_member(mem, it)
				menu.sel_item = -1
				main.refresh_hud()
				menu.rebuild())
		if not forge_button.pressed.is_connected(_to_forge):
			forge_button.pressed.connect(_to_forge)
		detail_hint.text = ""
	elif menu.sel_slot != "" and main.gd.items.has(menu.sel_slot):
		var md := main.gd.items[menu.sel_slot] as ItemDef
		detail_name.text = md.name
		detail_name.add_theme_color_override("font_color", Color("ffe9a8"))
		detail_info.text = "Материал. В сумке: %d" % main.inv.material_count(menu.sel_slot)
		detail_hint.text = _material_hint(menu.sel_slot)
		if menu.sel_slot == main.gd.life_skills.get("cooking", {}).get("output", "") and main.inv.material_count(menu.sel_slot) > 0:
			var use: ListButton = LIST_BUTTON.instantiate()
			equip_list.add_child(use)
			use.setup("Съесть паёк", null, 64.0, 18)
			use.pressed.connect(func():
				main.hud.toast(main.use_fish_ration())
				menu.rebuild())
	else:
		detail_name.text = "Выберите предмет в сумке."
		detail_name.add_theme_color_override("font_color", Color.WHITE)
		detail_info.text = ""
		detail_info.visible = false
		detail_hint.text = "Экипировку можно надеть на бойца или улучшить в кузнице. Материалы идут на улучшение и крафт."


func _to_forge() -> void:
	menu.sel_forge_item = menu.sel_item
	menu.set_tab("forge")


func _material_hint(id: String) -> String:
	match id:
		"enhance_stone": return "Нужен для улучшения предметов в кузнице."
		"iron_ore": return "Идёт на крафт оружия, брони и шлемов."
		"leather": return "Идёт на крафт брони и шлемов."
		"cloth_scrap": return "Идёт на крафт аксессуаров."
		"fishing_bait": return "Расходуется при ловле рыбы."
		"coastal_fish": return "Из двух рыб можно приготовить паёк у места рыбалки."
		"fish_ration": return "Восстанавливает часть запаса хода."
		"key_ruins", "key_tomb": return "Открывает подземелье."
		_: return ""
