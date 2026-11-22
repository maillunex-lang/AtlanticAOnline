class_name CraftProgress
extends RefCounted
## Ремесленный прогресс и очередь игрока. Время передаётся игровым циклом.

const WEAPON := "weapon"
const ARMOR := "armor"

var skills := {WEAPON: {"level": 1, "xp": 0}, ARMOR: {"level": 1, "xp": 0}}
var workload := 0
var analyzed_day := -1000000
var auto_recipe := ""
var auto_elapsed := 0.0


func level(profession: String) -> int:
	return int(skills[profession]["level"])


func next_xp(profession: String, config: Dictionary) -> int:
	return 0 if level(profession) >= int(config["max_level"]) else 8 + 2 * level(profession)


func title(profession: String, config: Dictionary) -> String:
	var current := ""
	for stage: Dictionary in config["titles"]:
		if level(profession) < int(stage["level"]):
			break
		current = str(stage["name"])
	return current


func gain(profession: String, amount: int, config: Dictionary) -> void:
	var skill: Dictionary = skills[profession]
	skill["xp"] += amount
	var needed := next_xp(profession, config)
	while needed > 0 and int(skill["xp"]) >= needed:
		skill["xp"] -= needed
		skill["level"] += 1
		needed = next_xp(profession, config)
	if needed == 0:
		skill["xp"] = 0


func add_workload(amount: int, config: Dictionary) -> void:
	workload = mini(int(config["max_workload"]), workload + amount)
