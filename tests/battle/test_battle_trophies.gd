extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _sim(robots := 0, lucky := false) -> BattleSim:
	var units: Array[BattleUnit] = [
		BattleUnit.make(1, A, 0, {"atk": 100, "ap": 150}),
		BattleUnit.make(2, A, 1, {"atk": 100, "ap": 150}),
		BattleUnit.make(3, A, 3, {"atk": 100, "ap": 150}),
		BattleUnit.make(101, B, 0, {"hp": 10}),
		BattleUnit.make(102, B, 3, {"hp": 10}),
		BattleUnit.make(103, B, 6, {"hp": 1000}),
	]
	var sim := BattleSim.new(BattleRules.new(), units, 4)
	var config: Dictionary = gd.rules["battle_loot"].duplicate()
	config["lucky_pct"] = 100 if lucky else 0
	sim.configure_loot(config, {"rolls": 1, "entries": [{"item": "iron_ore", "weight": 1}]}, robots, 4)
	return sim


func _attack(sim: BattleSim, actor: int, target: int) -> void:
	assert_bool(sim.submit({"type": "attack", "actor": actor, "target": target}).ok).is_true()


func test_search_spends_ap_once_and_search_all_only_collects_live_trophies() -> void:
	var sim := _sim()
	_attack(sim, 1, 101)
	_attack(sim, 2, 102)
	assert_array(sim.searchable_corpses()).is_equal([101, 102])
	var rejected := sim.submit({"type": "search", "actor": 3, "target": 103})
	assert_str(rejected.error).is_equal("bad_trophy")
	assert_int(sim.unit_by_id(3).ap).is_equal(200)
	sim.search_all()
	assert_array(sim.searchable_corpses()).is_equal([102])
	assert_int(sim.unit_by_id(3).ap).is_equal(150)
	assert_int(sim.collected_loot.size()).is_equal(1)
	assert_array(sim.search_all()).is_empty()


func test_corpses_expire_after_four_or_three_player_turns() -> void:
	for lucky in [false, true]:
		var sim := _sim(0, lucky)
		_attack(sim, 1, 101)
		var lifetime := 3 if lucky else 4
		for i in lifetime - 1:
			sim.end_turn()
			sim.end_turn()
			assert_bool(sim.corpses.has(101)).is_true()
		sim.end_turn()
		sim.end_turn()
		assert_bool(sim.corpses.has(101)).is_false()
		assert_array(sim.collected_loot).is_empty()


func test_robot_collects_one_body_per_turn_and_lucky_grants_rewards() -> void:
	var sim := _sim(1, true)
	_attack(sim, 1, 101)
	_attack(sim, 2, 102)
	sim.end_turn()
	sim.end_turn()
	assert_array(sim.searchable_corpses()).is_equal([102])
	assert_int(sim.loot_xp).is_equal(10)
	assert_int(sim.unit_by_id(1).stat("atk")).is_equal(110)
	assert_array(sim.collected_loot).is_equal([{"item": "iron_ore", "count": 1}, {"item": "h_cap", "count": 1}])
	sim.end_turn()
	sim.end_turn()
	assert_array(sim.searchable_corpses()).is_empty()
	assert_int(sim.loot_xp).is_equal(20)
	assert_int(_sim(10).loot_robots).is_equal(3)


func test_victory_collection_is_limited_once_per_survivor() -> void:
	var sim := _sim()
	sim.unit_by_id(103).hp = 1
	_attack(sim, 1, 101)
	_attack(sim, 2, 102)
	_attack(sim, 3, 103)
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)
	assert_bool(sim.submit({"type": "search", "actor": 1, "target": 101}).ok).is_true()
	assert_bool(sim.can_search(1)).is_false()
	sim.search_all()
	assert_array(sim.searchable_corpses()).is_empty()
	assert_int(sim.collected_loot.size()).is_equal(3)
	assert_array(sim.search_all()).is_empty()


func test_jackpot_keeps_separate_progress_and_pays_at_threshold() -> void:
	var config: Dictionary = gd.rules["battle_loot"]
	var bank := {}
	var first := LootTable.apply_jackpot([{"item": "iron_ore", "count": 6}, {"item": "leather", "count": 2}], "iron_ore", bank, config)
	assert_array(first).is_equal([{"item": "leather", "count": 2}])
	assert_int(bank.iron_ore).is_equal(6)
	var second := LootTable.apply_jackpot([{"item": "iron_ore", "count": 5}], "iron_ore", bank, config)
	assert_array(second).is_equal([{"item": "iron_ore", "count": 16}])
	assert_int(bank.iron_ore).is_equal(0)
