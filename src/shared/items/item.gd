class_name Item
extends RefCounted
## Экземпляр экипировки: тип, уровень улучшения (+N), серия неудач улучшения.

var uid := 0
var def_id := ""
var plus := 0
var star_stone := ""
var seal_opened := false
var wear := 0
## Подряд неудачных попыток улучшения на текущем уровне: каждая повышает шанс следующей.
var fail_streak := 0


func _init(p_uid: int, p_def_id: String) -> void:
	uid = p_uid
	def_id = p_def_id


## Стат предмета с учётом улучшения: база * (100 + процент_за_плюс * плюс) / 100.
func stat(stat_name: String, gd: GameData) -> int:
	return stat_at_plus(stat_name, gd, plus)


func stat_at_plus(stat_name: String, gd: GameData, level: int) -> int:
	var d: ItemDef = gd.items[def_id]
	var base := int(d.stats.get(stat_name, 0))
	var stone: ItemDef = gd.items.get(star_stone)
	var bonus := int(stone.stats.get(stat_name, 0)) if stone != null else 0
	return base * (100 + int(gd.rules["enhance"]["plus_pct_per_level"]) * level) / 100 + bonus


func stat_keys(gd: GameData) -> Array:
	var definition: ItemDef = gd.items[def_id]
	var stone: ItemDef = gd.items.get(star_stone)
	return definition.stats.keys() if stone == null else definition.stats.merged(stone.stats).keys()


func max_durability(gd: GameData) -> int:
	var rules: Dictionary = gd.rules.get("durability", {})
	var definition: ItemDef = gd.items[def_id]
	if rules.is_empty() or not definition.is_equip() or definition.level_req < int(rules["min_item_level"]) \
			or plus >= int(rules["exempt_plus"]) or definition.rarity == "legendary":
		return 0
	return int(rules["max"])


func condition_text(gd: GameData) -> String:
	var maximum := max_durability(gd)
	if maximum == 0:
		return "Прочность: не изнашивается"
	var remaining := maxi(0, maximum - wear)
	return "Прочность: %d/%d%s" % [remaining, maximum, " · нужен ремонт" if remaining == 0 else ""]


func is_broken(gd: GameData) -> bool:
	var maximum := max_durability(gd)
	return maximum > 0 and wear >= maximum


func apply_wear(amount: int, gd: GameData) -> bool:
	var maximum := max_durability(gd)
	if maximum == 0 or wear >= maximum or amount <= 0:
		return false
	wear = mini(maximum, wear + amount)
	return true


func repair_price(gd: GameData) -> int:
	return mini(wear, max_durability(gd)) * int(gd.rules.get("durability", {}).get("coins_per_point", 0))


func repair(gd: GameData, wallet: Dictionary) -> bool:
	var price := repair_price(gd)
	if price <= 0 or int(wallet.get("coins", 0)) < price:
		return false
	wallet["coins"] = int(wallet["coins"]) - price
	wear = 0
	return true


func has_seal(gd: GameData) -> bool:
	return gd.rules["enhance"].get("sealed_levels", []).any(func(level): return int(level) == plus)


func is_sealed(gd: GameData) -> bool:
	return has_seal(gd) and not seal_opened


func open_seal(inv: Inventory) -> bool:
	if inv.item_by_uid(uid) != self or not is_sealed(inv.gd):
		return false
	seal_opened = true
	return true


func has_socket(gd: GameData) -> bool:
	var definition: ItemDef = gd.items[def_id]
	var rules: Dictionary = gd.rules["star_sockets"]
	return definition.is_equip() and definition.slot in rules["slots"] and definition.level_req >= int(rules["min_item_level"])


func socket_error(stone_id: String, inv: Inventory) -> String:
	if not has_socket(inv.gd):
		return "no_socket"
	var stone: ItemDef = inv.gd.items.get(stone_id)
	if stone == null or stone.kind != "material" or stone.star_rank <= 0:
		return "invalid_stone"
	if not star_stone.is_empty():
		var installed: ItemDef = inv.gd.items[star_stone]
		if stone.star_rank <= installed.star_rank or not stone.same_star_type(installed):
			return "occupied"
	return "no_stone" if inv.material_count(stone_id) < 1 else ""


func install_stone(stone_id: String, inv: Inventory) -> String:
	var error := socket_error(stone_id, inv)
	if not error.is_empty():
		return error
	inv.take_material(stone_id, 1)
	star_stone = stone_id
	return ""
