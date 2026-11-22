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


func _unit(id: int, side: int, slot: int, stats: Dictionary, skill_ids: Array[String] = []) -> BattleUnit:
	var u := BattleUnit.make(id, side, slot, stats)
	u.skill_ids = skill_ids
	return u


func _sim(us: Array[BattleUnit]) -> BattleSim:
	return BattleSim.new(_rules(), us, 1, gd.skills)


func _skill(actor: int, skill: String, target := -1) -> Dictionary:
	return {"type": "skill", "actor": actor, "skill": skill, "target": target}


func test_damage_skill_uses_power_and_cost() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["gun_aimed"]), _unit(101, B, 0, {"hp": 1000})])
	var res := sim.submit(_skill(1, "gun_aimed", 101))
	assert_bool(res.ok).is_true()
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 200)  # сила 200%
	assert_int(sim.unit_by_id(1).ap).is_equal(100 - 55)


func test_unknown_or_unlearned_skill_rejected() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 10}, ["gun_shot"]), _unit(101, B, 0, {})])
	assert_str(sim.submit(_skill(1, "nope", 101)).error).is_equal("unknown_skill")
	assert_str(sim.submit(_skill(1, "gun_aimed", 101)).error).is_equal("unknown_skill")


func test_skill_level_raises_power() -> void:
	var u := _unit(1, A, 0, {"atk": 100}, ["gun_shot"])
	u.skill_levels = {"gun_shot": 3}
	var sim := _sim([u, _unit(101, B, 0, {"hp": 1000})])
	sim.submit(_skill(1, "gun_shot", 101))
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 130 * 120 / 100 * 1)  # 130% * (+20%)


func test_melee_skill_respects_front_column_but_ranged_does_not() -> void:
	var back := _unit(102, B, 2, {"hp": 1000})
	var sim := _sim([_unit(1, A, 0, {"atk": 10}, ["sword_slash"]), _unit(101, B, 0, {"hp": 1000}), back])
	assert_str(sim.submit(_skill(1, "sword_slash", 102)).error).is_equal("unreachable")
	var sim2 := _sim([_unit(1, A, 0, {"atk": 10}, ["gun_shot"]), _unit(101, B, 0, {"hp": 1000}), _unit(102, B, 2, {"hp": 1000})])
	assert_bool(sim2.submit(_skill(1, "gun_shot", 102)).ok).is_true()


func test_column_skill_hits_whole_target_column() -> void:
	var us: Array[BattleUnit] = [
		_unit(1, A, 0, {"atk": 100}, ["spear_pierce"]),
		_unit(101, B, 0, {"hp": 1000}), _unit(102, B, 3, {"hp": 1000}), _unit(103, B, 6, {"hp": 1000}),
		_unit(104, B, 1, {"hp": 1000}),
	]
	var sim := _sim(us)
	sim.submit(_skill(1, "spear_pierce", 101))
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 90)
	assert_int(sim.unit_by_id(102).hp).is_equal(1000 - 90)
	assert_int(sim.unit_by_id(103).hp).is_equal(1000 - 90)
	assert_int(sim.unit_by_id(104).hp).is_equal(1000)


func test_all_enemies_skill_hits_everyone_alive() -> void:
	var dead := _unit(103, B, 2, {"hp": 1000})
	dead.hp = 0
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["bow_volley"]), _unit(101, B, 0, {"hp": 1000}), _unit(102, B, 5, {"hp": 1000}), dead])
	sim.submit(_skill(1, "bow_volley"))
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 70)
	assert_int(sim.unit_by_id(102).hp).is_equal(1000 - 70)
	assert_int(sim.unit_by_id(103).hp).is_equal(0)


func test_heal_caps_at_max_hp_and_only_allies() -> void:
	var hurt := _unit(2, A, 1, {"hp": 100})
	hurt.hp = 40
	var sim := _sim([_unit(1, A, 0, {"atk": 20}, ["staff_heal"]), hurt, _unit(101, B, 0, {})])
	assert_str(sim.submit(_skill(1, "staff_heal", 101)).error).is_equal("bad_target")
	var res := sim.submit(_skill(1, "staff_heal", 2))
	assert_bool(res.ok).is_true()
	assert_int(hurt.hp).is_equal(70)  # 20 * 150%
	assert_int(res.events[1].amount).is_equal(30)


func test_buff_changes_stat_and_expires_after_turns() -> void:
	var us: Array[BattleUnit] = [
		_unit(1, A, 0, {"atk": 10, "def": 100}, ["sword_guard"]),
		_unit(2, A, 1, {}), _unit(101, B, 0, {}),
	]
	var sim := _sim(us)
	sim.submit(_skill(1, "sword_guard"))  # защита +40%, срок 3: текущий ход и ещё два хода стороны A
	assert_int(sim.unit_by_id(1).stat("def")).is_equal(140)
	sim.end_turn()  # конец хода B
	sim.end_turn()  # конец второго хода A: осталось 1
	assert_int(sim.unit_by_id(1).stat("def")).is_equal(140)
	sim.end_turn()
	sim.end_turn()  # конец третьего хода A: срок вышел
	assert_int(sim.unit_by_id(1).stat("def")).is_equal(100)


func test_debuff_on_enemy_reduces_defense_and_boosts_following_damage() -> void:
	var us: Array[BattleUnit] = [
		_unit(1, A, 0, {"atk": 100}, ["axe_sunder", "axe_chop"]),
		_unit(2, A, 1, {"atk": 100}, ["axe_chop"]),
		_unit(101, B, 0, {"hp": 1000, "def": 100}),
	]
	var sim := _sim(us)
	sim.submit(_skill(1, "axe_sunder", 101))  # защита врага -30% -> 70
	assert_int(sim.unit_by_id(101).stat("def")).is_equal(70)
	sim.end_turn()  # конец хода B, снова ход A
	sim.submit(_skill(2, "axe_chop", 101))
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 130 * 100 / (100 + 70))  # 130 * 100 / 170 = 76


func test_cooldown_blocks_reuse_then_releases() -> void:
	var us: Array[BattleUnit] = [_unit(1, A, 0, {"atk": 10, "ap_regen": 100}, ["sword_guard"]), _unit(101, B, 0, {})]
	var sim := _sim(us)  # sword_guard: перезарядка 2 хода
	assert_bool(sim.submit(_skill(1, "sword_guard")).ok).is_true()
	sim.end_turn()  # B
	assert_str(sim.submit(_skill(1, "sword_guard")).error).is_equal("on_cooldown")
	sim.end_turn()
	sim.end_turn()
	assert_str(sim.submit(_skill(1, "sword_guard")).error).is_equal("on_cooldown")
	sim.end_turn()
	sim.end_turn()
	assert_bool(sim.submit(_skill(1, "sword_guard")).ok).is_true()


func test_skill_without_ap_rejected() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 10, "ap": 10, "ap_regen": 0}, ["cannon_barrage"]), _unit(101, B, 0, {})])
	assert_str(sim.submit(_skill(1, "cannon_barrage")).error).is_equal("no_ap")


func test_battle_unit_built_from_mercenary() -> void:
	var m := Mercenary.new(1, "gunner", gd)
	m.set_level(10, gd)
	var u := BattleUnit.from_mercenary(m, gd, 5, A, 4)
	assert_int(u.reach).is_equal(BattleUnit.Reach.RANGED)
	assert_array(u.skill_ids).is_equal(["gun_shot"])
	assert_int(u.stat("atk")).is_equal(15 + 10 * 9 / 10)
	assert_int(u.max_hp).is_equal(90 + 80 * 9 / 10)
	var k := BattleUnit.from_mercenary(Mercenary.new(2, "swordsman", gd), gd, 6, A, 0)
	assert_int(k.reach).is_equal(BattleUnit.Reach.MELEE)


func test_full_battle_with_mercenaries_ends_with_a_winner() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 10000}
	for d in ["swordsman", "archer", "adept"]:
		sq.recruit(d, "coins", w)
	var us: Array[BattleUnit] = []
	var slot := 0
	for m in sq.mercs:
		us.append(BattleUnit.from_mercenary(m, gd, m.uid, A, slot))
		slot += 1
	us.append(_unit(101, B, 0, {"hp": 60, "atk": 8}))
	var sim := BattleSim.new(BattleRules.new(), us, 42, gd.skills)
	for i in 200:
		if sim.winner != BattleSim.Winner.NONE:
			break
		if sim.current_side == A:
			sim.submit({"type": "attack", "actor": 1, "target": 101})
			sim.end_turn()
		else:
			sim.submit({"type": "attack", "actor": 101, "target": 1})
			sim.end_turn()
	assert_int(sim.winner).is_not_equal(BattleSim.Winner.NONE)
