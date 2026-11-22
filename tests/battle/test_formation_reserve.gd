extends GdUnitTestSuite

const A := BattleRules.SIDE_A
const B := BattleRules.SIDE_B

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _rules() -> BattleRules:
	var rules := BattleRules.new()
	rules.battle_rooms = int(gd.rules["formation"]["battle_rooms"])
	rules.reserve_swap_limit = int(gd.rules["formation"]["pve_swaps"])
	return rules


func _reserve(id: int, room: int, side := A) -> BattleUnit:
	var unit := BattleUnit.make(id, side, 0)
	unit.reserve_room = room
	unit.participated = false
	return unit


func _swap(sim: BattleSim, actor: int, target: int) -> Dictionary:
	return sim.submit({"type": "swap_reserve", "actor": actor, "target": target})


func test_room_bounds_and_full_formation_exchange() -> void:
	var squad := Squad.new(gd)
	squad.create_hero("sword")
	var wallet := {"coins": 100000}
	for room in 40:
		var merc: Mercenary = squad.recruit("swordsman", "coins", wallet).merc
		assert_str(squad.move_to_room(merc.uid, room)).is_empty()
	assert_int(squad.rooms.size()).is_equal(40)
	for i in 8:
		assert_bool(squad.recruit("archer", "coins", wallet).ok).is_true()
	var outgoing := squad.mercs[0]
	var incoming: Mercenary = squad.rooms[39]
	assert_str(squad.move_to_room(outgoing.uid, 40)).is_equal("bad_room")
	assert_str(squad.restore_from_room(39)).is_equal("squad_full")
	assert_str(squad.move_to_room(outgoing.uid, 39)).is_empty()
	assert_int(squad.room_of(outgoing.uid)).is_equal(39)
	assert_int(squad.room_of(incoming.uid)).is_equal(-1)
	assert_int(squad.mercs.size()).is_equal(8)


func test_guards_granted_once_and_capped_at_60() -> void:
	gd.rules["max_level"] = 120
	var squad := Squad.new(gd)
	squad.create_hero("sword")
	squad.claim_starter_guards()
	squad.claim_starter_guards()
	assert_int(squad.rooms.size()).is_equal(2)
	var guard: Mercenary = squad.rooms[0]
	assert_int(guard.level).is_equal(1)
	guard.set_level(59, gd)
	assert_int(guard.add_xp(100000, gd)).is_equal(1)
	assert_int(guard.level).is_equal(60)
	guard.set_level(100, gd)
	assert_int(guard.level).is_equal(60)


func test_disabled_mercenaries_increase_ap_and_participant_xp() -> void:
	var demo := DemoMain.new()
	demo.gd = gd
	demo._setup_party()
	var squad := demo.squad
	var disabled := squad.mercs[0]
	var active := squad.mercs[1]
	var newcomer: Mercenary = squad.rooms[0]
	assert_str(squad.set_enabled(0, false)).is_equal("not_in_formation")
	assert_str(squad.set_enabled(newcomer.uid, false)).is_equal("not_in_formation")
	assert_str(squad.set_enabled(disabled.uid, false)).is_empty()
	var units := demo._player_units()
	demo.free()
	var foe := BattleUnit.make(1000, B, 0)
	units.append(foe)
	var sim := BattleSim.new(_rules(), units, 7)
	assert_object(sim.unit_by_id(disabled.uid + 1)).is_null()
	assert_int(sim.unit_by_id(1).ap).is_equal(110)
	assert_int(squad.formation_battle_xp(30, squad.disabled_count())).is_equal(33)
	squad.award_formation_battle_xp(30, [active.uid, newcomer.uid], squad.disabled_count())
	assert_int(squad.hero.xp).is_equal(33)
	assert_int(active.xp).is_equal(33)
	assert_int(disabled.xp).is_equal(0)
	assert_int(newcomer.xp).is_equal(33)
	assert_int(squad.rooms[1].xp).is_equal(0)
	var pvp_units := PvpMatch.build_units(squad, gd, B, 100)
	assert_int(pvp_units[1].slot).is_equal(6)
	assert_int(pvp_units[1].formation_ap_bonus).is_equal(5)


func test_battle_swap_limits_and_preserves_units_state() -> void:
	var hero := BattleUnit.make(1, A, 0, {"hero": true})
	var a := BattleUnit.make(2, A, 1)
	var b := BattleUnit.make(3, A, 2)
	var c := BattleUnit.make(4, A, 3)
	var d := BattleUnit.make(5, A, 4)
	var incoming := _reserve(6, 0)
	incoming.hp = 70
	incoming.mp = 17
	var later := _reserve(7, 4)
	var enemy := BattleUnit.make(100, B, 0)
	var enemy_reserve := _reserve(101, 1, B)
	var sim := BattleSim.new(_rules(), [hero, a, b, c, d, incoming, later, enemy, enemy_reserve], 7)
	assert_array(sim.reserve_targets(2)).is_equal([6])
	assert_str(_swap(sim, 1, 6).error).is_equal("bad_reserve")
	assert_str(_swap(sim, 2, 7).error).is_equal("bad_reserve")
	assert_str(_swap(sim, 2, 101).error).is_equal("bad_reserve")
	assert_int(a.ap).is_equal(100)
	assert_bool(_swap(sim, 2, 6).ok).is_true()
	assert_int(incoming.slot).is_equal(1)
	assert_int(a.reserve_room).is_equal(0)
	assert_int(a.ap).is_equal(50)
	assert_int(incoming.hp).is_equal(70)
	assert_int(incoming.mp).is_equal(17)
	assert_bool(incoming.participated).is_true()
	assert_str(sim.can_act(6)).is_equal("not_active")
	assert_array(sim.hit_set(100, 2)).is_empty()
	assert_bool(_swap(sim, 3, 2).ok).is_true()
	assert_bool(_swap(sim, 4, 3).ok).is_true()
	assert_str(_swap(sim, 5, 4).error).is_equal("bad_reserve")
	assert_int(sim.reserve_swaps).is_equal(3)


func test_reserve_never_counts_as_alive_on_field() -> void:
	var front := BattleUnit.make(1, A, 1)
	var reserve := _reserve(2, 0)
	var enemy := BattleUnit.make(100, B, 0)
	var rules := BattleRules.new()
	var sim := BattleSim.new(rules, [front, reserve, enemy], 9)
	assert_array(sim.reserve_targets(1)).is_empty()
	assert_array(sim.legal_targets(100)).is_equal([1])
	assert_str(sim.submit({"actor": 2, "type": "wait"}).error).is_equal("in_reserve")
	front.hp = 0
	assert_bool(sim.side_lost(A)).is_true()
