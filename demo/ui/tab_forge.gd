class_name TabForge
extends Control
## Вкладка «Кузница»: улучшение предметов (шанс, цена) и крафт по рецептам.

const LIST_BUTTON := preload("res://scenes/ui/list_button.tscn")

var menu: MenuScreen
var choose_auto_recipe := false
var inspect_uid := -1
var confirm_dismantle: ConfirmationDialog
var confirm_enchant: ConfirmationDialog
var enchant_target: Item
var enchant_donor: Item
var pending_enchant_target: Item
var pending_enchant_donor: Item

const CRAFT_ERRORS := {
	"inventory_full": "Сумка заполнена", "craft_level": "Не хватает уровня ремесла",
	"workload": "Не хватает нагрузки", "no_coins": "Не хватает монет",
	"no_materials": "Не хватает материалов", "materials_full": "Стеки материалов заполнены",
	"analysis_used": "Анализ уже использован сегодня", "not_in_bag": "Предмет должен быть в сумке",
}


@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var chosen_label: Label = %ChosenLabel
@onready var chance_label: Label = %ChanceLabel
@onready var cost_label: Label = %CostLabel
@onready var preview_label: Label = %EnhancePreview
@onready var note_label: Label = %NoteLabel
@onready var go_button: Button = %GoButton
@onready var message_label: Label = %MessageLabel
@onready var recipe_group: OptionButton = %RecipeGroup
@onready var craft_status: Label = %CraftStatus
@onready var auto_button: Button = %AutoCraft
@onready var enchant_button: Button = %EnchantButton
@onready var analyze_button: Button = %AnalyzeButton
@onready var dismantle_button: Button = %DismantleButton
@onready var craft_list: VBoxContainer = %CraftList


func _ready() -> void:
	recipe_group.item_selected.connect(func(_index: int): _rebuild_recipes())
	auto_button.pressed.connect(_toggle_auto)
	analyze_button.pressed.connect(_analyze_selected)
	confirm_dismantle = ConfirmationDialog.new()
	add_child(confirm_dismantle)
	confirm_dismantle.title = "Разбор предмета"
	confirm_dismantle.dialog_text = "Предмет будет разобран на материалы."
	confirm_dismantle.confirmed.connect(_dismantle_selected)
	dismantle_button.pressed.connect(func(): confirm_dismantle.popup_centered())

	confirm_enchant = ConfirmationDialog.new()
	confirm_enchant.hide()
	add_child(confirm_enchant)
	confirm_enchant.title = "Зачарование"
	confirm_enchant.ok_button_text = "Зачаровать"
	confirm_enchant.cancel_button_text = "Отмена"
	confirm_enchant.confirmed.connect(_confirm_enchant)
	enchant_button.pressed.connect(_show_enchant)



func _all_equipment(main: DemoMain) -> Array[Item]:
	var out: Array[Item] = []
	for m in main.members():
		for s in m.equipped:
			out.append(m.equipped[s])
	out.append_array(main.inv.items)
	return out


func rebuild(m: MenuScreen) -> void:
	menu = m
	var main := menu.main
	MenuScreen.clear(upgrade_list)
	var chosen: Item = null
	for it in _all_equipment(main):
		if it.uid == menu.sel_forge_item:
			chosen = it
		var idef := main.gd.items[it.def_id] as ItemDef
		var b: ListButton = LIST_BUTTON.instantiate()
		upgrade_list.add_child(b)
		b.disabled = it.uid == menu.sel_forge_item
		b.setup("%s +%d%s" % [idef.name, it.plus, "  (надето)" if main.inv.item_by_uid(it.uid) == null else ""], UiKit.item_icon(it.def_id, idef), 48.0, 18)
		b.pressed.connect(func(): menu.sel_forge_item = it.uid; menu.message = ""; menu.rebuild())
	for n in [chance_label, cost_label, note_label, preview_label, go_button]:
		n.visible = false
	%CraftPanel.visible = not menu.enchant_only
	%UpgradeTitle.text = "Вулкан · Зачарование" if menu.enchant_only else "Улучшение"
	if menu.enchant_only:
		_rebuild_enchantment(chosen)
		return
	enchant_button.hide()
	if chosen != null:
		var idef := main.gd.items[chosen.def_id] as ItemDef
		var limit := Enhancer.max_plus(chosen, main.gd)
		var maxed := chosen.plus >= limit
		chosen_label.text = "%s +%d   ->   +%d" % [idef.name, chosen.plus, chosen.plus + 1]
		chosen_label.add_theme_color_override("font_color", UiKit.rarity_color(idef.rarity))
		if maxed:
			chosen_label.text = "%s +%d · предел усиления +%d" % [idef.name, chosen.plus, limit]
		else:
			var cost := Enhancer.cost(chosen, main.gd)
			var ch := Enhancer.chance(chosen, main.gd)
			var stats: PackedStringArray = []
			var labels := {"atk": "Атака", "def": "Защита", "hp": "Здоровье", "ap_regen": "ОД за ход"}
			for key in labels:
				if idef.stats.has(key):
					stats.append("%s %d → %d" % [labels[key], chosen.stat(key, main.gd), chosen.stat_at_plus(key, main.gd, chosen.plus + 1)])
			preview_label.text = " · ".join(stats)
			chance_label.text = "Шанс успеха: %d%%%s" % [ch, ("  (серия неудач: +%d%%)" % (chosen.fail_streak * int(main.gd.rules["enhance"]["fail_streak_bonus_pct"]))) if chosen.fail_streak > 0 else ""]
			cost_label.text = "Цена: %d монет и %d камней закалки (есть %d)" % [cost.coins, cost.stones, main.inv.material_count("enhance_stone")]
			for n in [chance_label, cost_label, note_label, preview_label, go_button]:
				n.visible = true
			go_button.disabled = int(main.wallet["coins"]) < int(cost.coins) or main.inv.material_count("enhance_stone") < int(cost.stones)
			for c in go_button.pressed.get_connections():
				go_button.pressed.disconnect(c["callable"])
			go_button.pressed.connect(func():
				var r := Enhancer.try_enhance(chosen, main.inv, main.wallet, main.rng)
				if r.ok:
					main._save_tomb_checkpoint()
					menu.message = ("Успех! Теперь +%d" % r.plus) if r.success else "Неудача. Предмет цел, шанс следующей попытки выше."
				else:
					menu.message = "Нельзя: %s" % r.error
				main.refresh_hud()
				menu.rebuild())
	else:
		chosen_label.text = "Выберите предмет из списка."
		chosen_label.add_theme_color_override("font_color", Color.WHITE)
	inspect_uid = chosen.uid if chosen != null and main.inv.item_by_uid(chosen.uid) != null else -1
	analyze_button.visible = inspect_uid >= 0
	dismantle_button.visible = inspect_uid >= 0
	var day := GameClock.from_rules(main.gd.rules).day_index(Time.get_unix_time_from_system())
	analyze_button.disabled = day <= main.inv.crafting.analyzed_day
	_refresh_craft_status()
	message_label.text = menu.message
	message_label.visible = menu.message != ""
	_rebuild_recipes()


func _rebuild_enchantment(chosen: Item) -> void:
	var main := menu.main
	analyze_button.hide()
	dismantle_button.hide()
	chosen_label.text = "Выберите предмет из списка."
	if chosen != null:
		var definition: ItemDef = main.gd.items[chosen.def_id]
		chosen_label.text = "%s +%d" % [definition.name, chosen.plus]
	enchant_target = chosen
	enchant_donor = null
	enchant_button.visible = chosen != null and chosen.plus < Enhancer.max_plus(chosen, main.gd)
	if enchant_button.visible:
		for donor: Item in main.inv.items:
			if donor != chosen and donor.def_id == chosen.def_id and donor.plus == chosen.plus and (enchant_donor == null or donor.fail_streak < enchant_donor.fail_streak):
				enchant_donor = donor
		enchant_button.disabled = not Enhancer.enchant_error(chosen, enchant_donor, main.inv).is_empty()
		enchant_button.tooltip_text = "Нужны второй такой же предмет с тем же усилением в сумке и камни закалки."
	note_label.show()
	note_label.text = "Нужны второй такой же предмет с тем же усилением и камни закалки."
	if chosen != null and not enchant_button.visible:
		note_label.text = "Достигнут предел зачарования."
	elif enchant_donor != null:
		var stones := int(Enhancer.cost(chosen, main.gd).stones)
		note_label.text = "Результат: +%d. Расход: второй предмет и камни закалки ×%d (в сумке: %d)." % [
			chosen.plus + 1, stones, main.inv.material_count(Enhancer.STONE)]
	message_label.text = menu.message
	message_label.visible = not menu.message.is_empty()


func _show_enchant() -> void:
	var main := menu.main
	if not menu.enchant_only or enchant_target == null or not Enhancer.enchant_error(enchant_target, enchant_donor, main.inv).is_empty():
		return
	pending_enchant_target = enchant_target
	pending_enchant_donor = enchant_donor
	var definition: ItemDef = main.gd.items[enchant_target.def_id]
	confirm_enchant.dialog_text = "Предмет станет +%d. Будут израсходованы второй «%s» +%d из сумки и камни закалки ×%d." % [
		enchant_target.plus + 1, definition.name, enchant_donor.plus, Enhancer.cost(enchant_target, main.gd).stones]
	confirm_enchant.popup_centered()


func _confirm_enchant() -> void:
	var main := menu.main
	var target := pending_enchant_target
	var donor := pending_enchant_donor
	pending_enchant_target = null
	pending_enchant_donor = null
	if not menu.enchant_only or target == null or not _all_equipment(main).has(target):
		return
	var error := Enhancer.enchant(target, donor, main.inv)
	if error.is_empty():
		main._save_tomb_checkpoint()
		main.refresh_hud()
		menu.message = "Зачаровано до +%d" % target.plus
	else:
		menu.message = "Не хватает второго предмета или камней закалки."
	menu.rebuild()


func _refresh_craft_status() -> void:
	var main := menu.main
	var progress := main.inv.crafting
	var config: Dictionary = main.gd.rules["crafting"]
	var labels: Array[String] = []
	for profession: String in [CraftProgress.WEAPON, CraftProgress.ARMOR]:
		var name := "Оружейник" if profession == CraftProgress.WEAPON else "Бронник"
		var level := progress.level(profession)
		var xp := int(progress.skills[profession]["xp"])
		var remaining := progress.next_xp(profession, config)
		var experience := "%d/%d XP" % [xp, remaining] if remaining > 0 else "макс."
		labels.append("%s %d · %s · %s" % [name, level, progress.title(profession, config), experience])
	labels.append("Нагрузка: %d/%d" % [progress.workload, int(config["max_workload"])])
	craft_status.text = "\n".join(labels)
	auto_button.text = "Выбрать рецепт для автокрафта"
	if progress.auto_recipe != "":
		var recipe := Crafter.find(main.gd, progress.auto_recipe)
		auto_button.text = "Остановить: " + str(main.gd.items[recipe["output"]].name)
	elif choose_auto_recipe:
		auto_button.text = "Выберите рецепт · Отмена"


func _toggle_auto() -> void:
	var progress := menu.main.inv.crafting
	if progress.auto_recipe != "":
		progress.auto_recipe = ""
		progress.auto_elapsed = 0.0
		choose_auto_recipe = false
	else:
		choose_auto_recipe = not choose_auto_recipe
	menu.rebuild()


func _analyze_selected() -> void:
	var main := menu.main
	var res := Crafter.analyze(inspect_uid, main.inv, Time.get_unix_time_from_system(), main.rng)
	menu.message = "Анализ: +%d XP (×%d)" % [res.xp, res.multiplier] if res.ok else str(CRAFT_ERRORS.get(res.error, res.error))
	menu.rebuild()


func _dismantle_selected() -> void:
	var res := Crafter.dismantle(inspect_uid, menu.main.inv)
	menu.message = "Разобрано: материалы и +%d XP" % res.xp if res.ok else str(CRAFT_ERRORS.get(res.error, res.error))
	menu.rebuild()


func _rebuild_recipes() -> void:
	var main := menu.main
	if recipe_group.item_count == 0:
		recipe_group.add_item("Основные рецепты")
		recipe_group.set_item_metadata(0, "")
		for id in main.gd.equipment_sets:
			var def: Dictionary = main.gd.equipment_sets[id]
			if def.source_loot == "":
				recipe_group.add_item("Ур. %d · %s" % [def.level, def.name])
				recipe_group.set_item_metadata(recipe_group.item_count - 1, id)
		if main.gd.recipes.any(func(r: Dictionary) -> bool: return r.get("equipment_group") == "legendary"):
			recipe_group.add_item("Легендарное оружие")
			recipe_group.set_item_metadata(recipe_group.item_count - 1, "legendary")
		recipe_group.select(0)
	var group: String = recipe_group.get_selected_metadata()
	MenuScreen.clear(craft_list)
	for r in main.gd.recipes:
		if r.get("equipment_group", "") != group:
			continue
		var out := main.gd.items[r["output"]] as ItemDef
		var need: Array[String] = []
		var req := Crafter.requirements(r, main.gd)
		var error := Crafter.craft_error(r, main.inv, main.wallet)
		for mid in r["materials"]:
			need.append("%s %d/%d" % [main.gd.items[mid].name, main.inv.material_count(mid), int(r["materials"][mid])])
		var name := "Оружейник" if req.profession == CraftProgress.WEAPON else "Бронник"
		var requirement := "%s %d · нагрузка %d · +%d XP" % [name, req.level, req.workload, req.xp]
		var lack := "" if error.is_empty() else " · " + str(CRAFT_ERRORS.get(error, error))
		var b: ListButton = LIST_BUTTON.instantiate()
		craft_list.add_child(b)
		b.disabled = not error.is_empty() and not (choose_auto_recipe and error == "workload")
		b.setup("%s%s\n%s\n%s, %d монет" % [out.name, lack, requirement, ", ".join(need), int(r["coins"])],
			UiKit.item_icon(out.id, out), 86.0, 16)
		b.pressed.connect(func():
			if choose_auto_recipe:
				main.inv.crafting.auto_recipe = str(r["id"])
				main.inv.crafting.auto_elapsed = 0.0
				choose_auto_recipe = false
				menu.message = "Автокрафт: " + out.name
			else:
				var res := Crafter.craft(str(r["id"]), main.inv, main.wallet)
				menu.message = ("Создано: %s · +%d XP" % [out.name, res.xp]) if res.ok else str(CRAFT_ERRORS.get(res.error, res.error))
				main.refresh_hud()
			menu.rebuild())
