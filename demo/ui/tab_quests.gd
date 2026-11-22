class_name TabQuests
extends Control
## Вкладка «Задания»: активные задания с прогрессом и наградой, счётчик ежедневных.

const QUEST_CARD := preload("res://scenes/ui/quest_card.tscn")

var menu: MenuScreen

@onready var title_label: Label = %TitleLabel
@onready var empty_label: Label = %EmptyLabel
@onready var quest_list: VBoxContainer = %QuestList
@onready var summary_label: Label = %SummaryLabel


func rebuild(m: MenuScreen) -> void:
	menu = m
	var main := menu.main
	title_label.text = "Активные задания (%d из %d) · На экране %d/%d" % [main.log.active.size(),
		int(main.gd.rules["quests"]["max_active"]), main.log.hud_quests().size(), QuestLog.HUD_QUEST_LIMIT]
	empty_label.visible = main.log.active.is_empty()
	empty_label.text = "Нет активных заданий. Поговорите с капитаном Орвином в порту (знак «!» над ним)."
	MenuScreen.clear(quest_list)
	for qid in main.log.active:
		var card: QuestCard = QUEST_CARD.instantiate()
		quest_list.add_child(card)
		card.setup(main, qid)
		var navigate := Button.new()
		navigate.text = "К цели задания"
		navigate.mouse_filter = Control.MOUSE_FILTER_PASS
		navigate.custom_minimum_size.y = 48
		navigate.pressed.connect(main.run_to_quest.bind(qid))
		card.get_node("Box").add_child(navigate)
		card.hud_visibility_changed.connect(func(id: String, show_on_hud: bool):
			main.log.set_hud_quest(id, show_on_hud)
			main.refresh_hud()
			menu.rebuild())
		card.abandon.connect(func(id: String): main.log.abandon(id); main.refresh_hud(); menu.rebuild())
	summary_label.text = "Выполнено заданий: %d. Ежедневных взято сегодня: %d из %d." % [main.log.completed_ids().size(), main.log.daily_accepted_count(main.now), int(main.gd.rules["quests"]["max_daily"])]
