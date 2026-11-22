class_name Crafter
extends RefCounted
## Рецепты, нагрузка и опыт. Ручное и автоматическое изготовление используют одну проверку.


static func find(gd: GameData, recipe_id: String) -> Dictionary:
	for r in gd.recipes:
		if r["id"] == recipe_id:
			return r
	return {}


static func profession_for(item: ItemDef) -> String:
	return CraftProgress.WEAPON if item.slot == "weapon" else CraftProgress.ARMOR


static func requirements(recipe: Dictionary, gd: GameData) -> Dictionary:
	var item: ItemDef = gd.items[recipe["output"]]
	var skill_level := maxi(1, item.level_req - 10) if recipe.has("equipment_group") else 1
	return {
		"profession": profession_for(item), "level": skill_level,
		"workload": skill_level / 10, "xp": 10 + item.level_req * 2,
	}


static func craft_error(recipe: Dictionary, inv: Inventory, wallet: Dictionary) -> String:
	if recipe.is_empty():
		return "unknown_recipe"
	if inv.is_full():
		return "inventory_full"
	var req := requirements(recipe, inv.gd)
	if inv.crafting.level(req.profession) < int(req.level):
		return "craft_level"
	if int(wallet.get("coins", 0)) < int(recipe["coins"]):
		return "no_coins"
	for m in recipe["materials"]:
		if inv.material_count(m) < int(recipe["materials"][m]):
			return "no_materials"
	return "workload" if inv.crafting.workload < int(req.workload) else ""


static func craft(recipe_id: String, inv: Inventory, wallet: Dictionary) -> Dictionary:
	var recipe := find(inv.gd, recipe_id)
	var error := craft_error(recipe, inv, wallet)
	if error != "":
		return {"ok": false, "error": error}
	var req := requirements(recipe, inv.gd)
	for m in recipe["materials"]:
		inv.take_material(m, int(recipe["materials"][m]))
	wallet["coins"] -= int(recipe["coins"])
	inv.crafting.workload -= int(req.workload)
	inv.crafting.gain(req.profession, int(req.xp), inv.gd.rules["crafting"])
	return {"ok": true, "error": "", "item": inv.add_equipment(recipe["output"]), "xp": req.xp}


## Один заказ за тик. Большой скачок времени не вызывает пакетных списаний.
static func tick(delta: float, inv: Inventory, wallet: Dictionary) -> Dictionary:
	var progress := inv.crafting
	if progress.auto_recipe == "":
		progress.auto_elapsed = 0.0
		return {}
	progress.auto_elapsed += delta
	var config: Dictionary = inv.gd.rules["crafting"]
	if progress.auto_elapsed < float(config["tick_seconds"]):
		return {}
	progress.auto_elapsed = fmod(progress.auto_elapsed, float(config["tick_seconds"]))
	progress.add_workload(1, config)
	var result := craft(progress.auto_recipe, inv, wallet)
	if not result.ok and result.error != "workload":
		progress.auto_recipe = ""
	return result


static func dismantle(uid: int, inv: Inventory) -> Dictionary:
	var item := inv.item_by_uid(uid)
	if item == null:
		return {"ok": false, "error": "not_in_bag"}
	var def: ItemDef = inv.gd.items[item.def_id]
	var yield_materials := {}
	for recipe: Dictionary in inv.gd.recipes:
		if recipe["output"] != item.def_id:
			continue
		for material in recipe["materials"]:
			yield_materials[material] = maxi(1, int(recipe["materials"][material]) / 4)
		break
	if yield_materials.is_empty():
		yield_materials["iron_ore" if def.slot == "weapon" else "cloth_scrap"] = 1
	for material in yield_materials:
		if inv.material_count(material) + int(yield_materials[material]) > int(inv.gd.rules["material_stack_max"]):
			return {"ok": false, "error": "materials_full"}
	inv.items.erase(item)
	for material in yield_materials:
		inv.add_material(material, int(yield_materials[material]))
	var xp := 4 + def.level_req
	inv.crafting.gain(profession_for(def), xp, inv.gd.rules["crafting"])
	return {"ok": true, "error": "", "materials": yield_materials, "xp": xp}


## Анализ предмета из сумки один раз в игровые сутки. Предмет сохраняется.
static func analyze(uid: int, inv: Inventory, now: float, rng: RandomNumberGenerator) -> Dictionary:
	var item := inv.item_by_uid(uid)
	if item == null:
		return {"ok": false, "error": "not_in_bag"}
	var day := GameClock.from_rules(inv.gd.rules).day_index(now)
	if day <= inv.crafting.analyzed_day:
		return {"ok": false, "error": "analysis_used"}
	var def: ItemDef = inv.gd.items[item.def_id]
	var multiplier := rng.randi_range(2, 4)
	var xp := (4 + def.level_req) * multiplier
	inv.crafting.analyzed_day = day
	inv.crafting.gain(profession_for(def), xp, inv.gd.rules["crafting"])
	return {"ok": true, "error": "", "xp": xp, "multiplier": multiplier}
