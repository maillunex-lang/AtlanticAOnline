class_name TownScreen
extends Control

signal closed
signal menu_requested(tab: String)

const ERRORS := {
	"no_coins": "Недостаточно монет.",
	"no_deposit": "Недостаточно монет на счёте.",
	"no_materials": "Не хватает материалов.",
	"bag_full": "В сумке нет места для всей партии.",
	"level_too_low": "Требуется более высокий уровень.",
	"bad_name": "Проверьте длину названия.",
	"already_in_guild": "Вы уже состоите в гильдии.",
	"name_taken": "Это название уже занято.",
	"squad_full": "В отряде нет свободной клетки.",
	"squad_limit": "Достигнут предел этого типа наёмника.",
}

var main: DemoMain
var service := ""
var message := ""

@onready var title_label: Label = %Title
@onready var header: Label = %Header
@onready var status: Label = %Status
@onready var choices: VBoxContainer = %Choices
@onready var content: VBoxContainer = %Content


func setup(p_main: DemoMain, initial: String) -> void:
	main = p_main
	%Close.pressed.connect(func(): closed.emit())
	var zone: Dictionary = main.world.graph.zones[main.world.zone_id]
	title_label.text = str(zone["name"])
	for id in TownServices.services_at(main.gd, zone):
		_button(choices, str(_definition(id)["name"]), _open.bind(id))
	_open(initial)


func _definition(id: String) -> Dictionary:
	return main.gd.town_services["services"].get(id, {})


func _open(id: String) -> void:
	service = id
	message = ""
	_refresh()


func _refresh() -> void:
	MenuScreen.clear(content)
	for child in choices.get_children():
		child.disabled = child.text == _definition(service).get("name")
	var zone: Dictionary = main.world.graph.zones[main.world.zone_id]
	var info := _definition(service)
	header.text = str(info.get("name", "Городские службы"))
	status.text = "Монеты  %d" % int(main.wallet["coins"])
	_text(str(info.get("hint", "")))
	match service:
		"bank":
			var lot := int(info["lot"])
			_text("На счёте: %d монет" % main.town_services.bank_coins)
			_button(content, "Внести %d" % lot, func(): _result(main.town_services.bank(main.world, main.wallet, true)))
			_button(content, "Снять %d" % lot, func(): _result(main.town_services.bank(main.world, main.wallet, false)))
		"shop", "market":
			var stock: Array = _definition("shop")["stock"]
			for i in stock.size():
				var offer: Dictionary = stock[i]
				var row := "%s ×%d · %d монет" % [_item(offer["item"]), offer["count"], offer["coins"]]
				if service == "shop":
					_button(content, row, func(): _result(main.town_services.buy(main.world, main.wallet, main.inv, i)))
				else:
					_text(row)
			if service == "market":
				_button(content, "Открыть торговую точку", _open.bind("shop"))
		"exchange":
			for i in (info["rates"] as Array).size():
				var row: Dictionary = info["rates"][i]
				_button(content, "%s ×%d → %s ×%d" % [_item(row["from"]), row["count"], _item(row["to"]), row["reward"]],
					func(): _result(main.town_services.exchange(main.world, main.inv, i)))
		"travel_agent":
			_button(content, "Открыть карту мира", func(): menu_requested.emit("map"))
		"crafting":
			_button(content, "Открыть кузницу", func(): menu_requested.emit("forge"))
		"guild":
			_guild()
		"recruiter":
			for id in info["offers"]:
				var d: MercenaryDef = main.gd.mercs[id]
				_button(content, "%s · ранг %s · %d монет" % [d.name, d.display_rank(), d.recruit_coins], _recruit.bind(str(id)))
			for id in main.gd.mercs:
				var merc: MercenaryDef = main.gd.mercs[id]
				if not main.log.completed.has(merc.recruit_quest):
					continue
				var quest: Dictionary = main.gd.quests[merc.recruit_quest]
				if main.gd.npcs[quest["turn_in"]]["zone"] == main.world.zone_id:
					_button(content, "%s · за выполненное задание" % merc.name, _recruit.bind(str(id), "quest"))
		"town_hall":
			var kind := TownServices.profile(zone)
			_text({"town": "Город", "outpost": "Аванпост", "capital": "Столица"}.get(kind, ""))
			for district in main.gd.town_services["districts"].get(kind, []):
				var names: PackedStringArray = []
				for id in district["services"]:
					if main.town_services.available(main.world, id):
						names.append(str(_definition(id)["name"]))
				_text("%s · %s" % [district["title"], ", ".join(names)])
				for id in district["services"]:
					if main.town_services.available(main.world, id) and id != service:
						_button(content, "%s · %s" % [district["title"], _definition(id)["name"]], _open.bind(str(id)))
		"inn":
			_text("Бойцов в строю: %d" % main._player_units().filter(func(unit): return unit.reserve_room < 0).size())
	if message != "":
		_text(message)


func _guild() -> void:
	var guild := main.town_guilds.guild_of("demo")
	if guild != null:
		_text("%s · уровень %d · участников %d" % [guild.name, guild.level, guild.members.size()])
		return
	var config: Dictionary = main.gd.social["guild"]
	_text("Основание: уровень %d, %d монет." % [config["create_min_level"], config["create_cost"]])
	var name_field := LineEdit.new()
	name_field.custom_minimum_size.y = 64
	name_field.placeholder_text = "Название гильдии"
	name_field.max_length = int(config["name_max"])
	content.add_child(name_field)
	_button(content, "Основать гильдию", func():
		var result := main.town_guilds.create("demo", name_field.text, main.squad.hero.level, main.wallet)
		_result(str(result.error)))


func _recruit(id: String, method := "coins") -> void:
	var result := main.squad.recruit(id, method, main.wallet, main.log.completed_ids())
	if result.ok:
		for slot in BattleRules.SLOTS_PER_SIDE:
			if main.member_at_slot(slot) == null:
				main.formation[result.merc.uid] = slot
				break
	_result(str(result.error))


func _item(id: String) -> String:
	return (main.gd.items[id] as ItemDef).name


func _result(error: String) -> void:
	message = "Готово." if error.is_empty() else str(ERRORS.get(error, "Операция недоступна."))
	main.refresh_hud()
	_refresh()


func _text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _button(parent: Control, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 64
	button.pressed.connect(callback)
	parent.add_child(button)
