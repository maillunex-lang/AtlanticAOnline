class_name Mercenary
extends RefCounted
## Экземпляр наёмника у игрока: уровень, распределённые очки, навыки.
## Старения нет: сила растёт с уровнем и ступенью, а ненужных наёмников можно отправить в отставку за ресурсы.

var uid := 0
var def_id := ""
var level := 1
var bonus_points := 0
var skill_points := 0
var allocated: Dictionary = {}
## Изученные навыки: id -> уровень навыка (1..skill_max_level).
var skill_levels: Dictionary = {}
var xp := 0
## Надетая экипировка: слот -> Item.
var equipped: Dictionary = {}


func _init(p_uid: int, p_def_id: String, gd: GameData) -> void:
	uid = p_uid
	def_id = p_def_id
	var d: MercenaryDef = gd.mercs[p_def_id]
	# При найме известен только первый (базовый) навык.
	skill_levels[d.skill_ids[0]] = 1


func set_level(n: int, gd: GameData) -> void:
	level = clampi(n, 1, int(gd.rules["max_level"]))


## Герой получил уровень: наёмники получают очко характеристик и очко навыка.
func grant_hero_level_points() -> void:
	bonus_points += 1
	skill_points += 1


func allocate(stat: String, gd: GameData) -> String:
	if not gd.rules["bonus_point_value"].has(stat):
		return "bad_stat"
	if bonus_points <= 0:
		return "no_points"
	bonus_points -= 1
	allocated[stat] = int(allocated.get(stat, 0)) + 1
	return ""


func learn_skill(skill_id: String, gd: GameData) -> String:
	var d: MercenaryDef = gd.mercs[def_id]
	if not d.skill_ids.has(skill_id):
		return "not_available"
	if skill_levels.has(skill_id):
		return "already_learned"
	if skill_levels.size() >= int(gd.rules["max_skills"]):
		return "too_many_skills"
	if level < (gd.skills[skill_id] as SkillDef).unlock_level:
		return "level_too_low"
	if skill_points <= 0:
		return "no_points"
	skill_points -= 1
	skill_levels[skill_id] = 1
	return ""


func upgrade_skill(skill_id: String, gd: GameData) -> String:
	if not skill_levels.has(skill_id):
		return "not_learned"
	if int(skill_levels[skill_id]) >= int(gd.rules["skill_max_level"]):
		return "max_level"
	if skill_points <= 0:
		return "no_points"
	skill_points -= 1
	skill_levels[skill_id] += 1
	return ""


## Добавить опыт, вернуть сколько уровней получено. На максимальном уровне опыт не копится.
func add_xp(amount: int, gd: GameData) -> int:
	var gained := 0
	if amount <= 0:
		return 0
	xp += amount
	while level < int(gd.rules["max_level"]):
		var need := Progression.xp_to_next(level, gd)
		if xp < need:
			break
		xp -= need
		level += 1
		gained += 1
	if level >= int(gd.rules["max_level"]):
		xp = 0
	return gained


## Надеть предмет из сумки. Старый предмет в этом слоте возвращается в сумку.
func equip(item: Item, inv: Inventory) -> String:
	var gd := inv.gd
	var idef: ItemDef = gd.items[item.def_id]
	var d: MercenaryDef = gd.mercs[def_id]
	if not idef.is_equip() or inv.item_by_uid(item.uid) == null:
		return "not_in_inventory"
	if level < idef.level_req:
		return "level_too_low"
	if idef.slot == "weapon" and idef.weapon != d.weapon:
		return "wrong_weapon"
	var old: Item = equipped.get(idef.slot)
	inv.items.erase(item)
	if old != null:
		inv.items.append(old)
	equipped[idef.slot] = item
	return ""


func unequip(slot: String, inv: Inventory) -> String:
	if not equipped.has(slot):
		return "empty_slot"
	if inv.is_full():
		return "inventory_full"
	inv.items.append(equipped[slot])
	equipped.erase(slot)
	return ""


## Итоговые базовые статы для боя: база типа + рост за уровень + очки характеристик.
func compute_stats(gd: GameData) -> Dictionary:
	var d: MercenaryDef = gd.mercs[def_id]
	var out := d.base.duplicate()
	for stat in d.growth_x10:
		out[stat] = int(out.get(stat, 0)) + int(d.growth_x10[stat]) * (level - 1) / 10
	for stat in allocated:
		out[stat] = int(out.get(stat, 0)) + int(allocated[stat]) * int(gd.rules["bonus_point_value"][stat])
	for slot in equipped:
		var it: Item = equipped[slot]
		for stat in (gd.items[it.def_id] as ItemDef).stats:
			out[stat] = int(out.get(stat, 0)) + it.stat(stat, gd)
	return out
