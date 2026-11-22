class_name UnitView
extends Control
## Боец на поле боя. Вид задаётся сценой scenes/battle/unit_view.tscn (правится в редакторе), скрипт только наполняет её данными.

signal clicked(unit_id: int)

const SIZE := Vector2(112, 132)
## Где у сцены «ноги» бойца: на эту точку ставится центр клетки формации.
const FEET := Vector2(56, 80)

var unit_id := 0
var display_name := ""
var is_enemy := false
var selected := false
var targetable := false
var _pulse := 0.0

@onready var sprite: TextureRect = %Sprite
@onready var ring: TextureRect = %Ring
@onready var team_mark: TextureRect = %TeamMark
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var ap_label: Label = %ApLabel
@onready var buff_badge: Label = %BuffBadge


func setup(unit: BattleUnit, p_name: String, sprite_name: String) -> void:
	unit_id = unit.id
	display_name = p_name
	is_enemy = unit.side == BattleRules.SIDE_B
	name_label.text = p_name
	if sprite_name != "":
		sprite.texture = Art.character(sprite_name)
	team_mark.modulate = Color("e04b3f") if is_enemy else Color("4a8cf0")
	refresh(unit)


func refresh(unit: BattleUnit) -> void:
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_label.text = str(unit.hp)
	var frac := float(unit.hp) / float(maxi(unit.max_hp, 1))
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color("3fae55") if frac > 0.5 else (Color("d68a1a") if frac > 0.25 else Color("c0392b"))
	ap_label.text = "" if is_enemy else "ОД %d" % unit.ap
	var buffs := unit.stats.modifier_count()
	buff_badge.visible = buffs > 0
	buff_badge.text = str(buffs)
	sprite.modulate = Color(0.62, 0.62, 0.68) if (unit.acted and not is_enemy) else Color.WHITE
	modulate.a = 1.0 if unit.is_alive() else 0.22


func set_selected(v: bool) -> void:
	selected = v
	_update_ring()


func set_targetable(v: bool) -> void:
	targetable = v
	_update_ring()


func _update_ring() -> void:
	ring.visible = selected or targetable
	ring.modulate = Color("ff5a4d") if targetable else Color("ffe066")
	set_process(ring.visible)


func _process(delta: float) -> void:
	_pulse += delta * 6.0
	ring.scale = Vector2.ONE * (1.0 + sin(_pulse) * 0.05)
	ring.pivot_offset = ring.size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(unit_id)
		accept_event()
