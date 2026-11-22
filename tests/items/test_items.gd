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
	it.plus = 14
	assert_int(Enhancer.chance(it, gd)).is_equal(5)
	it.fail_streak = 3
	assert_int(Enhancer.chance(it, gd)).is_equal(20)  # +5% за каждую неудачу
	it.plus = 15
	assert_int(Enhancer.chance(it, gd)).is_equal(0)
	var w := {"coins": 100000}
	inv.add_material("enhance_stone", 100)
	assert_str(Enhancer.try_enhance(it, inv, w, _rng()).error).is_equal("max_plus")


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
	it.plus = 13  # шанс 10%, дорогое улучшение
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
		if it.plus == 15:
			break
	assert_bool(saw_fail).is_true()


func test_fail_streak_guarantees_eventual_success() -> void:
	var it := inv.add_equipment("w_sword_1")
	it.plus = 14  # шанс 5%
	var w := {"coins": 1000000}
	inv.add_material("enhance_stone", 999)
	var rng := _rng(7)
	var tries := 0
	while it.plus < 15 and tries < 25:
		Enhancer.try_enhance(it, inv, w, rng)
		tries += 1
	assert_int(it.plus).is_equal(15)  # не позже 19-й попытки (5% + 5% за каждую неудачу)
	assert_bool(tries <= 19).is_true()


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
