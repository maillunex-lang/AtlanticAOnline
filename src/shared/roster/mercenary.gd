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


## Итоговые базовые статы для боя: база типа + рост за уровень + очки характеристик.
func compute_stats(gd: GameData) -> Dictionary:
	var d: MercenaryDef = gd.mercs[def_id]
	var out := d.base.duplicate()
	for stat in d.growth_x10:
		out[stat] = int(out.get(stat, 0)) + int(d.growth_x10[stat]) * (level - 1) / 10
	for stat in allocated:
		out[stat] = int(out.get(stat, 0)) + int(allocated[stat]) * int(gd.rules["bonus_point_value"][stat])
	return out
