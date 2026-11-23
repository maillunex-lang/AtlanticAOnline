extends GdUnitTestSuite

var gd: GameData
var pw: PlayerWorld


func before_test() -> void:
	gd = GameData.load_dir()
	pw = PlayerWorld.new(gd, 0.0)


func test_world_data_is_consistent() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.world.zones.size()).is_equal(23)
	assert_int(gd.regions.size()).is_equal(13)


func test_every_zone_reachable_from_start_ignoring_levels() -> void:
	var g := WorldGraph.new(gd.world)
	assert_int(g.reachable(g.start_zone).size()).is_equal(gd.world.zones.size())


func test_player_starts_in_start_town_with_it_discovered() -> void:
	assert_str(pw.zone_id).is_equal("z_harbor")
	assert_bool(pw.discovered.has("z_harbor")).is_true()
	assert_int(pw.discovered.size()).is_equal(1)


func test_shortest_path_picks_fastest_route() -> void:
	var g := WorldGraph.new(gd.world)
	var r := g.shortest_path("z_harbor", "z_crossroads")
	# через луга: 20 + 40 = 60; через лес: 20 + 30 + 25 = 75
	assert_array(r.path).is_equal(["z_harbor", "z_meadow", "z_crossroads"])
	assert_float(r.seconds).is_equal(60.0)


func test_shortest_path_to_self_and_unknown() -> void:
	var g := WorldGraph.new(gd.world)
	assert_array(g.shortest_path("z_harbor", "z_harbor").path).is_equal(["z_harbor"])
	assert_array(g.shortest_path("z_harbor", "nowhere").path).is_empty()


func test_level_gating_blocks_and_reroutes() -> void:
	var g := WorldGraph.new(gd.world)
	# Лес открыт с 4 уровня, перекрёсток с 5: на 4 уровне туда можно только через луга? нет, перекрёсток закрыт
	assert_array(g.shortest_path("z_harbor", "z_crossroads", 4).path).is_empty()
	assert_array(g.shortest_path("z_harbor", "z_crossroads", 5).path).is_equal(["z_harbor", "z_meadow", "z_crossroads"])
	# к шахте на 8 уровне через лес, на 7 нельзя
	assert_array(g.shortest_path("z_harbor", "z_mine", 7).path).is_empty()
	assert_bool(g.shortest_path("z_harbor", "z_mine", 8).path.size() > 0).is_true()


func test_travel_takes_time_and_blocks_other_actions() -> void:
	var res := pw.travel_to("z_meadow", 1, 100.0)
	assert_bool(res.ok).is_true()
	assert_float(res.seconds).is_equal(20.0)
	assert_str(pw.travel_to("z_forest", 10, 105.0).error).is_equal("busy")
	assert_str(pw.teleport("z_crossroads", 10, 105.0).error).is_equal("busy")
	assert_str(pw.zone_id).is_equal("z_harbor")  # ещё в пути
	assert_bool(pw.update(119.9)).is_false()
	assert_bool(pw.update(120.0)).is_true()
	assert_str(pw.zone_id).is_equal("z_meadow")
	assert_bool(pw.traveling).is_false()


func test_arrival_discovers_every_zone_on_the_route() -> void:
	pw.travel_to("z_crossroads", 5, 0.0)
	pw.update(1000.0)
	assert_bool(pw.discovered.has("z_meadow")).is_true()
	assert_bool(pw.discovered.has("z_crossroads")).is_true()
	assert_bool(pw.discovered.has("z_forest")).is_false()


func test_travel_errors() -> void:
	assert_str(pw.travel_to("nowhere", 99, 0.0).error).is_equal("unknown_zone")
	assert_str(pw.travel_to("z_harbor", 99, 0.0).error).is_equal("already_there")
	assert_str(pw.travel_to("z_forest", 3, 0.0).error).is_equal("level_too_low")
	assert_str(pw.travel_to("z_crossroads", 5, 0.0).error).is_equal("")
	pw.update(1000.0)
	assert_str(pw.travel_to("z_mine", 7, 1000.0).error).is_equal("level_too_low")


func test_travel_starting_arrival_check_happens_on_next_call() -> void:
	pw.travel_to("z_meadow", 1, 0.0)
	var res := pw.travel_to("z_forest", 4, 50.0)  # путь уже завершён к моменту вызова
	assert_bool(res.ok).is_true()
	assert_float(res.seconds).is_equal(30.0)


func test_ship_route_to_second_region() -> void:
	var res := pw.travel_to("z_oasis", 18, 0.0)
	assert_bool(res.ok).is_true()
	assert_float(res.seconds).is_equal(120.0)
	assert_str(pw.travel_to("z_oasis", 17, 50.0).error).is_equal("busy")


func _walk(to: String, level: int, now: float) -> float:
	var r := pw.travel_to(to, level, now)
	assert_bool(r.ok).is_true()
	var t := now + float(r.seconds)
	pw.update(t)
	return t


func test_teleport_needs_discovered_town_and_costs_will() -> void:
	var t := _walk("z_crossroads", 5, 0.0)
	assert_str(pw.teleport("z_citadel", 20, t).error).is_equal("not_discovered")
	assert_str(pw.teleport("z_meadow", 20, t).error).is_equal("not_town")
	assert_str(pw.teleport("z_crossroads", 20, t).error).is_equal("already_there")
	var res := pw.teleport("z_harbor", 20, t)
	assert_bool(res.ok).is_true()
	assert_str(pw.zone_id).is_equal("z_harbor")
	assert_int(pw.will_at(t)).is_equal(80)


func test_will_runs_out_and_regenerates_over_time() -> void:
	var t := _walk("z_crossroads", 5, 0.0)
	for i in 5:  # 5 телепортов по 20 = вся воля
		var dest := "z_harbor" if pw.zone_id == "z_crossroads" else "z_crossroads"
		assert_bool(pw.teleport(dest, 20, t).ok).is_true()
	assert_int(pw.will_at(t)).is_equal(0)
	assert_str(pw.teleport("z_crossroads", 20, t).error).is_equal("no_will")
	assert_int(pw.will_at(t + 36.0)).is_equal(1)
	assert_int(pw.will_at(t + 36.0 * 20)).is_equal(20)
	assert_bool(pw.teleport("z_crossroads", 20, t + 36.0 * 20).ok).is_true()
	assert_int(pw.will_at(t + 36.0 * 20 + 36.0 * 1000)).is_equal(100)  # потолок


func test_teleport_requires_level_for_destination() -> void:
	var t := _walk("z_crossroads", 5, 0.0)
	assert_str(pw.teleport("z_harbor", 0, t).error).is_equal("level_too_low")


func test_ferry_requires_route_document_and_waits_for_arrival() -> void:
	var log := QuestLog.new(gd)
	assert_str(SeaFerry.depart(pw, log, 20, 0).error).is_equal("no_pass")
	log.load_dict({"active": {"m07_south": [0, 0]}})
	assert_str(SeaFerry.depart(pw, log, 17, 0).error).is_equal("level_too_low")
	pw.zone_id = "z_citadel"
	assert_str(SeaFerry.depart(pw, log, 20, 0).error).is_equal("wrong_port")
	pw.zone_id = "z_harbor"
	var voyage := SeaFerry.depart(pw, log, 20, 10)
	assert_bool(voyage.ok).is_true()
	assert_array(voyage.path).is_equal(["z_harbor", "z_oasis"])
	assert_bool(SeaFerry.arrive(pw, log, 129)).is_false()
	assert_str(log.state("m07_south", null, 20, 129)).is_equal("active")
	assert_bool(SeaFerry.arrive(pw, log, 130)).is_true()
	assert_str(log.state("m07_south", null, 20, 130)).is_equal("ready")
	assert_bool(pw.discovered.has("z_oasis")).is_true()
	assert_bool(SeaFerry.arrive(pw, log, 131)).is_false()


func test_copper_cove_ferry_requires_finished_charter_and_level_thirty() -> void:
	var log := QuestLog.new(gd)
	pw.zone_id = SeaFerry.SLUICE
	assert_str(SeaFerry.depart(pw, log, 30, 0).error).is_equal("no_pass")
	log.load_dict({"completed": {SeaFerry.CHARTER: true}})
	assert_str(SeaFerry.depart(pw, log, 29, 0).error).is_equal("level_too_low")
	assert_str(SeaFerry.contact_toward(pw, "z_fog_trail")).is_equal("npc_sluice_dara")
	assert_str(SeaFerry.contact_toward(pw, SeaFerry.HARBOR)).is_equal("npc_yara")
	assert_bool(SeaFerry.depart(pw, log, 30, 0).ok).is_true()
	assert_bool(SeaFerry.arrive(pw, log, 149)).is_false()
	assert_bool(SeaFerry.arrive(pw, log, 150)).is_true()
	assert_str(pw.region()).is_equal("south_america")
	assert_str(SeaFerry.contact_toward(pw, SeaFerry.HARBOR)).is_equal("npc_cove_ines")
	assert_bool(SeaFerry.depart(pw, log, 30, 150).ok).is_true()
	assert_bool(SeaFerry.arrive(pw, log, 300)).is_true()
	assert_str(pw.zone_id).is_equal(SeaFerry.SLUICE)
