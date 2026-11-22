extends GdUnitTestSuite
## Каталог навыков (WP-47): данные, пассивки, многократные удары, пробитие, вампиризм, статусы, снятие эффектов, пулы героя.

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _rules() -> BattleRules:
	var r := BattleRules.new()
	r.variance_pct = 0
	r.crit_chance_pct = 0
	r.hit_chance_pct = 100
	return r


func _unit(id: int, side: int, slot: int, stats: Dictionary, skill_ids: Array[String] = []) -> BattleUnit:
	var st := {"ap_regen": 100}
	st.merge(stats, true)
	var u := BattleUnit.make(id, side, slot, st)
	u.skill_ids = skill_ids
	return u


func _sim(us: Array[BattleUnit]) -> BattleSim:
	return BattleSim.new(_rules(), us, 1, gd.skills)


func _skill(actor: int, skill: String, target := -1) -> Dictionary:
	return {"type": "skill", "actor": actor, "skill": skill, "target": target}


func test_catalog_is_valid_and_covers_every_weapon() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.skills.size()).is_greater_equal(110)
	var by_weapon := {}
	var passives := 0
	for id in gd.skills:
		var s: SkillDef = gd.skills[id]
		by_weapon[s.weapon] = int(by_weapon.get(s.weapon, 0)) + 1
		if s.passive:
			passives += 1
	for w in WeaponType.ALL:
		assert_int(int(by_weapon.get(w, 0))).is_greater_equal(13)
	assert_int(passives).is_greater_equal(28)


func test_enabled_classes_have_wide_pools_with_slot4_and_spec() -> void:
	for id in gd.classes:
		var c: Dictionary = gd.classes[id]
		if not bool(c["enabled"]):
			continue
		var sk: Dictionary = c["skills"]
		assert_int((sk["base"] as Array).size()).is_greater_equal(11)
		assert_int((sk["slot4"] as Array).size()).is_greater_equal(3)
		assert_int((sk["spec"] as Array).size()).is_greater_equal(1)
		assert_int(gd.mercs["hero_" + id].skill_ids.size()).is_greater(5)


func test_passive_gives_permanent_bonus_and_cannot_be_used() -> void:
	var u := _unit(1, A, 0, {"atk": 100, "hp": 200}, ["sword_mastery", "sword_hardening"])
	var sim := _sim([u, _unit(101, B, 0, {"hp": 100})])
	assert_int(u.stat("atk")).is_equal(106)  # +6% на 1 уровне
	assert_int(u.max_hp).is_equal(216)  # +8% здоровья
	assert_str(sim.can_afford(1, "sword_mastery")).is_equal("passive")
	assert_str(sim.submit(_skill(1, "sword_mastery")).error).is_equal("passive")
	assert_bool(BattleAI.choose(sim, 1).get("skill", "") != "sword_mastery").is_true()


func test_passive_power_grows_with_skill_level() -> void:
	var u := _unit(1, A, 0, {"atk": 1000}, ["sword_mastery"])
	u.skill_levels = {"sword_mastery": 41}  # +60% к силе навыка: 6% -> 9%
	_sim([u, _unit(101, B, 0, {})])
	assert_int(u.stat("atk")).is_equal(1090)  # 6% * 160% = 9% (целочисленно)


func test_multi_hit_skill_strikes_several_times() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_flurry"]), _unit(101, B, 0, {"hp": 1000})])
	var res := sim.submit(_skill(1, "sword_flurry", 101))
	assert_bool(res.ok).is_true()
	assert_int(res.events.filter(func(e): return e["type"] == "damage").size()).is_equal(3)
	assert_int(sim.unit_by_id(101).hp).is_equal(1000 - 3 * 60)


func test_multi_hit_stops_when_target_dies() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_flurry"]), _unit(101, B, 0, {"hp": 50}), _unit(102, B, 1, {"hp": 50})])
	var res := sim.submit(_skill(1, "sword_flurry", 101))
	assert_int(res.events.filter(func(e): return e["type"] == "damage").size()).is_equal(1)


func test_pierce_ignores_part_of_defense() -> void:
	var plain := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_slash", "sword_cleanse_strike"]), _unit(101, B, 0, {"hp": 1000, "def": 100})])
	plain.submit(_skill(1, "sword_slash", 101))
	var lost_plain := 1000 - plain.unit_by_id(101).hp
	var pierce := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_slash", "sword_cleanse_strike"]), _unit(101, B, 0, {"hp": 1000, "def": 100})])
	pierce.submit(_skill(1, "sword_cleanse_strike", 101))
	var lost_pierce := 1000 - pierce.unit_by_id(101).hp
	assert_int(lost_pierce).is_greater(lost_plain * 140 / 120)  # сила 140 против 120 плюс пробитие


func test_lifesteal_heals_the_attacker() -> void:
	var a := _unit(1, A, 0, {"atk": 100, "hp": 500}, ["sword_blood"])
	a.hp = 100
	var sim := _sim([a, _unit(101, B, 0, {"hp": 1000})])
	sim.submit(_skill(1, "sword_blood", 101))
	assert_int(a.hp).is_equal(100 + 130 * 40 / 100)


func test_mp_burn_reduces_target_mana() -> void:
	var foe := _unit(101, B, 0, {"hp": 1000})
	foe.mp = 50
	var sim := _sim([_unit(1, A, 0, {"atk": 100, "intelligence": 0}, ["staff_drain"]), _unit(2, A, 1, {}), foe])  # второй боец держит ход открытым
	var r := sim.submit(_skill(1, "staff_drain", 101))
	assert_str(r.error).is_equal("")
	assert_int(foe.mp).is_less_equal(40)


func test_stun_status_makes_target_skip_next_turn() -> void:
	var foe := _unit(101, B, 0, {"hp": 1000})
	var u := _unit(1, A, 0, {"atk": 100}, ["axe_stunning"])
	gd.skills["axe_stunning"].status_chance = 100
	var sim := _sim([u, _unit(2, A, 1, {}), foe, _unit(102, B, 1, {"hp": 1000})])
	var res := sim.submit(_skill(1, "axe_stunning", 101))
	assert_bool(res.events.any(func(e): return e["type"] == "stunned" and e["unit"] == 101)).is_true()
	assert_bool(foe.stunned).is_true()
	var end := sim.submit({"type": "wait", "actor": 2})  # ход стороны A закончен, начался ход B
	assert_bool(end.events.any(func(e): return e["type"] == "stun_ended" and e["unit"] == 101)).is_true()
	assert_bool(sim.active_ids.has(101)).is_false()


func test_dot_deals_damage_each_turn_and_expires() -> void:
	var foe := _unit(101, B, 0, {"hp": 1000})
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_bleed"]), _unit(2, A, 1, {}), foe])
	sim.submit(_skill(1, "sword_bleed", 101))
	assert_int(foe.dots.size()).is_equal(1)
	var after_hit := foe.hp
	var res := sim.submit({"type": "wait", "actor": 2})  # начался ход B: яд сработал один раз
	assert_bool(res.events.any(func(e): return e["type"] == "dot" and e["target"] == 101)).is_true()
	assert_int(foe.hp).is_less(after_hit)
	assert_int(foe.dots[0]["turns"]).is_equal(2)


func test_dot_can_kill_and_ends_the_battle() -> void:
	var foe := _unit(101, B, 0, {"hp": 1000})
	var sim := _sim([_unit(1, A, 0, {"atk": 1000}, ["sword_bleed"]), _unit(2, A, 1, {}), foe])
	sim.submit(_skill(1, "sword_bleed", 101))
	foe.hp = 1  # осталось меньше, чем даст яд
	sim.submit({"type": "wait", "actor": 2})
	assert_bool(foe.is_alive()).is_false()
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_dispel_removes_debuffs_from_allies_and_buffs_from_enemies() -> void:
	var ally := _unit(1, A, 0, {"atk": 100}, ["sword_cleanse"])
	var foe := _unit(101, B, 0, {"hp": 1000, "def": 10})
	var mage := _unit(2, A, 1, {"atk": 10}, ["staff_disenchant"])
	var sim := _sim([ally, mage, foe])
	ally.stats.add_modifier("weak", "atk", StatBlock.Kind.PERCENT, -30, 3)
	foe.stats.add_modifier("buff", "def", StatBlock.Kind.PERCENT, 50, 3)
	assert_bool(sim.submit(_skill(1, "sword_cleanse")).ok).is_true()
	assert_bool(ally.stats.has_modifier("weak")).is_false()
	assert_bool(sim.submit({"type": "skill", "actor": 2, "skill": "staff_disenchant", "target": 101}).ok).is_true()
	assert_bool(foe.stats.has_modifier("buff")).is_false()


func test_skill_power_per_level_is_one_and_a_half_percent() -> void:
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_slash"]), _unit(101, B, 0, {"hp": 1000})])
	assert_int(sim._skill_level_bonus_pct(1)).is_equal(0)
	assert_int(sim._skill_level_bonus_pct(21)).is_equal(30)
	assert_int(sim._skill_level_bonus_pct(80)).is_equal(118)


func test_validation_catches_broken_new_fields() -> void:
	var s := SkillDef.from_dict({"id": "x_bad", "weapon": "sword", "target": "enemy_one", "effect": "damage", "power_pct": 150, "hits": 4})
	gd.skills["x_bad"] = s
	assert_bool(gd.validate().any(func(e): return "x_bad" in e)).is_true()
	gd.skills.erase("x_bad")
	var p := SkillDef.from_dict({"id": "x_pas", "weapon": "sword", "target": "self", "effect": "modify", "passive": true, "passive_mods": []})
	gd.skills["x_pas"] = p
	assert_bool(gd.validate().any(func(e): return "x_pas" in e)).is_true()


func test_ai_battles_with_every_weapon_catalog_finish_without_errors() -> void:
	for w in WeaponType.ALL:
		var ids: Array[String] = []
		for id in gd.skills:
			if (gd.skills[id] as SkillDef).weapon == w:
				ids.append(id)
		var a := _unit(1, A, 0, {"atk": 40, "hp": 400, "def": 10, "intelligence": 20}, ids)
		var a2 := _unit(2, A, 1, {"atk": 30, "hp": 300}, ids)
		a.is_hero = true
		for u in [a, a2]:
			u.skill_levels = {}
		var b := _unit(101, B, 0, {"atk": 30, "hp": 500, "def": 5})
		var b2 := _unit(102, B, 1, {"atk": 30, "hp": 500, "def": 5})
		var sim := _sim([a, a2, b, b2])
		var steps := 0
		while sim.winner == BattleSim.Winner.NONE and steps < 600:
			steps += 1
			for id in sim.active_ids.duplicate():
				if sim.winner != BattleSim.Winner.NONE:
					break
				var act := sim.unit_by_id(id)
				if act == null or act.acted:
					continue
				var res := sim.submit(BattleAI.choose(sim, id))
				assert_bool(res.ok).override_failure_message("%s: %s" % [w, res.error]).is_true()
		assert_bool(sim.winner != BattleSim.Winner.NONE).override_failure_message("бой с оружием %s не завершён" % w).is_true()


func test_combo_skills_gain_bonus_after_their_setup_skill() -> void:
	var combos := 0
	for id in gd.skills:
		if (gd.skills[id] as SkillDef).group == "combo":
			combos += 1
			assert_str((gd.skills[id] as SkillDef).combo_from).is_not_empty()
	assert_int(combos).is_greater_equal(7)
	var sim := _sim([_unit(1, A, 0, {"atk": 100}, ["sword_bash"]), _unit(2, A, 1, {"atk": 100}, ["sword_lethal"]), _unit(101, B, 0, {"hp": 2000})])
	gd.skills["sword_bash"].status_chance = 0
	sim.submit(_skill(1, "sword_bash", 101))
	var after_bash := sim.unit_by_id(101).hp
	var res := sim.submit(_skill(2, "sword_lethal", 101))
	assert_bool(res.events.any(func(e): return e["type"] == "damage" and e["combo"])).is_true()
	assert_int(after_bash - sim.unit_by_id(101).hp).is_equal(100 * (260 + 80) / 100)
