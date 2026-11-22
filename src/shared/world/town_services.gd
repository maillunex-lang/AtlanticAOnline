class_name TownServices
extends RefCounted
## Правила городских служб. Клиент передаёт выбор, стоимость берётся из каталога.

var gd: GameData
var bank_coins := 0


func _init(data: GameData) -> void:
	gd = data


static func profile(zone: Dictionary) -> String:
	if not GameData.is_settlement(str(zone.get("type", ""))):
		return ""
	return "capital" if bool(zone.get("capital", false)) else str(zone["type"])


static func services_at(data: GameData, zone: Dictionary) -> Array[String]:
	var kind := profile(zone)
	var services: Array[String] = []
	if kind == "":
		return services
	for id in data.town_services.get("profiles", {}).get(kind, []) + zone.get("services", []):
		if data.town_services.get("services", {}).has(id) and id not in services:
			services.append(id)
	return services


func _zone(world: PlayerWorld) -> Dictionary:
	return world.graph.zones.get(world.zone_id, {})


func available(world: PlayerWorld, service: String) -> bool:
	return not world.traveling and service in services_at(gd, _zone(world))


func bank(world: PlayerWorld, wallet: Dictionary, deposit: bool) -> String:
	if not available(world, "bank"):
		return "unavailable"
	var amount := int(gd.town_services["services"]["bank"]["lot"])
	if deposit and int(wallet.get("coins", 0)) < amount:
		return "no_coins"
	if not deposit and bank_coins < amount:
		return "no_deposit"
	bank_coins += amount if deposit else -amount
	wallet["coins"] = int(wallet.get("coins", 0)) + (-amount if deposit else amount)
	return ""


func buy(world: PlayerWorld, wallet: Dictionary, inv: Inventory, index: int) -> String:
	if not available(world, "shop"):
		return "unavailable"
	var stock: Array = gd.town_services["services"]["shop"]["stock"]
	if index < 0 or index >= stock.size():
		return "bad_offer"
	var offer: Dictionary = stock[index]
	var cost := int(offer["coins"])
	var count := int(offer["count"])
	if int(wallet.get("coins", 0)) < cost:
		return "no_coins"
	if not _fits(inv, str(offer["item"]), count):
		return "bag_full"
	inv.add_material(offer["item"], count)
	wallet["coins"] = int(wallet["coins"]) - cost
	return ""


func exchange(world: PlayerWorld, inv: Inventory, index: int) -> String:
	if not available(world, "exchange"):
		return "unavailable"
	var rates: Array = gd.town_services["services"]["exchange"]["rates"]
	if index < 0 or index >= rates.size():
		return "bad_offer"
	var row: Dictionary = rates[index]
	if not _fits(inv, str(row["to"]), int(row["reward"])):
		return "bag_full"
	if not inv.take_material(row["from"], int(row["count"])):
		return "no_materials"
	inv.add_material(row["to"], int(row["reward"]))
	return ""


func _fits(inv: Inventory, item: String, count: int) -> bool:
	return inv.material_count(item) + count <= int(gd.rules["material_stack_max"])
