extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func test_xp_curve_is_increasing_and_zero_at_cap() -> void:
	assert_int(Progression.xp_to_next(1, gd)).is_equal(100)
	assert_int(Progression.xp_to_next(2, gd)).is_equal(100 + 40 + 6)
	for l in range(1, 59):
		assert_bool(Progression.xp_to_next(l + 1, gd) > Progression.xp_to_next(l, gd)).is_true()
	assert_int(Progression.xp_to_next(60, gd)).is_equal(0)


func test_add_xp_levels_up_with_leftover() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_int(m.add_xp(99, gd)).is_equal(0)
	assert_int(m.add_xp(1, gd)).is_equal(1)
	assert_int(m.level).is_equal(2)
	assert_int(m.xp).is_equal(0)
	assert_int(m.add_xp(146 + 10, gd)).is_equal(1)  # нужно 146 на 2 уровне
	assert_int(m.xp).is_equal(10)


func test_multiple_levels_in_one_award_and_cap() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_bool(m.add_xp(1000, gd) >= 3).is_true()
	m.add_xp(100000000, gd)
	assert_int(m.level).is_equal(60)
	assert_int(m.xp).is_equal(0)
	assert_int(m.add_xp(500, gd)).is_equal(0)


func test_hero_created_once_and_outside_squad_limit() -> void:
	var sq := Squad.new(gd)
	assert_object(sq.create_hero("axe")).is_not_null()
	assert_object(sq.create_hero("axe")).is_null()
	var w := {"coins": 100000}
	for i in 8:
		assert_bool(sq.recruit("swordsman", "coins", w).ok).is_true()
	assert_int(sq.mercs.size()).is_equal(8)  # герой не занимает место
	assert_object(Squad.new(gd).create_hero("laser")).is_null()


func test_participants_get_full_xp_and_bench_half() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 1000}
	var a: Mercenary = sq.recruit("swordsman", "coins", w).merc
	var b: Mercenary = sq.recruit("archer", "coins", w).merc
	sq.award_battle_xp(80, [a.uid])
	assert_int(a.xp).is_equal(80)
	assert_int(b.xp).is_equal(40)


func test_hero_level_up_gives_points_to_every_merc() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 1000}
	sq.recruit("swordsman", "coins", w)
	sq.recruit("archer", "coins", w)
	sq.create_hero("sword")
	var res := sq.award_battle_xp(100)
	assert_int(res.hero_levels).is_equal(1)
	for m in sq.mercs:
		assert_int(m.bonus_points).is_equal(1)
		assert_int(m.skill_points).is_equal(1)
	assert_int(sq.hero.bonus_points).is_equal(0)  # герой очки не получает сам


func test_hero_as_battle_unit_with_skills_and_gear() -> void:
	var sq := Squad.new(gd)
	var inv := Inventory.new(gd)
	var hero := sq.create_hero("gun")
	hero.equip(inv.add_equipment("w_gun_1"), inv)
	var u := BattleUnit.from_mercenary(hero, gd, 1, 0, 0)
	assert_int(u.reach).is_equal(BattleUnit.Reach.RANGED)
	assert_int(u.stat("atk")).is_equal(int(15 * 1.3) + 9)
	assert_array(u.skill_ids).is_equal(["gun_shot"])


func test_full_cycle_loot_craft_enhance_equip_battle() -> void:
	var inv := Inventory.new(gd)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var wallet := {"coins": 5000}
	for i in 20:
		inv.add_drops(LootTable.roll(LootTable.find(gd, "boss_basic"), rng))
	assert_bool(inv.material_count("enhance_stone") > 0).is_true()
	var sword := inv.add_equipment("w_sword_1")
	var plus_before := sword.plus
	for i in 5:
		Enhancer.try_enhance(sword, inv, wallet, rng)
	assert_bool(sword.plus > plus_before).is_true()
	var sq := Squad.new(gd)
	var m: Mercenary = sq.recruit("swordsman", "coins", wallet).merc
	assert_str(m.equip(sword, inv)).is_equal("")
	assert_bool(m.compute_stats(gd).atk > 12 + 6).is_true()
