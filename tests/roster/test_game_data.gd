extends GdUnitTestSuite


func test_data_loads_and_is_consistent() -> void:
	var gd := GameData.load_dir()
	assert_int(gd.weapons.size()).is_equal(7)
	assert_bool(gd.skills.size() >= 21).is_true()
	assert_bool(gd.mercs.size() >= 14).is_true()
	assert_array(gd.validate()).is_empty()


func test_every_weapon_has_basic_and_advanced_merc() -> void:
	var gd := GameData.load_dir()
	for w in WeaponType.ALL:
		var tiers := []
		for id in gd.mercs:
			if (gd.mercs[id] as MercenaryDef).weapon == w:
				tiers.append((gd.mercs[id] as MercenaryDef).tier)
		assert_bool("basic" in tiers and "advanced" in tiers).is_true()


func test_advanced_are_limited_to_one_per_squad() -> void:
	var gd := GameData.load_dir()
	for id in gd.mercs:
		var m: MercenaryDef = gd.mercs[id]
		if m.tier != "basic":
			assert_int(m.squad_limit).is_equal(1)


func test_skill_of_other_weapon_is_reported_by_validation() -> void:
	var gd := GameData.load_dir()
	(gd.mercs["swordsman"] as MercenaryDef).skill_ids.append("bow_shot")
	assert_bool(gd.validate().size() > 0).is_true()
