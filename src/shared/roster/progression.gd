class_name Progression
extends RefCounted
## Таблицы опыта (data/xp_tables.json): цифры оригинала. Таблица `hero` (уровни 1-200) для героя,
## `dcb`, `a`, `s` (уровни 1-120) для наёмников по рангам D/C/B, A, S. Таблица для ступени наёмника выбирается правилом
## `xp_table_by_tier` в data/progression.json, явный ранг задаёт таблицу для новых наёмников. Поле `xp_table` имеет приоритет.
## `xp` у бойца это накопленный опыт внутри текущего уровня.


## Таблица, по которой растёт тип наёмника.
static func table_for(def: MercenaryDef, gd: GameData) -> String:
	if def.xp_table != "":
		return def.xp_table
	if MercenaryDef.RANK_XP_TABLE.has(def.rank):
		return str(MercenaryDef.RANK_XP_TABLE[def.rank])
	return str(gd.rules["xp_table_by_tier"].get(def.tier, "dcb"))


## Наибольший уровень таблицы (на 1 больше числа переходов).
static func table_max_level(table: String, gd: GameData) -> int:
	return (gd.xp_tables[table] as Array).size() + 1


## Опыт, нужный для перехода с `level` на следующий; 0, если уровень максимальный (по таблице или по `max_level` правил).
static func xp_to_next(level: int, gd: GameData, table := "hero") -> int:
	var t: Array = gd.xp_tables[table]
	if level >= int(gd.rules["max_level"]) or level < 1 or level > t.size():
		return 0
	return int(t[level - 1])


## Суммарный опыт от 1 уровня до `level`.
static func total_xp(level: int, gd: GameData, table := "hero") -> int:
	var sum := 0
	for l in range(1, mini(level, table_max_level(table, gd))):
		sum += int((gd.xp_tables[table] as Array)[l - 1])
	return sum


## Потеря опыта при смерти или отступлении: доля `death_xp_loss_permille` (тысячные) от опыта на текущий уровень, не больше накопленного.
static func death_loss(level: int, xp: int, gd: GameData, table := "hero") -> int:
	var need := xp_to_next(level, gd, table)
	if need <= 0 or xp <= 0:
		return 0
	return mini(xp, maxi(1, need * int(gd.rules["death_xp_loss_permille"]) / 1000))
