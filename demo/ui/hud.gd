class_name Hud
extends Control
## HUD карты: герой, опыт, монеты, задания, миникарта, подсказка, кнопка «Меню», джойстик, всплывающее сообщение.
## Сцена scenes/ui/hud.tscn растягивается под любой экран (якоря), положение элементов правится в редакторе.

@onready var info_label: Label = %InfoLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var quest_label: Label = %QuestLabel
@onready var minimap: Minimap = %Minimap
@onready var hint_label: Label = %HintLabel
@onready var menu_button: Button = %MenuButton
@onready var menu_dot: ColorRect = %MenuDot
@onready var joystick: ScreenStick = %Joystick
@onready var toast_label: Label = %ToastLabel


func toast(text: String, color := Color.WHITE) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
