class_name EnemySpawn
extends Marker2D
## Группа врагов на карте. Укажите encounter_id (из data/encounters.json): враги и их вид подхватятся сами.
## При контакте героя с группой начинается бой.

@export var encounter_id := ""
@export var contact_radius := 70.0

var alive := true
var back_at := 0.0
var display_name := ""
var enemy_count := 0
var _phase := 0.0


func _ready() -> void:
	add_to_group("enemy_spawn")
	_phase = global_position.x * 0.013


func setup(enc: Dictionary, monsters: Dictionary) -> void:
	display_name = str(enc["name"])
	var sprites := $Sprites as Node2D
	for c in sprites.get_children():
		c.queue_free()
	var list: Array = enc["enemies"]
	enemy_count = list.size()
	var n := mini(list.size(), 4)
	for k in n:
		var m: Dictionary = monsters[list[k]["monster"]]
		var s := Sprite2D.new()
		s.texture = Art.character(Art.monster_sprite(str(m["id"])))
		s.scale = Vector2.ONE * (float(Art.TILE) / maxf(s.texture.get_width(), s.texture.get_height()))
		var off := Vector2(cos(k * TAU / n + 0.6) * 34.0, sin(k * TAU / n + 0.6) * 20.0) if n > 1 else Vector2.ZERO
		s.position = off + Vector2(0, -28)
		s.set_meta("base_y", s.position.y)
		sprites.add_child(s)
	($NameLabel as Label).text = "%s (%d)" % [display_name, enemy_count]


func set_alive(v: bool) -> void:
	alive = v
	visible = v


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var i := 0
	for s in $Sprites.get_children():
		s.position.y = float(s.get_meta("base_y", -28.0)) + sin(t * 3.0 + i * 1.7 + _phase) * 3.0
		i += 1
