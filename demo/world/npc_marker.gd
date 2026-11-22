class_name NpcMarker
extends Marker2D
## NPC на карте. Укажите npc_id (из data/npcs.json) и sprite_name (имя файла из demo/assets/chars без .png).
## Подойдите к нему героем, чтобы начать разговор.

@export var npc_id := ""
@export var sprite_name := "captain"
@export var talk_radius := 90.0

var display_name := ""


func _ready() -> void:
	add_to_group("npc_marker")
	($Sprite as Sprite2D).texture = Art.character(sprite_name)


func setup(npc: Dictionary) -> void:
	display_name = str(npc["name"])
	($NameLabel as Label).text = display_name


func set_quest_marker(on: bool) -> void:
	($QuestMark as TextureRect).visible = on


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	($QuestMark as TextureRect).position.y = -128.0 + sin(t * 4.0) * 4.0
