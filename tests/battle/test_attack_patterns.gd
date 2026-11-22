extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B
const FIRST_ENEMY := 100
const BATTLE_VIEW := preload("res://scenes/battle/battle_view.tscn")


func _battle(pattern: String, gaps: Array = [], flyers: Array = []) -> BattleSim:
	var actor := BattleUnit.make(1, A, 0, {"attack_pattern": pattern, "atk": 100})
	var units: Array[BattleUnit] = [actor]
	for slot in BattleRules.SLOTS_PER_SIDE:
		if not gaps.has(slot):
			units.append(BattleUnit.make(FIRST_ENEMY + slot, B, slot, {
				"hp": 500, "flying": flyers.has(slot),
			}))
	var rules := BattleRules.new()
	rules.variance_pct = 0
	rules.crit_chance_pct = 0
	return BattleSim.new(rules, units, 1, GameData.load_dir().skills)


func _slots(ids: Array[int]) -> Array[int]:
	var slots: Array[int] = []
	for id in ids:
		slots.append(id - FIRST_ENEMY)
	slots.sort()
	return slots


func test_specification_examples() -> void:
	var cases := [
		["sword", 3, [], [3]],
		["dual_sword", 3, [], [0, 3, 4, 6]],
		["dual_sword", 0, [], [0, 1, 3]],
		["spear", 3, [], [3, 4]],
		["spear", 5, [], []],
		["armor_fist", 3, [], [3, 4]],
		["axe", 3, [], [0, 3, 6]],
		["power_saw", 3, [], [0, 3, 6]],
		["bow", 8, [], [8]],
		["gun", 4, [], [3, 4, 5]],
		["gun", 3, [4], [3, 5]],
		["instrument", 4, [], [4, 5]],
		["instrument", 4, [5], [4]],
		["instrument", 3, [4], [3]],
		["cannon", 4, [], [1, 3, 4, 5, 7]],
		["cannon", 0, [], [0, 1, 3]],
		["whip", 4, [], [1, 4, 7]],
		["whip", 4, [7], [1, 4]],
		["axe", 0, [3], [0]],
		["staff", 0, [], [0]],
	]
	for example in cases:
		var sim := _battle(example[0], example[2])
		assert_array(_slots(sim.hit_set(1, FIRST_ENEMY + int(example[1])))) \
			.override_failure_message(str(example)).is_equal(example[3])


func test_unreachable_attack_does_not_consume_ap() -> void:
	var sim := _battle("spear")
	var actor := sim.unit_by_id(1)
	var ap_before := actor.ap
	var result := sim.submit({"type": "attack", "actor": 1, "target": 105})
	assert_str(result.error).is_equal("unreachable")
	assert_int(actor.ap).is_equal(ap_before)


func test_front_column_moves_after_last_unit_dies() -> void:
	var sim := _battle("spear")
	for slot in [0, 3, 6]:
		sim.unit_by_id(FIRST_ENEMY + slot).hp = 0
	assert_array(_slots(sim.legal_targets(1))).is_equal([1, 4, 7])
	assert_array(_slots(sim.hit_set(1, 104))).is_equal([4, 5])


func test_melee_can_target_only_first_ground_unit_behind_flyer() -> void:
	var sim := _battle("sword", [], [0])
	assert_array(_slots(sim.legal_targets(1))).is_equal([1, 3, 6])
	sim.unit_by_id(101).hp = 0
	assert_array(_slots(sim.legal_targets(1))).is_equal([2, 3, 6])


func test_cannon_cannot_select_or_splash_flying_units() -> void:
	var sim := _battle("cannon", [], [0, 4])
	assert_array(sim.hit_set(1, 104)).is_empty()
	assert_array(_slots(sim.hit_set(1, 101))).is_equal([1, 2])
	for pattern in ["sword", "cannon"]:
		assert_array(_battle(pattern, range(1, 9), [0]).legal_targets(1)).is_empty()


func test_weapons_that_hit_flyers_can_target_front_flyer() -> void:
	for pattern in ["bow", "gun", "dual_sword", "instrument", "whip", "staff"]:
		assert_array(_battle(pattern, [], [0]).hit_set(1, 100)).contains([100])


func test_staff_basic_attack_and_magic_skill_have_independent_range() -> void:
	var sim := _battle("staff", [], [2])
	var actor := sim.unit_by_id(1)
	actor.skill_ids.append("staff_bolt")
	assert_array(sim.hit_set(1, 102)).is_empty()
	assert_array(sim.legal_targets(1, "staff_bolt")).contains([102])
	assert_bool(sim.submit({"type": "skill", "actor": 1, "skill": "staff_bolt", "target": 102}).ok).is_true()
	assert_bool(sim.unit_by_id(102).hit_phys).is_false()


func test_basic_damage_bonus_caps_and_multi_hit_spends_ap_once() -> void:
	var sim := _battle("spear")
	var actor := sim.unit_by_id(1)
	var ap_before := actor.ap
	var result := sim.submit({"type": "attack", "actor": 1, "target": 103})
	assert_bool(result.ok).is_true()
	assert_int(actor.ap).is_equal(ap_before - sim.rules.attack_cost)
	assert_int(sim.unit_by_id(103).hp).is_equal(364)
	assert_int(sim.unit_by_id(104).hp).is_equal(364)
	assert_int(sim.unit_by_id(105).hp).is_equal(500)


func test_demo_preview_ai_and_attack_share_the_same_hit_set() -> void:
	var gd := GameData.load_dir()
	for weapon in gd.weapons:
		var sim := _battle(str(gd.weapons[weapon]["attack_pattern"]))
		var view: BattleView = auto_free(BATTLE_VIEW.instantiate())
		add_child(view)
		view.setup(gd, sim, {}, {}, "Тест")
		var action := BattleAI.choose(sim, 1)
		assert_str(action.type).is_equal("attack")
		var expected := sim.hit_set(1, int(action.target))
		if weapon == "cannon":
			assert_int(int(action.target)).is_equal(104)
			assert_int(expected.size()).is_equal(5)
		view.selected = 1
		view._choose_attack()
		view._on_unit_clicked(int(action.target))
		var preview: Array[int] = []
		for id in view.views:
			var unit_view: UnitView = view.views[id]
			if unit_view.in_attack_area:
				assert_bool(unit_view.ring.visible).is_true()
				preview.append(id)
		assert_array(_slots(preview)).is_equal(_slots(expected))
		var result := sim.submit(action)
		assert_bool(result.ok).is_true()
		var actual: Array[int] = []
		for event in result.events:
			if event.type == "attack":
				actual.append(int(event.target))
		assert_array(actual).is_equal(expected)
		view._cancel()
		for unit_view: UnitView in view.views.values():
			assert_bool(unit_view.in_attack_area).is_false()


func test_bottom_bar_only_shows_fighters_eligible_to_act() -> void:
	var gd := GameData.load_dir()
	var rules := BattleRules.new()
	var first := BattleUnit.make(1, A, 0, {})
	var second := BattleUnit.make(2, A, 1, {})
	var waiting := BattleUnit.make(3, A, 2, {})
	waiting.ap = rules.ap_min
	var units: Array[BattleUnit] = [first, second, waiting, BattleUnit.make(100, B, 0, {})]
	var sim := BattleSim.new(rules, units, 1, gd.skills)
	var view: BattleView = auto_free(BATTLE_VIEW.instantiate())
	add_child(view)
	view.setup(gd, sim, {}, {}, "Тест")
	assert_bool(view.chips[1].visible).is_true()
	assert_bool(view.chips[2].visible).is_true()
	assert_bool(view.chips[3].visible).is_false()
	assert_bool(view.views[3].visible).is_true()

	first.acted = true
	second.ap = rules.ap_act_threshold - 1
	view._refresh_all()
	assert_bool(view.chips[1].visible).is_false()
	assert_bool(view.chips[2].visible).is_false()

	second.ap = rules.ap_act_threshold
	view._refresh_all()
	assert_bool(view.chips[2].visible).is_true()
	sim.current_side = B
	view._refresh_all()
	assert_bool(view.chips[2].visible).is_false()
