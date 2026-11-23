class_name DunesBattle
extends RefCounted
## Начальное состояние для серверного боя и его воспроизведения клиентом.

const SEED := 409
const SUPPORT := ["swordsman", "spearman", "archer", "adept", "axeman", "gunner"]
const SLOTS := [0, 2, 3, 4, 5, 7]


static func build(data: GameData, hero_class: String, level: int, encounter := "enc_dunes_drifters") -> BattleSim:
	# A fixed training roster is used by the two seeded pilot characters.
	var units: Array[BattleUnit] = []
	var squad := Squad.new(data)
	var hero := squad.create_hero(hero_class)
	hero.set_level(level, data)
	units.append(BattleUnit.from_mercenary(hero, data, 1, BattleRules.SIDE_A, 1, squad.formation_bonus()))
	for index in SUPPORT.size():
		var merc := Mercenary.new(index + 1, SUPPORT[index], data)
		merc.set_level(level, data)
		units.append(BattleUnit.from_mercenary(merc, data, index + 2, BattleRules.SIDE_A, SLOTS[index], squad.formation_bonus()))
	units.append_array(EncounterFactory.build_units(data.encounters[encounter], data, level))
	return BattleSim.new(BattleRules.new(), units, SEED, data.skills)
