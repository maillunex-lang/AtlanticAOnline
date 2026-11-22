class_name TabForge
extends Control
## Вкладка «Кузница»: улучшение предметов (шанс, цена) и крафт по рецептам.

const LIST_BUTTON := preload("res://scenes/ui/list_button.tscn")

var menu: MenuScreen

@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var chosen_label: Label = %ChosenLabel
@onready var chance_label: Label = %ChanceLabel
@onready var cost_label: Label = %CostLabel
@onready var note_label: Label = %NoteLabel
@onready var go_button: Button = %GoButton
@onready var message_label: Label = %MessageLabel
@onready var craft_list: VBoxContainer = %CraftList


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
		b.setup("%s +%d%s" % [idef.name, it.plus, "  (надето)" if main.inv.item_by_uid(it.uid) == null else ""], UiKit.item_icon(it.def_id), 48.0, 18)
		b.pressed.connect(func(): menu.sel_forge_item = it.uid; menu.message = ""; menu.rebuild())
	for n in [chance_label, cost_label, note_label, go_button]:
		n.visible = false
	if chosen != null:
		var idef := main.gd.items[chosen.def_id] as ItemDef
		var maxed := chosen.plus >= int(main.gd.rules["enhance"]["max_plus"])
		chosen_label.text = "%s +%d   ->   +%d" % [idef.name, chosen.plus, chosen.plus + 1]
		chosen_label.add_theme_color_override("font_color", UiKit.rarity_color(idef.rarity))
		if maxed:
			chosen_label.text = "%s +%d   (максимум)" % [idef.name, chosen.plus]
		else:
			var cost := Enhancer.cost(chosen, main.gd)
			var ch := Enhancer.chance(chosen, main.gd)
			chance_label.text = "Шанс успеха: %d%%%s" % [ch, ("  (серия неудач: +%d%%)" % (chosen.fail_streak * int(main.gd.rules["enhance"]["fail_streak_bonus_pct"]))) if chosen.fail_streak > 0 else ""]
			cost_label.text = "Цена: %d монет и %d камней закалки (есть %d)" % [cost.coins, cost.stones, main.inv.material_count("enhance_stone")]
			for n in [chance_label, cost_label, note_label, go_button]:
				n.visible = true
			go_button.disabled = int(main.wallet["coins"]) < int(cost.coins) or main.inv.material_count("enhance_stone") < int(cost.stones)
			for c in go_button.pressed.get_connections():
				go_button.pressed.disconnect(c["callable"])
			go_button.pressed.connect(func():
				var r := Enhancer.try_enhance(chosen, main.inv, main.wallet, main.rng)
				if r.ok:
					menu.message = ("Успех! Теперь +%d" % r.plus) if r.success else "Неудача. Предмет цел, шанс следующей попытки выше."
				else:
					menu.message = "Нельзя: %s" % r.error
				main.refresh_hud()
				menu.rebuild())
	else:
		chosen_label.text = "Выберите предмет из списка."
		chosen_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.text = menu.message
	message_label.visible = menu.message != ""
	MenuScreen.clear(craft_list)
	for r in main.gd.recipes:
		var out := main.gd.items[r["output"]] as ItemDef
		var need: Array[String] = []
		var ok := int(main.wallet["coins"]) >= int(r["coins"])
		for mid in r["materials"]:
			var have := main.inv.material_count(mid)
			need.append("%s %d/%d" % [main.gd.items[mid].name, have, int(r["materials"][mid])])
			if have < int(r["materials"][mid]):
				ok = false
		var lack := "" if int(main.wallet["coins"]) >= int(r["coins"]) else "   (не хватает монет)"
		var b: ListButton = LIST_BUTTON.instantiate()
		craft_list.add_child(b)
		b.disabled = not ok
		b.setup("%s%s\n%s, %d монет" % [out.name, lack, ", ".join(need), int(r["coins"])], UiKit.item_icon(out.id), 74.0, 16)
		b.pressed.connect(func():
			var res := Crafter.craft(str(r["id"]), main.inv, main.wallet)
			menu.message = ("Создано: %s" % out.name) if res.ok else "Нельзя: %s" % res.error
			main.refresh_hud()
			menu.rebuild())
