class_name Item
extends RefCounted
## Экземпляр экипировки: тип, уровень улучшения (+N), серия неудач улучшения.

var uid := 0
var def_id := ""
var plus := 0
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
	return base * (100 + int(gd.rules["enhance"]["plus_pct_per_level"]) * level) / 100
