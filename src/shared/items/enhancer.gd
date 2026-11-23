class_name Enhancer
extends RefCounted
## Безопасное улучшение: шанс успеха, предмет никогда не ломается и не теряет уровень.
## Неудача отнимает монеты и часть камней (остальное возвращается) и повышает шанс следующей попытки.

const STONE := "enhance_stone"


static func max_plus(item: Item, gd: GameData) -> int:
	var rules: Dictionary = gd.rules["enhance"]
	var definition: ItemDef = gd.items[item.def_id]
	return int(rules["max_plus"] if definition.rarity == "legendary" else rules["normal_max_plus"])


## Шанс следующей попытки в процентах (с учётом серии неудач), не больше 100.
static func chance(item: Item, gd: GameData) -> int:
	var e: Dictionary = gd.rules["enhance"]
	if item.plus >= max_plus(item, gd):
		return 0
	return mini(100, int(e["chance"][item.plus]) + item.fail_streak * int(e["fail_streak_bonus_pct"]))


## Цена следующего уровня: {"coins": n, "stones": n}.
static func cost(item: Item, gd: GameData) -> Dictionary:
	var e: Dictionary = gd.rules["enhance"]
	return {"coins": int(e["coins"][item.plus]), "stones": int(e["stones"][item.plus])}


static func try_enhance(item: Item, inv: Inventory, wallet: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var gd := inv.gd
	var e: Dictionary = gd.rules["enhance"]
	if item.plus >= max_plus(item, gd):
		return {"ok": false, "error": "max_plus"}
	var c := cost(item, gd)
	if int(wallet.get("coins", 0)) < c.coins:
		return {"ok": false, "error": "no_coins"}
	if inv.material_count(STONE) < c.stones:
		return {"ok": false, "error": "no_stones"}
	var ch := chance(item, gd)
	var success := rng.randi_range(1, 100) <= ch
	wallet["coins"] -= c.coins
	var spent: int = c.stones
	if success:
		_raise_plus(item)
	else:
		item.fail_streak += 1
		spent = c.stones - c.stones * int(e["fail_refund_pct"]) / 100
	inv.take_material(STONE, spent)
	return {"ok": true, "error": "", "success": success, "plus": item.plus, "chance": ch, "coins": c.coins, "stones": spent}


## Гарантированный плюс за второй экземпляр из сумки того же типа и уровня усиления.
static func enchant_error(item: Item, donor: Item, inv: Inventory) -> String:
	if item.plus >= max_plus(item, inv.gd):
		return "max_plus"
	if donor == null or donor == item or inv.item_by_uid(donor.uid) != donor or donor.def_id != item.def_id or donor.plus != item.plus or not donor.star_stone.is_empty():
		return "invalid_donor"
	return "no_stones" if inv.material_count(STONE) < int(cost(item, inv.gd).stones) else ""


static func enchant(item: Item, donor: Item, inv: Inventory) -> String:
	var error := enchant_error(item, donor, inv)
	if not error.is_empty():
		return error
	inv.take_material(STONE, int(cost(item, inv.gd).stones))
	inv.items.erase(donor)
	_raise_plus(item)
	return ""


static func _raise_plus(item: Item) -> void:
	item.plus += 1
	item.fail_streak = 0
	item.seal_opened = false
