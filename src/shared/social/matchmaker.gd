class_name Matchmaker
extends RefCounted
## Очередь PvP. Соперников подбирают по ступени лиги и уровню. Чем дольше ожидание, тем шире допуск
## (до заданных пределов). Выбор детерминирован: сначала те, кто ждёт дольше.

var gd: GameData
var queue: Array[Dictionary] = []


func _init(p_gd: GameData) -> void:
	gd = p_gd


func is_queued(pid: String) -> bool:
	for e in queue:
		if e["pid"] == pid:
			return true
	return false


func enqueue(pid: String, level: int, tier: int, now: float) -> Dictionary:
	if level < int(gd.social["pvp"]["min_level"]):
		return {"ok": false, "error": "level_too_low"}
	if is_queued(pid):
		return {"ok": false, "error": "already_queued"}
	queue.append({"pid": pid, "level": level, "tier": tier, "time": now})
	return {"ok": true, "error": ""}


func leave(pid: String) -> bool:
	for i in queue.size():
		if queue[i]["pid"] == pid:
			queue.remove_at(i)
			return true
	return false


func tier_gap(waited: float) -> int:
	var m: Dictionary = gd.social["pvp"]["match"]
	var steps := int(waited / float(m["widen_every_seconds"]))
	return mini(int(m["tier_gap_start"]) + steps * int(m["tier_gap_step"]), int(m["tier_gap_max"]))


func level_gap(waited: float) -> int:
	var m: Dictionary = gd.social["pvp"]["match"]
	var steps := int(waited / float(m["widen_every_seconds"]))
	return mini(int(m["level_gap_start"]) + steps * int(m["level_gap_step"]), int(m["level_gap_max"]))


## Составить пары и убрать их из очереди. Возвращает [[pid_a, pid_b], ...].
func find_matches(now: float) -> Array:
	var pairs: Array = []
	queue.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	var used := {}
	for i in queue.size():
		var a: Dictionary = queue[i]
		if used.has(a["pid"]):
			continue
		for j in range(i + 1, queue.size()):
			var b: Dictionary = queue[j]
			if used.has(b["pid"]):
				continue
			# допуск определяется тем, кто ждёт дольше
			var waited := now - float(a["time"])
			if abs(int(a["tier"]) - int(b["tier"])) <= tier_gap(waited) and abs(int(a["level"]) - int(b["level"])) <= level_gap(waited):
				pairs.append([a["pid"], b["pid"]])
				used[a["pid"]] = true
				used[b["pid"]] = true
				break
	queue = queue.filter(func(e): return not used.has(e["pid"]))
	return pairs
