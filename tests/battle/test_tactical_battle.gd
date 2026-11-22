extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B


func _arena() -> Dictionary:
	return {
		"width": 9, "height": 8, "round_limit": 6,
		"blocked": [[2, 2], [1, 3]],
		"abilities": {
			"five": {"area": 5, "range": 4, "power_pct": 90, "mp": 8, "cooldown": 2},
			"seven": {"area": 7, "range": 4, "power_pct": 80, "mp": 10, "cooldown": 3},
		},
		"units": [
			{"id": 1, "mercenary": "hero_sword", "cell": [1, 2], "move": 3, "range": 1, "hp": 30, "atk": 20},
			{"id": 2, "mercenary": "archer", "cell": [1, 1], "move": 3, "range": 4, "hp": 40, "atk": 15, "ability": "five"},
			{"id": 3, "mercenary": "adept", "cell": [1, 4], "move": 3, "range": 3, "hp": 40, "atk": 15, "ability": "seven"},
			{"id": 10, "monster": "bandit", "cell": [4, 2], "move": 2, "range": 1, "hp": 30, "atk": 50},
		],
		"objectives": [],
	}


func test_movement_paths_respect_walls_units_and_budget() -> void:
	var sim := TacticalBattle.new(_arena())
	assert_array(sim.reachable(1)).is_equal([Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 1), Vector2i(0, 4), Vector2i(0, 0)])
	assert_bool(sim.move(1, Vector2i(2, 2))).is_false()
	assert_bool(sim.move(1, Vector2i(2, 1))).is_false()
	assert_bool(sim.move(1, Vector2i(0, 4))).is_true()
	assert_bool(sim.move(1, Vector2i(0, 3))).is_false()


func test_area_geometry_clips_to_board_and_skills_affect_only_enemies() -> void:
	var sim := TacticalBattle.new(_arena())
	assert_int(sim.ability_area(2, Vector2i(3, 3)).size()).is_equal(25)
	assert_int(sim.ability_area(3, Vector2i(4, 4)).size()).is_equal(49)
	assert_int(sim.ability_area(2, Vector2i(0, 0)).size()).is_equal(9)
	assert_array(sim.ability_area(2, Vector2i(8, 7))).is_empty()
	assert_bool(sim.cast(2, Vector2i.ZERO)).is_false()
	assert_int(sim.units[2].mp).is_equal(100)
	assert_bool(sim.cast(2, Vector2i(3, 2))).is_true()
	assert_int(sim.units[1].hp).is_equal(30)
	assert_int(sim.units[10].hp).is_equal(17)
	assert_int(sim.units[2].mp).is_equal(92)
	assert_bool(sim.cast(2, Vector2i(3, 2))).is_false()
	sim.end_turn()
	sim.end_turn()
	assert_bool(sim.can_cast(2)).is_false()
	sim.end_turn()
	sim.end_turn()
	assert_bool(sim.can_cast(2)).is_true()


func test_attack_and_move_do_not_spend_ap() -> void:
	var sim := TacticalBattle.new(_arena())
	sim.units[2].ap = 0
	assert_bool(sim.attack(2, 10)).is_true()
	assert_int(sim.units[2].ap).is_equal(0)
	assert_bool(sim.attack(2, 10)).is_false()
	assert_bool(sim.move(2, Vector2i(2, 1))).is_true()
	assert_int(sim.units[2].ap).is_equal(0)
	assert_bool(sim.attack(10, 2)).is_false()


func test_skirmish_continues_after_hero_death() -> void:
	var sim := TacticalBattle.new(_arena())
	sim.positions[10] = Vector2i(0, 2)
	sim.end_turn()
	assert_bool(sim.attack(10, 1)).is_true()
	assert_bool(sim.units[1].is_alive()).is_false()
	assert_int(sim.winner).is_equal(BattleSim.Winner.NONE)
	sim.end_turn()
	sim.units[2].stats.base["atk"] = 50
	assert_bool(sim.attack(2, 10)).is_true()
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_objectives_require_guard_and_beacon_in_order() -> void:
	var mission := _arena()
	mission["objectives"] = [
		{"type": "defeat", "unit": 10, "text": "Дозорный"},
		{"type": "occupy", "cell": [0, 1], "text": "Маяк"},
	]
	var sim := TacticalBattle.new(mission)
	assert_bool(sim.move(2, Vector2i(0, 1))).is_true()
	assert_int(sim.objective_index).is_equal(0)
	assert_bool(sim.move(3, Vector2i(3, 4))).is_true()
	assert_bool(sim.cast(3, Vector2i(3, 2))).is_true()
	assert_int(sim.winner).is_equal(BattleSim.Winner.NONE)
	sim.end_turn()
	sim.end_turn()
	sim.units[2].stats.base["atk"] = 50
	assert_bool(sim.move(2, Vector2i(3, 1))).is_true()
	assert_bool(sim.attack(2, 10)).is_true()
	assert_int(sim.winner).is_equal(BattleSim.Winner.NONE)
	assert_int(sim.objective_index).is_equal(1)
	assert_bool(sim.move(1, Vector2i(0, 1))).is_true()
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_survival_and_round_limit_produce_defeat() -> void:
	var mission := _arena()
	mission["round_limit"] = 1
	var sim := TacticalBattle.new(mission)
	sim.end_turn()
	sim.enemy_turn()
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_B)


func test_demo_mission_is_valid_and_ai_can_navigate_around_walls() -> void:
	var gd := GameData.load_dir()
	assert_array(gd.validate()).is_empty()
	var sim := TacticalBattle.new(gd.tactical_missions["watchtower"])
	for turn in 5:
		if sim.winner != BattleSim.Winner.NONE:
			break
		sim.end_turn()
		sim.enemy_turn()
	assert_int(TacticalBattle.distance(sim.positions[101], Vector2i(1, 3))).is_less(5)


func test_view_previews_area_without_spending_mana_until_confirmed() -> void:
	var gd := GameData.load_dir()
	var scene := load("res://scenes/battle/tactical_view.tscn") as PackedScene
	var view: TacticalView = auto_free(scene.instantiate())
	add_child(view)
	view.setup(gd.tactical_missions["watchtower"], gd)
	view.select_cell(Vector2i(1, 2))
	view.move_button.pressed.emit()
	assert_bool(view.board.move_cells.has(Vector2i(3, 2))).is_true()
	view.select_cell(Vector2i(3, 2))
	view.ability_button.pressed.emit()
	view.select_cell(Vector2i(7, 2))
	assert_int(view.board.area_cells.size()).is_equal(25)
	assert_int(view.sim.units[2].mp).is_equal(100)
	view.select_cell(Vector2i(7, 2))
	assert_int(view.sim.units[2].mp).is_equal(92)
	assert_array(view.board.area_cells).is_empty()


func test_invalid_mission_cell_and_unknown_objective_are_reported() -> void:
	var gd := GameData.load_dir()
	gd.tactical_missions["watchtower"]["units"][0]["cell"] = [4, 0]
	gd.tactical_missions["watchtower"]["objectives"][0]["unit"] = 999
	var errors := gd.validate()
	assert_array(errors).contains([
		"tactics watchtower: занятая или недопустимая клетка бойца",
		"tactics watchtower: цель не ссылается на врага",
	])
