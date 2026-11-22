extends GdUnitTestSuite

var gd: GameData
var log: QuestLog
var world: PlayerWorld
var run: DialogueRunner
var inv: Inventory
var sq: Squad
var wallet: Dictionary


func before_test() -> void:
	gd = GameData.load_dir()
	log = QuestLog.new(gd)
	world = PlayerWorld.new(gd, 0.0)
	run = DialogueRunner.new(gd, log, world)
	inv = Inventory.new(gd)
	sq = Squad.new(gd)
	sq.create_hero("sword")
	wallet = {"coins": 0}


func _ctx(level := 1, now := 0.0) -> Dictionary:
	return {"inv": inv, "squad": sq, "wallet": wallet, "level": level, "now": now}


func _texts(view: Dictionary) -> Array:
	return view.choices.map(func(c): return c.text)


func test_cannot_talk_to_npc_in_another_zone_or_unknown() -> void:
	assert_str(run.start("npc_tavia", _ctx()).error).is_equal("wrong_zone")
	assert_str(run.start("npc_ghost", _ctx()).error).is_equal("unknown_npc")
	assert_str(run.choose(0, _ctx()).error).is_equal("not_running")


func test_cannot_talk_while_traveling() -> void:
	world.travel_to("z_meadow", 1, 0.0)
	assert_str(run.start("npc_orvin", _ctx(1, 5.0)).error).is_equal("busy")


func test_start_shows_greeting_quest_offer_and_exit() -> void:
	var res := run.start("npc_orvin", _ctx())
	assert_bool(res.ok).is_true()
	var t := _texts(res.view)
	assert_bool("Задание: Первые шаги" in t).is_true()
	assert_bool("До встречи" in t).is_true()
	assert_bool(res.view.text.begins_with("Капитан порта Орвин")).is_true()


func test_accept_quest_through_dialogue() -> void:
	run.start("npc_orvin", _ctx())
	var res := run.choose(0, _ctx())
	assert_bool(res.ok).is_true()
	assert_str(res.accepted).is_equal("m01_first_steps")
	assert_str(res.view.quest_line).is_equal(gd.quests["m01_first_steps"]["dialogue"]["accepted"])
	assert_bool(log.active.has("m01_first_steps")).is_true()
	assert_bool("Задание: Первые шаги" in _texts(res.view)).is_false()  # больше не предлагается


func test_turn_in_through_dialogue_gives_rewards() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	log.on_event({"type": "kill", "encounter": "enc_meadow_slimes"})
	var res := run.start("npc_orvin", _ctx())
	var idx := _texts(res.view).find("Сдать: Первые шаги")
	assert_int(idx).is_greater_equal(0)
	var out := run.choose(idx, _ctx())
	assert_str(out.turned_in).is_equal("m01_first_steps")
	assert_int(wallet.coins).is_equal(50)
	assert_bool("Сдать: Первые шаги" in _texts(out.view)).is_false()


func test_turn_in_not_offered_to_wrong_npc() -> void:
	log.accept("m01_first_steps", 1, 0.0)
	log.on_event({"type": "kill", "encounter": "enc_meadow_slimes"})
	var res := run.start("npc_tobin", _ctx())
	for t in _texts(res.view):
		assert_bool(t.begins_with("Сдать")).is_false()


func test_legacy_journal_resumes_with_new_dialogue_and_one_reward() -> void:
	var legacy := {"active": {"m02_wolves": [1, 0]}, "completed": {"m01_first_steps": true},
		"daily_accepted": {"d01_patrol": 0}, "daily_done": {"d01_patrol": 0},
		"chains_cleared": {"ch_tutorial_harbor": 1}, "favorites": ["ch_main_harbor"]}
	log.load_dict(JSON.parse_string(JSON.stringify(legacy)))
	assert_dict(log.to_dict()).is_equal(JSON.parse_string(JSON.stringify(legacy)))
	var quest: Dictionary = gd.quests["m02_wolves"]
	var view := run.start("npc_orvin", _ctx(5)).view as Dictionary
	var discuss := _texts(view).find("Обсудить: Волчья стая")
	assert_int(discuss).is_greater_equal(0)
	assert_str(run.choose(discuss, _ctx(5)).view.quest_line).is_equal(quest.dialogue.active)
	log.on_event({"type": "kill", "encounter": "enc_meadow_wolves"})
	view = run.start("npc_orvin", _ctx(5)).view
	discuss = _texts(view).find("Обсудить: Волчья стая")
	assert_str(run.choose(discuss, _ctx(5)).view.quest_line).is_equal(quest.dialogue.ready)
	view = run.start("npc_orvin", _ctx(5)).view
	var turn_in := _texts(view).find("Сдать: Волчья стая")
	var completed := run.choose(turn_in, _ctx(5))
	assert_str(completed.view.quest_line).is_equal(quest.dialogue.completed)
	assert_int(wallet.coins).is_equal(int(quest.rewards.coins))
	var reopened := QuestLog.new(gd)
	reopened.load_dict(JSON.parse_string(JSON.stringify(log.to_dict())))
	assert_str(reopened.state("m02_wolves", inv, 5, 0.0)).is_equal("done")
	assert_bool(reopened.turn_in("m02_wolves", _ctx(5), "npc_orvin").ok).is_false()
	assert_int(wallet.coins).is_equal(int(quest.rewards.coins))


func test_choice_navigation_and_end() -> void:
	var res := run.start("npc_tobin", _ctx())
	var about := _texts(res.view).find("Расскажи о себе")
	var r2 := run.choose(about, _ctx())
	assert_bool(r2.view.text.contains("торгует")).is_true()
	var back := _texts(r2.view).find("Назад")
	var r3 := run.choose(back, _ctx())
	assert_bool(r3.view.text.begins_with("Торговец Тобин")).is_true()
	var bye := _texts(r3.view).find("До встречи")
	var r4 := run.choose(bye, _ctx())
	assert_bool(r4.view.is_empty()).is_true()
	assert_bool(run.running).is_false()


func test_service_choice_reports_service_for_client() -> void:
	var res := run.start("npc_tobin", _ctx())
	var shop := _texts(res.view).find("Открыть лавку")
	assert_int(shop).is_greater_equal(0)
	assert_str(run.choose(shop, _ctx()).service).is_equal("shop")


func test_bad_choice_index_rejected() -> void:
	run.start("npc_orvin", _ctx())
	assert_str(run.choose(99, _ctx()).error).is_equal("bad_choice")
	assert_str(run.choose(-1, _ctx()).error).is_equal("bad_choice")


func test_accept_error_is_reported_through_dialogue() -> void:
	run.start("npc_orvin", _ctx())
	log.accept("m01_first_steps", 1, 0.0)  # взято в обход диалога
	var res := run.choose(0, _ctx())
	assert_bool(res.ok).is_false()  # устаревший пункт: задание уже активно


func test_talk_objective_counts_on_dialogue_start() -> void:
	# сгенерируем задание на разговор прямо в данных
	gd.quests["t_talk"] = {"id": "t_talk", "name": "Поговорить", "kind": "side", "giver": "npc_orvin", "turn_in": "npc_orvin", "level_min": 1,
		"objectives": [{"type": "talk", "target": "npc_tobin", "count": 1, "text": "Поговорить с Тобином"}], "rewards": {"coins": 7}}
	log.accept("t_talk", 1, 0.0)
	run.start("npc_tobin", _ctx())
	assert_str(log.state("t_talk", inv, 1, 0.0)).is_equal("ready")


func test_every_npc_dialogue_starts_and_ends() -> void:
	for id in gd.npcs:
		var w := PlayerWorld.new(gd, 0.0)
		w.zone_id = gd.npcs[id].zone
		var r := DialogueRunner.new(gd, QuestLog.new(gd), w)
		var res := r.start(id, _ctx(99))
		assert_bool(res.ok).is_true()
		var bye := _texts(res.view).find("До встречи")
		assert_int(bye).is_greater_equal(0)
		r.choose(bye, _ctx(99))
		assert_bool(r.running).is_false()


func test_full_flow_travel_fight_report() -> void:
	var c := _ctx(1, 0.0)
	run.start("npc_orvin", c)
	run.choose(0, c)  # взять «Первые шаги»
	var r := world.travel_to("z_meadow", 1, 0.0)
	var t := float(r.seconds)
	world.update(t)
	log.on_event({"type": "visit", "zone": world.zone_id})
	assert_str(world.can_fight("enc_meadow_slimes", t)).is_equal("")
	log.on_event({"type": "kill", "encounter": "enc_meadow_slimes"})
	var back := world.travel_to("z_harbor", 1, t)
	world.update(t + float(back.seconds))
	var c2 := _ctx(1, t + float(back.seconds))
	var res := run.start("npc_orvin", c2)
	var idx := _texts(res.view).find("Сдать: Первые шаги")
	assert_int(idx).is_greater_equal(0)
	assert_str(run.choose(idx, c2).turned_in).is_equal("m01_first_steps")
	assert_int(sq.hero.level).is_equal(2)
	assert_int(sq.hero.xp).is_equal(2)
