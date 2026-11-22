class_name LoginEvents
extends RefCounted
## Награды за вход по событиям (data/events.json): раз в игровые сутки на событие, пока оно идёт.
## Событие: {id, name, start, end (Unix-секунды), login_reward}. Выдача после суточного сброса и только один раз за сутки.

var gd: GameData
var clock: GameClock
## id события -> номер игровых суток последней выдачи.
var claimed: Dictionary = {}


func _init(p_gd: GameData, p_clock: GameClock) -> void:
	gd = p_gd
	clock = p_clock


func active(now: float) -> Array[String]:
	var out: Array[String] = []
	for id in gd.events:
		var e: Dictionary = gd.events[id]
		if now >= float(e["start"]) and now < float(e["end"]):
			out.append(id)
	return out


## Выдать награды всех идущих событий, не получавших сегодня. Результат: {"granted": [{event, reward}], "skipped": [ids без места]}.
func claim(ctx: Dictionary, now: float) -> Dictionary:
	var day := clock.day_index(now)
	var granted: Array = []
	var skipped: Array = []
	for id in active(now):
		if int(claimed.get(id, -1000000)) == day:
			continue
		var reward: Dictionary = gd.events[id]["login_reward"]
		if RewardGrant.apply(gd, ctx, reward):
			claimed[id] = day
			granted.append({"event": id, "reward": reward})
		else:
			skipped.append(id)
	return {"granted": granted, "skipped": skipped}


func to_dict() -> Dictionary:
	return {"claimed": claimed.duplicate()}


func load_dict(d: Dictionary) -> void:
	claimed = (d.get("claimed", {}) as Dictionary).duplicate()
