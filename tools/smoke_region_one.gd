extends SceneTree
## Offline slice: godot --headless --script tools/smoke_region_one.gd
## Visits scene markers directly. Pedestrian reachability is checked by test_world_scenes.gd.

class OfflineSettings extends DemoSettings:
	func load_file() -> void:
		hero_class = "warden"

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
	_check_release_start()
	demo.free()
	locations.clear()
	battles = 0
	_start_demo()
	demo._add_smoke_roster()
	demo.refresh_hud()
	assert(demo.squad.hero.level == 1)
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
			assert(demo.hud.quest_label.text.contains(demo.gd.npcs[quest["turn_in"]]["name"]), quest_id)
			_quest_dialogue(quest["turn_in"], quest_id, "turn_in")
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
	_check_recruitment()
	_check_field_practice()
	_check_citadel_watch()
	_check_signal_ledger()
	_check_promotion()
	_check_equipment_set()
	_check_crafting_professions()
	print("WP-24 PASS: story and recruitment")
	_check_south_route()
	quit()


func _check_release_start() -> void:
	assert(demo.squad.hero.level == 1 and demo.squad.all_mercenaries().is_empty())
	assert(not demo.squad.recruit("archer", "tutorial", demo.wallet).ok)
	_quest_dialogue("npc_orvin", "tut01_port", "accept")
	assert(not demo.hud.quest_label.visible)
	demo.open_menu("quests")
	var checkbox := demo._menu.find_child("ShowOnHud", true, false) as CheckButton
	assert(checkbox != null and not checkbox.button_pressed)
	checkbox.button_pressed = true
	assert(demo.hud.quest_label.visible and demo.hud.quest_label.text.contains("Знакомство с портом"))
	checkbox = demo._menu.find_child("ShowOnHud", true, false) as CheckButton
	checkbox.button_pressed = false
	assert(not demo.hud.quest_label.visible and demo.log.active.has("tut01_port"))
	demo.close_menu()
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
	_fight("enc_meadow_slimes")
	_quest_dialogue("npc_orvin", "m01_first_steps", "turn_in")
	_quest_dialogue("npc_orvin", "m02_wolves", "accept")
	_fight("enc_meadow_wolves")
	_quest_dialogue("npc_orvin", "m02_wolves", "turn_in")
	print("Release start PASS: solo hero, tutorial recruit, slimes and wolves")


func _check_south_route() -> void:
	_quest_dialogue("npc_sava", "m07_south", "accept")
	_ferry_dialogue("npc_orvin")
	assert(demo.world.zone_id == "z_oasis")
	_quest_dialogue("npc_nadia", "m07_south", "turn_in")
	_quest_dialogue("npc_yara", "q_se_cistern_cloth", "accept")
	_quest_dialogue("npc_nadia", "s04_scorpions", "accept")
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
	for _i in 3:
		_fight("enc_dunes_scorpions")
	_quest_dialogue("npc_nadia", "q_se_clear_way", "turn_in")
	_quest_dialogue("npc_nadia", "s04_scorpions", "turn_in")
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
	_ferry_dialogue("npc_yara")
	assert(demo.world.zone_id == "z_harbor")
	print("Southeast Asia ferry and dunes PASS: both sailings, all five quests")


func _ferry_dialogue(npc: String) -> void:
	_talk(npc)
	for index in demo.runner._shown.size():
		if demo.runner._shown[index].get("do", {}).get("service") == "sea_ferry":
			demo._dialogue_choose(index)
			break
	assert(demo.world.traveling)
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


func _check_recruitment() -> void:
	const QUEST := "q_recruit_swordsman"
	const NPC := "npc_mira"
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
	forge.recipe_group.select(2)
	forge.recipe_group.item_selected.emit(2)
	forge.auto_button.pressed.emit()
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
