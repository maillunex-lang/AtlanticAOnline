extends GdUnitTestSuite
## Цепочки заданий (WP-30): шаги, итоговая награда, сбросы, дистанционные действия, цели, журнал, сохранение.

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


## Принимает шаг и выполняет цели событиями и материалами, не сдавая.
func _complete(qid: String, level: int, now := 0.0) -> void:
	assert_bool(log.accept(qid, level, now).ok).is_true()
	for o in gd.quests[qid]["objectives"]:
		match str(o["type"]):
			"kill":
				for i in int(o["count"]):
					_kill(str(o["target"]) if o["target"] != "*" else "enc_meadow_slimes")
			"visit":
				log.on_event({"type": "visit", "zone": o["target"]})
			"talk":
				log.on_event({"type": "talk", "npc": o["target"]})
			"dungeon_clear":
				log.on_event({"type": "dungeon_clear", "zone": o["target"]})
			"collect":
				inv.add_material(str(o["target"]), int(o["count"]))


## Проходит шаг целиком: принять, выполнить, сдать.
func _finish(qid: String, level: int, now := 0.0) -> Dictionary:
	_complete(qid, level, now)
	return log.turn_in(qid, _ctx(level, now), "")


func test_chain_data_is_valid_and_every_quest_belongs_to_one_chain() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.chains.size()).is_equal(22)
	for qid in gd.quests:
		assert_bool(gd.quest_chain.has(qid)).is_true()
	assert_int((gd.chains["ch_main_harbor"]["steps"] as Array).size()).is_equal(7)


func test_validation_catches_broken_chains() -> void:
	var bad := GameData.load_dir()
	bad.chains["ch_x"] = {"id": "ch_x", "name": "x", "category": "nope", "level_min": 1, "steps": ["m01_first_steps", "ghost"], "reset": "weekly"}
	var errs := bad.validate()
	var text := "\n".join(errs)
	assert_bool(text.contains("неизвестная категория")).is_true()
	assert_bool(text.contains("нет задания ghost")).is_true()
	assert_bool(text.contains("уже в цепочке")).is_true()
	assert_bool(text.contains("неизвестный сброс")).is_true()
	var cyc := GameData.load_dir()
	cyc.chains["ch_side_leather"]["prereq_chains"] = ["ch_side_ore"]
	cyc.chains["ch_side_ore"]["prereq_chains"] = ["ch_side_leather"]
	assert_bool("\n".join(cyc.validate()).contains("цикл условий")).is_true()
	var orphan := GameData.load_dir()
	orphan.chains.erase("ch_side_scorpions")
	assert_bool("\n".join(orphan.validate()).contains("не входит ни в одну цепочку")).is_true()


func test_next_step_is_blocked_until_previous_is_done() -> void:
	gd.quests["m02_wolves"].erase("prereq")  # проверяем именно правило цепочки
	assert_str(log.availability("m02_wolves", 5, 0.0)).is_equal("prev_step")
	_finish("m01_first_steps", 1)
	assert_str(log.availability("m02_wolves", 5, 0.0)).is_equal("")


func test_chain_progress_and_final_reward_with_last_step() -> void:
	var cid := "ch_main_harbor"
	assert_str(log.chain_state(cid, 0.0)).is_equal("none")
	assert_int(log.chain_step(cid, 0.0)).is_equal(0)
	var steps: Array = gd.chains[cid]["steps"]
	for i in steps.size() - 1:
		assert_bool(_finish(steps[i], 30).ok).is_true()
		assert_int(log.chain_step(cid, 0.0)).is_equal(i + 1)
		assert_str(log.chain_state(cid, 0.0)).is_equal("active")
	var coins_before := int(wallet["coins"])
	var last := _finish(steps[steps.size() - 1], 30)
	assert_bool(last.ok).is_true()
	assert_str(last.chain_completed).is_equal(cid)
	var step_coins := int(gd.quests[steps[steps.size() - 1]]["rewards"].get("coins", 0))
	assert_int(int(wallet["coins"]) - coins_before).is_equal(step_coins + 400)
	assert_int(int(last.rewards["xp"])).is_equal(int(gd.quests[steps[steps.size() - 1]]["rewards"].get("xp", 0)) + 300)
	assert_str(log.chain_state(cid, 0.0)).is_equal("done")
	assert_int(int(log.chains_cleared[cid])).is_equal(1)


func test_final_reward_is_atomic_when_bag_is_full() -> void:
	var cid := "ch_main_harbor"
	gd.chains[cid]["rewards_final"] = {"xp": 10, "items": {"h_cap": 1}}
	var steps: Array = gd.chains[cid]["steps"]
	for i in steps.size() - 1:
		_finish(steps[i], 30)
	_complete(steps[steps.size() - 1], 30)
	while not inv.is_full():
		inv.add_equipment("h_cap")
	var r := log.turn_in(steps[steps.size() - 1], _ctx(30), "")
	assert_str(r.error).is_equal("inventory_full")
	assert_str(log.state(steps[steps.size() - 1], inv, 30, 0.0)).is_not_equal("done")
	assert_int(int(log.chains_cleared.get(cid, 0))).is_equal(0)


func test_chain_prerequisite_blocks_first_step() -> void:
	assert_str(log.availability("q_recruit_knight", 20, 0.0)).is_equal("prereq")
	gd.quests["q_recruit_knight"].erase("prereq")
	assert_str(log.availability("q_recruit_knight", 20, 0.0)).is_equal("chain_prereq")
	_finish("q_recruit_swordsman", 3)
	assert_str(log.availability("q_recruit_knight", 20, 0.0)).is_equal("")


func test_chain_level_min_applies() -> void:
	gd.chains["ch_side_scorpions"]["level_min"] = 18
	gd.quests["s04_scorpions"]["level_min"] = 1
	assert_str(log.availability("s04_scorpions", 10, 0.0)).is_equal("level_too_low")
	assert_str(log.availability("s04_scorpions", 18, 0.0)).is_equal("")


func test_daily_chain_resets_next_day() -> void:
	var cid := "ch_d01_patrol"
	_finish("d01_patrol", 5, 100.0)
	assert_str(log.chain_state(cid, 100.0)).is_equal("done")
	assert_str(log.availability("d01_patrol", 5, 100.0)).is_equal("already_done")
	var next_day := 100.0 + float(gd.rules["quests"]["day_seconds"])
	assert_str(log.chain_state(cid, next_day)).is_equal("none")
	assert_str(log.availability("d01_patrol", 5, next_day)).is_equal("")


func test_item_reset_requires_done_chain_and_item() -> void:
	var cid := "ch_side_ore"
	assert_str(log.reset_chain(cid, inv, 0.0).error).is_equal("not_done")
	_finish("s02_ore", 6)
	assert_str(log.reset_chain(cid, inv, 0.0).error).is_equal("no_item")
	inv.add_material("time_scroll", 1)
	assert_bool(log.reset_chain(cid, inv, 0.0).ok).is_true()
	assert_int(inv.material_count("time_scroll")).is_equal(0)
	assert_str(log.chain_state(cid, 0.0)).is_equal("none")
	assert_str(log.availability("s02_ore", 6, 0.0)).is_equal("")
	assert_int(int(log.chains_cleared[cid])).is_equal(1)  # история сохраняется
	assert_str(log.reset_chain("ch_side_leather", inv, 0.0).error).is_equal("not_resettable")
	assert_str(log.reset_chain("nope", inv, 0.0).error).is_equal("unknown_chain")


func test_remote_accept_and_turn_in_rules() -> void:
	assert_str(log.accept_remote("s01_leather", 10, 0.0).error).is_equal("remote_level")
	assert_bool(log.accept_remote("s01_leather", 20, 0.0).ok).is_true()
	inv.add_material("leather", 99)
	assert_bool(log.turn_in_remote("s01_leather", _ctx(20)).ok).is_true()
	assert_str(log.accept_remote("q_recruit_swordsman", 30, 0.0).error).is_equal("remote_not_allowed")
	assert_str(log.accept_remote("nope", 30, 0.0).error).is_equal("unknown_quest")
	log.accept("q_recruit_swordsman", 30, 0.0)
	assert_str(log.turn_in_remote("q_recruit_swordsman", _ctx(30)).error).is_equal("remote_not_allowed")


func test_objective_zone_points_to_the_next_place() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	assert_str(log.objective_zone("m01_first_steps", inv, 1)).is_equal("z_meadow")
	_kill("enc_meadow_slimes")
	assert_str(log.objective_zone("m01_first_steps", inv, 1)).is_equal("z_harbor")  # сдать Орвину
	assert_str(log.objective_zone("nope", inv, 1)).is_equal("")
	gd.quests["x_talk"] = {"id": "x_talk", "kind": "side", "giver": "npc_orvin", "turn_in": "npc_orvin", "level_min": 1, "name": "t", "rewards": {},
		"objectives": [{"type": "talk", "target": "npc_tavia", "count": 1, "text": "t"}]}
	gd.quests["x_visit"] = {"id": "x_visit", "kind": "side", "giver": "npc_orvin", "turn_in": "npc_orvin", "level_min": 1, "name": "v", "rewards": {},
		"objectives": [{"type": "visit", "target": "z_mine", "count": 1, "text": "v"}, {"type": "collect", "target": "leather", "count": 1, "text": "c"}]}
	log.accept("x_talk", 1, 0.0)
	log.accept("x_visit", 1, 0.0)
	assert_str(log.objective_zone("x_talk", inv, 1)).is_equal("z_crossroads")
	assert_str(log.objective_zone("x_visit", inv, 1)).is_equal("z_mine")
	log.on_event({"type": "visit", "zone": "z_mine"})
	assert_str(log.objective_zone("x_visit", inv, 1)).is_equal("")  # осталось собрать материал: места нет


func test_teleport_toward_objective_zone() -> void:
	var w := PlayerWorld.new(gd, 0.0)
	w.discovered["z_crossroads"] = true
	var r := w.teleport_toward("z_forest", 5, 0.0)
	assert_bool(r.ok).is_true()
	assert_str(r.town).is_equal("z_crossroads")
	assert_int(r.seconds_left).is_equal(25)
	assert_str(w.zone_id).is_equal("z_crossroads")
	assert_str(w.teleport_toward("z_crossroads", 5, 0.0).error).is_equal("already_there")
	assert_str(w.teleport_toward("nope", 5, 0.0).error).is_equal("unknown_zone")


func test_new_objective_types_follow_events() -> void:
	gd.quests["x_any"] = {"id": "x_any", "kind": "side", "giver": "npc_orvin", "turn_in": "npc_orvin", "level_min": 1, "name": "a", "rewards": {},
		"objectives": [{"type": "kill_any", "target": ["enc_meadow_slimes", "enc_meadow_wolves"], "count": 3, "text": "a"},
			{"type": "tbs_clear", "target": "watchtower", "count": 1, "text": "b"}, {"type": "escort", "target": "npc_tavia", "count": 1, "text": "c"}]}
	log.accept("x_any", 1, 0.0)
	_kill("enc_meadow_slimes")
	_kill("enc_meadow_wolves")
	_kill("enc_forest_bandits")  # не из списка
	assert_int(log.objective_count("x_any", 0, inv, 1)).is_equal(2)
	_kill("enc_meadow_wolves")
	assert_int(log.objective_count("x_any", 0, inv, 1)).is_equal(3)
	log.on_event({"type": "tbs_clear", "mission": "other"})
	assert_int(log.objective_count("x_any", 1, inv, 1)).is_equal(0)
	log.on_event({"type": "tbs_clear", "mission": "watchtower"})
	log.on_event({"type": "escort", "npc": "npc_edric"})
	assert_int(log.objective_count("x_any", 2, inv, 1)).is_equal(0)
	log.on_event({"type": "escort", "npc": "npc_tavia"})
	assert_str(log.state("x_any", inv, 1, 0.0)).is_equal("ready")
	var bad := GameData.load_dir()
	bad.quests["x_bad"] = {"id": "x_bad", "kind": "side", "giver": "npc_orvin", "turn_in": "npc_orvin", "level_min": 1, "name": "b", "rewards": {},
		"objectives": [{"type": "tbs_clear", "target": "ghost", "count": 1, "text": "b"}, {"type": "kill_any", "target": [], "count": 1, "text": "c"}]}
	var text := "\n".join(bad.validate())
	assert_bool(text.contains("нет миссии ghost")).is_true()
	assert_bool(text.contains("kill_any требует список")).is_true()


func test_journal_filters_favorites_and_tracker() -> void:
	var main_only := log.journal({"category": "main"}, 1, 0.0)
	assert_int(main_only.size()).is_equal(1)
	assert_str(main_only[0].state).is_equal("none")
	assert_int(main_only[0].steps).is_equal(7)
	# Цепочки выше уровня героя скрыты, пока не начаты.
	assert_int(log.journal({"category": "recruit"}, 1, 0.0).size()).is_equal(0)
	assert_int(log.journal({"category": "recruit"}, 3, 0.0).size()).is_equal(7)
	log.accept("m01_first_steps", 1, 0.0)
	assert_int(log.journal({"state": "active"}, 1, 0.0).size()).is_equal(1)
	assert_bool(log.toggle_favorite("ch_main_harbor").favorite).is_true()
	var tr := log.tracker(inv, 1, 0.0)
	assert_int(tr.size()).is_equal(1)
	assert_str(tr[0].quest).is_equal("m01_first_steps")
	assert_str(tr[0].zone).is_equal("z_meadow")
	assert_int(tr[0].objectives[0].need).is_equal(1)
	assert_bool(log.toggle_favorite("ch_main_harbor").favorite).is_false()
	assert_str(log.toggle_favorite("nope").error).is_equal("unknown_chain")
	var limit := int(gd.rules["quests"]["max_favorites"])
	var ids: Array = gd.chains.keys()
	for i in limit:
		assert_bool(log.toggle_favorite(ids[i]).ok).is_true()
	assert_str(log.toggle_favorite(ids[limit]).error).is_equal("too_many_favorites")


func test_save_and_load_roundtrip() -> void:
	_finish("m01_first_steps", 1)
	log.accept("m02_wolves", 5, 0.0)
	_kill("enc_meadow_wolves")
	log.toggle_favorite("ch_main_harbor")
	var d := log.to_dict()
	var copy := QuestLog.new(gd)
	copy.load_dict(JSON.parse_string(JSON.stringify(d)))  # через JSON, как при сохранении
	assert_bool(copy.completed.has("m01_first_steps")).is_true()
	assert_int(int(copy.active["m02_wolves"][1])).is_equal(1)
	assert_array(copy.favorites).is_equal(["ch_main_harbor"])
	assert_int(copy.chain_step("ch_main_harbor", 0.0)).is_equal(1)
