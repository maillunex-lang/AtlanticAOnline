class_name TacticalView
extends Control

signal finished(result: String)

enum Mode { SELECT, MOVE, ATTACK, ABILITY }

var sim: TacticalBattle
var selected := -1
var mode := Mode.SELECT
var preview := Vector2i(-1, -1)
var instructions := ""

@onready var board: TacticalBoard = %Board
@onready var title_label: Label = %Title
@onready var goal_label: Label = %Goal
@onready var status_label: Label = %Status
@onready var move_button: Button = %Move
@onready var attack_button: Button = %Attack
@onready var ability_button: Button = %Ability
@onready var end_button: Button = %EndTurn
@onready var exit_button: Button = %Exit


func setup(mission: Dictionary, gd: GameData) -> void:
	var data := mission.duplicate(true)
	for entry in data["units"]:
		if entry.has("mercenary"):
			var definition: MercenaryDef = gd.mercs[entry["mercenary"]]
			entry["name"] = entry.get("name", definition.name)
			board.sprites[int(entry["id"])] = Art.character(Art.merc_sprite(definition.id, definition.weapon))
		else:
			entry["name"] = entry.get("name", gd.monsters[entry["monster"]]["name"])
			board.sprites[int(entry["id"])] = Art.character(Art.monster_sprite(entry["monster"]))
	sim = TacticalBattle.new(data)
	board.sim = sim
	board.cell_pressed.connect(select_cell)
	move_button.pressed.connect(_set_mode.bind(Mode.MOVE))
	attack_button.pressed.connect(_set_mode.bind(Mode.ATTACK))
	ability_button.pressed.connect(_set_mode.bind(Mode.ABILITY))
	end_button.pressed.connect(_end_turn)
	exit_button.pressed.connect(_exit)
	instructions = str(mission["briefing"])
	_refresh()


func select_cell(at: Vector2i) -> void:
	if sim.side != BattleRules.SIDE_A or sim.winner != BattleSim.Winner.NONE:
		return
	var id := sim.unit_at(at)
	match mode:
		Mode.MOVE:
			if sim.move(selected, at):
				_set_mode(Mode.SELECT)
				return
		Mode.ATTACK:
			if sim.attack(selected, id):
				_set_mode(Mode.SELECT)
				return
		Mode.ABILITY:
			if sim.can_target_ability(selected, at):
				if preview == at:
					if sim.cast(selected, at):
						_set_mode(Mode.SELECT)
						return
					instructions = "В области нет врагов."
				else:
					preview = at
					instructions = "Коснитесь той же клетки, чтобы применить навык."
				_refresh()
				return
	if id >= 0 and sim.units[id].side == BattleRules.SIDE_A:
		selected = id
		_set_mode(Mode.SELECT)


func _set_mode(next: Mode) -> void:
	mode = next
	preview = Vector2i(-1, -1)
	match mode:
		Mode.SELECT: instructions = ""
		Mode.MOVE: instructions = "Выберите свободную выделенную клетку."
		Mode.ATTACK: instructions = "Выберите врага в дальности удара."
		Mode.ABILITY: instructions = "Выберите клетку, чтобы увидеть область навыка."
	_refresh()


func _end_turn() -> void:
	sim.end_turn()
	sim.enemy_turn()
	selected = -1
	_set_mode(Mode.SELECT)


func _exit() -> void:
	var result := "flee"
	if sim.winner == BattleSim.Winner.SIDE_A:
		result = "win"
	elif sim.winner == BattleSim.Winner.SIDE_B:
		result = "lose"
	finished.emit(result)


func _refresh() -> void:
	var running := sim.winner == BattleSim.Winner.NONE
	title_label.text = "%s  ·  Раунд %d/%d" % [sim.mission["title"], sim.round_number, sim.mission["round_limit"]]
	var goal := sim.objective()
	goal_label.text = goal.get("text", "Победите всех противников")
	if not running:
		goal_label.text = "Миссия выполнена" if sim.winner == BattleSim.Winner.SIDE_A else "Миссия не выполнена"
		exit_button.text = "Вернуться"
	var status := instructions
	if status == "" and not sim.log_lines.is_empty():
		status = sim.log_lines.back()
	if selected >= 0:
		var unit: BattleUnit = sim.units[selected]
		status = "%s  ·  Здоровье %d/%d  ·  Мана %d%s" % [sim.unit_name(selected), unit.hp, unit.max_hp, unit.mp,
			"   |   " + status if status != "" else ""]
	status_label.text = status if status != "" else "Выберите бойца, чтобы начать ход."
	move_button.disabled = sim.reachable(selected).is_empty()
	attack_button.disabled = sim.attack_targets(selected).is_empty()
	ability_button.disabled = not sim.can_cast(selected)
	var ability := sim.ability(selected)
	ability_button.text = "Навык" if ability.is_empty() else "%s %d×%d" % [ability["name"], ability["area"], ability["area"]]
	end_button.disabled = not running
	board.selected = selected
	board.move_cells.assign(sim.reachable(selected) if mode == Mode.MOVE else [])
	board.targets.assign(sim.attack_targets(selected) if mode == Mode.ATTACK else [])
	board.area_cells.assign(sim.ability_area(selected, preview) if mode == Mode.ABILITY else [])
	board.queue_redraw()
