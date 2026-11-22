extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _sim(units: Array[BattleUnit]) -> BattleSim:
	var rules := BattleRules.new()
	rules.crit_chance_pct = 0
	rules.variance_pct = 0
	return BattleSim.new(rules, units, 27, gd.skills)


func _unit(id: int, side: int, slot: int, stats := {}, skills: Array[String] = []) -> BattleUnit:
	var data := {"hp": 1000, "atk": 100, "ap": 100}
	data.merge(stats, true)
	var unit := BattleUnit.make(id, side, slot, data)
	unit.skill_ids = skills
	return unit


func _skill(actor: int, id: String, target: int) -> Dictionary:
	return {"type": "skill", "actor": actor, "skill": id, "target": target}


func test_primary_attributes_transform_stats_and_preserve_flat_bases() -> void:
	var ranged := Mercenary.new(1, "archer", gd)
	var melee := Mercenary.new(2, "spearman", gd)
	var caster := Mercenary.new(3, "adept", gd)
	for merc: Mercenary in [ranged, melee, caster]:
		merc.level = 20
		var before := merc.compute_stats(gd)
		merc.bonus_points = 40
		for stat in ["strength", "dexterity", "vitality", "intelligence"]:
			for i in 10:
				assert_str(merc.allocate(stat, gd)).is_empty()
		assert_str(merc.allocate("strength", gd)).is_equal("no_points")
		var after := merc.compute_stats(gd)
		assert_int(after.def - before.def).is_equal(10)
		assert_int(after.hp - before.hp).is_equal(19)
		assert_int(after.mp - before.mp).is_equal(11)
		assert_int(after.magic_def).is_equal(15)
		assert_int(after.crit).is_equal(1)
		assert_int(after.accuracy).is_equal(2)
		assert_int(after.evasion).is_equal(1)
		assert_int(after.multi_hit).is_equal(1)
		assert_int(after.crit_resist).is_equal(1)
		assert_int(after.atk - before.atk).is_equal(25 if merc == ranged else 10)


func test_reference_hp_formula_at_level_180() -> void:
	var merc := Mercenary.new(1, "adept", gd)
	merc.level = 180
	var cfg: Dictionary = gd.rules["combat_attributes"]["resource"]
	for row in [[1000, 14357], [5000, 195717], [10000, 714917]]:
		assert_int(merc._resource_total(row[0], float(cfg["hp_scale"]), cfg)).is_equal(row[1])


func test_ap_floor_applies_even_to_expensive_actions() -> void:
	var actor := _unit(1, A, 0, {"ap": 50}, ["staff_bolt"])
	gd.skills.staff_bolt.cost_ap = 210
	var sim := _sim([actor, _unit(10, B, 0)])
	assert_bool(sim.submit(_skill(1, "staff_bolt", 10)).ok).is_true()
	assert_int(actor.ap).is_equal(-50)


func test_miss_deals_no_damage_or_stun_progress() -> void:
	var foe := _unit(10, B, 0, {"evasion": 110})
	var sim := _sim([_unit(1, A, 0, {"accuracy": 10}), foe])
	var result := sim.submit({"type": "attack", "actor": 1, "target": 10})
	assert_bool(result.events[0].missed).is_true()
	assert_int(foe.hp).is_equal(1000)
	assert_int(foe.combo).is_equal(0)


func test_accuracy_counteracts_evasion_and_multi_hit_counts_once() -> void:
	var foe := _unit(10, B, 0, {"evasion": 50})
	var sim := _sim([_unit(1, A, 0, {"accuracy": 50, "multi_hit": 100}), foe])
	var result := sim.submit({"type": "attack", "actor": 1, "target": 10})
	assert_bool(result.events[1].multi_hit).is_true()
	assert_int(foe.hp).is_equal(850)
	assert_int(foe.combo).is_equal(1)


func test_critical_resistance_and_magical_defense() -> void:
	var actor := _unit(1, A, 0, {"crit": 100, "ap_regen": 100}, ["staff_bolt"])
	var foe := _unit(10, B, 0, {"def": 999, "magic_def": 100, "crit_resist": 100})
	var sim := _sim([actor, foe])
	var result := sim.submit(_skill(1, "staff_bolt", 10))
	assert_bool(result.events[1].crit).is_false()
	assert_int(foe.hp).is_equal(950)
	assert_int(actor.mp).is_equal(90)
	foe.stats.base["crit_resist"] = 0
	sim.end_turn()
	result = sim.submit(_skill(1, "staff_bolt", 10))
	assert_bool(result.events[1].crit).is_true()
	assert_int(foe.hp).is_equal(875)


func test_revive_rejects_heroes_enemies_and_occupied_slots() -> void:
	var actor := _unit(1, A, 0, {}, ["staff_revive"])
	var fallen := _unit(2, A, 1)
	var blocked := _unit(3, A, 0)
	var hero := _unit(4, A, 2, {"hero": true})
	var foe := _unit(11, B, 1)
	for unit: BattleUnit in [fallen, blocked, hero, foe]:
		unit.hp = 0
	fallen.combo = 2
	fallen.guarding = true
	fallen.stats.add_modifier("temporary", "def", StatBlock.Kind.FLAT, 20, 3)
	var sim := _sim([actor, fallen, blocked, hero, _unit(10, B, 0), foe])
	assert_array(sim.legal_targets(1, "staff_revive")).is_equal([2])
	for id in [1, 3, 4, 11]:
		assert_str(sim.submit(_skill(1, "staff_revive", id)).error).is_equal("bad_target")
	assert_int(actor.mp).is_equal(100)
	var result := sim.submit(BattleAI.choose(sim, 1))
	assert_bool(result.ok).is_true()
	assert_str(result.events[1].type).is_equal("revive")
	assert_int(fallen.hp).is_equal(350)
	assert_int(fallen.ap).is_equal(0)
	assert_int(fallen.combo).is_equal(0)
	assert_int(fallen.stats.modifier_count()).is_equal(0)
	assert_bool(fallen.guarding).is_false()
	assert_int(actor.mp).is_equal(75)
	assert_array(sim.legal_targets(1, "staff_revive")).is_empty()


func test_combo_requires_order_same_target_and_same_side_turn() -> void:
	for case_id in ["match", "other", "reverse", "expired"]:
		var axe := _unit(1, A, 0, {}, ["axe_sunder"])
		var staff := _unit(2, A, 1, {}, ["staff_bolt"])
		var sim := _sim([axe, staff, _unit(10, B, 0), _unit(11, B, 3)])
		if case_id != "reverse":
			assert_bool(sim.submit(_skill(1, "axe_sunder", 10)).ok).is_true()
		if case_id == "expired":
			sim.end_turn()
			sim.end_turn()
		var action := BattleAI.choose(sim, 2) if case_id == "match" else _skill(2, "staff_bolt", 11 if case_id == "other" else 10)
		var result := sim.submit(action)
		assert_bool(result.ok).is_true()
		assert_bool(result.events[1].combo).is_equal(case_id == "match")
		assert_int(result.events[1].damage).is_equal(160 if case_id == "match" else 100)


func test_seeded_demo_balance() -> void:
	for enc_id in ["enc_meadow_slimes", "enc_meadow_wolves", "enc_forest_wolves"]:
		var wins := 0
		for seed in 24:
			var demo := DemoMain.new()
			demo.gd = gd
			demo._setup_party()
			demo._add_smoke_roster()
			var units := demo._player_units()
			demo.free()
			units.append_array(EncounterFactory.build_units(gd.encounters[enc_id], gd))
			var sim := BattleSim.new(BattleRules.new(), units, seed, gd.skills)
			for action_count in 200:
				if sim.winner != BattleSim.Winner.NONE:
					break
				var acted := false
				for id in sim.active_ids:
					if sim.can_act(id) == "":
						assert_bool(sim.submit(BattleAI.choose(sim, id)).ok).is_true()
						acted = true
						break
				if not acted:
					sim.end_turn()
			assert_int(sim.winner).is_not_equal(BattleSim.Winner.NONE)
			if sim.winner == BattleSim.Winner.SIDE_A:
				wins += 1
		print("WP-11 balance %s: %d/24 wins" % [enc_id, wins])
		assert_int(wins).is_greater_equal(20)
