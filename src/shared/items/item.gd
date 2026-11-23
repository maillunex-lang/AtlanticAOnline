class_name Item
extends RefCounted
## Экземпляр экипировки: тип, уровень улучшения (+N), серия неудач улучшения.

var uid := 0
var def_id := ""
var plus := 0
var star_stone := ""
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
