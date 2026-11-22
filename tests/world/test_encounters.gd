extends GdUnitTestSuite

var gd: GameData
var pw: PlayerWorld


func before_test() -> void:
	gd = GameData.load_dir()
	pw = PlayerWorld.new(gd, 0.0)


func _go(zone: String, level: int, now: float) -> float:
	var r := pw.travel_to(zone, level, now)
	assert_bool(r.ok).is_true()
	pw.update(now + float(r.seconds))
	return now + float(r.seconds)


func _strong_squad(inv: Inventory) -> Array[BattleUnit]:
	var us: Array[BattleUnit] = []
	for i in 4:
		us.append(BattleUnit.make(1 + i, BattleRules.SIDE_A, i * 3 % 9 if i < 3 else 2, {"hp": 100000, "atk": 400}))
	us[3].reach = BattleUnit.Reach.RANGED
	return us


func _autoplay(sim: BattleSim) -> void:
	var guard := 0
	while sim.winner == BattleSim.Winner.NONE and guard < 400:
		guard += 1
		var side := sim.current_side
		var mine := sim.alive_units(side)
		var foes := sim.alive_units(1 - side)
		for u in mine:
			if sim.winner != BattleSim.Winner.NONE or sim.current_side != side:
				break
			if u.acted:
				continue
			for f in foes:
				if f.is_alive() and sim.submit({"type": "attack", "actor": u.id, "target": f.id}).ok:
					break
		if sim.winner == BattleSim.Winner.NONE and sim.current_side == side:
			sim.end_turn()


func test_encounter_builds_enemy_units_in_formation() -> void:
	var enc := EncounterFactory.find(gd, "enc_meadow_slimes")
	var units := EncounterFactory.build_units(enc, gd)
	assert_int(units.size()).is_equal(3)
	for u in units:
		assert_int(u.side).is_equal(BattleRules.SIDE_B)
		assert_int(u.id).is_greater_equal(1000)
	assert_int(units[0].max_hp).is_equal(40)
	var ids := units.map(func(u): return u.id)
	assert_int(ids.size()).is_equal(3)


func test_ranged_monsters_get_ranged_reach() -> void:
	var enc := EncounterFactory.find(gd, "enc_forest_bandits")
	var reaches := EncounterFactory.build_units(enc, gd).map(func(u): return u.reach)
	assert_bool(BattleUnit.Reach.RANGED in reaches).is_true()


func test_every_encounter_is_winnable_by_a_strong_squad() -> void:
	for id in gd.encounters:
		var enc: Dictionary = gd.encounters[id]
		var us := _strong_squad(null)
		us.append_array(EncounterFactory.build_units(enc, gd))
		var sim := BattleSim.new(BattleRules.new(), us, 5)
		_autoplay(sim)
		assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)


func test_can_fight_only_in_own_zone_when_ready() -> void:
	assert_str(pw.can_fight("enc_meadow_slimes", 0.0)).is_equal("wrong_zone")
	assert_str(pw.can_fight("nope", 0.0)).is_equal("unknown_encounter")
	var t := _go("z_meadow", 1, 0.0)
	assert_str(pw.can_fight("enc_meadow_slimes", t)).is_equal("")
	assert_str(pw.can_fight("enc_forest_wolves", t)).is_equal("wrong_zone")


func test_cannot_fight_while_traveling() -> void:
	pw.travel_to("z_meadow", 1, 0.0)
	assert_str(pw.can_fight("enc_meadow_slimes", 5.0)).is_equal("busy")


func test_encounter_respawns_after_cooldown() -> void:
	var t := _go("z_meadow", 1, 0.0)
	pw.mark_cleared("enc_meadow_slimes", t)
	assert_str(pw.can_fight("enc_meadow_slimes", t + 10.0)).is_equal("respawning")
	assert_float(pw.respawn_in("enc_meadow_slimes", t + 10.0)).is_equal(110.0)
	assert_str(pw.can_fight("enc_meadow_slimes", t + 120.0)).is_equal("")
	assert_str(pw.can_fight("enc_meadow_wolves", t + 10.0)).is_equal("")  # другое столкновение не затронуто


func test_dungeon_encounters_cannot_be_fought_in_open_world() -> void:
	var t := _go("z_mine", 10, 0.0)
	t = _go("z_ruins", 10, t)
	assert_str(pw.can_fight("enc_ruins_1", t)).is_equal("dungeon_only")


func test_dungeon_entry_requires_dungeon_level_and_key() -> void:
	var inv := Inventory.new(gd)
	assert_str(DungeonRun.enter(pw, inv, 10, 0.0).error).is_equal("not_dungeon")
	var t := _go("z_mine", 10, 0.0)
	t = _go("z_ruins", 10, t)
	assert_str(DungeonRun.enter(pw, inv, 10, t).error).is_equal("no_key")
	inv.add_material("key_ruins", 1)
	assert_str(DungeonRun.enter(pw, inv, 9, t).error).is_equal("level_too_low")
	assert_int(inv.material_count("key_ruins")).is_equal(1)  # ключ цел при отказе
	var res := DungeonRun.enter(pw, inv, 10, t)
	assert_bool(res.ok).is_true()
	assert_int(inv.material_count("key_ruins")).is_equal(0)
	assert_int(res.run.max_players).is_equal(3)


func test_dungeon_progresses_through_stages_to_reward() -> void:
	var inv := Inventory.new(gd)
	inv.add_material("key_ruins", 1)
	var t := _go("z_mine", 10, 0.0)
	t = _go("z_ruins", 10, t)
	var run: DungeonRun = DungeonRun.enter(pw, inv, 10, t).run
	assert_str(run.current_encounter()).is_equal("enc_ruins_1")
	assert_bool(run.complete_stage()).is_false()
	assert_str(run.current_encounter()).is_equal("enc_ruins_2")
	run.complete_stage()
	assert_str(run.current_encounter()).is_equal("enc_ruins_boss")
	assert_bool(run.complete_stage()).is_true()
	assert_bool(run.finished()).is_true()
	assert_str(run.current_encounter()).is_equal("")
	assert_bool(LootTable.find(gd, run.reward_loot).is_empty()).is_false()


func test_keys_drop_in_fields_that_lead_to_dungeons() -> void:
	var mine := LootTable.find(gd, "mine_loot")
	var has_key := false
	for e in mine.entries:
		if e.item == "key_ruins":
			has_key = true
	assert_bool(has_key).is_true()


func test_full_flow_walk_fight_collect_rewards() -> void:
	var inv := Inventory.new(gd)
	var sq := Squad.new(gd)
	sq.create_hero("sword")
	var wallet := {"coins": 0}
	var t := _go("z_meadow", 1, 0.0)
	assert_str(pw.can_fight("enc_meadow_slimes", t)).is_equal("")
	var enc := EncounterFactory.find(gd, "enc_meadow_slimes")
	var us: Array[BattleUnit] = [BattleUnit.from_mercenary(sq.hero, gd, 1, BattleRules.SIDE_A, 0)]
	us.append_array(EncounterFactory.build_units(enc, gd))
	var sim := BattleSim.new(BattleRules.new(), us, 3, gd.skills)
	us[0].hp = us[0].max_hp  # герой первого уровня против трёх слизней
	us[0].stats.base["atk"] = 100
	_autoplay(sim)
	assert_int(sim.winner).is_equal(BattleSim.Winner.SIDE_A)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	wallet.coins += int(enc.coins)
	var res := sq.award_battle_xp(int(enc.xp))
	inv.add_drops(LootTable.roll(LootTable.find(gd, enc.loot), rng))
	pw.mark_cleared("enc_meadow_slimes", t)
	assert_int(wallet.coins).is_equal(20)
	assert_int(sq.hero.xp).is_equal(30)
	assert_str(pw.can_fight("enc_meadow_slimes", t + 1.0)).is_equal("respawning")
