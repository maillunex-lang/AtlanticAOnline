class_name EncounterFactory
extends RefCounted
## Столкновение с врагами: список врагов в формации, награды. В бой игрок попадает при контакте с врагом на карте.


static func find(gd: GameData, enc_id: String) -> Dictionary:
	return gd.encounters.get(enc_id, {})


static func groups(enc: Dictionary) -> Array:
	var out := [enc.get("enemies", [])]
	out.append_array(enc.get("reinforcements", []))
	return out


static func enemy_entries(enc: Dictionary) -> Array:
	var entries := []
	for group in groups(enc):
		entries.append_array(group)
	return entries


## Бойцы стороны B по описанию столкновения. Идентификаторы начинаются с rules.world.enemy_id_base.
static func build_units(enc: Dictionary, gd: GameData, highest_hero_level := -1) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var next_id := int(gd.rules["world"]["enemy_id_base"])
	var cfg: Dictionary = gd.rules.get("pve", {})
	var wave := 0
	for group in groups(enc):
		for entry in group:
			var monster: Dictionary = gd.monsters[entry["monster"]]
			var percent := 100
			if highest_hero_level > 0 and monster.get("scale_to_hero", false):
				var cap := int(cfg.get("scaling_max_steps", 0))
				var delta := clampi(highest_hero_level - int(monster["level"]), -cap, cap)
				percent += delta * int(cfg.get("scaling_pct_per_level", 0))
			var unit := BattleUnit.make(next_id, BattleRules.SIDE_B, int(entry["slot"]), {
				"hp": maxi(1, int(monster["hp"]) * percent / 100),
				"atk": maxi(1, int(monster["atk"]) * percent / 100),
				"def": maxi(0, int(monster["def"]) * percent / 100), "ap_regen": monster["ap_regen"],
				"flying": monster.get("flying", false), "attack_pattern": monster.get("attack_pattern", ""),
				"reach": BattleUnit.Reach.RANGED if monster["reach"] == "ranged" else BattleUnit.Reach.MELEE,
			})
			unit.enemy_wave = wave
			out.append(unit)
			next_id += 1
		wave += 1
	return out
