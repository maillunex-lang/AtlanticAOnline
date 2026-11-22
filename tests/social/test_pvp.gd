extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _state(tier := 1) -> PvpLeague.State:
	var s := PvpLeague.State.new()
	s.tier = tier
	return s


func test_promotion_after_required_win_streak_and_streak_resets() -> void:
	var s := _state(1)  # нужно 2 победы подряд
	assert_str(PvpLeague.apply_result(s, "win", gd)).is_equal("")
	assert_str(PvpLeague.apply_result(s, "loss", gd)).is_equal("")  # с первой ступени не понижают
	assert_int(s.win_streak).is_equal(0)
	PvpLeague.apply_result(s, "win", gd)
	assert_str(PvpLeague.apply_result(s, "win", gd)).is_equal("promoted")
	assert_int(s.tier).is_equal(2)
	assert_int(s.win_streak).is_equal(0)


func test_demotion_after_loss_streak() -> void:
	var s := _state(5)  # понижают после 3 поражений подряд
	PvpLeague.apply_result(s, "loss", gd)
	PvpLeague.apply_result(s, "loss", gd)
	assert_int(s.tier).is_equal(5)
	assert_str(PvpLeague.apply_result(s, "loss", gd)).is_equal("demoted")
	assert_int(s.tier).is_equal(4)


func test_win_breaks_loss_streak_and_draw_changes_nothing() -> void:
	var s := _state(5)
	PvpLeague.apply_result(s, "loss", gd)
	PvpLeague.apply_result(s, "loss", gd)
	PvpLeague.apply_result(s, "draw", gd)
	assert_int(s.loss_streak).is_equal(2)
	PvpLeague.apply_result(s, "win", gd)
	assert_int(s.loss_streak).is_equal(0)
	assert_int(s.draws).is_equal(1)


func test_top_tier_never_promotes_and_rewards() -> void:
	var s := _state(10)
	for i in 20:
		assert_str(PvpLeague.apply_result(s, "win", gd)).is_equal("")
	assert_int(s.tier).is_equal(10)
	assert_int(PvpLeague.reward_coins("win", gd)).is_equal(100)
	assert_int(PvpLeague.reward_coins("loss", gd)).is_equal(20)


func test_matchmaker_pairs_by_tier_and_level_and_widens_over_time() -> void:
	var m := Matchmaker.new(gd)
	assert_str(m.enqueue("low", 5, 1, 0.0).error).is_equal("level_too_low")
	m.enqueue("a", 20, 3, 0.0)
	assert_str(m.enqueue("a", 20, 3, 0.0).error).is_equal("already_queued")
	m.enqueue("b", 20, 5, 0.0)  # разница ступеней 2, в начале допуск 0
	assert_array(m.find_matches(0.0)).is_empty()
	assert_int(m.queue.size()).is_equal(2)
	assert_int(m.tier_gap(30.0)).is_equal(2)
	var pairs := m.find_matches(30.0)
	assert_array(pairs).is_equal([["a", "b"]])
	assert_bool(m.queue.is_empty()).is_true()


func test_matchmaker_level_gap_limit_and_leave() -> void:
	var m := Matchmaker.new(gd)
	m.enqueue("a", 20, 1, 0.0)
	m.enqueue("b", 61, 1, 0.0)  # разница 41, предел допуска 40
	assert_array(m.find_matches(0.0)).is_empty()
	assert_array(m.find_matches(10000.0)).is_empty()
	assert_int(m.level_gap(10000.0)).is_equal(40)
	assert_bool(m.leave("a")).is_true()
	assert_bool(m.leave("a")).is_false()


func test_matchmaker_prefers_longest_waiting_and_unmatched_stay() -> void:
	var m := Matchmaker.new(gd)
	m.enqueue("c", 20, 1, 5.0)
	m.enqueue("a", 20, 1, 0.0)
	m.enqueue("b", 20, 1, 1.0)
	var pairs := m.find_matches(5.0)
	assert_array(pairs).is_equal([["a", "b"]])
	assert_int(m.queue.size()).is_equal(1)
	assert_str(m.queue[0].pid).is_equal("c")


func _squad(weapon: String, atk := 100) -> Squad:
	var sq := Squad.new(gd)
	var h := sq.create_hero(weapon)
	h.set_level(20, gd)
	return sq


func _match(now := 0.0) -> PvpMatch:
	var ua := PvpMatch.build_units(_squad("sword"), gd, BattleRules.SIDE_A, 1)
	var ub := PvpMatch.build_units(_squad("bow"), gd, BattleRules.SIDE_B, 101)
	return PvpMatch.new(gd, "pa", ua, "pb", ub, 5, now)


func test_build_units_places_hero_and_mercs() -> void:
	var sq := _squad("sword")
	var w := {"coins": 5000}
	sq.recruit("archer", "coins", w)
	sq.recruit("adept", "coins", w)
	var us := PvpMatch.build_units(sq, gd, BattleRules.SIDE_A, 1)
	assert_int(us.size()).is_equal(3)
	assert_int(us[0].slot).is_equal(0)
	assert_int(us[1].slot).is_equal(3)
	for u in us:
		assert_int(u.side).is_equal(BattleRules.SIDE_A)


func test_only_current_player_acts_with_own_units() -> void:
	var m := _match()
	assert_str(m.submit("pb", {"type": "wait", "actor": 101}, 1.0).error).is_equal("not_your_turn")
	assert_str(m.submit("zz", {"type": "wait", "actor": 1}, 1.0).error).is_equal("not_a_player")
	assert_str(m.submit("pa", {"type": "wait", "actor": 101}, 1.0).error).is_equal("unknown_unit")
	assert_bool(m.submit("pa", {"type": "wait", "actor": 1}, 1.0).ok).is_true()
	assert_int(m.sim.current_side).is_equal(BattleRules.SIDE_B)  # ход закрылся сам
	assert_bool(m.submit("pb", {"type": "wait", "actor": 101}, 2.0).ok).is_true()


func test_turn_timer_closes_turn_and_resets_deadline() -> void:
	var m := _match(0.0)
	assert_float(m.deadline).is_equal(30.0)
	assert_bool(m.tick(29.0)).is_false()
	assert_bool(m.tick(30.0)).is_true()  # просрочка, ход перешёл к B
	assert_int(m.sim.current_side).is_equal(BattleRules.SIDE_B)
	assert_float(m.deadline).is_equal(60.0)
	assert_int(m.timeouts[BattleRules.SIDE_A]).is_equal(1)


func test_three_timeouts_forfeit_the_match() -> void:
	var m := _match(0.0)
	var t := 0.0
	# A три раза не ходит, B ходит вовремя
	for i in 3:
		t += 30.0
		m.tick(t)  # просрочил A
		if m.finished():
			break
		m.end_turn("pb", t)
	assert_bool(m.finished()).is_true()
	assert_str(m.reason).is_equal("forfeit")
	assert_str(m.winner_pid).is_equal("pb")
	assert_str(m.result_for("pa")).is_equal("loss")
	assert_str(m.result_for("pb")).is_equal("win")
	assert_str(m.submit("pa", {"type": "wait", "actor": 1}, t).error).is_equal("match_over")


func test_forfeit_and_victory() -> void:
	var m := _match()
	assert_str(m.result_for("pa")).is_equal("")
	m.forfeit("pb")
	assert_str(m.result_for("pa")).is_equal("win")
	var us_a: Array[BattleUnit] = [BattleUnit.make(1, 0, 0, {"atk": 500, "hp": 1000})]
	var us_b: Array[BattleUnit] = [BattleUnit.make(101, 1, 0, {"hp": 10})]
	var m2 := PvpMatch.new(gd, "pa", us_a, "pb", us_b, 1, 0.0)
	assert_bool(m2.submit("pa", {"type": "attack", "actor": 1, "target": 101}, 1.0).ok).is_true()
	assert_bool(m2.finished()).is_true()
	assert_str(m2.winner_pid).is_equal("pa")
	assert_str(m2.reason).is_equal("victory")


func test_match_result_updates_league_and_wallet() -> void:
	var us_a: Array[BattleUnit] = [BattleUnit.make(1, 0, 0, {"atk": 500, "hp": 1000})]
	var us_b: Array[BattleUnit] = [BattleUnit.make(101, 1, 0, {"hp": 10})]
	var m := PvpMatch.new(gd, "pa", us_a, "pb", us_b, 1, 0.0)
	m.submit("pa", {"type": "attack", "actor": 1, "target": 101}, 1.0)
	var st_a := PvpPlayerState()
	var st_b := PvpPlayerState()
	PvpLeague.apply_result(st_a, m.result_for("pa"), gd)
	PvpLeague.apply_result(st_b, m.result_for("pb"), gd)
	assert_int(st_a.wins).is_equal(1)
	assert_int(st_b.losses).is_equal(1)
	assert_int(PvpLeague.reward_coins(m.result_for("pa"), gd)).is_equal(100)


func PvpPlayerState() -> PvpLeague.State:
	return PvpLeague.State.new()


func test_draw_by_round_limit() -> void:
	var us_a: Array[BattleUnit] = [BattleUnit.make(1, 0, 0, {"hp": 1000})]
	var us_b: Array[BattleUnit] = [BattleUnit.make(101, 1, 0, {"hp": 1000})]
	var m := PvpMatch.new(gd, "pa", us_a, "pb", us_b, 1, 0.0)
	var rules_rounds := m.sim.rules.max_rounds
	for i in rules_rounds:
		m.end_turn("pa", 0.0)
		m.end_turn("pb", 0.0)
	assert_str(m.result_for("pa")).is_equal("draw")
	assert_str(m.result_for("pb")).is_equal("draw")
