class_name Fishing
extends RefCounted
## Действия рыбалки получают время и инвентарь от вызывающего кода.

var xp := 0
var spot_id := ""
var _ready_at := 0.0


func rank(gd: GameData) -> int:
	return 1 + xp / int(gd.life_skills["fishing"]["xp_per_rank"])


func start(id: String, inv: Inventory, now: float) -> String:
	if not spot_id.is_empty():
		return "busy"
	var config: Dictionary = inv.gd.life_skills["fishing"]
	var spot: Dictionary = config["spots"].get(id, {})
	if spot.is_empty():
		return "unknown_spot"
	var error := _catch_error(config, spot, inv)
	if not error.is_empty():
		return error
	spot_id = id
	_ready_at = now + _duration(config, spot, inv.gd)
	return ""


func seconds_until_catch(now: float) -> int:
	return ceili(maxf(0.0, _ready_at - now))


func stop() -> void:
	spot_id = ""
	_ready_at = 0.0


func tick(inv: Inventory, now: float) -> Dictionary:
	if spot_id.is_empty() or now < _ready_at:
		return {}
	var config: Dictionary = inv.gd.life_skills["fishing"]
	var spot: Dictionary = config["spots"][spot_id]
	var error := _catch_error(config, spot, inv)
	if not error.is_empty():
		stop()
		return {"error": error}
	inv.take_material(config["bait"], 1)
	inv.add_material(spot["catch"], int(spot["count"]))
	xp += int(spot["xp"])
	var next_error := _catch_error(config, spot, inv)
	if next_error.is_empty():
		_ready_at = now + _duration(config, spot, inv.gd)
	else:
		stop()
	return {"item": spot["catch"], "count": int(spot["count"]), "error": next_error}


func _duration(config: Dictionary, spot: Dictionary, gd: GameData) -> float:
	return maxf(float(config["min_seconds"]), float(spot["seconds"]) - (rank(gd) - 1) * float(config["seconds_saved_per_rank"]))


func _catch_error(config: Dictionary, spot: Dictionary, inv: Inventory) -> String:
	if inv.material_count(config["bait"]) < 1:
		return "no_bait"
	if inv.material_count(spot["catch"]) + int(spot["count"]) > int(inv.gd.rules["material_stack_max"]):
		return "bag_full"
	return ""


static func cook(inv: Inventory) -> String:
	var recipe: Dictionary = inv.gd.life_skills["cooking"]
	var count := int(recipe["ingredient_count"])
	if inv.material_count(recipe["ingredient"]) < count:
		return "no_fish"
	if inv.material_count(recipe["output"]) >= int(inv.gd.rules["material_stack_max"]):
		return "bag_full"
	inv.take_material(recipe["ingredient"], count)
	inv.add_material(recipe["output"], 1)
	return ""


static func eat_ration(inv: Inventory, world: PlayerWorld, now: float) -> String:
	var recipe: Dictionary = inv.gd.life_skills["cooking"]
	if inv.material_count(recipe["output"]) < 1:
		return "no_ration"
	if world.will_at(now) >= world.will_max():
		return "full_will"
	inv.take_material(recipe["output"], 1)
	world.restore_will(int(recipe["will"]), now)
	return ""
