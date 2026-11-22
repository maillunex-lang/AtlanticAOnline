extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func test_tables_match_the_original_numbers() -> void:
	# Суммарный опыт по оригиналу (docs/plan/reference/wiki_numbers.json).
	assert_int(Progression.xp_to_next(1, gd)).is_equal(42)
	assert_int(Progression.total_xp(10, gd)).is_equal(3219)
	assert_int(Progression.total_xp(20, gd)).is_equal(39106)
	assert_int(Progression.total_xp(60, gd)).is_equal(5218628)
	assert_int(Progression.total_xp(100, gd)).is_equal(200000000)
	assert_int(Progression.total_xp(120, gd)).is_equal(2000000000)
	assert_int(Progression.total_xp(200, gd)).is_equal(641325210248255)
	assert_int(Progression.total_xp(100, gd, "dcb")).is_equal(200000000)
	assert_int(Progression.total_xp(100, gd, "a")).is_equal(241200000)
	assert_int(Progression.total_xp(100, gd, "s")).is_equal(290887200)
	for t in ["dcb", "a", "s"]:
		assert_int(Progression.total_xp(120, gd, t)).is_equal(5205000000)  # порог улучшения на 120 уровне


func test_hero_table_covers_200_levels_and_mercenary_tables_120() -> void:
	assert_int(Progression.table_max_level("hero", gd)).is_equal(200)
	for t in ["dcb", "a", "s"]:
		assert_int(Progression.table_max_level(t, gd)).is_equal(120)
	for l in range(1, 200):
		assert_bool(Progression.xp_to_next(l, gd, "hero") >= 0).is_true()
	gd.rules["max_level"] = 200
	for l in range(1, 200):
		assert_int(Progression.xp_to_next(l, gd, "hero")).is_greater(0)
	assert_int(Progression.xp_to_next(200, gd, "hero")).is_equal(0)


func test_higher_ranks_need_more_experience() -> void:
	# Сравниваем суммарный опыт (по уровням шаги в таблицах оригинала не строго упорядочены).
	for l in range(2, 120):
		assert_bool(Progression.total_xp(l, gd, "a") > Progression.total_xp(l, gd, "dcb")).is_true()
		assert_bool(Progression.total_xp(l, gd, "s") > Progression.total_xp(l, gd, "a")).is_true()


func test_zero_at_cap_and_invalid_levels() -> void:
	assert_int(Progression.xp_to_next(120, gd)).is_equal(0)  # предел max_level из правил
	assert_int(Progression.xp_to_next(0, gd)).is_equal(0)
	assert_int(Progression.xp_to_next(500, gd)).is_equal(0)


func test_tables_by_tier_and_explicit_override() -> void:
	assert_str(Mercenary.new(1, "swordsman", gd).xp_table(gd)).is_equal("dcb")
	assert_str(Mercenary.new(2, "hero_warden", gd).xp_table(gd)).is_equal("hero")
	for id in gd.mercs:
		var def: MercenaryDef = gd.mercs[id]
		if def.tier == "elite":
			assert_str(Progression.table_for(def, gd)).is_equal("a")
			break
	var def2: MercenaryDef = gd.mercs["swordsman"]
	def2.xp_table = "s"
	assert_str(Progression.table_for(def2, gd)).is_equal("s")
	assert_int(Mercenary.new(3, "swordsman", gd).xp_to_next(gd)).is_equal(634)


func test_add_xp_levels_up_with_leftover() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_int(m.add_xp(41, gd)).is_equal(0)
	assert_int(m.add_xp(1, gd)).is_equal(1)
	assert_int(m.level).is_equal(2)
	assert_int(m.xp).is_equal(0)
	assert_int(m.add_xp(61 + 10, gd)).is_equal(1)  # на 2 уровне нужно 61
	assert_int(m.xp).is_equal(10)
	assert_int(m.xp_to_next(gd)).is_equal(101)


func test_multiple_levels_in_one_award_and_cap() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	assert_int(m.add_xp(1000, gd)).is_equal(5)  # 42+61+101+165+256 = 625 до 6 уровня; 377 на 7-й не хватает
	assert_int(m.level).is_equal(6)
	assert_int(m.xp).is_equal(375)
	m.add_xp(100000000000, gd)
	assert_int(m.level).is_equal(120)
	assert_int(m.xp).is_equal(0)
	assert_int(m.add_xp(500, gd)).is_equal(0)


func test_death_loss_is_a_small_share_of_the_level() -> void:
	assert_int(Progression.death_loss(100, 1000000, gd)).is_equal(40251)  # 0,1% от 40 251 413 (переход 100 -> 101)
	assert_int(Progression.death_loss(100, 10000, gd)).is_equal(10000)  # не больше накопленного
	assert_int(Progression.death_loss(1, 31, gd)).is_equal(1)  # минимум 1
	assert_int(Progression.death_loss(1, 0, gd)).is_equal(0)
	assert_int(Progression.death_loss(120, 5, gd)).is_equal(0)  # на пределе опыт не копится
	gd.rules["death_xp_loss_permille"] = 0
	assert_int(Progression.death_loss(100, 1000000, gd)).is_equal(1)  # даже при нуле минимум 1, пока есть опыт


func test_slice_pacing_early_levels_use_the_tables() -> void:
	# Герой проходит 1-20 по таблице: на 20 уровне всего 39 106 опыта.
	var sq := Squad.new(gd)
	sq.create_hero("sword")
	var total := 0
	while sq.hero.level < 20:
		var need := sq.hero.xp_to_next(gd)
		total += need
		sq.hero.add_xp(need, gd)
	assert_int(total).is_equal(39106)


func test_validation_catches_broken_xp_data() -> void:
	var bad := GameData.load_dir()
	(bad.xp_tables["dcb"] as Array)[5] = 0
	bad.xp_tables.erase("s")
	bad.rules["xp_table_by_tier"]["elite"] = "z"
	bad.rules["max_level"] = 500
	bad.rules["death_xp_loss_permille"] = 2000
	(bad.mercs["swordsman"] as MercenaryDef).xp_table = "q"
	var t := "\n".join(bad.validate())
	for part in ["xp_tables.dcb: уровень 6", "нет таблицы s", "у ступени elite нет таблицы", "max_level больше таблицы героя", "death_xp_loss_permille должен", "нет таблицы опыта q"]:
		assert_bool(t.contains(part)).is_true()


func test_rewards_are_in_a_sane_band_of_the_level_requirement() -> void:
	# Награда за бой в зоне не больше уровня и не меньше 2%; за задание не больше полутора уровней и не меньше 5%.
	var zone_level := {}
	for z in gd.world["zones"]:
		zone_level[z["id"]] = int(z["min_level"])
	for id in gd.encounters:
		var e: Dictionary = gd.encounters[id]
		var need := Progression.xp_to_next(int(zone_level[e["zone"]]), gd)
		assert_bool(int(e["xp"]) <= need).is_true()
		assert_bool(int(e["xp"]) * 100 >= need * 2).is_true()
	var tutorial_steps: Array = gd.chains["ch_tutorial_harbor"]["steps"]
	for id in gd.quests:
		var q: Dictionary = gd.quests[id]
		if id in tutorial_steps:
			# Обучение можно проходить параллельно с сюжетом без двойного опыта.
			assert_int(int(q["rewards"].get("xp", 0))).is_equal(0)
			continue
		var need := Progression.xp_to_next(int(q["level_min"]), gd)
		var xp := int(q["rewards"].get("xp", 0))
		assert_bool(xp * 100 <= need * 150).is_true()
		assert_bool(xp * 100 >= need * 5).is_true()


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
	sq.award_battle_xp(30, [a.uid])  # меньше 42: уровня ещё нет
	assert_int(a.xp).is_equal(30)
	assert_int(b.xp).is_equal(15)


func test_hero_level_up_gives_points_to_every_merc() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 1000}
	sq.recruit("swordsman", "coins", w)
	sq.recruit("archer", "coins", w)
	sq.create_hero("sword")
	var res := sq.award_battle_xp(42)  # столько нужно герою на 2 уровень
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


func test_explicit_rank_sets_xp_and_scales_growth_with_legacy_compatibility() -> void:
	var fighter := Mercenary.new(1, "kiln_brawler", gd)
	fighter.set_level(11, gd)
	var def: MercenaryDef = gd.mercs[fighter.def_id]
	var growth := int(def.growth_x10["hp"])
	assert_str(def.display_rank()).is_equal("E")
	assert_str(fighter.xp_table(gd)).is_equal("dcb")
	assert_int(int(fighter.compute_stats(gd)["hp"])).is_equal(int(def.base["hp"]) + growth * 95 / 100)
	def.rank = "A"
	assert_str(fighter.xp_table(gd)).is_equal("a")
	assert_int(int(fighter.compute_stats(gd)["hp"])).is_equal(int(def.base["hp"]) + growth * 112 / 100)
	def.rank = "S"
	assert_str(fighter.xp_table(gd)).is_equal("s")
	assert_int(int(fighter.compute_stats(gd)["hp"])).is_equal(int(def.base["hp"]) + growth * 120 / 100)
	def.rank = ""
	assert_int(int(fighter.compute_stats(gd)["hp"])).is_equal(int(def.base["hp"]) + growth)
	assert_str(fighter.xp_table(gd)).is_equal("dcb")
