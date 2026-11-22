class_name Hud
extends Control
## HUD карты: герой, опыт, монеты, задания, миникарта, подсказка, кнопка «Меню», джойстик, всплывающее сообщение.
## Сцена scenes/ui/hud.tscn растягивается под любой экран (якоря), положение элементов правится в редакторе.

signal quest_pressed(quest_id: String)

@onready var info_label: Label = %InfoLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var quest_rows: VBoxContainer = %QuestRows
@onready var minimap: Minimap = %Minimap
@onready var hint_label: Label = %HintLabel
@onready var menu_button: Button = %MenuButton
@onready var menu_dot: ColorRect = %MenuDot
@onready var joystick: ScreenStick = %Joystick
@onready var toast_label: Label = %ToastLabel


var _quest_entries: Array[Dictionary] = []
var _expanded_quest := ""


func set_quest_rows(entries: Array[Dictionary]) -> void:
	if _quest_entries == entries:
		return
	_quest_entries = entries
	if not entries.any(func(entry): return entry["id"] == _expanded_quest and entry["details"].size() > 1):
		_expanded_quest = ""
	_render_quests()


func _render_quests() -> void:
	MenuScreen.clear(quest_rows)
	quest_rows.visible = not _quest_entries.is_empty()
	for entry in _quest_entries:
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 0)
		quest_rows.add_child(row)
		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(header)
		var details: Array = entry["details"]
		var multiple := details.size() > 1
		var expanded: bool = entry["id"] == _expanded_quest
		var title := str(entry["title"])
		if multiple:
			title += " · %d/%d" % [entry["done"], details.size()]
		var title_label := Button.new()
		title_label.text = title
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.custom_minimum_size.y = 36
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.tooltip_text = "Пробежать к цели"
		title_label.pressed.connect(func(): quest_pressed.emit(str(entry["id"])))
		title_label.name = "QuestTitle"
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(title_label)
		if multiple:
			var toggle := Button.new()
			toggle.name = "QuestToggle"
			toggle.text = "−" if expanded else "+"
			toggle.tooltip_text = "Свернуть цели" if expanded else "Развернуть цели"
			toggle.custom_minimum_size = Vector2(44, 44)
			toggle.pressed.connect(_toggle_quest.bind(str(entry["id"])))
			header.add_child(toggle)
		if not details.is_empty() and (not multiple or expanded):
			var details_label := _quest_text("\n".join(details), 14)
			details_label.name = "QuestDetails"
			row.add_child(details_label)
	%TopLeft.call_deferred("reset_size")


func _quest_text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _toggle_quest(qid: String) -> void:
	_expanded_quest = "" if _expanded_quest == qid else qid
	_render_quests()


func toast(text: String, color := Color.WHITE) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
