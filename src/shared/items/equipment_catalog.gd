class_name EquipmentCatalog
extends RefCounted
## Разворачивает ступени каталога в обычные ItemDef, рецепты и записи добычи.

const ARMOR_NAMES := {"armor": "Броня", "helm": "Шлем", "accessory": "Талисман"}
const ARMOR_SLOTS := ["armor", "helm", "accessory"]


static func load_into(gd: GameData, catalog: Dictionary) -> void:
	for set_definition: Dictionary in catalog["standard"]:
		_add_set(gd, set_definition, true)
	for set_definition: Dictionary in catalog["dungeons"]:
		_add_set(gd, set_definition, false)
	var legendary: Dictionary = catalog["legendary"]
	for weapon in WeaponType.ALL:
		_add_weapon(gd, legendary, weapon, "legendary", false)


static func _add_set(gd: GameData, definition: Dictionary, standard: bool) -> void:
	var id := str(definition["id"])
	var level := int(definition["level"])
	var pieces := 4 if standard else 3
	if gd.equipment_sets.has(id):
		gd.equipment_catalog_errors.append("equipment: повтор комплекта %s" % id)
		return
	gd.equipment_sets[id] = {
		"name": definition["name"], "level": level, "pieces": pieces, "source_loot": definition.get("loot", ""),
		"bonuses": {2: {"hp": 5 + level / 2}, pieces: {"def": 1 + level / 12}},
	}
	var loot_table := LootTable.find(gd, str(definition.get("loot", "")))
	for slot: String in ARMOR_SLOTS:
		var stats: Dictionary
		match slot:
			"armor": stats = {"hp": 6 + level * 2, "def": 1 + level / 3}
			"helm": stats = {"hp": 4 + level, "def": 1 + level / 5}
			_: stats = {"hp": 4 + level, "atk": 1 + level / 12}
		if not standard:
			stats["hp"] += 10 + level / 5
		var item_id := "%s_%s" % [id, slot]
		_add_item(gd, item_id, definition, slot, ARMOR_NAMES[slot], stats, "common" if standard else "rare", id)
		if standard:
			_add_recipe(gd, item_id, definition)
		elif not loot_table.is_empty():
			loot_table["entries"].append({"item": item_id, "weight": 4})
	if standard:
		for weapon in WeaponType.ALL:
			_add_weapon(gd, definition, weapon, "common", true)


static func _add_weapon(gd: GameData, definition: Dictionary, weapon: String, rarity: String, belongs_to_set: bool) -> void:
	var item_id := "%s_%s" % [definition["id"], weapon]
	var level := int(definition["level"])
	var base_weapon: ItemDef = gd.items["w_%s_1" % weapon]
	var stats := {"atk": int(base_weapon.stats["atk"]) + (level - 1) * 11 / 20}
	if rarity == "legendary":
		stats["atk"] += 12
	var set_id := str(definition["id"]) if belongs_to_set else ""
	_add_item(gd, item_id, definition, "weapon", str(gd.weapons[weapon]["name"]), stats, rarity, set_id, weapon)
	_add_recipe(gd, item_id, definition, rarity == "legendary")


static func _add_item(gd: GameData, id: String, definition: Dictionary, slot: String, name: String,
		stats: Dictionary, rarity: String, set_id: String, weapon := "") -> void:
	if gd.items.has(id):
		gd.equipment_catalog_errors.append("equipment: повтор предмета %s" % id)
		return
	gd.items[id] = ItemDef.from_dict({
		"id": id, "name": "%s · %s" % [name, definition["name"]], "kind": "equip", "slot": slot,
		"weapon": weapon, "rarity": rarity, "level_req": definition["level"], "stats": stats, "set_id": set_id,
	})


static func _add_recipe(gd: GameData, item_id: String, definition: Dictionary, legendary := false) -> void:
	var level := int(definition["level"])
	var materials := {"iron_ore": 2 + level / 5, "leather": 1 + level / 10}
	if legendary:
		materials["enhance_stone"] = 40
	gd.recipes.append({
		"id": "craft_" + item_id, "output": item_id, "materials": materials,
		"coins": 6000 if legendary else 28 + level * 6,
		"equipment_group": "legendary" if legendary else str(definition["id"]),
	})
