class_name QuestCard
extends PanelContainer
## Карточка задания в журнале. Сцена scenes/ui/quest_card.tscn.

signal abandon(quest_id: String)

@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var objectives_label: Label = %ObjectivesLabel
@onready var reward_label: Label = %RewardLabel
@onready var abandon_button: Button = %AbandonButton


func setup(main: DemoMain, qid: String) -> void:
	var q: Dictionary = main.gd.quests[qid]
	var lvl := main.squad.hero.level
	var state := main.log.state(qid, main.inv, lvl, main.now)
	var kind: String = {"main": "Основное", "side": "Побочное", "daily": "Ежедневное", "recruit": "Вербовка"}.get(str(q["kind"]), "")
	title_label.text = "%s  [%s]%s" % [q["name"], kind, "   ГОТОВО" if state == "ready" else ""]
	title_label.add_theme_color_override("font_color", Color("7dff9b") if state == "ready" else Color.WHITE)
	desc_label.text = ("" if main.log.uses_legacy_objectives(qid) else str(q["description"]))
	desc_label.visible = not desc_label.text.is_empty()
	var lines: Array[String] = []
	var objs := main.log.objectives_for(qid)
	for i in objs.size():
		lines.append("  - %s: %d/%d" % [objs[i]["text"], main.log.objective_count(qid, i, main.inv, lvl), int(objs[i]["count"])])
	objectives_label.text = "\n".join(lines)
	reward_label.text = "Награда: %s. Сдать: %s" % [main.rewards_text(q["rewards"]), str(main.gd.npcs[q["turn_in"]]["name"])]
	abandon_button.pressed.connect(func(): abandon.emit(qid))
