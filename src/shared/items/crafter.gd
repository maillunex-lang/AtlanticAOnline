class_name Crafter
extends RefCounted
## Крафт по рецептам: материалы и монеты на входе, всегда один и тот же предмет на выходе.


static func find(gd: GameData, recipe_id: String) -> Dictionary:
	for r in gd.recipes:
		if r["id"] == recipe_id:
			return r
	return {}


static func craft(recipe_id: String, inv: Inventory, wallet: Dictionary) -> Dictionary:
	var r := find(inv.gd, recipe_id)
	if r.is_empty():
		return {"ok": false, "error": "unknown_recipe"}
	if inv.is_full():
		return {"ok": false, "error": "inventory_full"}
	if int(wallet.get("coins", 0)) < int(r["coins"]):
		return {"ok": false, "error": "no_coins"}
	for m in r["materials"]:
		if inv.material_count(m) < int(r["materials"][m]):
			return {"ok": false, "error": "no_materials"}
	for m in r["materials"]:
		inv.take_material(m, int(r["materials"][m]))
	wallet["coins"] -= int(r["coins"])
	return {"ok": true, "error": "", "item": inv.add_equipment(r["output"])}
