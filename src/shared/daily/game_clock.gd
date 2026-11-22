class_name GameClock
extends RefCounted
## Серверные сутки, недели и месяцы. Чистая логика: время (Unix-секунды, UTC) передаётся снаружи.
## Правила в data/progression.json -> "time": utc_offset_hours (серверная зона), reset_hour (час суточного сброса),
## weekly_reset_weekday (день недели недельного сброса, 1 = понедельник ... 7 = воскресенье).
## Оригинал: суточный сброс в 6:00 серверного времени, недельный в день обслуживания (среда); календарь ежедневных
## наград привязан к полуночи серверного времени.

const DAY := 86400

var utc_offset := 0
var reset_hour := 6
var weekly_weekday := 3


static func from_rules(rules: Dictionary) -> GameClock:
	var c := GameClock.new()
	var t: Dictionary = rules.get("time", {})
	c.utc_offset = int(t.get("utc_offset_hours", 0)) * 3600
	c.reset_hour = int(t.get("reset_hour", 6))
	c.weekly_weekday = int(t.get("weekly_reset_weekday", 3))
	return c


## Номер игровых суток: меняется в час суточного сброса.
func day_index(now: float) -> int:
	return floori((now + utc_offset - reset_hour * 3600) / float(DAY))


## Момент следующего суточного сброса (Unix-секунды).
func next_reset(now: float) -> float:
	return float((day_index(now) + 1) * DAY - utc_offset + reset_hour * 3600)


## Сколько секунд до следующего суточного сброса.
func seconds_to_reset(now: float) -> float:
	return next_reset(now) - now


## Номер игровой недели: меняется в час сброса в день недели `weekly_reset_weekday`.
func week_index(now: float) -> int:
	var d := day_index(now)
	return floori((d + 3 - (weekly_weekday - 1)) / 7.0)


## Календарный день по серверной полуночи (дни от 1970-01-01).
func calendar_day(now: float) -> int:
	return floori((now + utc_offset) / float(DAY))


## Год, месяц (1..12), день (1..31) для календарного дня (алгоритм Хиннанта).
static func civil(day: int) -> Dictionary:
	var z := day + 719468
	var era := floori(z / 146097.0)
	var doe := z - era * 146097
	var yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y := yoe + era * 400
	var doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp := (5 * doy + 2) / 153
	var d := doy - (153 * mp + 2) / 5 + 1
	var m := mp + 3 if mp < 10 else mp - 9
	return {"year": y + (1 if m <= 2 else 0), "month": m, "day": d}


static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if [4, 6, 9, 11].has(month) else 31


## Ключ месяца вида "2026-11" (по серверной полуночи).
func month_key(now: float) -> String:
	var c := civil(calendar_day(now))
	return "%04d-%02d" % [c.year, c.month]


## Сколько дней в текущем месяце.
func days_in_current_month(now: float) -> int:
	var c := civil(calendar_day(now))
	return days_in_month(c.year, c.month)
