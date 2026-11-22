extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func test_every_item_uses_a_texture_from_its_category() -> void:
	var fallback := Art.icon("backpack")
	for item: ItemDef in gd.items.values():
		var texture := UiKit.item_icon(item.id, item)
		assert_bool(texture != null and texture != fallback).is_true()
	var weapon_icons := {}
	for weapon in gd.weapons:
		var item := ItemDef.from_dict({"id": "test_equipment", "slot": "weapon", "weapon": weapon})
		var texture := UiKit.item_icon(item.id, item)
		assert_bool(not weapon_icons.has(texture.resource_path)).is_true()
		weapon_icons[texture.resource_path] = true


func test_every_monster_has_a_distinct_sprite() -> void:
	var sprites := {}
	for id in gd.monsters:
		var name := Art.monster_sprite(id)
		assert_bool(not sprites.has(name)).is_true()
		assert_object(Art.character(name)).is_not_null()
		sprites[name] = true


func test_active_heroes_have_portraits_and_formation_sprites() -> void:
	for id in gd.classes:
		if not gd.classes[id]["enabled"]:
			continue
		assert_object(Art.hero_portrait(id, null)).is_not_null()
		assert_object(Art.hero_formation_sprite(id, null)).is_not_null()


func test_battles_use_the_local_terrain() -> void:
	var manifest := gd.chunk_manifest
	assert_str(BattleBackground.biome_for("z_forest", manifest)).is_equal("forest")
	assert_str(BattleBackground.biome_for("z_dunes", manifest)).is_equal("desert")
	assert_str(BattleBackground.biome_for("z_canyon", manifest)).is_equal("mountain")
	assert_str(BattleBackground.biome_for("z_tomb", manifest)).is_equal("ruins")
	assert_str(BattleBackground.biome_for("z_meadow", manifest)).is_equal("meadow")
