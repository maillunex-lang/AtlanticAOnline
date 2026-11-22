extends GdUnitTestSuite


func _world() -> PlayerWorld:
	var state := PlayerWorld.new(GameData.load_dir())
	state.discovered["z_crossroads"] = true
	return state


func test_licensed_teleport_and_discovered_destination() -> void:
	var state := _world()
	var wallet := {"coins": 100}
	assert_str(state.map_teleport("z_crossroads", 10, 0.0, false, wallet).error).is_equal("no_license")
	assert_str(state.map_teleport("z_citadel", 20, 0.0, true, wallet).error).is_equal("not_discovered")
	assert_bool(state.map_teleport("z_crossroads", 10, 0.0, true, wallet).ok).is_true()
	assert_str(state.zone_id).is_equal("z_crossroads")
	assert_int(state.will_at(0.0)).is_equal(80)
	assert_int(wallet.coins).is_equal(100)


func test_bureau_requires_service_and_only_charges_success() -> void:
	var state := _world()
	var wallet := {"coins": 24}
	assert_str(state.map_teleport("z_crossroads", 10, 0.0, false, wallet, true).error).is_equal("no_coins")
	assert_int(state.will_at(0.0)).is_equal(100)
	wallet.coins = 100
	state.zone_id = "z_meadow"
	assert_str(state.map_teleport("z_crossroads", 10, 0.0, false, wallet, true).error).is_equal("no_bureau")
	state.zone_id = "z_harbor"
	assert_bool(state.map_teleport("z_crossroads", 10, 0.0, false, wallet, true).ok).is_true()
	assert_int(wallet.coins).is_equal(75)
	assert_int(state.will_at(0.0)).is_equal(80)


func test_free_capital_and_group_entrance_require_context_and_level() -> void:
	var state := _world()
	var wallet := {"coins": 0}
	state.graph.zones["z_citadel"]["capital"] = true
	assert_str(state.map_teleport("z_citadel", 19, 0.0, false, wallet).error).is_equal("not_discovered")
	assert_bool(state.map_teleport("z_citadel", 20, 0.0, false, wallet).ok).is_true()
	assert_str(state.map_teleport("z_ruins", 9, 0.0, false, wallet, false, "z_ruins").error).is_equal("level_too_low")
	assert_str(state.map_teleport("z_ruins", 20, 0.0, false, wallet).error).is_equal("not_town")
	assert_bool(state.map_teleport("z_ruins", 20, 0.0, false, wallet, false, "z_ruins").ok).is_true()
	assert_int(state.will_at(0.0)).is_equal(100)
	assert_int(wallet.coins).is_equal(0)


func test_favorites_reject_unknown_zone_and_toggle() -> void:
	var state := _world()
	assert_bool(state.toggle_favorite("missing")).is_false()
	assert_bool(state.toggle_favorite("z_harbor")).is_true()
	assert_bool(state.toggle_favorite("z_harbor")).is_false()
	assert_bool(state.favorites.is_empty()).is_true()
