extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func test_new_mercenary_knows_only_first_skill() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_array(m.skill_levels.keys()).is_equal(["sword_slash"])


func test_stats_grow_with_level_and_points() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	var s1 := m.compute_stats(gd)
	assert_int(s1.atk).is_equal(12)
	m.set_level(11, gd)
	assert_int(m.compute_stats(gd).atk).is_equal(12 + 10 * 10 / 10)
	m.grant_hero_level_points()
	assert_str(m.allocate("atk", gd)).is_equal("")
	assert_int(m.compute_stats(gd).atk).is_equal(12 + 10 + 2)
	assert_str(m.allocate("atk", gd)).is_equal("no_points")
	assert_str(m.allocate("luck", gd)).is_equal("bad_stat")


func test_learn_skill_rules() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_str(m.learn_skill("sword_guard", gd)).is_equal("level_too_low")  # нужен 5 уровень
	m.set_level(5, gd)
	assert_str(m.learn_skill("sword_guard", gd)).is_equal("no_points")
	m.grant_hero_level_points()
	assert_str(m.learn_skill("sword_guard", gd)).is_equal("")
	assert_str(m.learn_skill("sword_guard", gd)).is_equal("already_learned")
	assert_str(m.learn_skill("bow_shot", gd)).is_equal("not_available")


func test_skill_upgrade_caps_at_book_level_then_max_level() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	for i in 90:
		m.grant_hero_level_points()
	for i in 19:
		assert_str(m.upgrade_skill("sword_slash", gd)).is_equal("")
	assert_int(m.skill_levels["sword_slash"]).is_equal(20)
	assert_str(m.upgrade_skill("sword_slash", gd)).is_equal("need_book")
	var inv := Inventory.new(gd)
	assert_str(m.read_skill_book("sword_slash", inv)).is_equal("no_book")
	for tier in [2, 3, 4]:
		inv.add_material("skill_book_%d" % tier, 1)
		assert_str(m.read_skill_book("sword_slash", inv)).is_equal("level_too_low" if m.skill_levels["sword_slash"] < m.skill_cap("sword_slash", gd) else "")
		for i in 20:
			m.upgrade_skill("sword_slash", gd)
	assert_int(m.skill_levels["sword_slash"]).is_equal(80)
	assert_str(m.upgrade_skill("sword_slash", gd)).is_equal("max_level")
	assert_str(m.read_skill_book("sword_slash", inv)).is_equal("max_book")
	assert_str(m.upgrade_skill("sword_guard", gd)).is_equal("not_learned")


func test_recruit_by_coins_and_by_quest() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 300}
	assert_bool(sq.recruit("swordsman", "coins", w).ok).is_true()
	assert_int(w.coins).is_equal(0)
	assert_str(sq.recruit("swordsman", "coins", w).error).is_equal("no_coins")
	assert_str(sq.recruit("knight", "quest", w, []).error).is_equal("quest_not_done")
	assert_bool(sq.recruit("knight", "quest", w, ["q_recruit_knight"]).ok).is_true()
	assert_str(sq.recruit("lancer", "coins", w).error).is_equal("not_for_sale")


func test_advanced_limited_to_one_and_squad_size_capped() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 100000}
	sq.recruit("knight", "quest", w, ["q_recruit_knight"])
	assert_str(sq.recruit("knight", "quest", w, ["q_recruit_knight"]).error).is_equal("squad_limit")
	for i in 7:
		assert_bool(sq.recruit("swordsman", "coins", w).ok).is_true()
	assert_int(sq.mercs.size()).is_equal(8)
	assert_str(sq.recruit("archer", "coins", w).error).is_equal("squad_full")


func test_retire_gives_shards_by_tier_and_level() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 300}
	var m: Mercenary = sq.recruit("swordsman", "coins", w).merc
	m.set_level(20, gd)
	var res := sq.retire(m.uid, w)
	assert_int(res.shards).is_equal(5 + 10)
	assert_int(w.shards).is_equal(15)
	assert_int(sq.mercs.size()).is_equal(0)
	assert_str(sq.retire(m.uid, w).error).is_equal("unknown_merc")


func test_upgrade_tier_requires_level_and_shards() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 300, "shards": 0}
	var m: Mercenary = sq.recruit("swordsman", "coins", w).merc
	assert_str(sq.upgrade(m.uid, w).error).is_equal("level_too_low")
	m.set_level(20, gd)
	assert_str(sq.upgrade(m.uid, w).error).is_equal("no_shards")
	w.shards = 50
	assert_bool(sq.upgrade(m.uid, w).ok).is_true()
	assert_str(m.def_id).is_equal("knight")
	assert_int(m.level).is_equal(20)
	assert_int(w.shards).is_equal(0)


func test_upgrade_blocked_when_target_already_in_squad() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 1000, "shards": 100}
	sq.recruit("knight", "quest", w, ["q_recruit_knight"])
	var m: Mercenary = sq.recruit("swordsman", "coins", w).merc
	m.set_level(20, gd)
	assert_str(sq.upgrade(m.uid, w).error).is_equal("squad_limit")


func test_hero_level_up_grants_points_to_all() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 1000}
	sq.recruit("swordsman", "coins", w)
	sq.recruit("archer", "coins", w)
	sq.on_hero_level_up()
	for m in sq.mercs:
		assert_int(m.bonus_points).is_equal(1)
		assert_int(m.skill_points).is_equal(1)


func test_promotion_preserves_equipment_skills_and_cannot_double_charge() -> void:
	var sq := Squad.new(gd)
	var bag := Inventory.new(gd)
	var m: Mercenary = sq.recruit("swordsman", "coins", {"coins": 300}).merc
	m.set_level(20, gd)
	var sword := bag.add_equipment("w_sword_1")
	assert_str(m.equip(sword, bag)).is_empty()
	m.skill_levels["sword_slash"] = 3
	m.xp = 23
	assert_str(sq.promote(m.uid, bag)).is_equal("no_materials")
	assert_str(m.def_id).is_equal("swordsman")
	bag.add_material("growth_crystal", 5)
	assert_str(sq.promote(m.uid, bag)).is_empty()
	assert_str(m.def_id).is_equal("knight")
	assert_int(m.xp).is_equal(23)
	assert_int(m.skill_levels["sword_slash"]).is_equal(3)
	assert_bool(m.equipped["weapon"] == sword).is_true()
	assert_int(bag.material_count("growth_crystal")).is_equal(3)
	assert_str(sq.promote(m.uid, bag)).is_equal("level_too_low")
	assert_int(bag.material_count("growth_crystal")).is_equal(3)
	m.set_level(50, gd)
	assert_str(sq.promote(m.uid, bag)).is_empty()
	assert_str(m.def_id).is_equal("paladin")
	assert_array(m.mercenary_promotions).is_equal([20, 50])


func test_hero_promotions_charge_gems_and_stop_at_release_cap() -> void:
	var sq := Squad.new(gd)
	var bag := Inventory.new(gd)
	var m := sq.create_hero("warden")
	m.set_level(120, gd)
	bag.add_material("growth_gem", 15)
	assert_str(sq.promote(m.uid, bag)).is_empty()
	assert_int(m.skill_slot_limit(gd)).is_equal(4)
	assert_str(sq.promote(m.uid, bag)).is_empty()
	assert_int(m.skill_slot_limit(gd)).is_equal(5)
	assert_str(sq.promote(m.uid, bag)).is_equal("level_cap")
	assert_int(bag.material_count("growth_gem")).is_equal(4)


func test_rank_s_uses_extra_material_and_late_thresholds_in_extended_fixture() -> void:
	var sq := Squad.new(gd)
	var bag := Inventory.new(gd)
	var m: Mercenary = sq.recruit("gear_sawyer", "coins", {"coins": 3000}).merc
	# Fixture only. Release max level and XP tables remain unchanged.
	gd.rules["max_level"] = 160
	var xp: Array = gd.xp_tables["s"]
	while xp.size() < 159:
		xp.append(100)
	m.set_level(160, gd)
	bag.add_material("growth_crystal", 12)
	bag.add_material("growth_gem", 51)
	for level in [20, 50, 80, 100, 120, 130, 140, 150, 160]:
		var offer := sq.promotion_offer(m.uid, bag)
		assert_int(int(offer.level)).is_equal(level)
		assert_str(sq.promote(m.uid, bag)).is_empty()
	assert_array(m.mercenary_promotions).is_equal([20, 50, 80, 100, 120, 130, 140, 150, 160])
	assert_int(bag.material_count("growth_crystal")).is_equal(0)
	assert_int(bag.material_count("growth_gem")).is_equal(0)
	assert_str(sq.promote(m.uid, bag)).is_equal("no_upgrade")
