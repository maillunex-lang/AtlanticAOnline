class_name HeroCreate
extends Control
## Экран создания героя: список классов слева, подробности справа, кнопка «Начать игру». Сцена scenes/ui/hero_create.tscn.
## Данные классов берутся из data/classes.json (GameData.classes), доступность из GameData.class_status.
## Закрытые классы показываются серыми с причиной; выбрать можно только доступный.

signal chosen(class_id: String)

const ROLE_NAMES := {"melee": "Ближний бой", "ranged": "Дальний бой", "staff": "Магия"}
const GROUP_NAMES := {"scion": "Потомки Атлантиды", "atlantian": "Атлантиды", "hero": "Особый герой"}
const STAT_NAMES := {"hp_pct": "здоровье отряда", "atk_pct": "атака отряда", "def_pct": "защита отряда", "ap_regen": "очки действий за ход"}

var gd: GameData
var selected := ""
var _buttons: Dictionary = {}

@onready var class_list: VBoxContainer = %ClassList
@onready var title_label: Label = %TitleLabel
@onready var role_label: Label = %RoleLabel
@onready var desc_label: Label = %DescLabel
@onready var stats_label: Label = %StatsLabel
@onready var skills_label: Label = %SkillsLabel
@onready var bonus_label: Label = %BonusLabel
@onready var region_label: Label = %RegionLabel
@onready var note_label: Label = %NoteLabel
@onready var start_button: Button = %StartButton


func setup(p_gd: GameData, preselect := "") -> void:
	gd = p_gd
	for c in class_list.get_children():
		class_list.remove_child(c)
		c.queue_free()
	_buttons.clear()
	var first_open := ""
	for id in gd.class_order:
		var c: Dictionary = gd.classes[id]
		var open := gd.class_status(id) == ""
		var b := (load("res://scenes/ui/list_button.tscn") as PackedScene).instantiate() as ListButton
		class_list.add_child(b)
		var mark := "" if open else "  (закрыт)"
		b.toggle_mode = true
		b.setup("%s   %s%s" % [c["name"], ROLE_NAMES[c["role"]], mark], Art.hero_portrait(id, Art.character(Art.merc_sprite("hero_" + id, str(c["weapon"])))), 64.0, 22)
		b.modulate = Color.WHITE if open else Color(0.62, 0.62, 0.68)
		b.pressed.connect(select.bind(id))
		_buttons[id] = b
		if open and first_open == "":
			first_open = id
	start_button.pressed.connect(func() -> void:
		if selected != "" and gd.class_status(selected) == "":
			chosen.emit(selected))
	select(preselect if gd.classes.has(preselect) else first_open)


func select(id: String) -> void:
	if not gd.classes.has(id):
		return
	selected = id
	var c: Dictionary = gd.classes[id]
	for k in _buttons:
		(_buttons[k] as Button).button_pressed = k == id
	title_label.text = str(c["name"])
	role_label.text = "%s, %s, оружие: %s" % [ROLE_NAMES[c["role"]], GROUP_NAMES[c["group"]], c["weapon_name"]]
	desc_label.text = str(c["description"])
	stats_label.text = "Здоровье %d   Атака %d   Защита %d   Очки действий за ход %d" % [int(c["hp"]), int(c["atk"]), int(c["def"]), int(c["ap_regen"])]
	var names: Array[String] = []
	for sid in c["skills"]["base"]:
		names.append(str((gd.skills[sid] as SkillDef).name) if gd.skills.has(sid) else str(sid))
	skills_label.text = "Навыки: " + (", ".join(names) if not names.is_empty() else "появятся с оружием класса")
	var bonus: Array[String] = []
	for k in c["squad_bonus"]:
		var v := int(c["squad_bonus"][k])
		bonus.append("+%d%s %s" % [v, "" if k == "ap_regen" else "%", STAT_NAMES.get(k, k)])
	bonus_label.text = "Бонус герою и отряду: " + ", ".join(bonus)
	var reg: Dictionary = gd.regions.get(str(c["start_region"]), {})
	region_label.text = "Старт: %s" % str(reg.get("name", c["start_region"]))
	var status := gd.class_status(id)
	note_label.text = {"": "", "disabled": "Класс откроется позже: ждёт оружия и навыков.", "region_locked": "Стартовая область ещё закрыта."}.get(status, "")
	start_button.disabled = status != ""
