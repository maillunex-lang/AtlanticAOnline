class_name UnitView
extends Control
## Боец на поле боя. Вид задаётся сценой scenes/battle/unit_view.tscn (правится в редакторе), скрипт только наполняет её данными.

signal clicked(unit_id: int)
signal effect_pressed(description: String)

const SIZE := Vector2(112, 132)
## Где у сцены «ноги» бойца: на эту точку ставится центр клетки формации.
const FEET := Vector2(56, 80)

var unit_id := 0
var display_name := ""
var is_enemy := false
var selected := false
var targetable := false
var in_attack_area := false
var _pulse := 0.0
var hero_animation: HeroAnimation
var hero_facing := "east"

@onready var sprite: TextureRect = %Sprite
@onready var ring: TextureRect = %Ring
@onready var team_mark: TextureRect = %TeamMark
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var ap_label: Label = %ApLabel
var effect_skills: Dictionary = {}
var _shown_effects: Array[Dictionary] = []

@onready var status_icons: HBoxContainer = %StatusIcons


func setup(unit: BattleUnit, p_name: String, sprite_name: String) -> void:
	unit_id = unit.id
	display_name = p_name
	is_enemy = unit.side == BattleRules.SIDE_B
	name_label.text = "%s ↑" % p_name if unit.flying else p_name
	if sprite_name != "":
		sprite.texture = Art.character(sprite_name)
	team_mark.modulate = Color("e04b3f") if is_enemy else Color("4a8cf0")
	refresh(unit)


func set_hero_animation(hero_class: String) -> void:
	hero_animation = HeroAnimation.create_for(hero_class)
	if hero_animation == null:
		return
	sprite.texture = null
	sprite.add_child(hero_animation)
	hero_animation.position = FEET - sprite.position
	play_hero_idle()


func play_hero_clip(clip: String, speed: float, keep_pose := false) -> void:
	hero_animation.play(StringName(clip + "_" + hero_facing), speed)
	await hero_animation.animation_finished
	if not keep_pose:
		play_hero_idle()


func play_hero_idle() -> void:
	if hero_animation != null:
		hero_animation.play(StringName("idle_" + hero_facing))


func refresh(unit: BattleUnit, skipped_by_stun := false) -> void:
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_label.text = str(unit.hp)
	var frac := float(unit.hp) / float(maxi(unit.max_hp, 1))
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color("3fae55") if frac > 0.5 else (Color("d68a1a") if frac > 0.25 else Color("c0392b"))
	ap_label.text = "" if is_enemy else "ОД %d" % unit.ap
	_refresh_effects(unit, skipped_by_stun)
	sprite.modulate = Color(0.62, 0.62, 0.68) if (unit.acted and not is_enemy) else Color.WHITE
	var interactive := unit.is_alive() or targetable
	modulate.a = 1.0 if interactive else 0.22
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func _refresh_effects(unit: BattleUnit, skipped_by_stun: bool) -> void:
	var effects: Array[Dictionary] = []
	if unit.is_alive():
		if unit.stunned or skipped_by_stun:
			var stun_text := "Оглушение · пропуск текущего хода" if skipped_by_stun else "Оглушение · пропуск следующего хода"
			effects.append({"icon": "gem", "title": stun_text, "turns": 0})
		if unit.guarding:
			effects.append({"icon": "shield", "title": "Защита · до начала своего хода", "turns": 0})
		for dot in unit.dots:
			effects.append({"icon": "potion_green", "title": "Яд · %d урона за ход" % dot["power"], "turns": int(dot["turns"])})
		for modifier in unit.stats.to_dict()["mods"]:
			if int(modifier["turns"]) <= 0:
				continue
			var skill: SkillDef = effect_skills.get(modifier["id"])
			var title := skill.name if skill != null else ("Усиление" if int(modifier["value"]) > 0 else "Ослабление")
			var icon := "potion_blue" if int(modifier["value"]) > 0 else "potion_red"
			effects.append({"icon": icon, "title": title, "turns": int(modifier["turns"])})
	if effects == _shown_effects:
		return
	_shown_effects = effects
	MenuScreen.clear(status_icons)
	status_icons.visible = not effects.is_empty()
	for i in mini(effects.size(), 3):
		var effect := effects[i]
		var turns := int(effect["turns"])
		_add_effect_button(Art.icon(effect["icon"]), str(turns) if turns > 0 else "", _effect_description(effect))
	if effects.size() > 3:
		var rest: PackedStringArray = []
		for effect in effects.slice(3):
			rest.append(_effect_description(effect))
		_add_effect_button(null, "…", " / ".join(rest))


func _effect_description(effect: Dictionary) -> String:
	var turns := int(effect["turns"])
	return str(effect["title"]) + (" · осталось ходов: %d" % turns if turns > 0 else "")


func _add_effect_button(texture: Texture2D, time_label: String, description: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(27, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = texture
	button.expand_icon = texture != null
	button.text = time_label
	button.tooltip_text = description
	button.add_theme_constant_override("icon_max_width", 13)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(func(): effect_pressed.emit("%s: %s" % [display_name, description]))
	status_icons.add_child(button)


func set_selected(v: bool) -> void:
	selected = v
	_update_ring()


func set_targetable(v: bool) -> void:
	targetable = v
	_update_ring()


func set_in_attack_area(value: bool) -> void:
	in_attack_area = value
	_update_ring()


func _update_ring() -> void:
	ring.visible = selected or targetable or in_attack_area
	ring.modulate = Color("ff5a4d") if targetable else Color("ffe066")
	if in_attack_area:
		ring.modulate = Color("fff1a0")
	set_process(ring.visible)


func _process(delta: float) -> void:
	_pulse += delta * 6.0
	ring.scale = Vector2.ONE * (1.0 + sin(_pulse) * 0.05)
	ring.pivot_offset = ring.size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(unit_id)
		accept_event()
