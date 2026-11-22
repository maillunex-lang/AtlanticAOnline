class_name NpcMarker
extends Marker2D
## NPC на карте. Укажите npc_id (из data/npcs.json) и sprite_name (имя файла из demo/assets/chars без .png).
## Подойдите к нему героем, чтобы начать разговор.

@export var npc_id := ""
@export var sprite_name := "captain"
@export var talk_radius := 90.0

const QUEST_COLORS := {"main": Color("ffe066"), "daily": Color("77bfff"), "side": Color("87e694")}
var display_name := ""
var _marker_kinds: Array = []
var _marks: Array[Label] = []


static func quest_marker_kind(kind: String) -> String:
	return kind if kind in ["main", "daily"] else "side"


func _ready() -> void:
	add_to_group("npc_marker")
	($Sprite as Sprite2D).texture = Art.character(sprite_name)


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
