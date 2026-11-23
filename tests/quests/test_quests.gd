extends GdUnitTestSuite

var gd: GameData
var log: QuestLog
var inv: Inventory
var sq: Squad
var wallet: Dictionary


func before_test() -> void:
	gd = GameData.load_dir()
	log = QuestLog.new(gd)
	inv = Inventory.new(gd)
	sq = Squad.new(gd)
	sq.create_hero("sword")
	wallet = {"coins": 0}


func _ctx(level := 1, now := 0.0) -> Dictionary:
	return {"inv": inv, "squad": sq, "wallet": wallet, "level": level, "now": now}


func _kill(enc: String) -> void:
	log.on_event({"type": "kill", "encounter": enc})


func test_quest_data_is_consistent() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.npcs.size()).is_equal(50)
	assert_int(gd.quests.size()).is_equal(129)


func test_every_recruit_quest_exists_for_basic_and_advanced_mercs() -> void:
	for id in gd.mercs:
		var m: MercenaryDef = gd.mercs[id]
		if m.tier in ["basic", "advanced"] and id not in gd.rules["formation"]["starter_guards"]:
			if m.rank != "" and m.recruit_quest == "":
				assert_int(m.recruit_coins).is_greater(0)
				assert_bool(id in gd.town_services["services"]["recruiter"]["offers"]).is_true()
			else:
				assert_bool(gd.quests.has(m.recruit_quest)).is_true()


func test_accept_requires_level_and_prereq() -> void:
	assert_str(log.availability("m01_first_steps", 1, 0.0)).is_equal("")
	assert_str(log.availability("m02_wolves", 1, 0.0)).is_equal("level_too_low")
	assert_str(log.availability("m02_wolves", 5, 0.0)).is_equal("prereq")
	assert_str(log.availability("nope", 1, 0.0)).is_equal("unknown_quest")
	assert_bool(log.accept("m01_first_steps", 1, 0.0).ok).is_true()
	assert_str(log.availability("m01_first_steps", 1, 0.0)).is_equal("already_active")


func test_kill_event_advances_only_matching_active_quest() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	assert_array(log.on_event({"type": "kill", "encounter": "enc_forest_wolves"})).is_empty()
	assert_array(log.on_event({"type": "kill", "encounter": "enc_meadow_slimes"})).is_equal(["m01_first_steps"])
	assert_str(log.state("m01_first_steps", inv, 1, 0.0)).is_equal("ready")


func test_progress_does_not_exceed_requirement_and_untaken_quests_ignore_events() -> void:
	_kill("enc_meadow_slimes")  # квест ещё не взят
	log.accept("m01_first_steps", 1, 0.0)
	assert_str(log.state("m01_first_steps", inv, 1, 0.0)).is_equal("active")
	for i in 5:
		_kill("enc_meadow_slimes")
	assert_int(log.objective_count("m01_first_steps", 0, inv, 1)).is_equal(1)


func test_multi_objective_quest_needs_all_objectives() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	_kill("enc_meadow_slimes")
	log.turn_in("m01_first_steps", _ctx())
	log.accept("m02_wolves", 2, 0.0)
	log.on_event({"type": "visit", "zone": "z_meadow"})
	assert_str(log.state("m02_wolves", inv, 2, 0.0)).is_equal("active")
	_kill("enc_meadow_wolves")
	assert_str(log.state("m02_wolves", inv, 2, 0.0)).is_equal("ready")


func test_turn_in_gives_rewards_once() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	assert_str(log.turn_in("m01_first_steps", _ctx()).error).is_equal("not_done")
	_kill("enc_meadow_slimes")
	var res := log.turn_in("m01_first_steps", _ctx())
	assert_bool(res.ok).is_true()
	assert_int(wallet.coins).is_equal(50)
	assert_int(sq.hero.level).is_equal(2)
	assert_int(sq.hero.xp).is_equal(2)
	assert_int(inv.items.size()).is_equal(1)  # шапка
	assert_str(log.state("m01_first_steps", inv, 1, 0.0)).is_equal("done")
	assert_str(log.turn_in("m01_first_steps", _ctx()).error).is_equal("not_active")
	assert_str(log.availability("m01_first_steps", 1, 0.0)).is_equal("already_done")


func test_turn_in_only_to_the_right_npc() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	_kill("enc_meadow_slimes")
	assert_str(log.turn_in("m01_first_steps", _ctx(), "npc_mira").error).is_equal("wrong_npc")
	assert_bool(log.turn_in("m01_first_steps", _ctx(), "npc_orvin").ok).is_true()


func test_collect_objective_counts_inventory_and_consumes_on_turn_in() -> void:
	log.accept("s01_leather", 3, 0.0)
	assert_str(log.state("s01_leather", inv, 3, 0.0)).is_equal("active")
	inv.add_material("leather", 7)
	assert_str(log.state("s01_leather", inv, 3, 0.0)).is_equal("ready")
	assert_bool(log.turn_in("s01_leather", _ctx(3)).ok).is_true()
	assert_int(inv.material_count("leather")).is_equal(2)  # 7 минус 5
	assert_int(wallet.coins).is_equal(100)


func test_collect_without_consume_keeps_the_item() -> void:
	gd.quests["m05_old_key"]["objectives"].append({
		"type": "collect", "target": "key_ruins", "count": 1, "consume": false,
	})
	gd.quests["m05_old_key"]["rewards"].erase("items")
	log.completed["m04_stone_sentry"] = true
	log.accept("m05_old_key", 10, 0.0)
	_kill("enc_mine_spiders")
	inv.add_material("key_ruins", 1)
	assert_bool(log.turn_in("m05_old_key", _ctx(10)).ok).is_true()
	assert_int(inv.material_count("key_ruins")).is_equal(1)


func test_reward_blocked_when_inventory_full_and_nothing_is_taken() -> void:
	for i in inv.capacity():
		inv.add_equipment("a_cloth")
	log.accept("m01_first_steps", 1, 0.0)
	_kill("enc_meadow_slimes")
	assert_str(log.turn_in("m01_first_steps", _ctx()).error).is_equal("inventory_full")
	assert_int(wallet.coins).is_equal(0)
	assert_str(log.state("m01_first_steps", inv, 1, 0.0)).is_equal("ready")


func test_reach_level_objective_uses_hero_level() -> void:
	log.completed["m06_ruins"] = true
	log.chains_cleared["main_03"] = 1
	log.accept("m07_south", 18, 0.0)
	log.on_event({"type": "visit", "zone": "z_oasis"})
	assert_str(log.state("m07_south", inv, 17, 0.0)).is_equal("active")
	assert_str(log.state("m07_south", inv, 18, 0.0)).is_equal("ready")


func test_abandon_resets_progress() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	_kill("enc_meadow_slimes")
	assert_bool(log.abandon("m01_first_steps")).is_true()
	assert_bool(log.abandon("m01_first_steps")).is_false()
	log.accept("m01_first_steps", 1, 0.0)
	assert_str(log.state("m01_first_steps", inv, 1, 0.0)).is_equal("active")


func test_active_quest_limit() -> void:
	var ids: Array = []
	for id in gd.quests:
		if gd.quests[id].kind == "side" or gd.quests[id].kind == "recruit":
			if not gd.quests[id].has("prereq") and gd.quests[id].level_min <= 18:
				ids.append(id)
	var taken := 0
	for id in ids:
		if log.accept(id, 99, 0.0).ok:
			taken += 1
	assert_int(taken).is_less_equal(20)
	assert_int(log.active.size()).is_equal(taken)


func test_daily_quest_resets_next_day_and_has_daily_limit() -> void:
	log.accept("d02_cloth", 5, 100.0)
	inv.add_material("cloth_scrap", 6)
	assert_bool(log.turn_in("d02_cloth", _ctx(5, 200.0)).ok).is_true()
	assert_str(log.state("d02_cloth", inv, 5, 300.0)).is_equal("done")
	assert_str(log.availability("d02_cloth", 5, 300.0)).is_equal("already_done")
	assert_str(log.availability("d02_cloth", 5, 86400.0 + 10.0)).is_equal("")  # следующие сутки
	# лимит: три разных ежедневных в сутки, четвёртого нет. Всего ежедневных три, поэтому проверяем счётчик
	log.accept("d01_patrol", 5, 300.0)
	log.accept("d03_wolf_patrol", 5, 300.0)
	assert_int(log.daily_accepted_count(300.0)).is_equal(3)
	assert_int(log.daily_accepted_count(86400.0 + 1.0)).is_equal(0)


func test_daily_limit_blocks_additional_daily_quests() -> void:
	gd.rules["quests"]["max_daily"] = 2
	log.accept("d01_patrol", 5, 10.0)
	log.accept("d02_cloth", 5, 10.0)
	assert_str(log.availability("d03_wolf_patrol", 5, 10.0)).is_equal("daily_limit")
	assert_str(log.availability("d03_wolf_patrol", 5, 86400.0 + 10.0)).is_equal("")


func test_any_encounter_kill_counts_for_patrol() -> void:
	log.accept("d01_patrol", 5, 0.0)
	_kill("enc_meadow_slimes")
	_kill("enc_forest_wolves")
	_kill("enc_mine_golem")
	assert_int(log.objective_count("d01_patrol", 0, inv, 5)).is_equal(3)


func test_talk_objective_and_recruit_flow_unlocks_recruiting() -> void:
	var base := "q_recruit_swordsman"
	assert_str(sq.recruit("swordsman", "quest", wallet, log.completed_ids()).error).is_equal("quest_not_done")
	log.accept(base, 3, 0.0)
	log.on_event({"type": "activity", "target": "guard@z_meadow"})
	assert_bool(log.turn_in(base, _ctx(3), "npc_mira").ok).is_true()
	assert_bool(sq.recruit("swordsman", "quest", wallet, log.completed_ids()).ok).is_true()


func test_advanced_recruit_quest_needs_basic_one_first() -> void:
	assert_str(log.availability("q_recruit_knight", 20, 0.0)).is_equal("prereq")
	log.completed["q_recruit_swordsman"] = true
	assert_str(log.availability("q_recruit_knight", 19, 0.0)).is_equal("level_too_low")
	assert_str(log.availability("q_recruit_knight", 20, 0.0)).is_equal("")


func test_available_from_lists_quests_of_that_npc_only() -> void:
	var from_orvin := log.available_from("npc_orvin", 1, 0.0)
	assert_array(from_orvin).is_equal(["m01_first_steps", "tut01_port", "q_ne_field_practice"])
	assert_bool("q_recruit_swordsman" in log.available_from("npc_mira", 3, 0.0)).is_true()
	assert_bool("q_recruit_knight" in log.available_from("npc_mira", 30, 0.0)).is_false()


func test_old_recruitment_keeps_counter_and_legacy_reward() -> void:
	var id := "q_recruit_swordsman"
	log.load_dict({"active": {id: [1, 0]}})
	assert_bool(log.uses_legacy_objectives(id)).is_true()
	assert_int(log.objective_count(id, 0, inv, 3)).is_equal(1)
	log.on_event({"type": "activity", "target": "guard@z_meadow"})
	assert_int(log.objective_count(id, 0, inv, 3)).is_equal(1)
	_kill("enc_meadow_wolves")
	inv.add_material("leather", 3)
	assert_bool(log.turn_in(id, _ctx(3), "npc_mira").ok).is_true()
	assert_int(inv.material_count("leather")).is_equal(0)
	assert_bool(log.turn_in(id, _ctx(3), "npc_mira").ok).is_false()
	assert_int(wallet.coins).is_equal(50)


func test_new_recruitment_roundtrip_keeps_role_and_zone() -> void:
	var id := "q_recruit_swordsman"
	assert_bool(log.accept(id, 3, 0.0).ok).is_true()
	log.load_dict(JSON.parse_string(JSON.stringify(log.to_dict())))
	assert_bool(log.uses_legacy_objectives(id)).is_false()
	_kill("enc_meadow_wolves")
	log.on_event({"type": "activity", "target": "guard@z_hills"})
	assert_str(log.state(id, inv, 3, 0.0)).is_equal("active")
	log.on_event({"type": "activity", "target": "guard@z_meadow"})
	assert_str(log.state(id, inv, 3, 0.0)).is_equal("ready")


func test_old_story_step_keeps_existing_progress() -> void:
	log.load_dict({"active": {"m13_citadel_signal": [1]}})
	assert_str(log.state("m13_citadel_signal", inv, 17, 0.0)).is_equal("ready")
	assert_bool(log.turn_in("m13_citadel_signal", _ctx(17), "npc_rook").ok).is_true()


func test_battle_practice_filters_out_enemy_actions_and_retreat() -> void:
	var id := "q_recruit_swordsman"
	assert_bool(log.accept(id, 3, 0.0).ok).is_true()
	var ally := BattleUnit.make(1, BattleRules.SIDE_A, 0)
	var enemy := BattleUnit.make(2, BattleRules.SIDE_B, 0)
	var sim := BattleSim.new(BattleRules.new(), [ally, enemy], 17)
	sim.events_log.append({"type": "guard", "actor": enemy.id})
	sim.winner = BattleSim.Winner.SIDE_A
	log.record_battle_practice(sim, "z_meadow")
	assert_int(log.objective_count(id, 0, inv, 3)).is_equal(0)
	sim.events_log.append({"type": "guard", "actor": ally.id})
	sim.winner = BattleSim.Winner.SIDE_B
	log.record_battle_practice(sim, "z_meadow")
	assert_int(log.objective_count(id, 0, inv, 3)).is_equal(0)
	sim.winner = BattleSim.Winner.SIDE_A
	log.record_battle_practice(sim, "z_meadow")
	assert_str(log.state(id, inv, 3, 0.0)).is_equal("ready")


func test_completed_ruins_count_for_late_optional_practice() -> void:
	var id := "q_ne_field_practice"
	log.load_dict({"completed": {"m06_ruins": true}})
	assert_bool(log.accept(id, 20, 0.0).ok).is_true()
	assert_int(log.objective_count(id, 3, inv, 20)).is_equal(1)
	assert_int(log.objective_count(id, 4, inv, 20)).is_equal(0)


func test_hud_tracks_only_selected_active_quests_and_caps_at_three() -> void:
	var ids := ["m01_first_steps", "tut01_port", "q_ne_field_practice", "s01_leather"]
	for id in ids:
		assert_bool(log.accept(id, 3, 0.0).ok).is_true()
	assert_array(log.hud_quests()).is_empty()
	assert_bool(log.set_hud_quest("m02_wolves", true)).is_false()
	for i in 3:
		assert_bool(log.set_hud_quest(ids[i], true)).is_true()
	assert_bool(log.set_hud_quest(ids[0], true)).is_true()
	assert_bool(log.set_hud_quest(ids[3], true)).is_false()
	log.load_dict(JSON.parse_string(JSON.stringify(log.to_dict())))
	assert_array(log.hud_quests()).is_equal(ids.slice(0, 3))
	_kill("enc_meadow_slimes")
	assert_bool(log.turn_in(ids[0], _ctx(3), "npc_orvin").ok).is_true()
	assert_bool(log.set_hud_quest(ids[3], true)).is_true()
	assert_bool(log.abandon(ids[1])).is_true()
	assert_bool(log.set_hud_quest(ids[2], false)).is_true()
	assert_array(log.hud_quests()).is_equal([ids[3]])
	assert_bool(log.active.has(ids[2])).is_true()


func test_route_goals_switch_from_objective_to_turn_in_npc() -> void:
	assert_bool(log.accept("m01_first_steps", 1, 0.0).ok).is_true()
	assert_array(log.route_goals("m01_first_steps", inv, 1)).is_equal([
		{"kind": "enemy", "id": "enc_meadow_slimes"},
	])
	_kill("enc_meadow_slimes")
	assert_array(log.route_goals("m01_first_steps", inv, 1)).is_equal([
		{"kind": "npc", "id": "npc_orvin"},
	])
	assert_array(log.route_goals("unknown", inv, 1)).is_empty()
