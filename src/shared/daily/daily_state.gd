class_name DailyState
extends RefCounted
## Суточные и недельные системы игрока: сброс по расписанию, дневник, ежедневное исследование, награды за вход,
## очки подземелья (недельный сброс) и дома, заметки. Время передаётся снаружи.
##
## Вызывать `tick(now)` при входе и периодически: он замечает пересечение суточного и недельного сброса и пишет заметки.
## События игры передавайте в `on_event`: подходящие дела дневника засчитываются автоматически.

var gd: GameData
var clock: GameClock
var diary: Diary
var exploration: DailyExploration
var login_events: LoginEvents
var notes := NoteBox.new()
## Очки: dungeon (сбрасываются раз в неделю, нужны рейдам и TBS-миссиям), home (не сбрасываются).
var points: Dictionary = {"dungeon": 0, "home": 0}
var _day := -1000000
var _week := -1000000


func _init(p_gd: GameData) -> void:
	gd = p_gd
	clock = GameClock.from_rules(gd.rules)
	diary = Diary.new(gd, clock)
	exploration = DailyExploration.new(gd, clock)
	login_events = LoginEvents.new(gd, clock)
	notes.max_notes = int(gd.rules["time"]["notes_max"])


## Проверить сбросы. Возвращает {"daily": bool, "weekly": bool}. Первый вызов только запоминает текущие сутки.
func tick(now: float) -> Dictionary:
	var d := clock.day_index(now)
	var w := clock.week_index(now)
	var res := {"daily": false, "weekly": false}
	if _day == -1000000:
		_day = d
		_week = w
		return res
	if d != _day:
		_day = d
		res["daily"] = true
		notes.add("daily_reset", now)
	if w != _week:
		_week = w
		res["weekly"] = true
		points["dungeon"] = 0
		notes.add("weekly_reset", now, {"points": "dungeon"})
	return res


## Событие игры: {"type": "quest_turn_in" | "individual_dungeon_clear" | ..., "count": n}. Возвращает выданный бонус
## {"xp", "dungeon_points", "home_points", "items": [id дел]}. Опыт нужно выдать вызывающему коду (squad.award_battle_xp).
func on_event(e: Dictionary, level: int, now: float) -> Dictionary:
	tick(now)
	var total := {"xp": 0, "dungeon_points": 0, "home_points": 0, "items": []}
	for id in gd.diary:
		if str(gd.diary[id]["event"]) != str(e.get("type", "")):
			continue
		var r := diary.credit(id, level, now, int(e.get("count", 1)))
		if not r.ok:
			continue
		total["xp"] += int(r.xp)
		total["dungeon_points"] += int(r.dungeon_points)
		total["home_points"] += int(r.home_points)
		(total["items"] as Array).append(id)
		points["dungeon"] = int(points["dungeon"]) + int(r.dungeon_points)
		points["home"] = int(points["home"]) + int(r.home_points)
	return total


## Потратить очки; false, если не хватает.
func spend(kind: String, amount: int) -> bool:
	if not points.has(kind) or amount < 0 or int(points[kind]) < amount:
		return false
	points[kind] = int(points[kind]) - amount
	return true


## Вход в игру: сбросы, награда исследования, награды событий. Результат {"exploration", "events", "resets"}.
func login(ctx: Dictionary, level: int, now: float) -> Dictionary:
	var resets := tick(now)
	var ex := exploration.claim(ctx, level, now)
	if ex.ok:
		notes.add("exploration_reward", now, {"step": ex.step})
	var ev := login_events.claim(ctx, now)
	for g in ev.granted:
		notes.add("event_login_reward", now, {"event": g["event"]})
	return {"exploration": ex, "events": ev, "resets": resets}


func to_dict() -> Dictionary:
	return {"day": _day, "week": _week, "points": points.duplicate(), "diary": diary.to_dict(), "exploration": exploration.to_dict(),
		"login_events": login_events.to_dict(), "notes": notes.to_dict()}


func load_dict(d: Dictionary) -> void:
	_day = int(d.get("day", -1000000))
	_week = int(d.get("week", -1000000))
	points = (d.get("points", {"dungeon": 0, "home": 0}) as Dictionary).duplicate()
	diary.load_dict(d.get("diary", {}))
	exploration.load_dict(d.get("exploration", {}))
	login_events.load_dict(d.get("login_events", {}))
	notes.load_dict(d.get("notes", {}))
