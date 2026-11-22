extends GdUnitTestSuite

var gd: GameData
var worlds: Dictionary
var levels: Dictionary
var party: Party
var inv: Inventory


func before_test() -> void:
	gd = GameData.load_dir()
	inv = Inventory.new(gd)
	var ps := PartyService.new(gd)
	party = ps.create("a").party
	for n in ["b", "c"]:
		ps.invite("a", n)
		ps.accept(n, party.id)
	worlds = {}
	levels = {}
	for pid in party.members:
		var w := PlayerWorld.new(gd, 0.0)
		w.zone_id = "z_ruins"
		worlds[pid] = w
		levels[pid] = 12


func test_party_enters_dungeon_together_and_key_is_used_once() -> void:
	inv.add_material("key_ruins", 1)
	var r := DungeonRun.enter_party(party, worlds, levels, inv, 0.0)
	assert_bool(r.ok).is_true()
	assert_array(r.run.participants).is_equal(["a", "b", "c"])
	assert_int(inv.material_count("key_ruins")).is_equal(0)


func test_entry_needs_everyone_present_leveled_and_a_key() -> void:
	assert_str(DungeonRun.enter_party(party, worlds, levels, inv, 0.0).error).is_equal("no_key")
	inv.add_material("key_ruins", 1)
	(worlds["b"] as PlayerWorld).zone_id = "z_mine"
	var r := DungeonRun.enter_party(party, worlds, levels, inv, 0.0)
	assert_str(r.error).is_equal("member_not_here")
	assert_str(r.player).is_equal("b")
	(worlds["b"] as PlayerWorld).zone_id = "z_ruins"
	levels["c"] = 9
	r = DungeonRun.enter_party(party, worlds, levels, inv, 0.0)
	assert_str(r.error).is_equal("member_level_too_low")
	assert_int(inv.material_count("key_ruins")).is_equal(1)  # при отказе ключ цел


func test_party_larger_than_dungeon_limit_rejected() -> void:
	gd.world.zones.filter(func(z): return z.id == "z_ruins")[0].dungeon["max_players"] = 2
	inv.add_material("key_ruins", 1)
	assert_str(DungeonRun.enter_party(party, worlds, levels, inv, 0.0).error).is_equal("party_too_big")


func test_not_a_dungeon_zone() -> void:
	for pid in worlds:
		(worlds[pid] as PlayerWorld).zone_id = "z_harbor"
	assert_str(DungeonRun.enter_party(party, worlds, levels, inv, 0.0).error).is_equal("not_dungeon")


func test_traveling_member_blocks_entry() -> void:
	inv.add_material("key_ruins", 1)
	var w: PlayerWorld = worlds["c"]
	w.zone_id = "z_mine"
	w.travel_to("z_ruins", 12, 0.0)
	assert_str(DungeonRun.enter_party(party, worlds, levels, inv, 1.0).error).is_equal("member_not_here")
