class_name UnitView
extends Control
## Боец на экране боя: круг цвета оружия, буква, имя, полоса здоровья, очки действий. Рисуется кодом, без ассетов.

signal clicked(unit_id: int)

const SIZE := Vector2(112, 128)

var unit_id := 0
var display_name := ""
var kind := ""
var is_enemy := false
var max_hp := 1
var hp := 1
var ap := 0
var acted := false
var buffs := 0
var selected := false
var targetable := false
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = SIZE * 0.5


func setup(unit: BattleUnit, p_name: String, p_kind: String) -> void:
	unit_id = unit.id
	display_name = p_name
	kind = p_kind
	is_enemy = unit.side == BattleRules.SIDE_B
	refresh(unit)


func refresh(unit: BattleUnit) -> void:
	max_hp = unit.max_hp
	hp = unit.hp
	ap = unit.ap
	acted = unit.acted
	buffs = unit.stats.modifier_count()
	modulate.a = 1.0 if unit.is_alive() else 0.22
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func set_targetable(v: bool) -> void:
	targetable = v
	queue_redraw()


func _process(delta: float) -> void:
	if targetable or selected:
		_pulse += delta * 6.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(unit_id)
		accept_event()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var c := Vector2(SIZE.x * 0.5, 50)
	# тень и метка команды под ногами
	var team := Color("c0392b") if is_enemy else Color("3f7de0")
	draw_set_transform(Vector2(c.x, c.y + 30), 0.0, Vector2(1.0, 0.33))
	draw_circle(Vector2.ZERO, 38, Color(team.r, team.g, team.b, 0.28))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex: Texture2D = Art.character(kind) if kind != "" else null
	if tex != null:
		var sz := float(Art.CHAR)
		var tint := Color(0.6, 0.6, 0.65) if (acted and not is_enemy) else Color.WHITE
		draw_texture_rect(tex, Rect2(Vector2(c.x - sz * 0.5, c.y - sz * 0.62), Vector2(sz, sz)), false, tint)
	else:
		draw_circle(c, 28, Color("7a7a7a"))
	if selected:
		var r := 40.0 + sin(_pulse) * 2.0
		draw_arc(c + Vector2(0, 2), r, 0.0, TAU, 40, Color("ffe066"), 4.0)
	if targetable:
		var r2 := 40.0 + sin(_pulse) * 3.0
		draw_arc(c + Vector2(0, 2), r2, 0.0, TAU, 40, Color("ff5a4d"), 4.0)
	draw_string(font, Vector2(0, 92), display_name, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 15, Color(1, 1, 1, 0.95), 0, 0, 0)
	# здоровье: полоса с числом внутри
	var bw := 92.0
	var bx := (SIZE.x - bw) * 0.5
	draw_rect(Rect2(bx, 98, bw, 14), Color(0, 0, 0, 0.65))
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var hc := Color("3fae55") if frac > 0.5 else (Color("d68a1a") if frac > 0.25 else Color("c0392b"))
	draw_rect(Rect2(bx, 98, bw * frac, 14), hc)
	draw_string(font, Vector2(bx, 109), "%d" % hp, HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(1, 1, 1, 0.95))
	if not is_enemy:
		draw_string(font, Vector2(bx, 124), "ОД %d" % ap, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9ad0ff"))
	if buffs > 0:
		draw_circle(Vector2(SIZE.x - 22, 22), 9, Color("f1c40f"))
		draw_string(font, Vector2(SIZE.x - 31, 27), "%d" % buffs, HORIZONTAL_ALIGNMENT_CENTER, 18, 13, Color.BLACK)
