extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _rules() -> BattleRules:
	var r := BattleRules.new()
	r.variance_pct = 0
	r.crit_chance_pct = 0
	return r


func _u(id: int, side: int, slot: int, stats: Dictionary, sk: Array[String] = []) -> BattleUnit:
	var st := {"ap_regen": 100}
	st.merge(stats, true)
	var u := BattleUnit.make(id, side, slot, st)
	u.skill_ids = sk
	return u


func _sim(us: Array[BattleUnit]) -> BattleSim:
	return BattleSim.new(_rules(), us, 1, gd.skills)


func test_can_act_reports_same_reasons_as_submit() -> void:
	var sim := _sim([_u(1, A, 0, {}), _u(101, B, 0, {})])
	assert_str(sim.can_act(1)).is_equal("")
	assert_str(sim.can_act(101)).is_equal("wrong_side")
	assert_str(sim.can_act(99)).is_equal("unknown_unit")
	sim.submit({"type": "wait", "actor": 1})
	assert_str(sim.can_act(1)).is_equal("wrong_side")
	sim.end_turn()
	assert_str(sim.can_act(101)).is_equal("wrong_side")


func test_can_act_already_acted_and_not_active() -> void:
	var sim := _sim([_u(1, A, 0, {}), _u(2, A, 1, {}), _u(3, A, 2, {"ap": 0, "ap_regen": 0}), _u(101, B, 0, {})])
	assert_str(sim.can_act(3)).is_equal("not_active")
	sim.submit({"type": "wait", "actor": 1})
	assert_str(sim.can_act(1)).is_equal("already_acted")
	assert_str(sim.can_act(2)).is_equal("")


func test_can_afford_ap_and_cooldown() -> void:
	var sim := _sim([_u(1, A, 0, {"ap": 30, "ap_regen": 0}, ["sword_slash", "sword_guard"] as Array[String]), _u(101, B, 0, {})])
	assert_str(sim.can_afford(1)).is_equal("no_ap")
	assert_str(sim.can_afford(1, "sword_guard")).is_equal("no_ap")
	var sim2 := _sim([_u(1, A, 0, {"mp": 5}, ["staff_bolt"] as Array[String]), _u(101, B, 0, {})])
	assert_str(sim2.can_afford(1, "staff_bolt")).is_equal("no_mp")
	assert_str(sim2.can_afford(1, "bow_shot")).is_equal("unknown_skill")
	assert_str(sim.can_afford(1, "sword_guard")).is_equal("no_ap")


func test_legal_targets_follow_reach_rules() -> void:
	var us: Array[BattleUnit] = [
		_u(1, A, 0, {}, ["sword_slash"] as Array[String]),
		_u(2, A, 1, {"reach": BattleUnit.Reach.RANGED}, ["gun_shot"] as Array[String]),
		_u(101, B, 0, {}), _u(102, B, 2, {}),
	]
	var sim := _sim(us)
	assert_array(sim.legal_targets(1)).is_equal([101])  # ближний: передняя колонка
	assert_array(sim.legal_targets(2)).is_equal([101, 102])  # дальний: все
	assert_array(sim.legal_targets(1, "sword_slash")).is_equal([101])
	assert_array(sim.legal_targets(2, "gun_shot")).is_equal([101, 102])
	assert_array(sim.legal_targets(1, "sword_guard")).is_empty()  # цель не нужна


func test_legal_targets_for_ally_skill_and_dead_filtered() -> void:
	var dead := _u(3, A, 2, {})
	dead.hp = 0
	var sim := _sim([_u(1, A, 0, {}, ["staff_heal"] as Array[String]), _u(2, A, 1, {}), dead, _u(101, B, 0, {})])
	assert_array(sim.legal_targets(1, "staff_heal")).is_equal([1, 2])
	assert_bool(sim.skill_needs_target("staff_heal")).is_true()
	assert_bool(sim.skill_needs_target("bow_volley")).is_false()


func test_ai_actions_are_always_accepted_by_the_simulation() -> void:
	var us: Array[BattleUnit] = [
		_u(1, A, 0, {"atk": 30, "hp": 300}, ["sword_slash", "sword_guard"] as Array[String]),
		_u(2, A, 1, {"atk": 30, "hp": 300, "reach": BattleUnit.Reach.RANGED}, ["bow_shot", "bow_volley"] as Array[String]),
		_u(3, A, 4, {"atk": 20, "hp": 300, "reach": BattleUnit.Reach.RANGED}, ["staff_bolt", "staff_heal"] as Array[String]),
		_u(101, B, 0, {"atk": 25, "hp": 400}), _u(102, B, 3, {"atk": 25, "hp": 400}), _u(103, B, 2, {"atk": 25, "hp": 400, "reach": BattleUnit.Reach.RANGED}),
	]
	us[0].skill_levels = {"sword_slash": 1}
	var sim := BattleSim.new(BattleRules.new(), us, 7, gd.skills)
	var guard := 0
	while sim.winner == BattleSim.Winner.NONE and guard < 600:
		guard += 1
		var side := sim.current_side
		for u in sim.alive_units(side):
			if sim.winner != BattleSim.Winner.NONE or sim.current_side != side:
				break
			if sim.can_act(u.id) != "":
				continue
			var action := BattleAI.choose(sim, u.id)
			var r := sim.submit(action)
			assert_bool(r.ok).is_true()
		if sim.winner == BattleSim.Winner.NONE and sim.current_side == side:
			sim.end_turn()
	assert_int(sim.winner).is_not_equal(BattleSim.Winner.NONE)


func test_ai_heals_badly_hurt_ally() -> void:
	var hurt := _u(2, A, 1, {"hp": 100})
	hurt.hp = 30
	var sim := _sim([_u(1, A, 0, {"atk": 20}, ["staff_heal"] as Array[String]), hurt, _u(101, B, 0, {})])
	var act := BattleAI.choose(sim, 1)
	assert_str(act.type).is_equal("skill")
	assert_str(act.skill).is_equal("staff_heal")
	assert_int(act.target).is_equal(2)


func test_ai_prefers_strongest_damage_skill_and_weakest_target() -> void:
	var us: Array[BattleUnit] = [
		_u(1, A, 0, {"atk": 50, "reach": BattleUnit.Reach.RANGED}, ["gun_shot", "gun_aimed"] as Array[String]),
		_u(101, B, 0, {"hp": 500}), _u(102, B, 3, {"hp": 100}),
	]
	var sim := _sim(us)
	var act := BattleAI.choose(sim, 1)
	assert_str(act.skill).is_equal("gun_aimed")  # 200% сильнее 130%
	assert_int(act.target).is_equal(102)  # слабейший


func test_ai_waits_without_ap_and_buffs_only_once() -> void:
	var sim := _sim([_u(1, A, 0, {"ap": 5, "ap_regen": 0}), _u(101, B, 0, {})])
	assert_str(BattleAI.choose(sim, 1).type).is_equal("wait")  # не действует: ход пропущен
	var sim2 := _sim([_u(1, A, 0, {"atk": 10}, ["sword_guard"] as Array[String]), _u(2, A, 1, {}), _u(101, B, 0, {})])
	assert_str(BattleAI.choose(sim2, 1).type).is_equal("skill")  # бафф ещё не висит
	sim2.submit({"type": "skill", "actor": 1, "skill": "sword_guard"})
	sim2.end_turn()
	sim2.submit({"type": "wait", "actor": 101})
	assert_str(BattleAI.choose(sim2, 1).type).is_equal("attack")  # бафф уже действует, перезарядка


func test_ai_is_deterministic() -> void:
	var make := func():
		return _sim([_u(1, A, 0, {"atk": 20}, ["sword_slash"] as Array[String]), _u(101, B, 0, {"hp": 50}), _u(102, B, 3, {"hp": 60})])
	assert_dict(BattleAI.choose(make.call(), 1)).is_equal(BattleAI.choose(make.call(), 1))
