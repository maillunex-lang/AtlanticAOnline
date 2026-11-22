class_name Progression
extends RefCounted
## Кривая опыта. Нужный опыт для следующего уровня: base + linear*(L-1) + quad*(L-1)^2.


static func xp_to_next(level: int, gd: GameData) -> int:
	if level >= int(gd.rules["max_level"]):
		return 0
	var x: Dictionary = gd.rules["xp"]
	var l := level - 1
	return int(x["base"]) + int(x["linear"]) * l + int(x["quad"]) * l * l
