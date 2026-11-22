class_name BattleSim
extends RefCounted
## Детерминированная симуляция пошагового боя. Не знает про сцены, сеть и UI.
## Сервер использует её как источник истины, клиент для предпросмотра.
##
## Ход стороны: число действующих бойцов растёт с каждым ходом этой стороны
## (1, 2, 3 ... до потолка). Каждый действующий боец выполняет одно действие:
## attack, move или wait. Действия тратят очки действий (AP), которые
## восстанавливаются в начале хода стороны. Ход закрывается сам, когда все
## действующие сходили, либо вызовом end_turn().

enum Winner { NONE = -1, SIDE_A = 0, SIDE_B = 1, DRAW = 2 }

var rules: BattleRules
var units: Array[BattleUnit] = []
var current_side := BattleRules.SIDE_A
var round_number := 1
var side_turns: Array[int] = [0, 0]
var active_count := 0
var acted_count := 0
var winner: int = Winner.NONE
var events_log: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()


func _init(p_rules: BattleRules, p_units: Array[BattleUnit], p_seed: int) -> void:
	rules = p_rules
	units = p_units
	_rng.seed = p_seed
	_begin_turn()


## Подать действие. Формат:
##   {"type": "attack", "actor": id, "target": id}
##   {"type": "move",   "actor": id, "slot": 0..8}
##   {"type": "wait",   "actor": id}
## Возвращает {"ok": bool, "error": String, "events": Array}.
func submit(action: Dictionary) -> Dictionary:
	if winner != Winner.NONE:
		return _fail("battle_over")
	var actor := unit_by_id(int(action.get("actor", -1)))
	if actor == null:
		return _fail("unknown_unit")
	if actor.side != current_side:
		return _fail("wrong_side")
	if not actor.is_alive():
		return _fail("dead")
	if actor.acted:
		return _fail("already_acted")
	if acted_count >= active_count:
		return _fail("active_limit")

	var mark := events_log.size()
	match str(action.get("type", "")):
		"attack":
			var err := _do_attack(actor, action)
			if err != "":
				return _fail(err)
		"move":
			var err := _do_move(actor, action)
			if err != "":
				return _fail(err)
		"wait":
			_emit({"type": "wait", "actor": actor.id})
		_:
			return _fail("bad_action")

	actor.acted = true
	acted_count += 1
	_check_victory()
	if winner == Winner.NONE and acted_count >= active_count:
		_close_turn()
	return {"ok": true, "error": "", "events": events_log.slice(mark)}


## Закончить ход досрочно (оставшиеся бойцы не действуют).
func end_turn() -> Dictionary:
	if winner != Winner.NONE:
		return _fail("battle_over")
	var mark := events_log.size()
	_close_turn()
	return {"ok": true, "error": "", "events": events_log.slice(mark)}


func unit_by_id(id: int) -> BattleUnit:
	for u in units:
		if u.id == id:
			return u
	return null


func alive_units(side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.side == side and u.is_alive():
			out.append(u)
	return out


## Снимок состояния: для переподключения клиента и сохранения.
func to_dict() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append({"id": u.id, "side": u.side, "slot": u.slot, "hp": u.hp, "ap": u.ap, "acted": u.acted})
	return {
		"side": current_side, "round": round_number, "active": active_count,
		"acted": acted_count, "winner": winner, "units": us,
	}


func _begin_turn() -> void:
	side_turns[current_side] += 1
	var alive := alive_units(current_side)
	var n := side_turns[current_side]
	active_count = mini(mini(rules.active_start + (n - 1) * rules.active_growth, rules.active_cap), alive.size())
	acted_count = 0
	for u in alive:
		u.acted = false
		u.ap = mini(rules.ap_max, u.ap + u.ap_regen)
	_emit({"type": "turn_started", "side": current_side, "round": round_number, "active": active_count})


func _close_turn() -> void:
	_emit({"type": "turn_ended", "side": current_side})
	if current_side == BattleRules.SIDE_B:
		round_number += 1
		if round_number > rules.max_rounds:
			winner = Winner.DRAW
			_emit({"type": "battle_ended", "winner": winner})
			return
	current_side = 1 - current_side
	_begin_turn()


func _do_attack(actor: BattleUnit, action: Dictionary) -> String:
	if actor.ap < rules.attack_cost:
		return "no_ap"
	var target := unit_by_id(int(action.get("target", -1)))
	if target == null or not target.is_alive() or target.side == actor.side:
		return "bad_target"
	if actor.reach == BattleUnit.Reach.MELEE and target.column() != _front_column(target.side):
		return "unreachable"
	actor.ap -= rules.attack_cost
	var base := actor.atk * rules.def_scale / (rules.def_scale + maxi(target.def, 0))
	var roll := 100
	if rules.variance_pct > 0:
		roll = _rng.randi_range(100 - rules.variance_pct, 100 + rules.variance_pct)
	var dmg := base * roll / 100
	var crit := rules.crit_chance_pct > 0 and _rng.randi_range(1, 100) <= rules.crit_chance_pct
	if crit:
		dmg = dmg * rules.crit_mult_pct / 100
	dmg = maxi(1, dmg)
	target.hp = maxi(0, target.hp - dmg)
	_emit({"type": "attack", "actor": actor.id, "target": target.id, "damage": dmg, "crit": crit, "killed": not target.is_alive()})
	return ""


func _do_move(actor: BattleUnit, action: Dictionary) -> String:
	var slot := int(action.get("slot", -1))
	if slot < 0 or slot >= BattleRules.SLOTS_PER_SIDE or slot == actor.slot:
		return "bad_slot"
	if actor.ap < rules.move_cost:
		return "no_ap"
	actor.ap -= rules.move_cost
	var other: BattleUnit = null
	for u in alive_units(actor.side):
		if u.slot == slot:
			other = u
	var from := actor.slot
	actor.slot = slot
	if other != null:
		other.slot = from
	_emit({"type": "move", "actor": actor.id, "from": from, "to": slot, "swapped": other.id if other != null else -1})
	return ""


## Передняя занятая колонка стороны: ближняя атака бьёт только по ней.
func _front_column(side: int) -> int:
	var best := BattleRules.GRID_COLS
	for u in alive_units(side):
		best = mini(best, u.column())
	return best


func _check_victory() -> void:
	var a := alive_units(BattleRules.SIDE_A).size()
	var b := alive_units(BattleRules.SIDE_B).size()
	if a == 0 and b == 0:
		winner = Winner.DRAW
	elif b == 0:
		winner = Winner.SIDE_A
	elif a == 0:
		winner = Winner.SIDE_B
	if winner != Winner.NONE:
		_emit({"type": "battle_ended", "winner": winner})


func _emit(e: Dictionary) -> void:
	events_log.append(e)


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code, "events": []}
