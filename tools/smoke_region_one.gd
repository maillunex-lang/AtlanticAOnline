extends SceneTree
## Offline slice: godot --headless --script tools/smoke_region_one.gd
## Visits scene markers directly. Pedestrian reachability is checked by test_world_scenes.gd.

class OfflineSettings extends DemoSettings:
	func load_file() -> void:
		hero_class = "warden"

	func save_file() -> void:
		pass

var demo: DemoMain
var locations: Dictionary = {}
var battles := 0


func _initialize() -> void:
	call_deferred("_run")


func _start_demo() -> void:
	demo = (load("res://scenes/demo.tscn") as PackedScene).instantiate()
	demo.settings = OfflineSettings.new()
	root.add_child(demo)
	demo.set_process(false)
	demo.map.set_process(false)
	demo.map.streamer.use_threads = false
	demo.rng.seed = 409
	_index_world()



func _run() -> void:
	_start_demo()
	await _check_town_service_scroll()
	_check_effect_icons()
	_check_release_start()
	_check_harbor_fishing()
	demo.free()
	locations.clear()
	battles = 0
	_start_demo()
	demo._add_smoke_roster()
	demo.refresh_hud()
	assert(demo.squad.hero.level == 1)
	_check_resident_routine()
	_check_meadow_stops()
	_quest_dialogue("npc_orvin", "q_ne_field_practice", "accept")
	_quest_dialogue("npc_orvin", "tut01_port", "accept")
	_quest_dialogue("npc_mira", "tut01_port", "turn_in")
	_quest_dialogue("npc_mira", "tut02_gear", "accept")
	_quest_dialogue("npc_hild", "tut02_gear", "turn_in")
	_quest_dialogue("npc_hild", "tut03_field", "accept")
	for chain_id in ["ch_main_harbor", "main_02", "main_03"]:
		for quest_id: String in demo.gd.chains[chain_id]["steps"]:
			var quest: Dictionary = demo.gd.quests[quest_id]
			_quest_dialogue(quest["giver"], quest_id, "accept")
			for objective: Dictionary in quest["objectives"]:
				var id := str(objective["target"])
				match objective["type"]:
					"activity":
						_story_activity(id)
					"visit":
						_arrive(locations[id][0])
					"talk":
						_talk(id)
						demo._close_info()
					"kill":
						for _index in int(objective["count"]):
							_fight(id)
					"dungeon_clear":
						_dungeon(id, quest_id)
					_:
						assert(false, "Unsupported objective: " + str(objective["type"]))
			assert(demo.log.set_hud_quest(quest_id, true))
			demo.refresh_hud()
			assert((demo.hud.quest_rows.find_child("QuestTitle", true, false) as Button).text.contains(demo.gd.npcs[quest["turn_in"]]["name"]), quest_id)
			_quest_dialogue(quest["turn_in"], quest_id, "turn_in")
			if quest_id == "m04_mine_survey":
				assert(demo.map.streamer.nodes[Vector2i(5, 0)].get_node("RecoveredCargo").visible)
			if quest_id == "m01_first_steps":
				_quest_dialogue("npc_orvin", "tut03_field", "turn_in")
				assert(demo.log.chain_state("ch_tutorial_harbor", demo.now) == "done")
				print("Tutorial PASS: port, town services and first battle")
			print("WP-24 ", quest_id, " level=", demo.squad.hero.level)
			await process_frame
		assert(demo.log.chain_state(chain_id, demo.now) == "done", chain_id)
	assert(demo.squad.hero.level == 20)
	assert(battles == 19)
	print("WP-24 story PASS: level 20, ", battles, " battle victories")
	_arrive(locations["npc_liska"][0])
	assert(demo.map.streamer.nodes[Vector2i(8, 0)].get_node("SignalBeacon").visible)
	_arrive(locations["npc_edric"][0])
	assert(demo.map.streamer.nodes[Vector2i(5, 0)].get_node("RecoveredCargo").visible)
	_check_recruitment()
	_check_field_practice()
	_check_citadel_watch()
	_check_signal_ledger()
	await _check_promotion()
	_check_equipment_set()
	await _check_crafting_professions()
	print("WP-24 PASS: story and recruitment")
	_check_south_route()
	quit()


func _buy_fishing_bait(npc_id: String) -> void:
	_talk(npc_id)
	_press_dialogue_button("Открыть лавку")
	assert(demo.town_screen != null)
	var stock: Array = demo.gd.town_services["services"]["shop"]["stock"]
	var offer := stock.find_custom(func(row): return row.item == "fishing_bait")
	assert(offer >= 0 and demo.buy_at_shop(offer).is_empty())
	demo._close_town()


func _open_fishing_spot(id: String) -> void:
	_arrive(locations[id][0])
	demo.map._process(0.0)
	assert(demo.hud.interact_button.visible and demo.map._interaction.npc_id == id)
	demo.hud.interact_button.pressed.emit()
	_press_dialogue_button("Подойти к воде")
	assert(demo._fishing_spot == id)


func _check_harbor_fishing() -> void:
	_buy_fishing_bait("npc_tobin")
	assert(demo.inv.material_count("fishing_bait") == 5)
	_open_fishing_spot("npc_harbor_fishing")
	_press_dialogue_button("Закинуть удочку")
	demo._process(7.0)
	assert(demo.inv.material_count("coastal_fish") == 0)
	demo._process(1.0)
	demo._process(8.0)
	assert(demo.inv.material_count("coastal_fish") == 2)
	assert(demo.inv.material_count("fishing_bait") == 3)
	_press_dialogue_button("Смотать удочку")
	_press_dialogue_button("Приготовить паёк · рыба ×2")
	assert(demo.inv.material_count("fish_ration") == 1)
	var saved := demo.settings.tomb_checkpoint.duplicate(true)
	demo._close_info()
	demo.fishing.xp = 0
	TombCheckpoint.restore(demo, saved)
	assert(demo.fishing.xp == 10 and demo.inv.material_count("fish_ration") == 1)
	demo.world.restore_will_snapshot({"points": 85, "time": demo.now})
	assert(demo.use_fish_ration() == "Запас хода пополнен.")
	assert(demo.world.will_at(demo.now) == 93)
	assert(demo.settings.tomb_checkpoint["will"]["points"] == 93)
	print("Harbor fishing PASS: shop, automatic catches, cooking and restored save")


func _check_resident_routine() -> void:
	_arrive(locations["npc_orvin"][0] + Vector2(0, -360))
	var orvin: NpcMarker
	for npc in demo.map.npcs:
		if npc.npc_id == "npc_orvin":
			orvin = npc
			break
	assert(orvin != null)
	var work := orvin.position
	var home := orvin.routine[-1]
	var visited_home := false
	var returned_to_work := false
	for step in 800:
		demo.map._process(0.1)
		visited_home = visited_home or orvin.position == home
		if visited_home and orvin.position == work:
			returned_to_work = true
			break
	assert(visited_home and returned_to_work)
	_arrive(orvin.global_position)
	demo.map._process(0.0)
	assert(demo.hud.interact_button.visible and not demo.runner.running)
	_arrive(orvin.global_position + Vector2(0, -360))
	demo.map._process(0.0)
	assert(not demo.hud.interact_button.visible and not demo.runner.running)
	print("Resident routines PASS: work, home, return and explicit interaction")


func _check_meadow_stops() -> void:
	_talk("npc_meadow_teamster")
	_press_dialogue_button("Осмотреть колесо")
	assert(demo.runner.node_id == "wheel")
	demo._close_info()
	_arrive(locations["npc_forest_tracks"][0])
	demo.map._process(0.0)
	assert(demo.hud.interact_button.visible and demo.hud.interact_button.text.begins_with("Осмотреть"))
	demo.hud.interact_button.pressed.emit()
	assert(demo.runner.running and demo.runner.npc_id == "npc_forest_tracks")
	_press_dialogue_button("До встречи")
	assert(not demo.runner.running)
	demo._close_info()
	_arrive(locations["npc_edric"][0])
	assert(not demo.map.streamer.nodes[Vector2i(5, 0)].get_node("RecoveredCargo").visible)
	print("Everheim road PASS: teamster, trail discovery and original yard")


func _check_town_service_scroll() -> void:
	var original_size := root.size
	root.size = Vector2i(1280, 600)
	assert(demo._open_town("town_directory"))
	var town := demo.town_screen
	await process_frame
	await process_frame
	var scroll := town.service_scroll
	var bar := scroll.get_v_scroll_bar()
	assert(bar.max_value > bar.page)
	var first := town.choices.get_child(2) as Button
	var start := first.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.position = start
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for _step in 3:
		root.push_input(wheel, true)
	assert(scroll.scroll_vertical > 0)
	scroll.scroll_vertical = 0
	await process_frame
	await _drag_scroll_from_row(first)
	assert(scroll.scroll_vertical > 0)
	assert(town.service == "town_directory")
	demo._close_town()
	root.size = original_size
	await process_frame
	print("Town services scroll PASS: list scrolls without opening a service")


func _drag_scroll_from_row(row: Control) -> void:
	var previous_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var start := row.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = start
	root.push_input(hover, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	var previous := start
	for distance in [20, 48, 80]:
		var drag := InputEventMouseMotion.new()
		drag.position = start - Vector2(0, distance)
		drag.relative = drag.position - previous
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag, true)
		previous = drag.position
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = previous
	root.push_input(release, true)
	Input.emulate_touch_from_mouse = previous_emulation


func _check_effect_icons() -> void:
	var view := (load("res://scenes/battle/unit_view.tscn") as PackedScene).instantiate() as UnitView
	root.add_child(view)
	var fighter := BattleUnit.make(1, BattleRules.SIDE_A, 0)
	fighter.stats.add_modifier("squad_bonus", "def", StatBlock.Kind.PERCENT, 5)
	view.setup(fighter, "Боец", "")
	assert(not view.status_icons.visible)
	fighter.guarding = true
	fighter.dots.append({"power": 6, "turns": 2})
	view.refresh(fighter, true)
	assert(view.status_icons.get_child_count() == 3)
	var poison := view.status_icons.get_child(2) as Button
	assert(poison.icon != null and poison.text == "2" and poison.tooltip_text.contains("Яд"))
	var messages: Array[String] = []
	view.effect_pressed.connect(func(description: String): messages.append(description))
	poison.pressed.emit()
	assert(messages.size() == 1 and messages[0].contains("Яд"))
	fighter.guarding = false
	fighter.dots.clear()
	view.refresh(fighter)
	assert(not view.status_icons.visible)
	view.free()


func _check_release_start() -> void:
	assert(demo.squad.hero.level == 1 and demo.squad.all_mercenaries().is_empty())
	assert(not demo.squad.recruit("archer", "tutorial", demo.wallet).ok)
	_quest_dialogue("npc_orvin", "tut01_port", "accept")
	assert(not demo.hud.quest_rows.visible)
	demo.open_menu("quests")
	var checkbox := demo._menu.find_child("ShowOnHud", true, false) as CheckButton
	assert(checkbox != null and not checkbox.button_pressed)
	checkbox.button_pressed = true
	assert(demo.hud.quest_rows.visible and (demo.hud.quest_rows.find_child("QuestTitle", true, false) as Button).text.contains("Знакомство с портом"))
	checkbox = demo._menu.find_child("ShowOnHud", true, false) as CheckButton
	checkbox.button_pressed = false
	assert(not demo.hud.quest_rows.visible and demo.log.active.has("tut01_port"))
	demo.close_menu()
	_quest_dialogue("npc_orvin", "q_ne_field_practice", "accept")
	assert(demo.log.set_hud_quest("q_ne_field_practice", true))
	demo.refresh_hud()
	assert(demo.hud.quest_rows.find_child("QuestDetails", true, false) == null)
	var toggle := demo.hud.quest_rows.find_child("QuestToggle", true, false) as Button
	assert(toggle != null)
	toggle.pressed.emit()
	assert(demo.hud.quest_rows.find_child("QuestDetails", true, false) != null)
	toggle = demo.hud.quest_rows.find_child("QuestToggle", true, false) as Button
	toggle.pressed.emit()
	assert(demo.hud.quest_rows.find_child("QuestDetails", true, false) == null)
	assert(demo.log.set_hud_quest("q_ne_field_practice", false))
	_quest_dialogue("npc_mira", "tut01_port", "turn_in")
	_talk("npc_mira")
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("service") == "recruiter":
			demo._dialogue_choose(index)
			break
	assert(demo.town_screen != null)
	var coins := int(demo.wallet["coins"])
	for child in demo.town_screen.content.get_children():
		if child is Button and child.text == "Нанять лучника бесплатно · обучение":
			child.pressed.emit()
			break
	assert(demo.squad.count_of("archer") == 1 and demo.wallet["coins"] == coins)
	assert(not demo.squad.recruit("archer", "tutorial", demo.wallet, ["tut01_port"]).ok)
	demo._close_town()
	_quest_dialogue("npc_orvin", "m01_first_steps", "accept")
	assert(demo.log.set_hud_quest("m01_first_steps", true))
	demo.refresh_hud()
	var tracked := demo.hud.quest_rows.find_child("QuestTitle", true, false) as Button
	tracked.pressed.emit()
	_walk_quest_route()
	assert(demo.battle != null and demo.world.zone_id == "z_meadow")
	_win_battle("enc_meadow_slimes")
	demo._close_info()
	tracked = demo.hud.quest_rows.find_child("QuestTitle", true, false) as Button
	tracked.pressed.emit()
	_walk_quest_route()
	assert(demo._info == null and demo.hud.interact_button.visible)
	assert(demo.hud.interact_button.text.begins_with("Поговорить"))
	demo.hud.interact_button.pressed.emit()
	assert(not demo.hud.interact_button.visible)
	assert(demo.runner.npc_id == "npc_orvin" and demo._info != null)
	var turn_in_mark := demo._info.choice_list.get_children().filter(
		func(button): return button.text.begins_with("!  Сдать: Первые шаги"))
	assert(turn_in_mark.size() == 1)
	assert(turn_in_mark[0].get_theme_color("font_color") == NpcMarker.QUEST_COLORS["main"])
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("turn_in") == "m01_first_steps":
			demo._dialogue_choose(index)
			break
	assert(demo.log.completed.has("m01_first_steps"))
	demo._close_info()
	print("Quest autorun PASS: HUD click reaches encounter, then turn-in NPC")
	_quest_dialogue("npc_orvin", "m02_wolves", "accept")
	_fight("enc_meadow_wolves")
	_quest_dialogue("npc_orvin", "m02_wolves", "turn_in")
	print("Release start PASS: solo hero, tutorial recruit, slimes and wolves")


func _walk_quest_route() -> void:
	assert(not demo.map._quest_route.is_empty())
	for _step in 1500:
		demo.map._process(0.05)
		if demo.map._quest_route.is_empty():
			break


func _check_south_route() -> void:
	_quest_dialogue("npc_sava", "m07_south", "accept")
	_walk_to_southern_goal("npc", "npc_orvin")
	_ferry_dialogue("npc_orvin")
	assert(demo.world.zone_id == "z_oasis")
	_quest_dialogue("npc_nadia", "m07_south", "turn_in")
	_quest_dialogue("npc_yara", "q_se_cistern_cloth", "accept")
	_quest_dialogue("npc_nadia", "q_se_water_marks", "accept")
	_talk("npc_said")
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("activity") == "se_water_mark":
			demo._dialogue_choose(index)
			break
	demo._close_info()
	_quest_dialogue("npc_said", "q_se_water_marks", "turn_in")
	_quest_dialogue("npc_said", "q_se_clear_way", "accept")
	_fight("enc_dunes_drifters")
	_quest_dialogue("npc_nadia", "q_se_clear_way", "turn_in")
	# Exercise a legitimate supply purchase rather than relying on loot rolls.
	_talk("npc_yara")
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("service") == "shop":
			demo._dialogue_choose(index)
			break
	assert(demo.town_screen != null)
	while demo.inv.material_count("cloth_scrap") < 4:
		assert(demo.town_services.buy(demo.world, demo.wallet, demo.inv, 2).is_empty())
	demo._close_town()
	_quest_dialogue("npc_yara", "q_se_cistern_cloth", "turn_in")
	_progress_step("npc_nadia", "npc_said", "q_se_dune_notice")
	_progress_step("npc_said", "npc_yara", "q_se_dune_water_list")
	assert(demo.squad.hero.level >= 22)
	print("Early South level 22 PASS: dunes dispatch")
	_check_echo_canyon()
	_ferry_dialogue("npc_yara")
	assert(demo.world.zone_id == "z_harbor")
	print("Southeast Asia ferry and dunes PASS: both sailings and Oasis errands")


func _check_echo_canyon() -> void:
	var border := Vector2(96 * 64, 110.5 * 64)
	_quest_dialogue("npc_nadia", "q_se_echo_pass", "accept")
	_arrive(border - Vector2(32, 0))
	assert(not demo.map._blocked(border + Vector2(32, 0)))
	assert(demo.map._move(Vector2(64, 0)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_canyon")
	_inspect_echo("npc_amina", "se_echo_survey")
	demo.log.load_dict(JSON.parse_string(JSON.stringify(demo.log.to_dict())))
	_quest_dialogue("npc_amina", "q_se_echo_pass", "turn_in")
	_quest_dialogue("npc_amina", "q_se_echo_road", "accept")
	_quest_dialogue("npc_amina", "q_se_echo_bandages", "accept")
	demo.inv.add_material("cloth_scrap", 5)
	_quest_dialogue("npc_amina", "q_se_echo_bandages", "turn_in")
	_quest_dialogue("npc_salih", "q_se_echo_watch", "accept")
	_fight("enc_canyon_sentries")
	_quest_dialogue("npc_salih", "q_se_echo_watch", "turn_in")
	_fight("enc_canyon_mummies")
	_quest_dialogue("npc_nadia", "q_se_echo_road", "turn_in")
	_progress_step("npc_nadia", "npc_amina", "q_se_canyon_account")
	_progress_step("npc_amina", "npc_salih", "q_se_canyon_witness")
	_progress_step("npc_salih", "npc_nadia", "q_se_canyon_return")
	assert(demo.squad.hero.level >= 25)
	print("Early South level 25 PASS: canyon report")
	_quest_dialogue("npc_salih", "q_se_echo_seal", "accept")
	_inspect_echo("npc_salih", "se_echo_seal")
	var keys := demo.inv.material_count("key_tomb")
	_quest_dialogue("npc_salih", "q_se_echo_seal", "turn_in")
	assert(demo.inv.material_count("key_tomb") == keys + 1)
	assert(not demo.log.turn_in("q_se_echo_seal", demo._ctx(), "npc_salih").ok)
	_check_sand_tomb()
	_arrive(border + Vector2(32, 0))
	assert(demo.map._move(Vector2(-64, 0)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_dunes")
	var oasis_border := Vector2(32 * 64, 111.5 * 64)
	_arrive(oasis_border + Vector2(32, 0))
	assert(demo.map._move(Vector2(-64, 0)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_oasis")
	print("Echo Canyon PASS: both crossings, five quests, restored journal and one key")


func _check_sand_tomb() -> void:
	_quest_dialogue("npc_salih", "q_se_tomb_archive", "accept")
	var keys := demo.inv.material_count("key_tomb")
	var entrance := _spawn_for("enc_tomb_1")
	demo.map.enemy_contact.emit(entrance)
	_press_dialogue_button("Открыть ключом")
	assert(demo.inv.material_count("key_tomb") == keys - 1)
	_win_battle("enc_tomb_1")
	var remaining_keys := demo.inv.material_count("key_tomb")
	_press_dialogue_button("Выйти в Каньон Эха")
	assert(demo.world.zone_id == "z_canyon")
	assert(demo._dungeon_run.stage == 1 and not demo._dungeon_run.can_fight())
	var boss := _spawn_for("enc_tomb_boss")
	demo.map.enemy_contact.emit(boss)
	assert(demo.battle == null)
	demo._close_info()
	_tomb_action("npc_tomb_tablet", "tomb_tablet")
	assert(demo._dungeon_run.findings.is_empty())
	_tomb_action("npc_tomb_wheels", "tomb_wrong_wheel")
	assert(demo._dungeon_run.findings.is_empty())
	_tomb_action("npc_tomb_wheels", "tomb_wheels")
	# Reload the same Variant representation used by ConfigFile.
	var cfg := ConfigFile.new()
	cfg.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(cfg.encode_to_text()) == OK)
	demo._dungeon_run = null
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo._dungeon_run.stage == 1 and demo._dungeon_run.findings.has("tomb_wheels"))
	assert(not demo._dungeon_run.can_fight())
	assert(demo.inv.material_count("key_tomb") == remaining_keys)
	_tomb_action("npc_tomb_tablet", "tomb_tablet")
	assert(demo._dungeon_run.can_fight())
	boss = _spawn_for("enc_tomb_boss")
	demo.map.enemy_contact.emit(boss)
	_press_dialogue_button("Начать бой")
	_win_battle("enc_tomb_boss")
	_press_dialogue_button("Выйти в Каньон Эха")
	assert(demo.world.zone_id == "z_canyon")
	_quest_dialogue("npc_salih", "q_se_tomb_archive", "turn_in")
	assert(not demo.log.turn_in("q_se_tomb_archive", demo._ctx(), "npc_salih").ok)
	_quest_dialogue("npc_salih", "q_se_tomb_trade", "accept")
	_talk("npc_nadia")
	assert(not demo.runner._shown.any(func(choice): return choice.get("next") == "east_market"))
	demo._close_info()
	_quest_dialogue("npc_nadia", "q_se_tomb_trade", "turn_in")
	_talk("npc_nadia")
	_press_dialogue_button("!  Куда ведёт оттиск?")
	assert(demo.runner.running and demo.runner.node_id == "east_market")
	_press_dialogue_button("До встречи")
	_progress_step("npc_nadia", "npc_yara", "q_se_archive_copy")
	assert(demo.squad.hero.level >= 26)
	print("Early South level 26 PASS: archive copy")
	print("Sand Tomb PASS: key, both battles, mechanism order, checkpoint, exit and rewards")
	_check_east_market()


func _check_east_market() -> void:
	var border := Vector2(144.5, 128.0) * 64.0
	_quest_dialogue("npc_nadia", "q_se_market_bridge", "accept")
	_arrive(border - Vector2(0, 32))
	assert(demo.map._move(Vector2(0, 64)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_east_market")
	_talk("npc_market_bridge")
	_press_dialogue_button("!  Проверить опоры у сухой кромки")
	_quest_dialogue("npc_market_ren", "q_se_market_bridge", "turn_in")
	_quest_dialogue("npc_market_ren", "q_se_market_weights", "accept")
	_talk("npc_market_tala")
	_press_dialogue_button("!  Сопоставить оттиск с клеймом на гире")
	_quest_dialogue("npc_market_tala", "q_se_market_weights", "turn_in")
	_quest_dialogue("npc_market_tala", "q_se_market_straps", "accept")
	assert(demo.log.state("q_se_market_straps", demo.inv, 26, demo.now) == "active")
	_talk("npc_market_tala")
	_press_dialogue_button("Открыть торговую точку")
	assert(demo.town_screen != null)
	var coins := int(demo.wallet["coins"])
	var leather := demo.inv.material_count("leather")
	assert(demo.buy_at_shop(1).is_empty())
	assert(int(demo.wallet["coins"]) == coins - 10)
	assert(demo.inv.material_count("leather") == leather + 2)
	demo._close_town()
	var checkpoint := ConfigFile.new()
	checkpoint.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(checkpoint.encode_to_text()) == OK)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo.log.state("q_se_market_straps", demo.inv, 26, demo.now) == "ready")
	_quest_dialogue("npc_market_tala", "q_se_market_straps", "turn_in")
	assert(demo.inv.material_count("leather") == leather + 1)
	assert(not demo.log.turn_in("q_se_market_straps", demo._ctx(), "npc_market_tala").ok)
	_progress_step("npc_market_tala", "npc_market_ren", "q_se_market_receipt")
	assert(demo.squad.hero.level >= 27)
	print("Early South level 27 PASS: market receipt")
	var dock_border := Vector2(149.5, 192.0) * 64.0
	_arrive(dock_border - Vector2(0, 32))
	assert(not demo.map._move(Vector2(0, 64)))
	_quest_dialogue("npc_market_tala", "q_se_market_dispatch", "accept")
	_arrive(border + Vector2(0, 32))
	assert(demo.map._move(Vector2(0, -64)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_canyon")
	_quest_dialogue("npc_nadia", "q_se_market_dispatch", "turn_in")
	assert(demo.log.chains_cleared.has("ch_se_east_market"))
	print("East Arch Market PASS: two-way route, inspections, purchase, checkpoint and rewards")

	_check_lower_dock()
	_check_sluice_finale()
	_check_copper_cove()


func _check_lower_dock() -> void:
	var border := Vector2(149.5, 192.0) * 64.0
	_quest_dialogue("npc_market_tala", "q_se_dock_ledger", "accept")
	_arrive(border - Vector2(0, 32))
	assert(demo.map._move(Vector2(0, 64)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_lower_dock")
	_inspect_echo("npc_dock_ledger", "se_dock_ledger")
	var checkpoint := ConfigFile.new()
	checkpoint.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(checkpoint.encode_to_text()) == OK)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo.world.zone_id == "z_lower_dock")
	assert(demo.log.state("q_se_dock_ledger", demo.inv, 27, demo.now) == "ready")
	_quest_dialogue("npc_dock_mira", "q_se_dock_ledger", "turn_in")
	_quest_dialogue("npc_dock_mira", "q_se_dock_rope", "accept")
	var leather := demo.inv.material_count("leather")
	_quest_dialogue("npc_dock_mira", "q_se_dock_rope", "turn_in")
	assert(demo.inv.material_count("leather") == leather - 1)
	_quest_dialogue("npc_dock_mira", "q_se_dock_proof", "accept")
	_inspect_echo("npc_dock_post", "se_dock_post")
	var marsh_border := Vector2(150.5, 224.0) * 64.0
	_arrive(marsh_border - Vector2(0, 32))
	assert(not demo.map._move(Vector2(0, 64)))
	_arrive(border + Vector2(0, 32))
	assert(demo.map._move(Vector2(0, -64)))
	demo.map._process(0.0)
	assert(demo.world.zone_id == "z_east_market")
	var coins := int(demo.wallet["coins"])
	_quest_dialogue("npc_market_tala", "q_se_dock_proof", "turn_in")
	assert(demo.log.chains_cleared.has("ch_se_lower_dock"))
	assert(not demo.log.turn_in("q_se_dock_proof", demo._ctx(), "npc_market_tala").ok)
	assert(int(demo.wallet["coins"]) == coins + 820)
	print("Lower Docks PASS: two-way route, ledger and mooring post, checkpoint and rewards")


func _check_sluice_finale() -> void:
	var earlier_save := ConfigFile.new()
	earlier_save.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(earlier_save.encode_to_text()) == OK)
	demo.log.completed.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo.log.completed.has("q_se_dock_proof"))
	assert(demo.world.zone_id == "z_east_market")
	_quest_dialogue("npc_market_tala", "q_se_river_survey", "accept")
	_walk_to_southern_goal("npc", "npc_river_gauge")
	assert(demo.world.zone_id == "z_river_marsh")
	var sluice_border := Vector2(147.5, 256.0) * 64.0
	_arrive(sluice_border - Vector2(0, 32))
	assert(not demo.map._move(Vector2(0, 64)))
	_inspect_echo("npc_river_gauge", "se_river_gauge")
	_walk_to_southern_goal("npc", "npc_marsh_ilan")
	_quest_dialogue("npc_marsh_ilan", "q_se_river_survey", "turn_in")
	_quest_dialogue("npc_marsh_ilan", "q_se_river_patrol", "accept")
	_walk_to_southern_goal("enemy", "enc_marsh_roadblock")
	_win_battle("enc_marsh_roadblock")
	demo._close_info()
	assert(demo.settings.tomb_checkpoint["quests"]["active"]["q_se_river_patrol"] == [1])
	_walk_to_southern_goal("npc", "npc_sluice_dara")
	assert(demo.world.zone_id == "z_sluice_town")
	_quest_dialogue("npc_sluice_dara", "q_se_river_patrol", "turn_in")
	_quest_dialogue("npc_sluice_dara", "q_se_sluice_charter", "accept")
	_walk_to_southern_goal("npc", "npc_sluice_winch")
	_inspect_echo("npc_sluice_winch", "se_sluice_winch")
	var ready_checkpoint := demo.settings.tomb_checkpoint.duplicate(true)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, ready_checkpoint)
	assert(demo.log.state("q_se_sluice_charter", demo.inv, demo.squad.hero.level, demo.now) == "ready")
	_walk_to_southern_goal("npc", "npc_nadia")
	assert(demo.world.zone_id == "z_oasis")
	var coins := int(demo.wallet["coins"])
	_quest_dialogue("npc_nadia", "q_se_sluice_charter", "turn_in")
	assert(demo.log.chains_cleared.has("ch_se_river_route"))
	assert(not demo.log.turn_in("q_se_sluice_charter", demo._ctx(), "npc_nadia").ok)
	assert(int(demo.wallet["coins"]) == coins + 1100)
	assert(demo.settings.tomb_checkpoint["quests"]["completed"].has("q_se_sluice_charter"))
	print("Sluice finale PASS: prior checkpoint, walking routes, battle and one reward")


func _check_copper_cove() -> void:
	var old_checkpoint := demo.settings.tomb_checkpoint.duplicate(true)
	old_checkpoint.erase("voyage")
	TombCheckpoint.restore(demo, old_checkpoint)
	assert(not demo.world.traveling and demo.log.completed.has("q_se_sluice_charter"))
	var hero := demo.squad.hero
	var before := Progression.total_xp(hero.level, demo.gd) + hero.xp
	var gap := Progression.total_xp(30, demo.gd) - before
	var victories := battles
	_quest_dialogue("npc_nadia", "q_se_convoy_orders", "accept")
	_walk_to_southern_goal("npc", "npc_sluice_dara")
	if hero.level < 30:
		assert(SeaFerry.depart(demo.world, demo.log, hero.level, demo.now).error == "level_too_low")
	_quest_dialogue("npc_sluice_dara", "q_se_convoy_orders", "turn_in")
	_quest_dialogue("npc_sluice_dara", "q_se_convoy_watch", "accept")
	_walk_to_southern_goal("npc", "npc_marsh_ilan")
	_quest_dialogue("npc_marsh_ilan", "q_se_convoy_watch", "turn_in")
	if hero.level < 30:
		_progress_step("npc_marsh_ilan", "npc_sluice_dara", "q_se_convoy_load")
	assert(hero.level >= 30 and battles == victories)
	_walk_to_southern_goal("npc", "npc_sluice_dara")
	_start_ferry_dialogue("npc_sluice_dara")
	assert(demo.world.traveling and demo.world.destination == SeaFerry.COVE)
	var voyage := ConfigFile.new()
	voyage.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(voyage.encode_to_text()) == OK)
	demo.world.traveling = false
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo.world.traveling and demo.map.frozen)
	demo.now = demo.world.arrive_at - 1.0
	demo._finish_ferry_if_due()
	assert(demo.world.traveling)
	demo.now += 1.0
	demo._finish_ferry_if_due()
	assert(demo.world.zone_id == SeaFerry.COVE and demo.world.discovered.has(SeaFerry.COVE))
	assert(not demo.world.traveling)
	_walk_to_southern_goal("npc", "npc_cove_ines")
	assert(demo.squad.hero.level >= 30 and battles == victories)
	print("Convoy progression PASS: ", gap, " XP missing, level ", demo.squad.hero.level, " without combat or level override")
	_quest_dialogue("npc_cove_ines", "q_sa_tide_survey", "accept")
	_walk_to_southern_goal("npc", "npc_fog_stake")
	_inspect_echo("npc_fog_stake", "sa_fog_stake")
	var survey_checkpoint := demo.settings.tomb_checkpoint.duplicate(true)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, survey_checkpoint)
	assert(demo.log.state("q_sa_tide_survey", demo.inv, 30, demo.now) == "ready")
	_walk_to_southern_goal("npc", "npc_cove_ines")
	_quest_dialogue("npc_cove_ines", "q_sa_tide_survey", "turn_in")
	_quest_dialogue("npc_cove_ines", "q_sa_fog_watch", "accept")
	_walk_to_southern_goal("enemy", "enc_fog_road_robbers")
	_win_battle("enc_fog_road_robbers")
	demo._close_info()
	_walk_to_southern_goal("npc", "npc_cove_ines")
	var coins := int(demo.wallet["coins"])
	_quest_dialogue("npc_cove_ines", "q_sa_fog_watch", "turn_in")
	assert(not demo.log.turn_in("q_sa_fog_watch", demo._ctx(), "npc_cove_ines").ok)
	assert(int(demo.wallet["coins"]) == coins + 1420)
	_check_copper_ridge()
	_check_reed_camp()
	_check_pass_settlement()
	_check_watershed_finale()
	_buy_fishing_bait("npc_cove_ines")
	_open_fishing_spot("npc_cove_fishing")
	_press_dialogue_button("Закинуть удочку")
	demo._process(10.0)
	assert(demo.inv.material_count("coastal_fish") == 2)
	_press_dialogue_button("Отойти")
	assert(demo.fishing.spot_id.is_empty())
	print("Cove fishing PASS: local bait shop and larger catch")
	_ferry_dialogue("npc_cove_ines")
	assert(demo.world.zone_id == SeaFerry.SLUICE and not demo.settings.tomb_checkpoint["voyage"])
	assert(demo.log.chains_cleared.has("ch_sa_copper_cove"))
	print("Copper Cove PASS: old save, resumed voyage, walking route, rewards and return")


func _check_copper_ridge() -> void:
	_quest_dialogue("npc_cove_ines", "q_sa_ridge_survey", "accept")
	_walk_to_southern_goal("npc", "npc_ridge_amaro")
	assert(demo.world.zone_id == "z_copper_ridge")
	_quest_dialogue("npc_ridge_amaro", "q_sa_ridge_survey", "turn_in")
	_quest_dialogue("npc_ridge_amaro", "q_sa_ridge_signal", "accept")
	_walk_to_southern_goal("enemy", "enc_copper_ridge_raiders")
	_win_battle("enc_copper_ridge_raiders")
	demo._close_info()
	var saved := demo.settings.tomb_checkpoint.duplicate(true)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, saved)
	assert(demo.log.state("q_sa_ridge_signal", demo.inv, demo.squad.hero.level, demo.now) == "ready")
	_walk_to_southern_goal("npc", "npc_cove_ines")
	_quest_dialogue("npc_cove_ines", "q_sa_ridge_signal", "turn_in")
	assert(demo.log.chains_cleared.has("ch_sa_copper_ridge"))
	assert(not demo.log.turn_in("q_sa_ridge_signal", demo._ctx(), "npc_cove_ines").ok)
	print("Copper Ridge PASS: walking routes, fight, saved progress and final report")


func _check_reed_camp() -> void:
	var checkpoint := ConfigFile.new()
	checkpoint.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(checkpoint.encode_to_text()) == OK)
	demo.log.completed.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	var hero := demo.squad.hero
	assert(demo.world.zone_id == "z_copper_cove" and demo.log.completed.has("q_sa_ridge_signal"))
	assert(hero.level >= 31)
	var missing := Progression.total_xp(35, demo.gd) - Progression.total_xp(hero.level, demo.gd) - hero.xp
	assert(missing > 0)
	var victories := battles
	_quest_dialogue("npc_cove_ines", "q_sa_missing_watch", "accept")
	_walk_to_southern_goal("npc", "npc_crossing_luz")
	assert(demo.world.zone_id == "z_river_crossing")
	_quest_dialogue("npc_crossing_luz", "q_sa_missing_watch", "turn_in")
	_quest_dialogue("npc_crossing_luz", "q_sa_reed_route", "accept")
	_walk_to_southern_goal("npc", "npc_camp_teo")
	assert(demo.world.zone_id == "z_reed_camp")
	_quest_dialogue("npc_camp_teo", "q_sa_reed_route", "turn_in")
	_quest_dialogue("npc_camp_teo", "q_sa_east_watch", "accept")
	_walk_to_southern_goal("enemy", "enc_crossing_raiders")
	_win_battle("enc_crossing_raiders")
	demo._close_info()
	var fought := demo.settings.tomb_checkpoint.duplicate(true)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, fought)
	assert(demo.log.state("q_sa_east_watch", demo.inv, demo.squad.hero.level, demo.now) == "ready")
	_walk_to_southern_goal("npc", "npc_camp_teo")
	_quest_dialogue("npc_camp_teo", "q_sa_east_watch", "turn_in")
	_quest_dialogue("npc_camp_teo", "q_sa_watch_report", "accept")
	_walk_to_southern_goal("npc", "npc_cove_ines")
	_quest_dialogue("npc_cove_ines", "q_sa_watch_report", "turn_in")
	assert(demo.log.chains_cleared.has("ch_sa_reed_watch"))
	assert(not demo.log.turn_in("q_sa_watch_report", demo._ctx(), "npc_cove_ines").ok)
	assert(demo.squad.hero.level >= 35 and battles == victories + 1)
	print("Reed Camp PASS: missing ", missing, " XP, finished at level 35 with ", demo.squad.hero.xp, " XP and one victory")


func _check_pass_settlement() -> void:
	var previous_save := ConfigFile.new()
	previous_save.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(previous_save.encode_to_text()) == OK)
	demo.log.completed.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	var hero := demo.squad.hero
	assert(demo.world.zone_id == "z_copper_cove" and demo.log.completed.has("q_sa_watch_report"))
	assert(hero.level >= 35)
	var victories := battles
	_quest_dialogue("npc_cove_ines", "q_sa_pass_road", "accept")
	_walk_to_southern_goal("npc", "npc_foothills_renata")
	assert(demo.world.zone_id == "z_pass_foothills")
	_quest_dialogue("npc_foothills_renata", "q_sa_pass_road", "turn_in")
	_quest_dialogue("npc_foothills_renata", "q_sa_pass_contact", "accept")
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	assert(demo.world.zone_id == "z_pass_settlement")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_contact", "turn_in")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_recovery", "accept")
	_walk_to_southern_goal("enemy", "enc_pass_supply_raiders")
	_win_battle("enc_pass_supply_raiders")
	demo._close_info()
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_recovery", "turn_in")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_manifest", "accept")
	_walk_to_southern_goal("npc", "npc_pass_cargo")
	_inspect_echo("npc_pass_cargo", "sa_pass_cargo")
	var inspected := demo.settings.tomb_checkpoint.duplicate(true)
	demo.log.active.clear()
	TombCheckpoint.restore(demo, inspected)
	assert(demo.log.state("q_sa_pass_manifest", demo.inv, demo.squad.hero.level, demo.now) == "ready")
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_manifest", "turn_in")
	_quest_dialogue("npc_pass_bruno", "q_sa_pass_link", "accept")
	_walk_to_southern_goal("npc", "npc_camp_teo")
	assert(demo.world.zone_id == "z_reed_camp")
	_quest_dialogue("npc_camp_teo", "q_sa_pass_link", "turn_in")
	assert(demo.log.chains_cleared.has("ch_sa_pass_supplies"))
	assert(not demo.log.turn_in("q_sa_pass_link", demo._ctx(), "npc_camp_teo").ok)
	assert(demo.squad.hero.level >= 40 and battles == victories + 1)
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	_talk("npc_pass_bruno")
	_press_dialogue_button("Открыть лавку")
	assert(demo.town_screen != null)
	demo._close_town()
	_walk_to_southern_goal("npc", "npc_cove_ines")
	print("High Pass PASS: level 35 to 40, one victory, saved cargo inspection and return")


func _check_watershed_finale() -> void:
	var save := ConfigFile.new()
	save.set_value("game", "checkpoint", demo.settings.tomb_checkpoint)
	var restored := ConfigFile.new()
	assert(restored.parse(save.encode_to_text()) == OK)
	demo.log.completed.clear()
	TombCheckpoint.restore(demo, restored.get_value("game", "checkpoint"))
	assert(demo.squad.hero.level >= 40)
	assert(demo.log.completed.has("q_sa_pass_link"))
	var victories := battles
	_walk_to_southern_goal("npc", "npc_camp_teo")
	_quest_dialogue("npc_camp_teo", "q_sa_terrace_road", "accept")
	_walk_to_southern_goal("npc", "npc_terrace_mara")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_road", "turn_in")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_marks", "accept")
	_walk_to_southern_goal("npc", "npc_terrace_gauge")
	_inspect_echo("npc_terrace_gauge", "sa_terrace_gauge")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_marks", "turn_in")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_cloth", "accept")
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	if demo.inv.material_count("leather") == 0:
		assert(demo.buy_at_shop(1).is_empty())
	_quest_dialogue("npc_pass_bruno", "q_sa_terrace_cloth", "turn_in")
	_quest_dialogue("npc_pass_bruno", "q_sa_terrace_seal", "accept")
	_walk_to_southern_goal("npc", "npc_terrace_mara")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_seal", "turn_in")
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_guard", "accept")
	_walk_to_southern_goal("enemy", "enc_terrace_guard")
	_win_battle("enc_terrace_guard")
	demo._close_info()
	_quest_dialogue("npc_terrace_mara", "q_sa_terrace_guard", "turn_in")
	assert(demo.inv.material_count("key_cistern") == 1)
	_quest_dialogue("npc_terrace_mara", "q_sa_cistern_clear", "accept")
	_walk_to_southern_goal("enemy", "enc_cistern_entry")
	_press_dialogue_button("Войти")
	assert(demo.inv.material_count("key_cistern") == 0)
	_win_battle("enc_cistern_entry")
	demo._close_info()
	var between_halls := demo.settings.tomb_checkpoint.duplicate(true)
	demo._dungeon_run = null
	TombCheckpoint.restore(demo, between_halls)
	assert(demo._dungeon_run.current_encounter() == "enc_cistern_keeper")
	var gate := _spawn_for("enc_cistern_entry")
	demo.map.enemy_contact.emit(gate)
	_win_battle("enc_cistern_keeper")
	demo._close_info()
	assert(demo._dungeon_run == null and demo.inv.material_count("key_cistern") == 0)
	_walk_to_southern_goal("npc", "npc_terrace_mara")
	_quest_dialogue("npc_terrace_mara", "q_sa_cistern_clear", "turn_in")
	_quest_dialogue("npc_terrace_mara", "q_sa_water_dispatch", "accept")
	_walk_to_southern_goal("npc", "npc_pass_bruno")
	_quest_dialogue("npc_pass_bruno", "q_sa_water_dispatch", "turn_in")
	_quest_dialogue("npc_pass_bruno", "q_sa_expedition_end", "accept")
	_walk_to_southern_goal("npc", "npc_cove_ines")
	_quest_dialogue("npc_cove_ines", "q_sa_expedition_end", "turn_in")
	assert(demo.log.chains_cleared.has("ch_sa_watershed"))
	assert(not demo.log.turn_in("q_sa_expedition_end", demo._ctx(), "npc_cove_ines").ok)
	assert(demo.squad.hero.level >= 48 and battles == victories + 3)
	print("Watershed finale PASS: level 48 with ", demo.squad.hero.xp, " XP, two halls, saved key and return")


func _progress_step(giver: String, recipient: String, quest: String) -> void:
	_quest_dialogue(giver, quest, "accept")
	_walk_to_southern_goal("npc", recipient)
	_quest_dialogue(recipient, quest, "turn_in")


func _walk_to_southern_goal(kind: String, target: String) -> void:
	assert(demo.map.start_quest_route([{"kind": kind, "id": target}]), target)
	_walk_quest_route()
	if kind == "npc":
		assert(demo.hud.interact_button.visible and demo.map._interaction.npc_id == target, target)


func _tomb_action(npc: String, service: String) -> void:
	_talk(npc)
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("service") == service:
			demo._dialogue_choose(index)
			return
	assert(false, "Missing tomb interaction: " + service)


func _inspect_echo(npc: String, target: String) -> void:
	_talk(npc)
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("activity") == target:
			demo._dialogue_choose(index)
			demo._close_info()
			return
	assert(false, "Missing investigation: " + target)


func _start_ferry_dialogue(npc: String) -> void:
	_talk(npc)
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("service") == "sea_ferry":
			demo._dialogue_choose(index)
			assert(demo.world.traveling)
			return
	assert(false, "Missing ferry dialogue: " + npc)


func _ferry_dialogue(npc: String) -> void:
	_start_ferry_dialogue(npc)
	demo.now = demo.world.arrive_at - 1.0
	demo._finish_ferry_if_due()
	assert(demo.world.traveling)
	demo.now += 1.0
	demo._finish_ferry_if_due()
	assert(not demo.world.traveling)

func _check_field_practice() -> void:
	const ID := "q_ne_field_practice"
	for item in demo.inv.items:
		if item.def_id == "h_cap":
			assert(demo.equip_member(demo.squad.hero, item).is_empty())
			break
	var slot := int(demo.formation[demo.squad.hero.uid])
	demo.place_member(demo.squad.hero, (slot + 1) % BattleRules.SLOTS_PER_SIDE)
	_talk("npc_tavia")
	demo._close_info()
	assert(demo.map_teleport("z_harbor", true).is_empty())
	assert(demo.log.objectives_done(ID, demo.inv, 20))
	_quest_dialogue("npc_orvin", ID, "turn_in")
	print("Northeast Asia optional practice PASS: equip, formation, hire, key, map travel")


func _check_signal_ledger() -> void:
	var coins := int(demo.wallet["coins"])
	_quest_dialogue("npc_nera", "q_ne_ledger_citadel", "accept")
	_talk("npc_rook")
	demo._close_info()
	_quest_dialogue("npc_sava", "q_ne_ledger_citadel", "turn_in")
	_quest_dialogue("npc_sava", "q_ne_ledger_crossroads", "accept")
	_talk("npc_tavia")
	demo._close_info()
	_quest_dialogue("npc_nera", "q_ne_ledger_crossroads", "turn_in")
	assert(demo.log.chain_state("ch_ne_signal_ledger", demo.now) == "done")
	assert(int(demo.wallet["coins"]) == coins + 90)
	print("Northeast Asia ledger PASS: both posts and rewards")


func _story_activity(id: String) -> void:
	_talk("npc_marek" if id == "cargo_manifest" else "npc_liska")
	if id == "signal_test":
		assert(not demo.map.streamer.nodes[Vector2i(8, 0)].get_node("SignalBeacon").visible)
	for i in demo.runner._shown.size():
		if demo.runner._shown[i].get("do", {}).get("activity") == id:
			demo._dialogue_choose(i)
			demo._close_info()
			return
	assert(false, "Missing story interaction: " + id)


func _press_dialogue_button(label: String) -> void:
	for choice in demo._info.choice_list.get_children():
		if choice is Button and choice.text == label:
			choice.pressed.emit()
			return
	assert(false, "Missing dialogue button: " + label)


func _check_recruitment() -> void:
	const QUEST := "q_recruit_swordsman"
	const NPC := "npc_mira"
	_talk(NPC)
	_press_dialogue_button("Испытания вербовки (7)")
	assert(demo._info.title_label.text == "Испытания вербовки")
	_press_dialogue_button("Следующая страница")
	_press_dialogue_button("Предыдущая страница")
	_press_dialogue_button("Назад к разговору")
	assert(demo._info.title_label.text == demo.gd.npcs[NPC]["name"])
	demo._close_info()
	_quest_dialogue(NPC, QUEST, "accept")
	var encounter := "enc_meadow_wolves"
	demo.map.enemy_contact.emit(_spawn_for(encounter))
	var sim := demo.battle.sim
	for id in sim.active_ids:
		if sim.can_act(id) == "":
			assert(sim.submit({"type": "guard", "actor": id}).ok)
			break
	_win_battle(encounter)
	demo._close_info()
	_quest_dialogue(NPC, QUEST, "turn_in")
	_talk(NPC)
	for i in demo.runner._shown.size():
		if demo.runner._shown[i].get("do", {}).get("service") == "recruiter":
			demo._dialogue_choose(i)
			break
	assert(demo.town_screen != null)
	var count := demo.squad.count_of("swordsman")
	var coins := int(demo.wallet["coins"])
	for child in demo.town_screen.content.get_children():
		if child is Button and child.text.ends_with("за выполненное задание"):
			child.pressed.emit()
			break
	assert(demo.squad.count_of("swordsman") == count + 1)
	assert(demo.wallet["coins"] == coins)
	demo._close_town()


func _check_citadel_watch() -> void:
	_quest_dialogue("npc_sava", "q_citadel_watch_report", "accept")
	_quest_dialogue("npc_tavia", "q_citadel_watch_report", "turn_in")
	_quest_dialogue("npc_tavia", "q_citadel_watch_hills", "accept")
	_arrive(locations["z_hills"][0])
	_fight("enc_hills_harpies")
	_quest_dialogue("npc_sava", "q_citadel_watch_hills", "turn_in")
	_quest_dialogue("npc_sava", "q_citadel_watch_route", "accept")
	_talk("npc_rook")
	demo._close_info()
	_quest_dialogue("npc_sava", "q_citadel_watch_route", "turn_in")
	assert(demo.log.chain_state("ch_citadel_watch", demo.now) == "done")
	print("Citadel watch PASS: dialogues, route and battle")


func _check_promotion() -> void:
	var members := demo.members()
	var index := members.find_custom(func(m: Mercenary) -> bool: return m.def_id == "swordsman")
	assert(index >= 0)
	var fighter: Mercenary = members[index]
	fighter.set_level(20, demo.gd)
	_arrive(locations["z_harbor"][0])
	var stock: Array = demo.gd.town_services["services"]["shop"]["stock"]
	var crystal_offer := stock.find_custom(func(offer: Dictionary) -> bool: return offer["item"] == "growth_crystal")
	assert(crystal_offer >= 0)
	for purchase in range(2):
		assert(demo.town_services.buy(demo.world, demo.wallet, demo.inv, crystal_offer) == "")
	demo.open_menu("squad")
	demo._menu.sel_member = index
	demo._menu.rebuild()
	var tab := demo._menu.get_node("%TabSquad") as TabSquad
	(tab.get_node("%PartyButton") as Button).pressed.emit()
	var seats := tab.get_node("%PartySeats") as VBoxContainer
	var first := seats.get_child(2) as OptionButton
	var saved_key: String = first.get_item_metadata(1)
	first.item_selected.emit(1)
	assert(demo.settings.party_formations["duo"][0] == saved_key)
	var second := seats.get_child(4) as OptionButton
	for option in second.item_count:
		assert(second.get_item_metadata(option) != saved_key)
	var size_picker := tab.get_node("%PartySize") as OptionButton
	size_picker.item_selected.emit(1)
	assert(seats.get_child_count() == 5)
	assert((seats.get_child(2) as OptionButton).selected == 0)
	size_picker.item_selected.emit(0)
	assert(seats.get_child_count() == 9)
	assert((seats.get_child(2) as OptionButton).get_selected_metadata() == saved_key)
	(tab.get_node("%PartyBack") as Button).pressed.emit()
	assert(demo.squad.set_enabled(demo.squad.hero.uid, false) == "not_in_formation")
	assert(demo.send_to_room(demo.squad.hero, 0) == "not_in_formation")
	assert(demo.squad.hero.enabled and demo.squad.room_of(demo.squad.hero.uid) == -1)
	# Populate reserve rooms to exercise overflow even in a tall headless viewport.
	for room in range(2, 22):
		demo.squad.rooms[room] = Mercenary.new(100 + room, "archer", demo.gd)
	demo._menu.rebuild()
	await process_frame
	await process_frame
	var scroll_bar := tab.member_scroll.get_v_scroll_bar()
	assert(scroll_bar.max_value > scroll_bar.page)
	tab.member_scroll.scroll_vertical = roundi(scroll_bar.max_value - scroll_bar.page)
	assert(tab.member_scroll.scroll_vertical > 0)
	var selected_rows := tab.member_list.get_children().filter(
		func(node): return node is ListButton and node.text_label.text.begins_with("✓ "))
	assert(selected_rows.size() == 1 and selected_rows[0].text_label.text.contains(demo.member_name(fighter)))
	for room in range(2, 22):
		demo.squad.rooms.erase(room)
	demo._menu.rebuild()
	assert(not tab.promotion_button.disabled)
	tab.promotion_button.pressed.emit()
	assert(fighter.def_id == "knight")
	assert(demo.inv.material_count("growth_crystal") == 0)
	assert(tab.promotion_button.disabled and tab.promotion_button.text.contains("50"))
	demo.close_menu()
	print("WP-42 PASS: purchase and squad promotion")


func _check_equipment_set() -> void:
	demo.inv.add_material("iron_ore", 8)
	demo.inv.add_material("leather", 4)
	demo.open_menu("forge")
	var forge := demo._menu.get_node("%TabForge") as TabForge
	forge.recipe_group.select(2)
	forge.recipe_group.item_selected.emit(2)
	assert(forge.craft_list.get_child_count() == 15)
	for index in range(2):
		var recipe := forge.craft_list.get_child(index) as ListButton
		assert(not recipe.disabled)
		recipe.pressed.emit()
	demo.close_menu()
	var hero := demo.squad.hero
	for item: Item in demo.inv.items.duplicate():
		if item.def_id in ["field_10_armor", "field_10_helm"]:
			assert(hero.equip(item, demo.inv) == "")
	assert(hero.equipped_sets(demo.gd).get("field_10") == 2)
	demo.open_menu("squad")
	var squad_tab := demo._menu.get_node("%TabSquad") as TabSquad
	assert(squad_tab.xp_label.text.contains("Речной рубеж · 2/4"))
	demo.close_menu()
	print("WP-50 PASS: forge selection, craft and equipped set")


func _check_crafting_professions() -> void:
	var progress := demo.inv.crafting
	assert(progress.level(CraftProgress.ARMOR) > 1)
	assert(progress.level(CraftProgress.WEAPON) == 1)
	assert(progress.workload > 0)
	demo.inv.add_material("iron_ore", 4)
	demo.inv.add_material("leather", 2)
	demo.open_menu("forge")
	var forge := demo._menu.get_node("%TabForge") as TabForge
	assert(forge.craft_status.text.contains("Бронник"))
	var original_size := root.size
	root.size = Vector2i(1280, 600)
	await process_frame
	await process_frame
	var craft_scroll := forge.craft_list.get_parent() as ScrollContainer
	var first_recipe := forge.craft_list.get_child(1) as ListButton
	var coins := int(demo.wallet["coins"])
	await _drag_scroll_from_row(first_recipe)
	assert(craft_scroll.scroll_vertical > 0, "Dragging over a recipe should scroll the craft list")
	assert(int(demo.wallet["coins"]) == coins, "A swipe must not buy a recipe")
	print("Forge recipe swipe PASS: drag scrolls without crafting")
	root.size = original_size
	forge.recipe_group.select(2)
	forge.recipe_group.item_selected.emit(2)
	forge.auto_button.pressed.emit()
	await process_frame
	await process_frame
	for list in [forge.craft_list, forge.upgrade_list]:
		var row := list.get_child(0) as ListButton
		var scroll := list.get_parent() as ScrollContainer
		assert(row.size.x >= scroll.size.x * 0.9 and row.text_label.size.x > 120.0, "Forge list should fill its scroll column")
	var recipe := forge.craft_list.get_child(0) as ListButton
	assert(not recipe.disabled)
	recipe.pressed.emit()
	assert(progress.auto_recipe == "craft_field_10_armor")
	var count := demo.inv.items.size()
	demo._process(float(demo.gd.rules["crafting"]["tick_seconds"]))
	assert(demo.inv.items.size() == count + 1)
	var item: Item = demo.inv.items.back()
	assert(item.def_id == "field_10_armor")
	forge.auto_button.pressed.emit()
	assert(progress.auto_recipe.is_empty())
	demo._menu.sel_forge_item = item.uid
	demo._menu.rebuild()
	assert(forge.analyze_button.visible and not forge.analyze_button.disabled)
	forge.analyze_button.pressed.emit()
	assert(forge.analyze_button.disabled)
	forge.dismantle_button.pressed.emit()
	forge.confirm_dismantle.confirmed.emit()
	assert(demo.inv.item_by_uid(item.uid) == null)
	demo.close_menu()
	print("WP-51 PASS: profession XP, auto craft, analysis and dismantling")


func _index_world() -> void:
	for chunk: Dictionary in demo.gd.chunk_manifest["chunks"]:
		var scene := (load(chunk["scene"]) as PackedScene).instantiate()
		var origin := Vector2(chunk["x"], chunk["y"]) * demo.map.grid.chunk_px()
		_remember(chunk["zone"], origin + Vector2.ONE * demo.map.grid.chunk_px() / 2.0)
		for marker in scene.get_children():
			if marker is NpcMarker:
				_remember(marker.npc_id, origin + marker.position)
			elif marker is EnemySpawn:
				_remember(marker.encounter_id, origin + marker.position)
		scene.free()


func _remember(id: String, point: Vector2) -> void:
	if not locations.has(id):
		locations[id] = []
	locations[id].append(point)


func _arrive(point: Vector2) -> void:
	demo.map.hero.position = point
	demo.map.streamer.prime(point)
	var zone := demo.map.streamer.zone_at(point)
	assert(not zone.is_empty(), str(point))
	if demo.map.zone_id != zone:
		demo.map.zone_id = zone
		demo.map.zone_changed.emit(zone, demo.map.zone_name_of(zone))


func _talk(npc_id: String) -> void:
	assert(locations.has(npc_id), npc_id)
	_arrive(locations[npc_id][0])
	assert(demo.map.npcs.any(func(npc): return npc.npc_id == npc_id), npc_id)
	demo.map.npc_contact.emit(npc_id)
	assert(demo.runner.running and demo.runner.npc_id == npc_id, npc_id)


func _quest_dialogue(npc_id: String, quest_id: String, action: String) -> void:
	_talk(npc_id)
	for i in demo.runner._shown.size():
		if demo.runner._shown[i].get(action) == quest_id:
			demo._dialogue_choose(i)
			assert(demo.log.active.has(quest_id) if action == "accept" else demo.log.completed.has(quest_id), quest_id)
			demo._close_info()
			return
	assert(false, "%s %s at level %d" % [action, quest_id, demo.squad.hero.level])


func _spawn_for(id: String) -> EnemySpawn:
	assert(locations.has(id), id)
	# Advance the map clock between encounters so previously defeated groups can respawn.
	demo.now += DemoMain.RESPAWN_SECONDS + 1.0
	demo.map.respawn_ready(demo.now)
	for point: Vector2 in locations[id]:
		_arrive(point)
		for spawn: EnemySpawn in demo.map.spawns:
			if spawn.encounter_id == id and spawn.alive:
				return spawn
	assert(false, "Missing live encounter: " + id)
	return null


func _fight(id: String) -> void:
	demo.map.enemy_contact.emit(_spawn_for(id))
	_win_battle(id)
	demo._close_info()


func _win_battle(id: String) -> void:
	assert(demo.battle != null, id)
	var sim := demo.battle.sim
	for _action in 400:
		if sim.winner != BattleSim.Winner.NONE:
			break
		var actor := -1
		for unit_id in sim.active_ids:
			if sim.can_act(unit_id) == "":
				actor = unit_id
				break
		if actor == -1:
			sim.end_turn()
		else:
			assert(sim.submit(BattleAI.choose(sim, actor)).ok, id)
	assert(sim.winner == BattleSim.Winner.SIDE_A, "%s winner=%d level=%d" % [id, sim.winner, demo.squad.hero.level])
	demo.battle.finished.emit("win")
	battles += 1


func _dungeon(zone_id: String, quest_id: String) -> void:
	var stages: Array = demo.world.graph.zones[zone_id]["dungeon"]["stages"]
	var entrance := _spawn_for(stages[0])
	demo.map.enemy_contact.emit(entrance)
	assert(demo.battle == null and demo._info != null)
	var keys_before := demo.inv.material_count("key_ruins")
	assert(keys_before > 0)
	assert(demo.log.objective_count("q_ne_field_practice", 3, demo.inv, demo.squad.hero.level) == 0)
	demo._enter_dungeon(entrance)
	assert(demo.inv.material_count("key_ruins") == keys_before - 1)
	assert(demo.log.objective_count("q_ne_field_practice", 3, demo.inv, demo.squad.hero.level) == 1)
	for i in stages.size():
		assert(demo._dungeon_run.current_encounter() == stages[i])
		_win_battle(stages[i])
		if i < stages.size() - 1:
			assert(demo.log.state(quest_id, demo.inv, demo.squad.hero.level, demo.now) == "active")
			demo._continue_dungeon(entrance)
	assert(demo._dungeon_run == null)
	demo._close_info()
