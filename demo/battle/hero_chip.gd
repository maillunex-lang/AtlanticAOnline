class_name HeroChip
extends Button
## Плитка бойца на нижней панели боя: портрет, здоровье, очки действий. Коснитесь её, чтобы открыть меню действий бойца.

signal chosen(unit_id: int)

var unit_id := 0

@onready var sprite: TextureRect = %Sprite
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var ap_label: Label = %ApLabel
@onready var done_label: Label = %DoneLabel


func setup(unit: BattleUnit, p_name: String, sprite_name: String) -> void:
	unit_id = unit.id
	name_label.text = p_name
	sprite.texture = Art.character(sprite_name)
	pressed.connect(func(): chosen.emit(unit_id))
	refresh(unit, false, false)


func refresh(unit: BattleUnit, can_act: bool, selected: bool) -> void:
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	var frac := float(unit.hp) / float(maxi(unit.max_hp, 1))
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color("3fae55") if frac > 0.5 else (Color("d68a1a") if frac > 0.25 else Color("c0392b"))
	ap_label.text = "ОД %d" % unit.ap
	disabled = not can_act
	done_label.visible = not unit.is_alive() or unit.acted
	done_label.text = "ПАЛ" if not unit.is_alive() else "ХОДИЛ"
	sprite.modulate = Color(0.55, 0.55, 0.6) if (not can_act) else Color.WHITE
	modulate = Color(1.0, 0.95, 0.7) if selected else Color.WHITE
