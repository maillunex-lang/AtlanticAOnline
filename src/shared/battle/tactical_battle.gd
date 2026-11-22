class_name TacticalBattle
extends RefCounted
## Бой на общей сетке. Каждый боец может переместиться и совершить одно действие за ход стороны.

const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var rules := BattleRules.new()
var mission: Dictionary
var size: Vector2i
var walls := {}
var units: Dictionary = {}
var definitions: Dictionary = {}
var positions: Dictionary = {}
var objective_index := 0
var round_number := 1
var side := BattleRules.SIDE_A
var winner := BattleSim.Winner.NONE
var log_lines: Array[String] = []


func _init(data: Dictionary) -> void:
	mission = data
	size = Vector2i(int(data["width"]), int(data["height"]))
	for wall in data.get("blocked", []):
		walls[cell(wall)] = true
	for entry in data["units"]:
		var id := int(entry["id"])
		var unit_side := BattleRules.SIDE_A if entry.has("mercenary") else BattleRules.SIDE_B
		var unit := BattleUnit.make(id, unit_side, 0, entry)
		unit.is_hero = str(entry.get("mercenary", "")).begins_with("hero_") or unit.is_hero
		units[id] = unit
		definitions[id] = entry
		positions[id] = cell(entry["cell"])


static func cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func inside(at: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(at)


func unit_at(at: Vector2i) -> int:
	for id in positions:
		if positions[id] == at and units[id].is_alive():
			return int(id)
	return -1


func can_act(id: int) -> bool:
	var unit: BattleUnit = units.get(id)
	return winner == BattleSim.Winner.NONE and unit != null and unit.is_alive() and unit.side == side


func reachable(id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_act(id) or units[id].moved:
		return result
	var start: Vector2i = positions[id]
	var budget := int(definitions[id]["move"])
	var queue: Array[Vector2i] = [start]
	var steps := {start: 0}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if int(steps[current]) >= budget:
			continue
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if steps.has(next) or not _walkable_for(id, next):
				continue
			steps[next] = int(steps[current]) + 1
			queue.append(next)
			result.append(next)
	return result


func move(id: int, to: Vector2i) -> bool:
	if to not in reachable(id):
		return false
	positions[id] = to
	units[id].moved = true
	_check_outcome()
	return true


func attack_targets(id: int) -> Array[int]:
	var targets: Array[int] = []
	if not can_act(id) or units[id].acted:
		return targets
	for target in units:
		if units[target].is_alive() and units[target].side != side and distance(positions[id], positions[target]) <= int(definitions[id]["range"]):
			targets.append(int(target))
	return targets


func attack(id: int, target: int) -> bool:
	if target not in attack_targets(id):
		return false
	units[id].acted = true
	_hit(id, target, 100)
	_check_outcome()
	return true


func ability(id: int) -> Dictionary:
	if not definitions.has(id):
		return {}
	return mission.get("abilities", {}).get(definitions[id].get("ability", ""), {})


func can_cast(id: int) -> bool:
	var skill := ability(id)
	if skill.is_empty() or not can_act(id):
		return false
	var unit: BattleUnit = units[id]
	return not unit.acted and not unit.cooldowns.has("tactics") and unit.mp >= int(skill["mp"])


func can_target_ability(id: int, at: Vector2i) -> bool:
	return can_cast(id) and inside(at) and distance(positions[id], at) <= int(ability(id)["range"])


func ability_area(id: int, at: Vector2i) -> Array[Vector2i]:
	var area: Array[Vector2i] = []
	if not can_target_ability(id, at):
		return area
	var radius := int(ability(id)["area"]) / 2
	for y in range(maxi(0, at.y - radius), mini(size.y, at.y + radius + 1)):
		for x in range(maxi(0, at.x - radius), mini(size.x, at.x + radius + 1)):
			area.append(Vector2i(x, y))
	return area


func cast(id: int, at: Vector2i) -> bool:
	var area := ability_area(id, at)
	if area.is_empty():
		return false
	var skill := ability(id)
	var targets: Array[int] = []
	for target in units:
		if units[target].is_alive() and units[target].side != side and positions[target] in area:
			targets.append(int(target))
	if targets.is_empty():
		return false
	var unit: BattleUnit = units[id]
	unit.acted = true
	unit.mp -= int(skill["mp"])
	unit.cooldowns["tactics"] = int(skill["cooldown"])
	for target in targets:
		_hit(id, target, int(skill["power_pct"]))
	_check_outcome()
	return true


func _hit(id: int, target: int, power_pct: int) -> void:
	var attacker: BattleUnit = units[id]
	var victim: BattleUnit = units[target]
	var scale := rules.def_scale
	var damage := maxi(1, attacker.stat("atk") * power_pct * scale / (100 * (scale + victim.stat("def"))))
	victim.hp = maxi(0, victim.hp - damage)
	log_lines.append("%s → %s: −%d" % [unit_name(id), unit_name(target), damage])


func unit_name(id: int) -> String:
	return str(definitions[id].get("name", id))


func objective() -> Dictionary:
	var objectives: Array = mission.get("objectives", [])
	return objectives[objective_index] if objective_index < objectives.size() else {}


func end_turn() -> void:
	if winner != BattleSim.Winner.NONE:
		return
	if side == BattleRules.SIDE_B:
		if round_number >= int(mission.get("round_limit", 0)) and int(mission.get("round_limit", 0)) > 0:
			winner = BattleSim.Winner.SIDE_B
			log_lines.append("Время вышло")
			return
		round_number += 1
	side = 1 - side
	for unit: BattleUnit in units.values():
		if unit.side == side and unit.is_alive():
			unit.moved = false
			unit.acted = false
			if unit.cooldowns.has("tactics"):
				unit.cooldowns["tactics"] -= 1
				if int(unit.cooldowns["tactics"]) <= 0:
					unit.cooldowns.erase("tactics")


func enemy_turn() -> void:
	if side != BattleRules.SIDE_B or winner != BattleSim.Winner.NONE:
		return
	for id in units:
		if not can_act(id):
			continue
		var targets := attack_targets(id)
		if targets.is_empty():
			var best: Vector2i = positions[id]
			var distances := _attack_distances(id)
			var best_distance := int(distances.get(best, 2147483647))
			for to in reachable(id):
				var candidate := int(distances.get(to, 2147483647))
				if candidate < best_distance:
					best = to
					best_distance = candidate
			move(id, best)
			targets = attack_targets(id)
		if not targets.is_empty():
			targets.sort_custom(func(a: int, b: int) -> bool:
				return units[a].hp < units[b].hp if units[a].hp != units[b].hp else a < b)
			attack(id, targets[0])
	end_turn()


func _attack_distances(id: int) -> Dictionary:
	var distances := {}
	var queue: Array[Vector2i] = []
	var weapon_range := int(definitions[id]["range"])
	var enemy_cells: Array[Vector2i] = []
	for target in units:
		if units[target].side != side and units[target].is_alive():
			enemy_cells.append(positions[target])
	for y in size.y:
		for x in size.x:
			var at := Vector2i(x, y)
			if _walkable_for(id, at) and enemy_cells.any(func(enemy): return distance(at, enemy) <= weapon_range):
				distances[at] = 0
				queue.append(at)
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not _walkable_for(id, next) or distances.has(next):
				continue
			distances[next] = int(distances[current]) + 1
			queue.append(next)
	return distances


func _walkable_for(id: int, at: Vector2i) -> bool:
	if not inside(at) or walls.has(at):
		return false
	var occupant := unit_at(at)
	return occupant < 0 or occupant == id


func _check_outcome() -> void:
	if not units.values().any(func(unit): return unit.side == BattleRules.SIDE_A and unit.is_alive()):
		winner = BattleSim.Winner.SIDE_B
		return
	var objectives: Array = mission.get("objectives", [])
	if objectives.is_empty():
		if not units.values().any(func(unit): return unit.side == BattleRules.SIDE_B and unit.is_alive()):
			winner = BattleSim.Winner.SIDE_A
		return
	while objective_index < objectives.size():
		var goal := objective()
		if goal["type"] == "defeat" and units[int(goal["unit"])].is_alive():
			return
		if goal["type"] == "occupy":
			var occupant := unit_at(cell(goal["cell"]))
			if occupant < 0 or units[occupant].side != BattleRules.SIDE_A:
				return
		objective_index += 1
	winner = BattleSim.Winner.SIDE_A
