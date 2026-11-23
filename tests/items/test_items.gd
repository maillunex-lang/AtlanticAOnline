extends GdUnitTestSuite

var gd: GameData
var inv: Inventory


func before_test() -> void:
	gd = GameData.load_dir()
	inv = Inventory.new(gd)


func _rng(seed := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_data_is_consistent() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.rules.equip_slots.size()).is_equal(4)


func test_every_weapon_type_has_two_weapons() -> void:
	for w in WeaponType.ALL:
		assert_bool(gd.items.has("w_%s_1" % w) and gd.items.has("w_%s_2" % w)).is_true()


func test_inventory_capacity_and_material_stack_cap() -> void:
	for i in inv.capacity():
		assert_object(inv.add_equipment("a_cloth")).is_not_null()
	assert_object(inv.add_equipment("a_cloth")).is_null()
	assert_int(inv.add_material("iron_ore", 5000)).is_equal(999)
	assert_int(inv.add_material("iron_ore", 5)).is_equal(0)
	assert_int(inv.add_material("a_cloth", 1)).is_equal(0)  # не материал
	assert_bool(inv.take_material("iron_ore", 1000)).is_false()


func test_item_stat_scales_with_plus() -> void:
	var it := inv.add_equipment("w_sword_1")  # атака 6
	assert_int(it.stat("atk", gd)).is_equal(6)
	it.plus = 5
	assert_int(it.stat("atk", gd)).is_equal(6 * 150 / 100)


func test_equip_rules() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	var bow := inv.add_equipment("w_bow_1")
	assert_str(m.equip(bow, inv)).is_equal("wrong_weapon")
	var great := inv.add_equipment("h_great")  # уровень 25
	assert_str(m.equip(great, inv)).is_equal("level_too_low")
	var sword := inv.add_equipment("w_sword_1")
	assert_str(m.equip(sword, inv)).is_equal("")
	assert_object(inv.item_by_uid(sword.uid)).is_null()
	assert_str(m.equip(sword, inv)).is_equal("not_in_inventory")


func test_equip_swaps_old_item_back_to_inventory() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	var a := inv.add_equipment("w_sword_1")
	var b := inv.add_equipment("w_sword_2")
	m.set_level(20, gd)
	m.equip(a, inv)
	m.equip(b, inv)
	assert_int(m.equipped["weapon"].uid).is_equal(b.uid)
	assert_object(inv.item_by_uid(a.uid)).is_not_null()


func test_equipment_adds_to_merc_and_battle_stats() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	var before := m.compute_stats(gd)
	m.equip(inv.add_equipment("w_sword_1"), inv)
	m.equip(inv.add_equipment("a_cloth"), inv)
	var after := m.compute_stats(gd)
	assert_int(after.atk).is_equal(before.atk + 6)
	assert_int(after.def).is_equal(before.def + 3)
	assert_int(after.hp).is_equal(before.hp + 20)
	var u := BattleUnit.from_mercenary(m, gd, 1, 0, 0)
	assert_int(u.stat("atk")).is_equal(after.atk)
	assert_int(u.max_hp).is_equal(after.hp)


func test_unequip_returns_item_or_fails_when_full() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	m.equip(inv.add_equipment("w_sword_1"), inv)
	assert_str(m.unequip("armor", inv)).is_equal("empty_slot")
	for i in inv.capacity():
		inv.add_equipment("a_cloth")
	assert_str(m.unequip("weapon", inv)).is_equal("inventory_full")
	inv.items.pop_back()
	assert_str(m.unequip("weapon", inv)).is_equal("")
	assert_bool(m.equipped.is_empty()).is_true()


func test_retire_returns_equipment_to_inventory() -> void:
	var sq := Squad.new(gd)
	var w := {"coins": 300}
	var m: Mercenary = sq.recruit("swordsman", "coins", w).merc
	m.equip(inv.add_equipment("w_sword_1"), inv)
	assert_str(sq.retire(m.uid, w).error).is_equal("unequip_first")  # без сумки нельзя
	var res := sq.retire(m.uid, w, inv)
	assert_bool(res.ok).is_true()
	assert_int(inv.items.size()).is_equal(1)


func test_enhance_cost_chance_and_max() -> void:
	var it := inv.add_equipment("w_sword_1")
	assert_int(Enhancer.chance(it, gd)).is_equal(100)
	it.plus = 9
	assert_int(Enhancer.chance(it, gd)).is_equal(30)
	it.fail_streak = 3
	assert_int(Enhancer.chance(it, gd)).is_equal(45)
	it.plus = 10
	assert_int(Enhancer.chance(it, gd)).is_equal(0)
	var w := {"coins": 100000}
	inv.add_material("enhance_stone", 100)
	assert_str(Enhancer.try_enhance(it, inv, w, _rng()).error).is_equal("max_plus")
	it.plus = 15
	assert_str(Enhancer.try_enhance(it, inv, w, _rng()).error).is_equal("max_plus")
	assert_int(it.plus).is_equal(15)
	assert_int(it.stat("atk", gd)).is_equal(it.stat_at_plus("atk", gd, 15))
	var legendary := inv.add_equipment("aurora_sword")
	legendary.plus = 10
	legendary.fail_streak = 15
	assert_bool(Enhancer.try_enhance(legendary, inv, w, _rng()).success).is_true()
	assert_int(legendary.plus).is_equal(11)
	assert_str(Enhancer.try_enhance(legendary, inv, w, _rng()).error).is_equal("max_plus")


func test_enhance_success_spends_full_cost() -> void:
	var it := inv.add_equipment("w_sword_1")
	var w := {"coins": 100}
	inv.add_material("enhance_stone", 3)
	var res := Enhancer.try_enhance(it, inv, w, _rng())  # шанс 100%
	assert_bool(res.success).is_true()
	assert_int(it.plus).is_equal(1)
	assert_int(w.coins).is_equal(50)
	assert_int(inv.material_count("enhance_stone")).is_equal(2)


func test_enhance_requires_coins_and_stones() -> void:
	var it := inv.add_equipment("w_sword_1")
	assert_str(Enhancer.try_enhance(it, inv, {"coins": 0}, _rng()).error).is_equal("no_coins")
	assert_str(Enhancer.try_enhance(it, inv, {"coins": 1000}, _rng()).error).is_equal("no_stones")


func test_failed_enhance_never_breaks_and_refunds_half_stones() -> void:
	var it := inv.add_equipment("w_sword_1")
	it.plus = 9  # шанс 30%, дорогое улучшение
	var w := {"coins": 1000000}
	inv.add_material("enhance_stone", 900)
	var rng := _rng(2)
	var saw_fail := false
	for i in 60:
		var before_plus := it.plus
		var before_stones := inv.material_count("enhance_stone")
		var price := Enhancer.cost(it, gd)
		var res := Enhancer.try_enhance(it, inv, w, rng)
		assert_bool(it.plus >= before_plus).is_true()  # уровень не падает
		if not res.success:
			saw_fail = true
			assert_int(before_stones - inv.material_count("enhance_stone")).is_equal(price.stones - price.stones * 50 / 100)
		if it.plus == 10:
			break
	assert_bool(saw_fail).is_true()


func test_fail_streak_guarantees_eventual_success() -> void:
	var it := inv.add_equipment("aurora_sword")
	it.plus = 10  # шанс 25%
	var w := {"coins": 1000000}
	inv.add_material("enhance_stone", 999)
	var rng := _rng(7)
	var tries := 0
	while it.plus < 11 and tries < 25:
		Enhancer.try_enhance(it, inv, w, rng)
		tries += 1
	assert_int(it.plus).is_equal(11)  # не позже 16-й попытки (25% + 5% за каждую неудачу)
	assert_bool(tries <= 16).is_true()


func test_craft_consumes_inputs_and_creates_item() -> void:
	var w := {"coins": 600}
	inv.add_material("iron_ore", 10)
	inv.add_material("enhance_stone", 5)
	var res := Crafter.craft("craft_w_sword_2", inv, w)
	assert_bool(res.ok).is_true()
	assert_str(res.item.def_id).is_equal("w_sword_2")
	assert_int(w.coins).is_equal(100)
	assert_int(inv.material_count("iron_ore")).is_equal(0)


func test_craft_errors() -> void:
	assert_str(Crafter.craft("nope", inv, {"coins": 1}).error).is_equal("unknown_recipe")
	assert_str(Crafter.craft("craft_w_sword_2", inv, {"coins": 1}).error).is_equal("no_coins")
	assert_str(Crafter.craft("craft_w_sword_2", inv, {"coins": 1000}).error).is_equal("no_materials")
	inv.add_material("iron_ore", 10)
	inv.add_material("enhance_stone", 5)
	for i in inv.capacity():
		inv.add_equipment("a_cloth")
	assert_str(Crafter.craft("craft_w_sword_2", inv, {"coins": 1000}).error).is_equal("inventory_full")
	assert_int(inv.material_count("iron_ore")).is_equal(10)  # при ошибке ничего не списано


func test_loot_odds_sum_to_100_and_are_published() -> void:
	for t in gd.loot:
		var total := 0.0
		for o in LootTable.odds(t):
			total += o.percent
		assert_float(total).is_equal_approx(100.0, 0.001)


func test_loot_is_deterministic_and_respects_ranges() -> void:
	var t := LootTable.find(gd, "field_common")
	var a := LootTable.roll(t, _rng(4))
	var b := LootTable.roll(t, _rng(4))
	assert_array(a).is_equal(b)
	for i in 200:
		for d in LootTable.roll(t, _rng(i)):
			assert_bool(d.count >= 1 and d.count <= 6).is_true()
			assert_bool(gd.items.has(d.item)).is_true()


func test_loot_empirical_rates_match_weights() -> void:
	var t: Dictionary = LootTable.find(gd, "boss_basic").duplicate()
	t["rolls"] = 1  # один бросок: доля партий с камнем равна шансу записи
	var rng := _rng(11)
	var stones := 0
	var n := 6000
	for i in n:
		for d in LootTable.roll(t, rng):
			if d.item == "enhance_stone":
				stones += 1
	var rate := float(stones) * 100.0 / n
	assert_bool(rate > 40.0 and rate < 47.0).is_true()  # ожидание 40 из 92, примерно 43,5%


func test_add_drops_reports_what_did_not_fit() -> void:
	for i in inv.capacity():
		inv.add_equipment("a_cloth")
	var lost := inv.add_drops([{"item": "iron_ore", "count": 3}, {"item": "a_chain", "count": 2}])
	assert_int(inv.material_count("iron_ore")).is_equal(3)
	assert_int(lost.size()).is_equal(2)


func test_level_sets_cover_all_weapon_types_and_have_craft_recipes() -> void:
	var levels := [1, 10, 15, 25, 35, 50, 60, 70, 80, 90, 95, 97, 100, 105, 110, 113, 120, 130, 135, 140, 150, 155, 165, 175, 180]
	assert_int(gd.equipment_sets.size()).is_equal(levels.size() + 2)
	for level: int in levels:
		for kind: String in WeaponType.ALL + ["armor", "helm", "accessory"]:
			var id := "field_%d_%s" % [level, kind]
			var item: ItemDef = gd.items[id]
			assert_int(item.level_req).is_equal(level)
			assert_str(item.set_id).is_equal("field_%d" % level)
			assert_str(Crafter.find(gd, "craft_" + id)["output"]).is_equal(id)
	for weapon: String in WeaponType.ALL:
		var id := "aurora_" + weapon
		var item: ItemDef = gd.items[id]
		assert_str(item.rarity).is_equal("legendary")
		assert_str(item.weapon).is_equal(weapon)
		assert_str(Crafter.find(gd, "craft_" + id)["output"]).is_equal(id)


func test_set_bonus_applies_to_stats_and_is_lost_when_mixing_pieces() -> void:
	var m := Mercenary.new(1, "swordsman", gd)
	m.set_level(10, gd)
	var baseline := int(m.compute_stats(gd)["hp"])
	var armor := inv.add_equipment("field_10_armor")
	var helmet := inv.add_equipment("field_10_helm")
	assert_str(m.equip(armor, inv)).is_empty()
	assert_str(m.equip(helmet, inv)).is_empty()
	var armor_hp := armor.stat("hp", gd)
	var helmet_hp := helmet.stat("hp", gd)
	assert_int(int(m.compute_stats(gd)["hp"])).is_equal(baseline + armor_hp + helmet_hp + 10)
	assert_str(m.unequip("helm", inv)).is_empty()
	var mismatched := inv.add_equipment("field_1_helm")
	assert_str(m.equip(mismatched, inv)).is_empty()
	assert_int(int(m.compute_stats(gd)["hp"])).is_equal(baseline + armor_hp + mismatched.stat("hp", gd))


func test_dungeon_sets_drop_from_their_own_boss_tables() -> void:
	for id: String in ["guardian_relics", "sand_relics"]:
		var table := LootTable.find(gd, gd.equipment_sets[id]["source_loot"])
		var drop_items := {}
		var rng := _rng()
		for attempt in range(256):
			for drop: Dictionary in LootTable.roll(table, rng):
				drop_items[drop["item"]] = true
		for slot: String in ["armor", "helm", "accessory"]:
			assert_bool(("%s_%s" % [id, slot]) in drop_items).is_true()
			assert_dict(Crafter.find(gd, "craft_%s_%s" % [id, slot])).is_empty()


func test_profession_requirements_and_stalled_craft_are_atomic() -> void:
	var id := "craft_field_25_sword"
	var recipe := Crafter.find(gd, id)
	var req := Crafter.requirements(recipe, gd)
	var wallet := {"coins": int(recipe["coins"])}
	for material in recipe["materials"]:
		inv.add_material(material, int(recipe["materials"][material]))
	assert_str(Crafter.craft(id, inv, wallet).error).is_equal("craft_level")
	inv.crafting.gain(CraftProgress.WEAPON, 10000, gd.rules["crafting"])
	assert_str(Crafter.craft(id, inv, wallet).error).is_equal("workload")
	assert_int(wallet.coins).is_equal(int(recipe["coins"]))
	for material in recipe["materials"]:
		assert_int(inv.material_count(material)).is_equal(int(recipe["materials"][material]))
	inv.crafting.add_workload(int(req.workload), gd.rules["crafting"])
	assert_bool(Crafter.craft(id, inv, wallet).ok).is_true()
	assert_int(inv.crafting.workload).is_equal(0)
	assert_int(inv.crafting.level(CraftProgress.ARMOR)).is_equal(1)


func test_autocraft_waits_and_stops_without_resource_loss() -> void:
	var id := "craft_field_25_armor"
	var recipe := Crafter.find(gd, id)
	var wallet := {"coins": int(recipe["coins"])}
	for material in recipe["materials"]:
		inv.add_material(material, int(recipe["materials"][material]))
	inv.crafting.gain(CraftProgress.ARMOR, 10000, gd.rules["crafting"])
	inv.crafting.auto_recipe = id
	assert_dict(Crafter.tick(5.9, inv, wallet)).is_empty()
	assert_bool(Crafter.tick(0.2, inv, wallet).ok).is_true()
	assert_int(inv.items.size()).is_equal(1)
	assert_str(Crafter.tick(60.0, inv, wallet).error).is_equal("no_coins")
	assert_str(inv.crafting.auto_recipe).is_empty()
	assert_int(inv.items.size()).is_equal(1)


func test_analysis_resets_daily_and_dismantle_preserves_item_if_stack_full() -> void:
	var item := inv.add_equipment("w_sword_1")
	var clock := GameClock.from_rules(gd.rules)
	var start := clock.next_reset(0.0)
	var result := Crafter.analyze(item.uid, inv, start, _rng())
	assert_bool(result.ok).is_true()
	assert_int(result.multiplier).is_between(2, 4)
	assert_str(Crafter.analyze(item.uid, inv, start + 1.0, _rng()).error).is_equal("analysis_used")
	assert_bool(Crafter.analyze(item.uid, inv, clock.next_reset(start), _rng()).ok).is_true()
	inv.add_material("iron_ore", int(gd.rules["material_stack_max"]))
	assert_str(Crafter.dismantle(item.uid, inv).error).is_equal("materials_full")
	assert_object(inv.item_by_uid(item.uid)).is_not_null()
	inv.take_material("iron_ore", 1)
	assert_bool(Crafter.dismantle(item.uid, inv).ok).is_true()
	assert_object(inv.item_by_uid(item.uid)).is_null()


func test_craft_progress_stops_at_profession_cap() -> void:
	var crafting: Dictionary = gd.rules["crafting"]
	inv.crafting.gain(CraftProgress.WEAPON, 1000000, crafting)
	assert_int(inv.crafting.level(CraftProgress.WEAPON)).is_equal(180)
	assert_str(inv.crafting.title(CraftProgress.WEAPON, crafting)).is_equal("Совершенный")
	assert_int(inv.crafting.next_xp(CraftProgress.WEAPON, crafting)).is_equal(0)
	assert_int(inv.crafting.level(CraftProgress.ARMOR)).is_equal(1)


func test_enchant_consumes_only_matching_bag_copy_and_stones() -> void:
	var target := inv.add_equipment("w_sword_1")
	var donor := inv.add_equipment("w_sword_1")
	target.plus = 1
	assert_str(Enhancer.enchant(target, donor, inv)).is_equal("invalid_donor")
	donor.plus = target.plus
	assert_str(Enhancer.enchant(target, target, inv)).is_equal("invalid_donor")
	assert_str(Enhancer.enchant(target, donor, inv)).is_equal("no_stones")
	assert_int(inv.items.size()).is_equal(2)
	inv.add_material(Enhancer.STONE, 2)
	target.fail_streak = 2
	assert_str(Enhancer.enchant(target, donor, inv)).is_empty()
	assert_int(target.plus).is_equal(2)
	assert_int(target.fail_streak).is_equal(0)
	assert_int(inv.material_count(Enhancer.STONE)).is_equal(1)
	assert_object(inv.item_by_uid(donor.uid)).is_null()


func test_star_socket_applies_new_stat_to_battle_and_cannot_be_overwritten() -> void:
	var hero := Mercenary.new(1, "swordsman", gd)
	hero.set_level(20, gd)
	var old_sword := inv.add_equipment("w_sword_1")
	var sword := inv.add_equipment("w_sword_2")
	const STONE := "star_health_1"
	inv.add_material(STONE, 2)
	assert_str(old_sword.install_stone(STONE, inv)).is_equal("no_socket")
	assert_str(sword.install_stone("iron_ore", inv)).is_equal("invalid_stone")
	assert_str(sword.install_stone("star_attack_1", inv)).is_equal("no_stone")
	hero.equip(sword, inv)
	var hp := int(hero.compute_stats(gd).hp)
	assert_str(sword.install_stone(STONE, inv)).is_empty()
	assert_str(sword.install_stone(STONE, inv)).is_equal("occupied")
	assert_int(inv.material_count(STONE)).is_equal(1)
	assert_int(sword.stat("hp", gd)).is_equal(24)
	assert_int(BattleUnit.from_mercenary(hero, gd, 1, 0, 0).max_hp).is_equal(hp + 24)
	assert_str(Enhancer.enchant_error(inv.add_equipment("w_sword_2"), sword, inv)).is_equal("invalid_donor")


func test_star_stones_combine_through_rank_five_without_losing_materials() -> void:
	const BASE := "star_attack_1"
	inv.add_material(BASE, 16)
	for rank in range(1, 5):
		var source := "star_attack_%d" % rank
		var result := "star_attack_%d" % (rank + 1)
		for index in 16 >> rank:
			assert_str(inv.combine_star_stone(source)).is_equal(result)
		assert_int(inv.material_count(source)).is_equal(0)
		assert_str(inv.combine_star_stone(source)).is_empty()
	assert_str(inv.combine_star_stone("star_attack_5")).is_empty()
	inv.add_material(BASE, 2)
	inv.add_material("star_attack_2", 999)
	assert_str(inv.combine_star_stone(BASE)).is_empty()
	assert_int(inv.material_count(BASE)).is_equal(2)
	var sword := inv.add_equipment("w_sword_2")
	assert_str(sword.install_stone(BASE, inv)).is_empty()
	inv.add_material("star_defense_5", 1)
	assert_str(sword.install_stone("star_defense_5", inv)).is_equal("occupied")
	assert_int(inv.material_count("star_defense_5")).is_equal(1)
	assert_str(sword.install_stone("star_attack_5", inv)).is_empty()
	assert_str(sword.install_stone(BASE, inv)).is_equal("occupied")
	assert_int(sword.stat("atk", gd)).is_equal(35)
