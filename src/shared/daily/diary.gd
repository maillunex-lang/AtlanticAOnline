class_name Diary
extends RefCounted
## «Дневник»: суточные дела с бонусным опытом и очками (подземелья, дом). Данные в data/diary.json.
## Дело засчитывается не более `max_times` раз в сутки (плюс расширение за ресурс, оплату проводит вызывающий код).
## Бонус опыта = bonus_xp_per_level * уровень героя за каждое засчитанное выполнение.

var gd: GameData
var clock: GameClock
## id дела -> сколько раз засчитано в текущие игровые сутки.
var counters: Dictionary = {}
## id дела -> расширение лимита на текущие сутки.
var extra: Dictionary = {}
var day := -1000000


func _init(p_gd: GameData, p_clock: GameClock) -> void:
	gd = p_gd
	clock = p_clock


func _roll(now: float) -> void:
	var d := clock.day_index(now)
	if d != day:
		day = d
		counters.clear()
		extra.clear()


func cap(item_id: String, now: float) -> int:
	_roll(now)
	return int(gd.diary[item_id]["max_times"]) + int(extra.get(item_id, 0))


func credited(item_id: String, now: float) -> int:
	_roll(now)
	return int(counters.get(item_id, 0))


func remaining(item_id: String, now: float) -> int:
	return maxi(0, cap(item_id, now) - credited(item_id, now))


## Засчитать дело. Возвращает {"ok", "error", "credited", "xp", "dungeon_points", "home_points"}.
## Ошибки: unknown_item, level_too_low, limit_reached.
func credit(item_id: String, level: int, now: float, times := 1) -> Dictionary:
	_roll(now)
	if not gd.diary.has(item_id):
		return {"ok": false, "error": "unknown_item"}
	var it: Dictionary = gd.diary[item_id]
	if level < int(it["min_level"]):
		return {"ok": false, "error": "level_too_low"}
	var n := mini(times, remaining(item_id, now))
	if n <= 0:
		return {"ok": false, "error": "limit_reached"}
	counters[item_id] = credited(item_id, now) + n
	return {"ok": true, "error": "", "credited": n, "xp": int(it["bonus_xp_per_level"]) * level * n,
		"dungeon_points": int(it["dungeon_points"]) * n, "home_points": int(it["home_points"]) * n}


## Расширить суточный лимит дела (оплата, например рудой Атласа, вне этого класса).
func extend(item_id: String, times: int, now: float) -> Dictionary:
	_roll(now)
	if not gd.diary.has(item_id):
		return {"ok": false, "error": "unknown_item"}
	if not bool(gd.diary[item_id]["extendable"]):
		return {"ok": false, "error": "not_extendable"}
	if times <= 0:
		return {"ok": false, "error": "bad_count"}
	extra[item_id] = int(extra.get(item_id, 0)) + times
	return {"ok": true, "error": ""}


## Вкладка «Дела»: список дел с прогрессом.
func things_to_do(level: int, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in gd.diary:
		var it: Dictionary = gd.diary[id]
		out.append({"id": id, "name": it["name"], "done": credited(id, now), "cap": cap(id, now), "locked": level < int(it["min_level"]),
			"min_level": int(it["min_level"]), "extendable": bool(it["extendable"])})
	return out


## Вкладка «Подземелья»: личные подземелья в диапазоне уровня героя.
func dungeons(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for z in gd.world["zones"]:
		if z["type"] == "dungeon" and int(z["min_level"]) <= level:
			out.append({"zone": z["id"], "name": z["name"], "min_level": int(z["min_level"]), "key": z["dungeon"]["key"]})
	return out


func to_dict() -> Dictionary:
	return {"day": day, "counters": counters.duplicate(), "extra": extra.duplicate()}


func load_dict(d: Dictionary) -> void:
	day = int(d.get("day", -1000000))
	counters = (d.get("counters", {}) as Dictionary).duplicate()
	extra = (d.get("extra", {}) as Dictionary).duplicate()
