extends GdUnitTestSuite

var gd: GameData
var inv: Inventory
var fishing: Fishing


func before_test() -> void:
	gd = GameData.load_dir()
	inv = Inventory.new(gd)
	fishing = Fishing.new()


func test_automatic_casts_use_one_bait_and_award_rank() -> void:
	assert_str(fishing.start("npc_harbor_fishing", inv, 0)).is_equal("no_bait")
	inv.add_material("fishing_bait", 4)
	assert_str(fishing.start("npc_harbor_fishing", inv, 0)).is_empty()
	assert_str(fishing.start("npc_cove_fishing", inv, 0)).is_equal("busy")
	assert_dict(fishing.tick(inv, 7.99)).is_empty()
	assert_int(int(fishing.tick(inv, 100)["count"])).is_equal(1)
	assert_int(inv.material_count("fishing_bait")).is_equal(3)
	assert_dict(fishing.tick(inv, 100)).is_empty()
	for now in [108, 116, 124]:
		fishing.tick(inv, now)
	assert_int(inv.material_count("coastal_fish")).is_equal(4)
	assert_int(fishing.xp).is_equal(20)
	assert_int(fishing.rank(gd)).is_equal(2)
	assert_str(fishing.spot_id).is_empty()


func test_full_stack_or_cancel_preserves_bait() -> void:
	var cap := int(gd.rules["material_stack_max"])
	inv.add_material("coastal_fish", cap - 1)
	inv.add_material("fishing_bait", 2)
	assert_str(fishing.start("npc_cove_fishing", inv, 0)).is_equal("bag_full")
	assert_str(fishing.start("npc_harbor_fishing", inv, 0)).is_empty()
	fishing.stop()
	assert_dict(fishing.tick(inv, 20)).is_empty()
	assert_int(inv.material_count("fishing_bait")).is_equal(2)
	assert_int(fishing.xp).is_equal(0)


func test_ration_uses_fish_and_refills_will_only_when_needed() -> void:
	var world := PlayerWorld.new(gd)
	assert_str(Fishing.cook(inv)).is_equal("no_fish")
	inv.add_material("coastal_fish", 2)
	assert_str(Fishing.cook(inv)).is_empty()
	assert_int(inv.material_count("coastal_fish")).is_equal(0)
	assert_str(Fishing.eat_ration(inv, world, 0)).is_equal("full_will")
	assert_int(inv.material_count("fish_ration")).is_equal(1)
	world.restore_will_snapshot({"points": 95, "time": 0})
	assert_str(Fishing.eat_ration(inv, world, 0)).is_empty()
	assert_int(inv.material_count("fish_ration")).is_equal(0)
	assert_int(world.will_at(0)).is_equal(world.will_max())
	assert_str(Fishing.eat_ration(inv, world, 0)).is_equal("no_ration")
