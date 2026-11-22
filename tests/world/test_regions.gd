extends GdUnitTestSuite
## Регионы мира (WP-20): данные, проверки целостности, форпосты, связность.

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _errors_text(g: GameData) -> String:
	return "\n".join(g.validate())


func test_regions_data_is_valid_and_complete() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.regions.size()).is_equal(13)
	assert_int(gd.parts.size()).is_equal(2)
	var surface := 0
	var atlantis := 0
	for id in gd.regions:
		if gd.regions[id]["part"] == "surface":
			surface += 1
		else:
			atlantis += 1
	assert_int(surface).is_equal(10)
	assert_int(atlantis).is_equal(3)
	assert_str(gd.start_region).is_equal("northeast_asia")
	assert_str(gd.region_order[0]).is_equal("northeast_asia")
	assert_str(gd.region_order[12]).is_equal("titan_island")


func test_current_zones_are_migrated_to_first_two_regions() -> void:
	assert_str(gd.region_of_zone("z_harbor")).is_equal("northeast_asia")
	assert_str(gd.region_of_zone("z_citadel")).is_equal("northeast_asia")
	assert_str(gd.region_of_zone("z_oasis")).is_equal("southeast_asia_india")
	assert_str(gd.region_of_zone("z_tomb")).is_equal("southeast_asia_india")
	assert_str(gd.region_of_zone("nope")).is_equal("")
	assert_bool(gd.world.has("continents")).is_false()
	var pw := PlayerWorld.new(gd, 0.0)
	assert_str(pw.region()).is_equal("northeast_asia")


func test_every_zone_reachable_from_every_town_ignoring_levels() -> void:
	var g := WorldGraph.new(gd.world)
	for z in gd.world["zones"]:
		if GameData.is_settlement(str(z["type"])):
			assert_int(g.reachable(str(z["id"])).size()).is_equal(gd.world["zones"].size())


func test_planned_regions_have_no_zones_and_active_have_a_town() -> void:
	for id in gd.regions:
		var zones := 0
		var towns := 0
		for z in gd.world["zones"]:
			if z["region"] == id:
				zones += 1
				if GameData.is_settlement(str(z["type"])):
					towns += 1
		if gd.regions[id]["status"] == "active":
			assert_int(towns).is_greater(0)
		else:
			assert_int(zones).is_equal(0)


func test_validation_catches_region_errors() -> void:
	var bad := GameData.load_dir()
	bad.regions["northeast_asia"]["part"] = "moon"
	bad.regions["south_america"]["level_band"] = [50, 30]
	bad.regions["africa"]["status"] = "soon"
	bad.regions["australia"]["map_pos"] = [1200, 5]
	bad.regions["west_atlantis"]["order"] = 1
	var t := _errors_text(bad)
	assert_bool(t.contains("неизвестная часть moon")).is_true()
	assert_bool(t.contains("region south_america: неверная полоса уровней")).is_true()
	assert_bool(t.contains("неизвестный статус soon")).is_true()
	assert_bool(t.contains("map_pos должен быть в пределах")).is_true()
	assert_bool(t.contains("порядок 1 уже занят")).is_true()


func test_validation_catches_zone_region_errors() -> void:
	var bad := GameData.load_dir()
	for z in bad.world["zones"]:
		if z["id"] == "z_meadow":
			z["region"] = "atlantis_nowhere"
		if z["id"] == "z_tomb":
			z["region"] = "africa"  # плановый регион с зоной и уровень 25 вне полосы 100-160
	var t := _errors_text(bad)
	assert_bool(t.contains("zone z_meadow: неизвестный регион")).is_true()
	assert_bool(t.contains("zone z_tomb: уровень 25 вне полосы региона africa")).is_true()
	assert_bool(t.contains("region africa: в плановом регионе есть зоны")).is_true()


func test_cross_region_edge_needs_explicit_kind_and_inner_edge_is_path() -> void:
	var bad := GameData.load_dir()
	for e in bad.world["edges"]:
		if e["a"] == "z_harbor" and e["b"] == "z_oasis":
			e["kind"] = "path"
		if e["a"] == "z_harbor" and e["b"] == "z_meadow":
			e["kind"] = "portal"
	var t := _errors_text(bad)
	assert_bool(t.contains("между регионами должен иметь kind sea или portal")).is_true()
	assert_bool(t.contains("внутри региона должен иметь kind path")).is_true()


func test_disconnected_zone_is_reported() -> void:
	var bad := GameData.load_dir()
	bad.world["zones"].append({"id": "z_island", "name": "Остров", "region": "northeast_asia", "type": "field", "min_level": 5})
	assert_bool(_errors_text(bad).contains("zone z_island: недостижима из стартового города")).is_true()


func test_start_zone_must_be_in_start_region_and_region_count_fixed() -> void:
	var bad := GameData.load_dir()
	bad.start_region = "africa"
	assert_bool(_errors_text(bad).contains("стартовая зона не в стартовом регионе")).is_true()
	var few := GameData.load_dir()
	few.regions.erase("titan_island")
	assert_bool(_errors_text(few).contains("должно быть 13 регионов")).is_true()


func test_outpost_is_a_teleport_destination_without_enemies() -> void:
	gd.world["zones"].append({"id": "z_outpost", "name": "Форпост", "region": "northeast_asia", "type": "outpost", "min_level": 1, "services": ["travel_agent"]})
	gd.world["edges"].append({"a": "z_meadow", "b": "z_outpost", "seconds": 15})
	assert_array(gd.validate()).is_empty()
	var pw := PlayerWorld.new(gd, 0.0)
	pw.discovered["z_outpost"] = true
	var r := pw.teleport("z_outpost", 1, 0.0)
	assert_bool(r.ok).is_true()
	assert_str(pw.zone_id).is_equal("z_outpost")
	gd.encounters["enc_bad"] = {"id": "enc_bad", "zone": "z_outpost", "enemies": [{"monster": "slime", "slot": 0}], "xp": 1, "coins": 1, "loot": "meadow_loot", "respawn_seconds": 10}
	assert_bool(_errors_text(gd).contains("в городе нет врагов")).is_true()
