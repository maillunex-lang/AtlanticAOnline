class_name DailyExploration
extends RefCounted
## «Ежедневное исследование»: календарь наград за вход (data/exploration.json), с `min_level` героя.
## Награда выдаётся при первом входе игрового дня (по серверной полуночи). Карта растёт на один шаг за день входа:
## пропуск дня шаг не сбрасывает, но лишает главного приза месяца. В начале месяца карта обнуляется.
## Награды месяца можно переопределить в `monthly` по ключу "ГГГГ-ММ".

var gd: GameData
var clock: GameClock
var month := ""
var steps := 0
var last_day := -1000000
var perfect := true


func _init(p_gd: GameData, p_clock: GameClock) -> void:
	gd = p_gd
	clock = p_clock


func _calendar(key: String) -> Array:
	var monthly: Dictionary = gd.exploration.get("monthly", {})
	return monthly.get(key, gd.exploration["calendar"])


## Состояние карты на момент now без выдачи награды: {"month", "steps", "claimed_today", "perfect", "days"}.
func status(now: float) -> Dictionary:
	_roll_month(now)
	return {"month": month, "steps": steps, "claimed_today": last_day == clock.calendar_day(now), "perfect": perfect, "days": clock.days_in_current_month(now)}


func _roll_month(now: float) -> void:
	var key := clock.month_key(now)
	if key != month:
		month = key
		steps = 0
		last_day = -1000000
		perfect = true


## Награда, которую даст следующий вход (без выдачи); пустой словарь, если карта закончилась.
func next_reward(now: float) -> Dictionary:
	_roll_month(now)
	var cal := _calendar(month)
	if steps >= cal.size() or steps >= clock.days_in_current_month(now):
		return {}
	return (cal[steps] as Dictionary)["reward"]


## Вход игрока: засчитывает день и выдаёт награду. ctx как у RewardGrant. Результат:
## {"ok", "error", "step", "reward", "month_prize"}. Ошибки: level_too_low, already_claimed, finished, inventory_full.
func claim(ctx: Dictionary, level: int, now: float) -> Dictionary:
	_roll_month(now)
	if level < int(gd.exploration["min_level"]):
		return {"ok": false, "error": "level_too_low"}
	var today := clock.calendar_day(now)
	if last_day == today:
		return {"ok": false, "error": "already_claimed"}
	var days := clock.days_in_current_month(now)
	if steps >= days:
		return {"ok": false, "error": "finished"}
	var reward: Dictionary = (_calendar(month)[steps] as Dictionary)["reward"].duplicate(true)
	# День, пропущенный между входами (не первый вход месяца), лишает главного приза.
	var missed := steps > 0 and today - last_day > 1
	var will_perfect := perfect and not missed
	# Календарный день месяца должен совпадать с шагом: пропуск в начале месяца тоже лишает приза.
	if steps + 1 < GameClock.civil(today)["day"]:
		will_perfect = false
	var prize: Dictionary = {}
	if steps + 1 == days and will_perfect:
		prize = gd.exploration.get("month_prize", {})
		reward = RewardGrant.merge(reward, prize)
	if not RewardGrant.apply(gd, ctx, reward):
		return {"ok": false, "error": "inventory_full"}
	steps += 1
	last_day = today
	perfect = will_perfect
	return {"ok": true, "error": "", "step": steps, "reward": reward, "month_prize": prize}


func to_dict() -> Dictionary:
	return {"month": month, "steps": steps, "last_day": last_day, "perfect": perfect}


func load_dict(d: Dictionary) -> void:
	month = str(d.get("month", ""))
	steps = int(d.get("steps", 0))
	last_day = int(d.get("last_day", -1000000))
	perfect = bool(d.get("perfect", true))
