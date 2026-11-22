class_name WorldGraph
extends RefCounted
## Граф мира: зоны (города, поля, подземелья) и пути между ними со временем в пути.
## Кратчайший путь по времени (Дейкстра). Зона закрыта, пока уровень игрока ниже её min_level.

var zones: Dictionary = {}
var start_zone := ""
var _adj: Dictionary = {}


func _init(world: Dictionary) -> void:
	start_zone = str(world["start_zone"])
	for z in world["zones"]:
		zones[str(z["id"])] = z
		_adj[str(z["id"])] = []
	for e in world["edges"]:
		_adj[str(e["a"])].append({"to": str(e["b"]), "seconds": float(e["seconds"])})
		_adj[str(e["b"])].append({"to": str(e["a"]), "seconds": float(e["seconds"])})


func has_zone(id: String) -> bool:
	return zones.has(id)


func min_level(id: String) -> int:
	return int(zones[id]["min_level"])


func zone_type(id: String) -> String:
	return str(zones[id]["type"])


func neighbors(id: String) -> Array:
	return _adj.get(id, [])


## Кратчайший путь по времени. level < 0 значит «без ограничений по уровню».
## Возвращает {"path": [id...], "seconds": float}; путь пустой, если маршрута нет.
func shortest_path(from: String, to: String, level := -1) -> Dictionary:
	if not zones.has(from) or not zones.has(to):
		return {"path": [], "seconds": 0.0}
	var dist := {from: 0.0}
	var prev := {}
	var open: Array[String] = [from]
	var done := {}
	while not open.is_empty():
		var cur := open[0]
		for id in open:
			if dist[id] < dist[cur]:
				cur = id
		open.erase(cur)
		if done.has(cur):
			continue
		done[cur] = true
		if cur == to:
			break
		for e in _adj[cur]:
			var nxt: String = e["to"]
			if level >= 0 and min_level(nxt) > level:
				continue
			var nd: float = dist[cur] + float(e["seconds"])
			if not dist.has(nxt) or nd < dist[nxt]:
				dist[nxt] = nd
				prev[nxt] = cur
				open.append(nxt)
	if not dist.has(to):
		return {"path": [], "seconds": 0.0}
	var path: Array[String] = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return {"path": path, "seconds": dist[to]}


## Зоны, достижимые из from без учёта уровня.
func reachable(from: String) -> Array[String]:
	var seen := {from: true}
	var stack: Array[String] = [from]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for e in _adj[cur]:
			if not seen.has(e["to"]):
				seen[e["to"]] = true
				stack.append(e["to"])
	var out: Array[String] = []
	for k in seen:
		out.append(k)
	return out
