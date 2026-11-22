class_name QuestLog
extends RefCounted
## Журнал заданий игрока: принятие, прогресс по событиям, сдача, ежедневные задания.
## Идея структуры (запись квеста, цели, состояние) подсмотрена у Rubonnek/quest-manager (MIT), код написан заново.
##
## Цели: kill (столкновение или "*" для любого), visit (зона), talk (NPC), dungeon_clear (подземелье),
## collect (материал в сумке, при сдаче расходуется, если consume), reach_level (уровень героя).
## Прогресс kill/visit/talk/dungeon_clear копится по событиям, collect и reach_level считаются по состоянию игрока.

var gd: GameData
## id задания -> массив прогресса по целям.
var active: Dictionary = {}
var completed: Dictionary = {}
var daily_done: Dictionary = {}
var daily_accepted: Dictionary = {}


func _init(p_gd: GameData) -> void:
	gd = p_gd


func day_of(now: float) -> int:
	return int(floor(now / float(gd.rules["quests"]["day_seconds"])))


func completed_ids() -> Array:
	return completed.keys()


func has(qid: String) -> bool:
	return gd.quests.has(qid)


## Сколько выполнено по цели i, не больше требуемого.
func objective_count(qid: String, i: int, inv: Inventory, hero_level: int) -> int:
	var o: Dictionary = (gd.quests[qid]["objectives"] as Array)[i]
	var need := int(o["count"])
	match str(o["type"]):
		"collect":
			return mini(inv.material_count(str(o["target"])) if inv != null else 0, need)
		"reach_level":
			return mini(hero_level, need)
		_:
			var prog: Array = active[qid]
			return mini(int(prog[i]), need)


func objectives_done(qid: String, inv: Inventory, hero_level: int) -> bool:
	var objs: Array = gd.quests[qid]["objectives"]
	for i in objs.size():
		if objective_count(qid, i, inv, hero_level) < int((objs[i] as Dictionary)["count"]):
			return false
	return true


## "none", "active", "ready" (можно сдавать) или "done".
func state(qid: String, inv: Inventory, hero_level: int, now: float) -> String:
	var q: Dictionary = gd.quests.get(qid, {})
	if q.is_empty():
		return "none"
	if q["kind"] == "daily":
		if int(daily_done.get(qid, -1)) == day_of(now) and not active.has(qid):
			return "done"
	elif completed.has(qid):
		return "done"
	if active.has(qid):
		return "ready" if objectives_done(qid, inv, hero_level) else "active"
	return "none"


## "" если задание можно взять, иначе код ошибки.
func availability(qid: String, level: int, now: float) -> String:
	var q: Dictionary = gd.quests.get(qid, {})
	if q.is_empty():
		return "unknown_quest"
	if active.has(qid):
		return "already_active"
	if q["kind"] == "daily":
		if int(daily_done.get(qid, -1)) == day_of(now):
			return "already_done"
	elif completed.has(qid):
		return "already_done"
	if level < int(q["level_min"]):
		return "level_too_low"
	for pre in q.get("prereq", []):
		if not completed.has(pre):
			return "prereq"
	if active.size() >= int(gd.rules["quests"]["max_active"]):
		return "too_many_active"
	if q["kind"] == "daily" and not daily_accepted_today(qid, now) and daily_accepted_count(now) >= int(gd.rules["quests"]["max_daily"]):
		return "daily_limit"
	return ""


func daily_accepted_today(qid: String, now: float) -> bool:
	return int(daily_accepted.get(qid, -1)) == day_of(now)


func daily_accepted_count(now: float) -> int:
	var n := 0
	for k in daily_accepted:
		if int(daily_accepted[k]) == day_of(now):
			n += 1
	return n


func accept(qid: String, level: int, now: float) -> Dictionary:
	var err := availability(qid, level, now)
	if err != "":
		return {"ok": false, "error": err}
	var q: Dictionary = gd.quests[qid]
	var prog: Array = []
	for o in q["objectives"]:
		prog.append(0)
	active[qid] = prog
	if q["kind"] == "daily":
		daily_accepted[qid] = day_of(now)
	return {"ok": true, "error": ""}


func abandon(qid: String) -> bool:
	return active.erase(qid)


## Событие игры. Возвращает id заданий, у которых изменился прогресс.
## События: {"type":"kill","encounter":id}, {"type":"visit","zone":id}, {"type":"talk","npc":id},
## {"type":"dungeon_clear","zone":id}.
func on_event(e: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	var t := str(e.get("type", ""))
	for qid in active:
		var objs: Array = gd.quests[qid]["objectives"]
		var prog: Array = active[qid]
		for i in objs.size():
			var o: Dictionary = objs[i]
			if str(o["type"]) != t:
				continue
			var key := "encounter" if t == "kill" else ("npc" if t == "talk" else "zone")
			var target := str(o["target"])
			if target != "*" and target != str(e.get(key, "")):
				continue
			if int(prog[i]) < int(o["count"]):
				prog[i] = int(prog[i]) + 1
				if not changed.has(qid):
					changed.append(qid)
	return changed


## Задания, которые NPC может выдать сейчас.
func available_from(npc_id: String, level: int, now: float) -> Array[String]:
	var out: Array[String] = []
	for qid in gd.quests:
		if gd.quests[qid]["giver"] == npc_id and availability(qid, level, now) == "":
			out.append(qid)
	return out


## Выполненные задания, которые можно сдать этому NPC.
func ready_at(npc_id: String, inv: Inventory, hero_level: int, now: float) -> Array[String]:
	var out: Array[String] = []
	for qid in active:
		if gd.quests[qid]["turn_in"] == npc_id and state(qid, inv, hero_level, now) == "ready":
			out.append(qid)
	return out


## Сдать задание. ctx: {"inv": Inventory, "squad": Squad, "wallet": Dictionary, "level": int, "now": float}.
## Если указан npc_id, сдача возможна только ему. Награда выдаётся целиком или не выдаётся совсем.
func turn_in(qid: String, ctx: Dictionary, npc_id := "") -> Dictionary:
	var inv: Inventory = ctx["inv"]
	var level := int(ctx["level"])
	var now := float(ctx["now"])
	if not active.has(qid):
		return {"ok": false, "error": "not_active"}
	var q: Dictionary = gd.quests[qid]
	if npc_id != "" and q["turn_in"] != npc_id:
		return {"ok": false, "error": "wrong_npc"}
	if not objectives_done(qid, inv, level):
		return {"ok": false, "error": "not_done"}
	var rew: Dictionary = q["rewards"]
	var need_slots := 0
	for id in rew.get("items", {}):
		if (gd.items[id] as ItemDef).is_equip():
			need_slots += int(rew["items"][id])
	if inv.items.size() + need_slots > inv.capacity():
		return {"ok": false, "error": "inventory_full"}
	for o in q["objectives"]:
		if o["type"] == "collect" and bool(o.get("consume", true)):
			inv.take_material(str(o["target"]), int(o["count"]))
	var wallet: Dictionary = ctx["wallet"]
	wallet["coins"] = int(wallet.get("coins", 0)) + int(rew.get("coins", 0))
	var drops: Array = []
	for id in rew.get("items", {}):
		drops.append({"item": id, "count": int(rew["items"][id])})
	inv.add_drops(drops)
	if ctx.get("squad") != null and int(rew.get("xp", 0)) > 0:
		(ctx["squad"] as Squad).award_battle_xp(int(rew["xp"]))
	active.erase(qid)
	if q["kind"] == "daily":
		daily_done[qid] = day_of(now)
	else:
		completed[qid] = true
	return {"ok": true, "error": "", "rewards": rew}
