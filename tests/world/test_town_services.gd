extends GdUnitTestSuite

var gd: GameData
var world: PlayerWorld
var town: TownServices
var inv: Inventory
var wallet: Dictionary


func before_test() -> void:
	gd = GameData.load_dir()
	world = PlayerWorld.new(gd)
	town = TownServices.new(gd)
	inv = Inventory.new(gd)
	wallet = {"coins": 100}


func test_town_profiles_and_capital_districts() -> void:
	assert_array(gd.validate()).is_empty()
	assert_array(TownServices.services_at(gd, world.graph.zones["z_harbor"])).contains(["bank", "market", "exchange", "guild", "town_hall", "shop", "crafting", "recruiter"])
	assert_array(TownServices.services_at(gd, {"type": "outpost"})).is_equal(["inn", "travel_agent", "shop"])
	assert_array(TownServices.services_at(gd, {"type": "field", "services": ["bank"]})).is_empty()
	assert_str(TownServices.profile({"type": "town", "capital": true})).is_equal("capital")
	assert_int(gd.town_services["districts"]["capital"].size()).is_equal(3)


func test_bank_moves_exact_amount_and_rejects_outside_town() -> void:
	assert_str(town.bank(world, wallet, false)).is_equal("no_deposit")
	assert_str(town.bank(world, wallet, true)).is_empty()
	assert_int(wallet.coins).is_equal(75)
	assert_int(town.bank_coins).is_equal(25)
	world.zone_id = "z_meadow"
	assert_str(town.bank(world, wallet, false)).is_equal("unavailable")
	world.zone_id = "z_harbor"
	assert_str(town.bank(world, wallet, false)).is_empty()
	assert_int(wallet.coins).is_equal(100)
	assert_int(town.bank_coins).is_equal(0)


func test_shop_and_exchange_are_atomic_on_insufficient_funds_or_capacity() -> void:
	wallet.coins = 0
	assert_str(town.buy(world, wallet, inv, 0)).is_equal("no_coins")
	assert_int(inv.material_count("iron_ore")).is_equal(0)
	wallet.coins = 100
	assert_str(town.buy(world, wallet, inv, 0)).is_empty()
	assert_int(wallet.coins).is_equal(88)
	assert_int(inv.material_count("iron_ore")).is_equal(3)
	inv.add_material("enhance_stone", int(gd.rules["material_stack_max"]))
	assert_str(town.exchange(world, inv, 0)).is_equal("bag_full")
	assert_int(inv.material_count("iron_ore")).is_equal(3)
	inv.take_material("enhance_stone", 1)
	assert_str(town.exchange(world, inv, 0)).is_empty()
	assert_int(inv.material_count("iron_ore")).is_equal(0)
	assert_str(town.buy(world, wallet, inv, -1)).is_equal("bad_offer")


func test_settlement_npcs_dispatch_town_services_from_dialogue() -> void:
	var runner := DialogueRunner.new(gd, QuestLog.new(gd), world)
	var ctx := {"level": 5, "now": 0.0, "inv": inv, "wallet": wallet}
	var cases := [
		["npc_orvin", "Городские службы", "town_directory"],
		["npc_tobin", "Открыть лавку", "shop"],
		["npc_edric", "Городские службы", "town_directory"],
		["npc_sava", "Городские службы", "town_directory"],
		["npc_rook", "Открыть вербовочную", "recruiter"],
	]
	for test_case in cases:
		world.zone_id = gd.npcs[test_case[0]]["zone"]
		if test_case[2] != "town_directory":
			assert_bool(town.available(world, test_case[2])).is_true()
		var sent := ""
		var initial := runner.start(test_case[0], ctx)
		assert_bool(initial.ok).is_true()
		for choice in initial.view["choices"]:
			if choice["text"] == test_case[1]:
				sent = runner.choose(choice["index"], ctx).service
		assert_str(sent).is_equal(test_case[2])
