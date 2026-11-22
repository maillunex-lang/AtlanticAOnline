extends GdUnitTestSuite
## Сутки, недели, дневник, ежедневное исследование, награды за вход, заметки (WP-34). Время передаётся снаружи.

var gd: GameData
var clock: GameClock
var inv: Inventory
var wallet: Dictionary


func before_test() -> void:
	gd = GameData.load_dir()
	clock = GameClock.from_rules(gd.rules)
	inv = Inventory.new(gd)
	wallet = {"coins": 0}


## Unix-секунды по дате UTC.
func _t(y: int, m: int, d: int, h := 0, mi := 0, s := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": h, "minute": mi, "second": s}))


func _ctx(level := 30) -> Dictionary:
	return {"inv": inv, "wallet": wallet, "level": level}


# ---------- часы ----------

func test_daily_reset_happens_at_reset_hour() -> void:
	assert_int(clock.day_index(_t(2026, 11, 22, 5, 59, 59))).is_not_equal(clock.day_index(_t(2026, 11, 22, 6, 0, 0)))
	assert_int(clock.day_index(_t(2026, 11, 22, 6, 0, 0))).is_equal(clock.day_index(_t(2026, 11, 23, 5, 59, 59)))
	assert_float(clock.next_reset(_t(2026, 11, 22, 10))).is_equal(_t(2026, 11, 23, 6))
	assert_float(clock.seconds_to_reset(_t(2026, 11, 22, 5, 59, 0))).is_equal(60.0)


func test_weekly_reset_is_wednesday_at_reset_hour() -> void:
	assert_int(clock.week_index(_t(2026, 11, 25, 5, 59, 59))).is_not_equal(clock.week_index(_t(2026, 11, 25, 6, 0, 0)))
	assert_int(clock.week_index(_t(2026, 11, 25, 6))).is_equal(clock.week_index(_t(2026, 12, 2, 5, 59, 59)))
	assert_int(clock.week_index(_t(2026, 12, 2, 6))).is_equal(clock.week_index(_t(2026, 11, 25, 6)) + 1)


func test_server_timezone_shifts_resets() -> void:
	gd.rules["time"]["utc_offset_hours"] = 3
	var shifted := GameClock.from_rules(gd.rules)
	# 06:00 по серверному времени UTC+3 это 03:00 UTC.
	assert_int(shifted.day_index(_t(2026, 11, 22, 2, 59, 59))).is_not_equal(shifted.day_index(_t(2026, 11, 22, 3, 0, 0)))
	assert_float(shifted.next_reset(_t(2026, 11, 22, 10))).is_equal(_t(2026, 11, 23, 3))


func test_calendar_conversions_and_month_keys() -> void:
	assert_dict(GameClock.civil(clock.calendar_day(_t(2024, 2, 29, 12)))).is_equal({"year": 2024, "month": 2, "day": 29})
	assert_dict(GameClock.civil(clock.calendar_day(_t(2026, 12, 1)))).is_equal({"year": 2026, "month": 12, "day": 1})
	assert_dict(GameClock.civil(0)).is_equal({"year": 1970, "month": 1, "day": 1})
	assert_int(GameClock.days_in_month(2024, 2)).is_equal(29)
	assert_int(GameClock.days_in_month(2026, 2)).is_equal(28)
	assert_int(GameClock.days_in_month(2100, 2)).is_equal(28)
	assert_int(GameClock.days_in_month(2000, 2)).is_equal(29)
	assert_int(GameClock.days_in_month(2026, 11)).is_equal(30)
	assert_str(clock.month_key(_t(2026, 11, 30, 23, 59, 59))).is_equal("2026-11")
	assert_str(clock.month_key(_t(2026, 12, 1))).is_equal("2026-12")
	assert_int(clock.days_in_current_month(_t(2026, 11, 5))).is_equal(30)


func test_daily_quests_use_the_same_reset_hour() -> void:
	var log := QuestLog.new(gd)
	assert_int(log.day_of(_t(2026, 11, 22, 5, 59, 59))).is_not_equal(log.day_of(_t(2026, 11, 22, 6)))


# ---------- дневник ----------

func test_diary_caps_levels_and_rewards() -> void:
	var d := Diary.new(gd, clock)
	var now := _t(2026, 11, 22, 12)
	assert_str(d.credit("quest", 19, now).error).is_equal("level_too_low")
	var r := d.credit("quest", 30, now)
	assert_bool(r.ok).is_true()
	assert_int(r.xp).is_equal(30 * 30)
	assert_int(r.dungeon_points).is_equal(6)
	assert_int(r.home_points).is_equal(4)
	d.credit("quest", 30, now)
	d.credit("quest", 30, now)
	assert_str(d.credit("quest", 30, now).error).is_equal("limit_reached")
	assert_int(d.remaining("quest", now)).is_equal(0)
	assert_str(d.credit("ghost", 30, now).error).is_equal("unknown_item")
	var many := d.credit("compete", 30, now, 5)  # лимит 2
	assert_int(many.credited).is_equal(2)
	assert_int(many.dungeon_points).is_equal(16)


func test_diary_resets_at_daily_reset_and_extends() -> void:
	var d := Diary.new(gd, clock)
	var now := _t(2026, 11, 22, 12)
	d.credit("individual_dungeon", 40, now)
	assert_str(d.credit("individual_dungeon", 40, now).error).is_equal("limit_reached")
	assert_bool(d.extend("individual_dungeon", 2, now).ok).is_true()
	assert_int(d.remaining("individual_dungeon", now)).is_equal(2)
	assert_str(d.extend("rest", 1, now).error).is_equal("not_extendable")
	assert_str(d.extend("ghost", 1, now).error).is_equal("unknown_item")
	assert_str(d.extend("quest", 0, now).error).is_equal("bad_count")
	# До сброса счётчик жив, после сброса новое число попыток и расширение сгорает.
	assert_int(d.credited("individual_dungeon", _t(2026, 11, 23, 5, 59))).is_equal(1)
	assert_int(d.credited("individual_dungeon", _t(2026, 11, 23, 6))).is_equal(0)
	assert_int(d.cap("individual_dungeon", _t(2026, 11, 23, 6))).is_equal(1)


func test_diary_tabs() -> void:
	var d := Diary.new(gd, clock)
	var list := d.things_to_do(25, _t(2026, 11, 22, 12))
	assert_int(list.size()).is_equal(gd.diary.size())
	var locked := list.filter(func(x): return x.locked)
	assert_bool(locked.size() > 0).is_true()  # дела с порогом выше 25 заблокированы
	var dg := d.dungeons(12)
	assert_int(dg.size()).is_equal(1)
	assert_str(dg[0].zone).is_equal("z_ruins")
	assert_int(d.dungeons(5).size()).is_equal(0)


# ---------- ежедневное исследование ----------

func test_exploration_claims_once_per_day_and_gives_calendar_reward() -> void:
	var ex := DailyExploration.new(gd, clock)
	var now := _t(2026, 11, 1, 12)
	assert_str(ex.claim(_ctx(19), 19, now).error).is_equal("level_too_low")
	var r := ex.claim(_ctx(), 30, now)
	assert_bool(r.ok).is_true()
	assert_int(r.step).is_equal(1)
	assert_int(int(wallet["coins"])).is_equal(500)  # награда дня 1
	assert_str(ex.claim(_ctx(), 30, now + 3600.0).error).is_equal("already_claimed")
	var r2 := ex.claim(_ctx(), 30, _t(2026, 11, 2, 1))
	assert_int(r2.step).is_equal(2)
	assert_int(int(ex.next_reward(_t(2026, 11, 2, 2))["items"]["iron_ore"])).is_equal(3)  # награда дня 3


func test_exploration_missed_day_keeps_progress_but_loses_month_prize() -> void:
	var ex := DailyExploration.new(gd, clock)
	ex.claim(_ctx(), 30, _t(2026, 11, 1, 12))
	ex.claim(_ctx(), 30, _t(2026, 11, 3, 12))  # пропущено 2 ноября
	assert_int(ex.status(_t(2026, 11, 3, 13)).steps).is_equal(2)
	assert_bool(ex.status(_t(2026, 11, 3, 13)).perfect).is_false()
	var last := {}
	for day in range(4, 31):
		last = ex.claim(_ctx(), 30, _t(2026, 11, day, 12))
	# Шагов 29 из 30: карта не закончена, приза нет.
	assert_int(ex.steps).is_equal(29)
	assert_dict(last.month_prize).is_empty()


func test_exploration_perfect_month_gives_prize_on_last_day() -> void:
	var ex := DailyExploration.new(gd, clock)
	var last := {}
	for day in range(1, 31):
		last = ex.claim(_ctx(), 30, _t(2026, 11, day, 12))
		assert_bool(last.ok).is_true()
	assert_int(last.step).is_equal(30)
	assert_bool(last.month_prize.has("coins")).is_true()
	assert_int(int(last.reward["coins"])).is_greater_equal(10000)
	assert_str(ex.claim(_ctx(), 30, _t(2026, 11, 30, 20)).error).is_equal("already_claimed")


func test_exploration_late_start_in_month_never_gets_prize() -> void:
	var ex := DailyExploration.new(gd, clock)
	for day in range(5, 31):
		ex.claim(_ctx(), 30, _t(2026, 11, day, 12))
	assert_bool(ex.status(_t(2026, 11, 30, 13)).perfect).is_false()


func test_exploration_resets_in_new_month() -> void:
	var ex := DailyExploration.new(gd, clock)
	ex.claim(_ctx(), 30, _t(2026, 11, 29, 12))
	ex.claim(_ctx(), 30, _t(2026, 11, 30, 12))
	var r := ex.claim(_ctx(), 30, _t(2026, 12, 1, 12))
	assert_int(r.step).is_equal(1)
	assert_str(ex.status(_t(2026, 12, 1, 13)).month).is_equal("2026-12")
	assert_bool(ex.status(_t(2026, 12, 1, 13)).perfect).is_true()


func test_exploration_full_bag_does_not_consume_the_step() -> void:
	gd.exploration["calendar"][0]["reward"] = {"items": {"h_cap": 1}}
	var ex := DailyExploration.new(gd, clock)
	while not inv.is_full():
		inv.add_equipment("h_cap")
	var now := _t(2026, 11, 1, 12)
	assert_str(ex.claim(_ctx(), 30, now).error).is_equal("inventory_full")
	assert_int(ex.steps).is_equal(0)
	inv.items.pop_back()
	assert_bool(ex.claim(_ctx(), 30, now).ok).is_true()


func test_exploration_monthly_override() -> void:
	var cal: Array = []
	for day in 31:
		cal.append({"day": day + 1, "reward": {"coins": 7}})
	gd.exploration["monthly"] = {"2026-12": cal}
	assert_array(gd.validate()).is_empty()
	var ex := DailyExploration.new(gd, clock)
	ex.claim(_ctx(), 30, _t(2026, 12, 1, 12))
	assert_int(int(wallet["coins"])).is_equal(7)


# ---------- события входа ----------

func test_login_events_once_per_day_while_active() -> void:
	var le := LoginEvents.new(gd, clock)
	var inside := _t(2026, 11, 24, 12)
	assert_array(le.active(inside)).is_equal(["ev_guest_week"])
	assert_array(le.active(_t(2026, 11, 22, 12))).is_empty()
	assert_array(le.active(_t(2026, 12, 8, 12))).is_empty()
	assert_int(le.claim(_ctx(), inside).granted.size()).is_equal(1)
	assert_int(inv.material_count("leather")).is_equal(3)
	assert_int(le.claim(_ctx(), inside + 600.0).granted.size()).is_equal(0)
	assert_int(le.claim(_ctx(), _t(2026, 11, 25, 7)).granted.size()).is_equal(1)  # после сброса снова


func test_login_event_skipped_when_bag_is_full_and_retried() -> void:
	gd.events["ev_guest_week"]["login_reward"] = {"items": {"h_cap": 1}}
	var le := LoginEvents.new(gd, clock)
	while not inv.is_full():
		inv.add_equipment("h_cap")
	var now := _t(2026, 11, 24, 12)
	assert_array(le.claim(_ctx(), now).skipped).is_equal(["ev_guest_week"])
	inv.items.pop_back()
	assert_int(le.claim(_ctx(), now).granted.size()).is_equal(1)


# ---------- единое состояние ----------

func test_tick_notes_daily_and_weekly_resets() -> void:
	var st := DailyState.new(gd)
	assert_bool(st.tick(_t(2026, 11, 24, 12)).daily).is_false()  # первый вызов только запоминает
	assert_int(st.notes.notes.size()).is_equal(0)
	assert_bool(st.tick(_t(2026, 11, 25, 5, 59)).daily).is_false()
	var r := st.tick(_t(2026, 11, 25, 6))  # среда 6:00: и сутки, и неделя
	assert_bool(r.daily).is_true()
	assert_bool(r.weekly).is_true()
	assert_int(st.notes.notes.size()).is_equal(2)
	assert_str(st.notes.notes[0].type).is_equal("daily_reset")
	assert_str(st.notes.notes[1].type).is_equal("weekly_reset")
	var r2 := st.tick(_t(2026, 11, 26, 6))
	assert_bool(r2.daily).is_true()
	assert_bool(r2.weekly).is_false()
	assert_bool(st.tick(_t(2026, 11, 26, 7)).daily).is_false()


func test_events_feed_diary_and_points_weekly_reset_keeps_home_points() -> void:
	var st := DailyState.new(gd)
	var now := _t(2026, 11, 24, 12)
	st.tick(now)
	var r := st.on_event({"type": "quest_turn_in"}, 30, now)
	assert_int(r.xp).is_equal(900)
	assert_array(r["items"]).is_equal(["quest"])
	assert_int(st.points["dungeon"]).is_equal(6)
	assert_int(st.points["home"]).is_equal(4)
	assert_int(st.on_event({"type": "unknown_event"}, 30, now).xp).is_equal(0)
	assert_bool(st.spend("dungeon", 10)).is_false()
	assert_bool(st.spend("dungeon", 6)).is_true()
	st.on_event({"type": "pvp_match"}, 30, now)
	assert_int(st.points["dungeon"]).is_equal(8)
	st.tick(_t(2026, 11, 25, 6))  # неделя сменилась
	assert_int(st.points["dungeon"]).is_equal(0)
	assert_int(st.points["home"]).is_equal(4)
	assert_bool(st.spend("nope", 1)).is_false()
	assert_bool(st.spend("home", -1)).is_false()


func test_login_combines_exploration_events_and_notes() -> void:
	var st := DailyState.new(gd)
	var r := st.login(_ctx(), 30, _t(2026, 11, 24, 12))
	assert_bool(r.exploration.ok).is_true()
	assert_int(r.events.granted.size()).is_equal(1)
	var types := st.notes.notes.map(func(n): return n.type)
	assert_bool(types.has("exploration_reward")).is_true()
	assert_bool(types.has("event_login_reward")).is_true()
	assert_int(st.notes.unread_count()).is_equal(2)
	st.notes.mark_read(st.notes.notes[0].id)
	assert_int(st.notes.unread_count()).is_equal(1)
	st.notes.mark_all_read()
	assert_int(st.notes.unread_count()).is_equal(0)
	assert_bool(st.notes.mark_read(9999)).is_false()
	var r2 := st.login(_ctx(), 30, _t(2026, 11, 24, 13))
	assert_str(r2.exploration.error).is_equal("already_claimed")
	assert_int(r2.events.granted.size()).is_equal(0)


func test_notes_are_limited() -> void:
	var nb := NoteBox.new()
	nb.max_notes = 3
	for i in 5:
		nb.add("x", float(i))
	assert_int(nb.notes.size()).is_equal(3)
	assert_int(int(nb.notes[0].id)).is_equal(3)


func test_save_and_load_roundtrip() -> void:
	var st := DailyState.new(gd)
	st.login(_ctx(), 30, _t(2026, 11, 24, 12))
	st.on_event({"type": "quest_turn_in"}, 30, _t(2026, 11, 24, 12))
	var copy := DailyState.new(gd)
	copy.load_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_int(copy.exploration.steps).is_equal(1)
	assert_int(copy.diary.credited("quest", _t(2026, 11, 24, 13))).is_equal(1)
	assert_int(int(copy.points["dungeon"])).is_equal(6)
	assert_int(copy.notes.notes.size()).is_equal(st.notes.notes.size())
	assert_str(copy.exploration.claim(_ctx(), 30, _t(2026, 11, 24, 14)).error).is_equal("already_claimed")
	assert_int(copy.login_events.claim(_ctx(), _t(2026, 11, 24, 15)).granted.size()).is_equal(0)


# ---------- проверка данных ----------

func test_daily_data_is_valid_and_validation_catches_errors() -> void:
	assert_array(gd.validate()).is_empty()
	var bad := GameData.load_dir()
	bad.rules["time"]["reset_hour"] = 30
	bad.rules["time"]["weekly_reset_weekday"] = 9
	bad.rules["time"]["utc_offset_hours"] = 20
	bad.diary["quest"]["max_times"] = 0
	bad.diary["fish"]["home_points"] = -1
	bad.exploration["calendar"].remove_at(5)
	bad.exploration["calendar"][0]["reward"] = {"items": {"ghost": 1}}
	bad.events["ev_guest_week"]["end"] = 1
	var t := "\n".join(bad.validate())
	for part in ["reset_hour должен", "weekly_reset_weekday должен", "utc_offset_hours вне", "max_times должен", "не может быть отрицательным",
			"календарь должен содержать 31", "нет предмета награды ghost", "конец раньше начала"]:
		assert_bool(t.contains(part)).is_true()
