extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B


func _rules() -> BattleRules:
	var r := BattleRules.new()
	r.variance_pct = 0
	r.crit_chance_pct = 0
	return r


## Две стороны по n бойцов: id стороны A = 1..n, стороны B = 101..100+n, слот = индекс.
func _sim(n := 9, stats := {"hp": 10000, "atk": 20}, rules: BattleRules = null, seed := 1) -> BattleSim:
	var us: Array[BattleUnit] = []
	for i in n:
		us.append(BattleUnit.make(1 + i, A, i, stats))
		us.append(BattleUnit.make(101 + i, B, i, stats))
	return BattleSim.new(rules if rules != null else _rules(), us, seed)


func _wait(sim: BattleSim, id: int) -> Dictionary:
	return sim.submit({"type": "wait", "actor": id})


func test_active_set_is_capped_and_takes_highest_ap() -> void:
	var us: Array[BattleUnit] = []
	for i in 9:
		us.append(BattleUnit.make(1 + i, A, i, {"ap": 50 + i * 10}))
		us.append(BattleUnit.make(101 + i, B, i))
	var sim := BattleSim.new(_rules(), us, 1)
	# AP после прироста: 100..180, берутся пятеро с наибольшим: ids 9,8,7,6,5
	assert_int(sim.active_count).is_equal(5)
	assert_array(sim.active_ids).is_equal([9, 8, 7, 6, 5])


func test_units_below_threshold_are_not_active() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"ap": 0, "ap_regen": 0}),
		BattleUnit.make(2, A, 1, {"ap": 100, "ap_regen": 0}),
		BattleUnit.make(101, B, 0),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_array(sim.active_ids).is_equal([2])
	assert_str(_wait(sim, 1).error).is_equal("not_active")


func test_ap_gain_capped_at_max() -> void:
	var us: Array[BattleUnit] = [BattleUnit.make(1, A, 0, {"ap": 290, "ap_regen": 50}), BattleUnit.make(101, B, 0)]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_int(sim.unit_by_id(1).ap).is_equal(299)


func test_first_side_can_be_b() -> void:
	var us: Array[BattleUnit] = [BattleUnit.make(1, A, 0), BattleUnit.make(101, B, 0)]
	var sim := BattleSim.new(_rules(), us, 1, {}, B)
	assert_int(sim.current_side).is_equal(B)
	assert_str(_wait(sim, 1).error).is_equal("wrong_side")


func test_turn_skipped_when_nobody_can_act_and_idle_draw() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"ap": 0, "ap_regen": 0}),
		BattleUnit.make(101, B, 0, {"ap": 0, "ap_regen": 0}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_int(sim.winner).is_equal(BattleSim.Winner.DRAW)


func test_sides_alternate_and_round_increments() -> void:
	var sim := _sim()
	assert_int(sim.current_side).is_equal(A)
	assert_int(sim.round_number).is_equal(1)
	sim.end_turn()
	assert_int(sim.current_side).is_equal(B)
	assert_int(sim.round_number).is_equal(1)
	sim.end_turn()
	assert_int(sim.current_side).is_equal(A)
	assert_int(sim.round_number).is_equal(2)


func test_turn_closes_automatically_when_all_active_acted() -> void:
	var sim := _sim(2)
	assert_bool(_wait(sim, 1).ok).is_true()
	assert_int(sim.current_side).is_equal(A)
	assert_bool(_wait(sim, 2).ok).is_true()
	assert_int(sim.current_side).is_equal(B)


func test_wrong_side_rejected() -> void:
	var sim := _sim()
	assert_str(_wait(sim, 101).error).is_equal("wrong_side")


func test_unit_cannot_act_twice_in_a_turn() -> void:
	var sim := _sim()
	assert_int(sim.active_count).is_equal(5)
	assert_bool(_wait(sim, 1).ok).is_true()
	assert_str(_wait(sim, 1).error).is_equal("already_acted")
	assert_bool(_wait(sim, 2).ok).is_true()
	assert_int(sim.current_side).is_equal(A)  # ход ещё идёт: сходили двое из пяти


func test_unknown_unit_and_bad_action_rejected() -> void:
	var sim := _sim()
	assert_str(_wait(sim, 999).error).is_equal("unknown_unit")
	assert_str(sim.submit({"type": "dance", "actor": 1}).error).is_equal("bad_action")


func test_melee_can_only_hit_front_column() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 20}),
		BattleUnit.make(101, B, 0, {"hp": 1000}),
		BattleUnit.make(102, B, 2, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_str(sim.submit({"type": "attack", "actor": 1, "target": 102}).error).is_equal("unreachable")
	assert_bool(sim.submit({"type": "attack", "actor": 1, "target": 101}).ok).is_true()


func test_ranged_can_hit_back_column() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 20, "reach": BattleUnit.Reach.RANGED}),
		BattleUnit.make(101, B, 0, {"hp": 1000}),
		BattleUnit.make(102, B, 2, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_bool(sim.submit({"type": "attack", "actor": 1, "target": 102}).ok).is_true()


func test_back_column_becomes_reachable_when_front_dies() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 100}),
		BattleUnit.make(2, A, 1, {"atk": 100}),
		BattleUnit.make(101, B, 0, {"hp": 10}),
		BattleUnit.make(102, B, 2, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})  # убит
	assert_bool(sim.submit({"type": "attack", "actor": 2, "target": 102}).ok).is_true()


func test_attack_damage_and_ap_cost() -> void:
	var sim := _sim()
	var res := sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_bool(res.ok).is_true()
	assert_int(sim.unit_by_id(101).hp).is_equal(10000 - 20)
	assert_int(sim.unit_by_id(1).ap).is_equal(0)  # 100 - 100


func test_defense_reduces_damage_and_minimum_is_one() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 20}),
		BattleUnit.make(101, B, 0, {"hp": 100, "def": 100}),
		BattleUnit.make(102, B, 1, {"hp": 100, "def": 100000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_int(sim.unit_by_id(101).hp).is_equal(100 - 10)  # 20 * 100 / (100 + 100)
	var weak: Array[BattleUnit] = [BattleUnit.make(1, A, 0, {"atk": 1}), BattleUnit.make(101, B, 0, {"hp": 100, "def": 100000})]
	sim = BattleSim.new(_rules(), weak, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_int(sim.unit_by_id(101).hp).is_equal(99)


func test_attack_rejected_without_ap() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 20, "ap": 10, "ap_regen": 0}),
		BattleUnit.make(2, A, 1, {"atk": 20, "ap": 100, "ap_regen": 0}),
		BattleUnit.make(101, B, 0, {"hp": 100}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_str(sim.submit({"type": "attack", "actor": 1, "target": 101}).error).is_equal("not_active")
	assert_str(sim.can_afford(1)).is_equal("no_ap")
	assert_bool(sim.submit({"type": "attack", "actor": 2, "target": 101}).ok).is_true()


func test_bad_target_rejected() -> void:
	var sim := _sim()
	assert_str(sim.submit({"type": "attack", "actor": 1, "target": 2}).error).is_equal("bad_target")
	assert_str(sim.submit({"type": "attack", "actor": 1, "target": 999}).error).is_equal("bad_target")


func test_move_into_empty_slot_costs_ap_and_keeps_action() -> void:
	var us: Array[BattleUnit] = [BattleUnit.make(1, A, 0, {"atk": 20}), BattleUnit.make(101, B, 0)]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_bool(sim.submit({"type": "move", "actor": 1, "slot": 5}).ok).is_true()
	assert_int(sim.unit_by_id(1).slot).is_equal(5)
	assert_int(sim.unit_by_id(1).ap).is_equal(50)  # 100 - 50
	assert_bool(sim.unit_by_id(1).acted).is_false()
	assert_str(sim.submit({"type": "move", "actor": 1, "slot": 6}).error).is_equal("already_moved")
	assert_bool(_wait(sim, 1).ok).is_true()  # действие остаётся


func test_move_into_occupied_slot_swaps() -> void:
	var us: Array[BattleUnit] = [BattleUnit.make(1, A, 0), BattleUnit.make(2, A, 1), BattleUnit.make(101, B, 0)]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "move", "actor": 1, "slot": 1})
	assert_int(sim.unit_by_id(1).slot).is_equal(1)
	assert_int(sim.unit_by_id(2).slot).is_equal(0)


func test_move_to_bad_slot_rejected() -> void:
	var sim := _sim()
	assert_str(sim.submit({"type": "move", "actor": 1, "slot": 9}).error).is_equal("bad_slot")
	assert_str(sim.submit({"type": "move", "actor": 1, "slot": 0}).error).is_equal("bad_slot")


func test_ap_gain_at_own_turn_start() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 1, "ap": 70, "ap_regen": 30}),
		BattleUnit.make(101, B, 0, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	assert_int(sim.unit_by_id(1).ap).is_equal(100)
	sim.submit({"type": "attack", "actor": 1, "target": 101})  # 100 -> 0
	assert_int(sim.unit_by_id(1).ap).is_equal(0)
	sim.end_turn()  # конец хода B, снова A: +30
	assert_int(sim.unit_by_id(1).ap).is_equal(30)
	assert_int(sim.current_side).is_equal(B)  # у A не хватает AP: его ход пропущен автоматически


func test_victory_and_no_actions_afterwards() -> void:
	var us: Array[BattleUnit] = [BattleUnit.make(1, A, 0, {"atk": 100}), BattleUnit.make(101, B, 0, {"hp": 10})]
	var sim := BattleSim.new(_rules(), us, 1)
	var res := sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_bool(res.ok).is_true()
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)
	assert_str(_wait(sim, 1).error).is_equal("battle_over")
	assert_str(sim.end_turn().error).is_equal("battle_over")


func test_draw_after_max_rounds() -> void:
	var r := _rules()
	r.max_rounds = 2
	var sim := _sim(1, {"hp": 100}, r)
	for i in 4:
		sim.end_turn()
	assert_int(sim.winner).is_equal(BattleSim.Winner.DRAW)


func test_same_seed_gives_same_log_and_other_seed_differs() -> void:
	var r1 := BattleRules.new()
	var r2 := BattleRules.new()
	var r3 := BattleRules.new()
	var logs: Array = []
	for pair in [[r1, 7], [r2, 7], [r3, 8]]:
		var sim := _sim(1, {"hp": 100000, "atk": 100, "ap_regen": 100}, pair[0], pair[1])
		for i in 30:
			sim.submit({"type": "attack", "actor": 1 if sim.current_side == A else 101, "target": 101 if sim.current_side == A else 1})
			if sim.winner != BattleSim.Winner.NONE:
				break
		logs.append(sim.events_log)
	assert_array(logs[0]).is_equal(logs[1])
	assert_bool(logs[0] == logs[2]).is_false()


func test_snapshot_contains_state() -> void:
	var sim := _sim(2)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	var d := sim.to_dict()
	assert_int(d.side).is_equal(A)
	assert_array(d.active).is_equal([1, 2])
	assert_int(d.units[0].mp).is_equal(100)
	assert_int(d.units.size()).is_equal(4)
	assert_int(d.winner).is_equal(BattleSim.Winner.NONE)



func test_guard_costs_ap_and_raises_defense_until_next_own_turn() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 100, "ap_regen": 100}),
		BattleUnit.make(101, B, 0, {"hp": 1000, "def": 100}),
	]
	var sim := BattleSim.new(_rules(), us, 1, {}, B)
	assert_bool(sim.submit({"type": "guard", "actor": 101}).ok).is_true()
	assert_int(sim.unit_by_id(101).ap).is_equal(50)  # 100 - 50
	assert_bool(sim.unit_by_id(101).guarding).is_true()
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	# защита 100 * 1.5 = 150: урон 100 * 100 / (100 + 150) = 40
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 40)
	# Ход A закрылся сам, начался новый ход B: защита снята.
	assert_int(sim.current_side).is_equal(B)
	assert_bool(sim.unit_by_id(101).guarding).is_false()


func test_three_turns_of_physical_hits_stun_target() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 10, "ap_regen": 100}),
		BattleUnit.make(101, B, 0, {"hp": 10000, "ap_regen": 100}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	for i in 2:
		sim.submit({"type": "attack", "actor": 1, "target": 101})
		assert_bool(sim.unit_by_id(101).stunned).is_false()
		sim.end_turn()  # B ничего не делает
	sim.submit({"type": "attack", "actor": 1, "target": 101})  # третий ход подряд, ход A закрылся
	assert_bool(sim.events_log.any(func(e): return e.type == "stunned")).is_true()
	# Ход B пропущен: оглушённый не действует и не получает AP, оглушение снято.
	assert_bool(sim.events_log.any(func(e): return e.type == "stun_ended")).is_true()
	assert_bool(sim.unit_by_id(101).stunned).is_false()
	assert_int(sim.unit_by_id(101).combo).is_equal(0)
	assert_int(sim.current_side).is_equal(A)


func test_missed_turn_resets_combo() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 10, "ap_regen": 100}),
		BattleUnit.make(101, B, 0, {"hp": 10000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_int(sim.unit_by_id(101).combo).is_equal(1)
	sim.end_turn()
	_wait(sim, 1)  # A ходит, но не бьёт
	assert_int(sim.unit_by_id(101).combo).is_equal(0)


func test_hero_death_ends_battle_even_with_mercenaries_alive() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 100}),
		BattleUnit.make(101, B, 0, {"hp": 10, "hero": true}),
		BattleUnit.make(102, B, 1, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_side_without_hero_loses_only_when_all_dead() -> void:
	var us: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 100}),
		BattleUnit.make(101, B, 0, {"hp": 10}),
		BattleUnit.make(102, B, 1, {"hp": 1000}),
	]
	var sim := BattleSim.new(_rules(), us, 1)
	sim.submit({"type": "attack", "actor": 1, "target": 101})
	assert_int(sim.winner).is_equal(BattleSim.Winner.NONE)
