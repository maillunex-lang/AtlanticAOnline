class_name NpcMarker
extends Marker2D
## NPC на карте. Укажите npc_id (из data/npcs.json) и sprite_name (спрайт персонажа или icon:имя_значка).
## Маршрут жителя задаётся точками в координатах чанка. Последняя точка — дом.

@export var npc_id := ""
@export var sprite_name := "captain"
@export var talk_radius := 90.0
@export var routine := PackedVector2Array()

const PROP_TEXTURES := {
	"fishing_rod": preload("res://assets/world/interaction_props/fishing_rod.png"),
	"trail_tag": preload("res://assets/world/interaction_props/trail_tag.png"),
	"bridge_support": preload("res://assets/world/interaction_props/bridge_support.png"),
	"stone_wheels": preload("res://assets/world/interaction_props/stone_wheels.png"),
	"stone_tablet": preload("res://assets/world/interaction_props/stone_tablet.png"),
	"dock_ledger": preload("res://assets/world/interaction_props/dock_ledger.png"),
	"mooring_post": preload("res://assets/world/interaction_props/mooring_post.png"),
}
const WALK_SPEED := 68.0

const QUEST_COLORS := {"main": Color("ffe066"), "daily": Color("77bfff"), "side": Color("87e694")}
var display_name := ""
var _marker_kinds: Array = []
var _marks: Array[Label] = []
var _work := Vector2.ZERO
var _routine_step := 0
var _routine_direction := 1
var _wait := 0.0
var _walk_time := 0.0


static func quest_marker_kind(kind: String) -> String:
	return kind if kind in ["main", "daily"] else "side"


func _ready() -> void:
	add_to_group("npc_marker")
	var sprite := $Sprite as Sprite2D
	_work = position
	_wait = 4.0 + absi(npc_id.hash()) % 13
	if is_prop():
		sprite.texture = PROP_TEXTURES[sprite_name]
		sprite.scale = Vector2(3, 3)
		sprite.position.y = -25.0
	elif sprite_name.begins_with("icon:"):
		sprite.texture = Art.icon(sprite_name.trim_prefix("icon:"))
	else:
		sprite.texture = Art.character(sprite_name)


func is_prop() -> bool:
	return PROP_TEXTURES.has(sprite_name) or sprite_name.begins_with("icon:")


func advance_routine(delta: float, paused: bool) -> void:
	if routine.is_empty():
		return
	var sprite := $Sprite as Sprite2D
	if paused or _wait > 0.0:
		if not paused:
			_wait = maxf(0.0, _wait - delta)
		sprite.position.y = -32.0
		return
	var destination := _work if _routine_step < 0 else routine[_routine_step]
	var travel := destination - position
	position = position.move_toward(destination, WALK_SPEED * delta)
	if absf(travel.x) > 1.0:
		sprite.flip_h = travel.x < 0.0
	_walk_time += delta
	sprite.position.y = -32.0 - absf(sin(_walk_time * 12.0)) * 4.0
	if position != destination:
		return
	if _routine_step == routine.size() - 1:
		_routine_direction = -1
		_wait = 9.0
	elif _routine_step < 0:
		_routine_direction = 1
		_wait = 16.0
	_routine_step += _routine_direction


func setup(npc: Dictionary) -> void:
	display_name = str(npc["name"])
	($NameLabel as Label).text = display_name


func set_quest_marker(kinds: Array) -> void:
	if kinds == _marker_kinds and not _marks.is_empty():
		return
	_marker_kinds = kinds.duplicate()
	if _marks.is_empty():
		_marks.append($QuestMark as Label)
		for i in 2:
			var mark := $QuestMark.duplicate() as Label
			add_child(mark)
			_marks.append(mark)
	for i in _marks.size():
		var mark := _marks[i]
		mark.visible = i < kinds.size()
		if mark.visible:
			mark.position.x = -20.0 + (float(i) - (kinds.size() - 1) * 0.5) * 24.0
			mark.add_theme_color_override("font_color", QUEST_COLORS[kinds[i]])


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for mark in _marks:
		mark.position.y = -128.0 + sin(t * 4.0) * 4.0
