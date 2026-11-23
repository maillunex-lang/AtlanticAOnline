extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func test_full_auto_requires_license_and_spends_once_per_battle() -> void:
	var policy := PvePolicy.new(gd.rules["pve"])
	policy.begin_battle()
	assert_bool(policy.enable_full_auto(false)).is_false()
	assert_int(policy.auto_points).is_equal(5)
	assert_bool(policy.enable_full_auto(true)).is_true()
	assert_bool(policy.enable_full_auto(true)).is_true()
	assert_int(policy.auto_points).is_equal(4)
	policy.finish_battle("win")
	assert_int(policy.auto_points).is_equal(4)
	policy.begin_battle()
	policy.auto_points = 0
	assert_bool(policy.enable_full_auto(true)).is_false()


func test_manual_battles_award_points_up_to_cap_and_never_on_flee() -> void:
	var policy := PvePolicy.new(gd.rules["pve"])
	for i in 16:
		policy.begin_battle()
		policy.finish_battle("win")
	assert_int(policy.auto_points).is_equal(50)
	policy.auto_points = 10
	policy.begin_battle()
	policy.finish_battle("lose")
	policy.finish_battle("lose")
	assert_int(policy.auto_points).is_equal(15)
	policy.begin_battle()
	policy.finish_battle("flee")
	assert_int(policy.auto_points).is_equal(15)
	policy.begin_battle()
	policy.any_auto_used = true
	policy.finish_battle("win")
	assert_int(policy.auto_points).is_equal(15)


func test_ai_settings_filter_active_skills() -> void:
	var actor := BattleUnit.make(1, A, 0, {"ap": 200})
	actor.skill_ids = ["sword_slash"]
	var sim := BattleSim.new(BattleRules.new(), [actor, BattleUnit.make(101, B, 0)], 8, gd.skills)
	assert_str(BattleAI.choose(sim, 1).type).is_equal("skill")
	assert_str(BattleAI.choose(sim, 1, false).type).is_equal("attack")
	assert_str(BattleAI.choose(sim, 1, true, ["sword_slash"]).type).is_equal("attack")


func test_group_reinforcements_are_targetable_only_after_previous_group_dies() -> void:
	var enc := {
		"enemies": [{"monster": "slime", "slot": 0}],
		"reinforcements": [[{"monster": "slime", "slot": 0}], [{"monster": "slime", "slot": 0}]],
	}
	var units: Array[BattleUnit] = []
	for i in 3:
		units.append(BattleUnit.make(i + 1, A, i, {"atk": 300, "ap": 200}))
	var enemies := EncounterFactory.build_units(enc, gd)
	units.append_array(enemies)
	var sim := BattleSim.new(BattleRules.new(), units, 8)
	assert_array(sim.legal_targets(1)).is_equal([enemies[0].id])
	assert_str(sim.submit({"type": "attack", "actor": 1, "target": enemies[1].id}).error).is_equal("unreachable")
	for i in 3:
		var result := sim.submit({"type": "attack", "actor": i + 1, "target": enemies[i].id})
		assert_bool(result.ok).is_true()
		if i < 2:
			assert_int(sim.winner).is_equal(BattleSim.Winner.NONE)
			assert_int(sim.enemy_wave).is_equal(i + 1)
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_only_marked_monsters_scale_and_steps_are_capped() -> void:
	var enc := {"enemies": [{"monster": "bandit", "slot": 0}, {"monster": "slime", "slot": 1}]}
	var baseline := EncounterFactory.build_units(enc, gd)
	var raised := EncounterFactory.build_units(enc, gd, 100)
	var same := EncounterFactory.build_units(enc, gd, 14)
	assert_int(raised[0].max_hp).is_equal(baseline[0].max_hp * 148 / 100)
	assert_int(raised[0].max_hp).is_equal(same[0].max_hp)
	assert_int(raised[1].max_hp).is_equal(baseline[1].max_hp)
	assert_int(EncounterFactory.build_units(enc, gd, 1)[0].max_hp).is_less(baseline[0].max_hp)


func test_defeat_and_retreat_losses_and_blessing() -> void:
	var policy := PvePolicy.new(gd.rules["pve"])
	var squad := Squad.new(gd)
	var hero := squad.create_hero("sword")
	var wallet := {"coins": 1500}
	var merc: Mercenary = squad.recruit("archer", "coins", wallet).merc
	hero.xp = 31
	merc.xp = 29
	var units: Array[BattleUnit] = [
		BattleUnit.from_mercenary(hero, gd, 1, A, 0),
		BattleUnit.from_mercenary(merc, gd, merc.uid + 1, A, 1),
		BattleUnit.make(101, B, 0),
	]
	var sim := BattleSim.new(BattleRules.new(), units, 8)
	assert_dict(policy.apply_losses(squad, wallet, sim, "flee", true)).is_equal({"coins": 0, "xp": 0})
	assert_int(policy.victory_xp(30, true)).is_equal(45)
	# Потеря опыта по таблице: 0,1% опыта уровня, минимум 1 (на 1 уровне нужно 42).
	assert_dict(policy.apply_losses(squad, wallet, sim, "flee", false)).is_equal({"coins": 120, "xp": 2})
	assert_int(wallet.coins).is_equal(1080)
	assert_int(hero.xp).is_equal(30)
	units[1].hp = 0
	assert_dict(policy.apply_losses(squad, wallet, sim, "win", false)).is_equal({"coins": 0, "xp": 1})
	assert_int(hero.xp).is_equal(30)
	assert_int(merc.xp).is_equal(27)


func test_mercenary_auto_leaves_hero_and_excluded_fighters_manual() -> void:
	var units: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"hero": true}),
		BattleUnit.make(2, A, 1),
		BattleUnit.make(3, A, 2),
		BattleUnit.make(101, B, 0),
	]
	var view := BattleView.new()
	view.sim = BattleSim.new(BattleRules.new(), units, 8)
	view.settings = DemoSettings.new()
	view.settings.auto_mercs_only = true
	view.settings.auto_disabled_units[1] = true
	view.pve = PvePolicy.new(gd.rules["pve"])
	view.pve.begin_battle()
	assert_bool(view._enable_auto()).is_true()
	assert_int(view.pve.auto_points).is_equal(5)
	assert_int(view._auto_actor()).is_equal(3)
	view.sim.submit({"type": "wait", "actor": 3})
	assert_int(view._auto_actor()).is_equal(-1)
	assert_str(view.sim.can_act(1)).is_empty()
	assert_str(view.sim.can_act(2)).is_empty()
	view.free()


func test_pve_wear_only_affects_participating_units_and_repair_restores_bonuses() -> void:
	var squad := Squad.new(gd)
	var hero := squad.create_hero("sword")
	var wallet := {"coins": 1500}
	var merc: Mercenary = squad.recruit("archer", "coins", wallet).merc
	var inv := Inventory.new(gd)
	hero.set_level(25, gd)
	merc.set_level(25, gd)
	var attack := int(hero.compute_stats(gd).atk)
	var sword := inv.add_equipment("w_sword_2")
	var reserve_armor := inv.add_equipment("a_plate")
	assert_str(hero.equip(sword, inv)).is_empty()
	assert_str(merc.equip(reserve_armor, inv)).is_empty()
	sword.wear = 99
	var hero_unit := BattleUnit.from_mercenary(hero, gd, 1, A, 0)
	var reserve := BattleUnit.from_mercenary(merc, gd, merc.uid + 1, A, 1)
	reserve.participated = false
	var sim := BattleSim.new(BattleRules.new(), [hero_unit, reserve, BattleUnit.make(101, B, 0)], 8)
	assert_dict(PvePolicy.apply_equipment_wear(squad, sim, "lose")).is_equal({"worn": 1, "broken": 1})
	assert_int(sword.wear).is_equal(100)
	assert_int(reserve_armor.wear).is_equal(0)
	assert_int(hero.compute_stats(gd).atk).is_equal(attack)
	assert_bool(sword.repair(gd, {"coins": 199})).is_false()
	wallet.coins = 200
	assert_bool(sword.repair(gd, wallet)).is_true()
	assert_int(wallet.coins).is_equal(0)
	assert_int(hero.compute_stats(gd).atk).is_equal(attack + 15)
	assert_bool(inv.add_equipment("w_sword_1").apply_wear(2, gd)).is_false()
	assert_bool(inv.add_equipment("aurora_sword").apply_wear(2, gd)).is_false()
	sword.plus = 10
	assert_bool(sword.apply_wear(2, gd)).is_false()
