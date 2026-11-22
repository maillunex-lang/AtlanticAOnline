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


func _run() -> void:
	demo = (load("res://scenes/demo.tscn") as PackedScene).instantiate()
	demo.settings = OfflineSettings.new()
	root.add_child(demo)
	demo.set_process(false)
	demo.map.set_process(false)
	demo.map.streamer.use_threads = false
	demo.rng.seed = 409
	_index_world()
	assert(demo.squad.hero.level == 1)
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
	_check_recruitment()
	print("WP-24 PASS: story and recruitment")
	quit()


func _check_recruitment() -> void:
	const QUEST := "q_recruit_swordsman"
	const NPC := "npc_mira"
	_quest_dialogue(NPC, QUEST, "accept")
	for _victory in 2:
		_fight("enc_meadow_wolves")
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
	demo._enter_dungeon(entrance)
	assert(demo.inv.material_count("key_ruins") == keys_before - 1)
	for i in stages.size():
		assert(demo._dungeon_run.current_encounter() == stages[i])
		_win_battle(stages[i])
		if i < stages.size() - 1:
			assert(demo.log.state(quest_id, demo.inv, demo.squad.hero.level, demo.now) == "active")
			demo._continue_dungeon(entrance)
	assert(demo._dungeon_run == null)
	demo._close_info()
