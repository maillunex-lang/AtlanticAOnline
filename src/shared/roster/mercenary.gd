class_name Mercenary
extends RefCounted
## Экземпляр наёмника у игрока: уровень, распределённые очки, навыки.
## Старения нет: сила растёт с уровнем и ступенью, а ненужных наёмников можно отправить в отставку за ресурсы.

var uid := 0
var def_id := ""
var level := 1
var enabled := true
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
	level = clampi(n, 1, max_level(gd))


func max_level(gd: GameData) -> int:
	var cap := int(gd.rules["max_level"])
	var definition: MercenaryDef = gd.mercs[def_id]
	return mini(cap, definition.level_cap) if definition.level_cap > 0 else cap


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
	var cap := max_level(gd)
	while level < cap:
		var need := Progression.xp_to_next(level, gd)
		if xp < need:
			break
		xp -= need
		level += 1
		gained += 1
	if level >= cap:
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
	var mp: Dictionary = gd.rules.get("mp", {"base": 40, "per_level": 3})
	out["mp"] = int(mp["base"]) + int(mp["per_level"]) * (level - 1)
	for stat in allocated:
		out[stat] = int(out.get(stat, 0)) + int(allocated[stat]) * int(gd.rules["bonus_point_value"][stat])
	for slot in equipped:
		var it: Item = equipped[slot]
		for stat in (gd.items[it.def_id] as ItemDef).stats:
			out[stat] = int(out.get(stat, 0)) + it.stat(stat, gd)
	var cfg: Dictionary = gd.rules.get("combat_attributes", {})
	if not cfg.is_empty():
		_apply_attributes(out, d.weapon, cfg)
	return out


func _apply_attributes(out: Dictionary, weapon: String, cfg: Dictionary) -> void:
	var strength := maxi(0, int(out.get("strength", 0)))
	var dexterity := maxi(0, int(out.get("dexterity", 0)))
	var vitality := maxi(0, int(out.get("vitality", 0)))
	var intelligence := maxi(0, int(out.get("intelligence", 0)))
	var resource: Dictionary = cfg["resource"]
	var baseline := _resource_total(0, 0.0, resource)
	out["hp"] += _resource_total(vitality, float(resource["hp_scale"]), resource) - baseline
	out["mp"] += _resource_total(intelligence, float(resource["mp_scale"]), resource) - baseline
	var attack_bonus := int(strength * float(cfg["melee_attack_per_strength"]))
	if weapon == "staff":
		attack_bonus = int(intelligence * float(cfg["staff_attack_per_intelligence"]))
	elif weapon in ["bow", "gun", "cannon", "instrument", "whip"]:
		attack_bonus = int(dexterity * float(cfg["ranged_attack_per_dexterity"]))
	out["atk"] += attack_bonus
	out["def"] += int(strength * float(cfg["defense_per_strength"]))
	out["magic_def"] = int(out.get("magic_def", 0)) + int(intelligence * float(cfg["magic_defense_per_intelligence"]))
	var dexterity_rates: Dictionary = cfg["dexterity_points_per_percent"]
	for stat in dexterity_rates:
		out[stat] = int(out.get(stat, 0)) + dexterity / maxi(1, int(dexterity_rates[stat]))


func _resource_total(attribute: int, scale: float, cfg: Dictionary) -> int:
	var offset := float(cfg["level_offset"])
	var factor := attribute / float(cfg["stat_divisor"]) + level + offset
	return floori((float(cfg["level_scale"]) * level + scale * attribute) * factor / offset + float(cfg["offset"]))
