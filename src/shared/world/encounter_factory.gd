class_name EncounterFactory
extends RefCounted
## Столкновение с врагами: список врагов в формации, награды. В бой игрок попадает при контакте с врагом на карте.


static func find(gd: GameData, enc_id: String) -> Dictionary:
	return gd.encounters.get(enc_id, {})


## Бойцы стороны B по описанию столкновения. Идентификаторы начинаются с rules.world.enemy_id_base.
static func build_units(enc: Dictionary, gd: GameData) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var next_id := int(gd.rules["world"]["enemy_id_base"])
	for e in enc["enemies"]:
		var m: Dictionary = gd.monsters[e["monster"]]
		var u := BattleUnit.make(next_id, BattleRules.SIDE_B, int(e["slot"]), {
			"hp": m["hp"], "atk": m["atk"], "def": m["def"], "ap_regen": m["ap_regen"],
			"flying": m.get("flying", false),
			"attack_pattern": m.get("attack_pattern", ""),
			"reach": BattleUnit.Reach.RANGED if m["reach"] == "ranged" else BattleUnit.Reach.MELEE,
		})
		out.append(u)
		next_id += 1
	return out
