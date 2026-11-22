class_name PvpMatch
extends RefCounted
## Матч PvP между двумя игроками на BattleSim. Таймер хода: при просрочке ход закрывается сам,
## после max_timeouts просрочек игрок проигрывает. Время передаётся явно (секунды).

var sim: BattleSim
var player_a := ""
var player_b := ""
var gd: GameData
var deadline := 0.0
var winner_pid := ""
var reason := ""
var timeouts := {BattleRules.SIDE_A: 0, BattleRules.SIDE_B: 0}
var _turn_key := ""


## Бойцы игрока: герой и наёмники. Расстановка по умолчанию: герой в слоте 0, остальные 3, 6, 1, 4, 7, 2, 5, 8.
static func build_units(squad: Squad, gd: GameData, side: int, id_base: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var slots := [0, 3, 6, 1, 4, 7, 2, 5, 8]
	var fighters: Array[Mercenary] = []
	if squad.hero != null:
		fighters.append(squad.hero)
	fighters.append_array(squad.mercs)
	var ap_bonus := squad.formation_ap_bonus()
	for i in mini(fighters.size(), slots.size()):
		if not fighters[i].enabled:
			continue
		var unit := BattleUnit.from_mercenary(fighters[i], gd, id_base + i, side, slots[i], squad.formation_bonus())
		unit.formation_ap_bonus = ap_bonus
		out.append(unit)
	return out


func _init(p_gd: GameData, pid_a: String, units_a: Array[BattleUnit], pid_b: String, units_b: Array[BattleUnit], seed: int, now: float) -> void:
	gd = p_gd
	player_a = pid_a
	player_b = pid_b
	var all: Array[BattleUnit] = []
	all.append_array(units_a)
	all.append_array(units_b)
	sim = BattleSim.new(BattleRules.new(), all, seed, gd.skills)
	_reset_deadline(now)


func side_of(pid: String) -> int:
	if pid == player_a:
		return BattleRules.SIDE_A
	if pid == player_b:
		return BattleRules.SIDE_B
	return -1


func finished() -> bool:
	return winner_pid != "" or reason != ""


## Действие игрока. Ход выполняет только тот, чья очередь.
func submit(pid: String, action: Dictionary, now: float) -> Dictionary:
	tick(now)
	if finished():
		return {"ok": false, "error": "match_over"}
	var side := side_of(pid)
	if side < 0:
		return {"ok": false, "error": "not_a_player"}
	if side != sim.current_side:
		return {"ok": false, "error": "not_your_turn"}
	var u := sim.unit_by_id(int(action.get("actor", -1)))
	if u == null or u.side != side:
		return {"ok": false, "error": "unknown_unit"}
	var r := sim.submit(action)
	_after(now)
	return r


func end_turn(pid: String, now: float) -> Dictionary:
	tick(now)
	if finished():
		return {"ok": false, "error": "match_over"}
	if side_of(pid) != sim.current_side:
		return {"ok": false, "error": "not_your_turn"}
	var r := sim.end_turn()
	_after(now)
	return r


## Проверить просрочку хода. Возвращает true, если ход был закрыт принудительно.
func tick(now: float) -> bool:
	if finished() or now < deadline:
		return false
	var side := sim.current_side
	timeouts[side] += 1
	if int(timeouts[side]) >= int(gd.social["pvp"]["max_timeouts"]):
		_finish_by_forfeit(side)
		return true
	sim.end_turn()
	_after(now)
	return true


func forfeit(pid: String) -> void:
	var side := side_of(pid)
	if side >= 0 and not finished():
		_finish_by_forfeit(side)


## Итог для игрока: "win", "loss", "draw" или "" пока матч идёт.
func result_for(pid: String) -> String:
	if not finished():
		return ""
	if reason == "draw":
		return "draw"
	return "win" if winner_pid == pid else "loss"


func _after(now: float) -> void:
	if sim.winner == BattleSim.Winner.SIDE_A:
		winner_pid = player_a
		reason = "victory"
	elif sim.winner == BattleSim.Winner.SIDE_B:
		winner_pid = player_b
		reason = "victory"
	elif sim.winner == BattleSim.Winner.DRAW:
		reason = "draw"
	if not finished():
		var key := "%d:%d" % [sim.round_number, sim.current_side]
		if key != _turn_key:
			_reset_deadline(now)


func _reset_deadline(now: float) -> void:
	_turn_key = "%d:%d" % [sim.round_number, sim.current_side]
	deadline = now + float(gd.social["pvp"]["turn_seconds"])


func _finish_by_forfeit(losing_side: int) -> void:
	winner_pid = player_b if losing_side == BattleRules.SIDE_A else player_a
	reason = "forfeit"
