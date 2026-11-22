class_name QuestLog
extends RefCounted
## Журнал заданий игрока: принятие, прогресс по событиям, сдача, ежедневные задания.
## Идея структуры (запись квеста, цели, состояние) подсмотрена у Rubonnek/quest-manager (MIT), код написан заново.
##
## Цели: kill (столкновение или "*" для любого), kill_any (одно из списка столкновений), visit (зона), talk (NPC),
## dungeon_clear (подземелье), tbs_clear (миссия тактического боя), escort (доставка спутника к NPC),
## collect (материал в сумке, при сдаче расходуется, если consume), reach_level (уровень героя).
## Прогресс копится по событиям, collect и reach_level считаются по состоянию игрока.
##
## Цепочки (data/chains.json): задание это шаг цепочки. Шаг n доступен после шага n-1, цепочка может требовать другие цепочки
## (`prereq_chains`), сбрасывается по суткам (`reset: daily`, ровно один шаг) или предметом (`reset: item`), за последний шаг
## выдаётся итоговая награда `rewards_final` вместе с наградой шага (одной транзакцией).
## Время передаётся снаружи (now), случайности нет.

var gd: GameData
## id задания -> массив прогресса по целям.
var active: Dictionary = {}
var completed: Dictionary = {}
var daily_done: Dictionary = {}
var daily_accepted: Dictionary = {}
## id цепочки -> сколько раз пройдена целиком (условие `prereq_chains`, история сбросов).
var chains_cleared: Dictionary = {}
## Избранные цепочки для трекера на экране.
var favorites: Array = []


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
	var cid: String = gd.quest_chain.get(qid, "")
	if cid != "":
		var c: Dictionary = gd.chains[cid]
		var idx: int = (c["steps"] as Array).find(qid)
		if idx > 0 and not completed.has(c["steps"][idx - 1]):
			return "prev_step"
		if idx == 0 or idx == -1:
			for pc in c.get("prereq_chains", []):
				if not _chain_cleared(str(pc)):
					return "chain_prereq"
		if level < int(c["level_min"]):
			return "level_too_low"
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
			if not _matches(o, t, e):
				continue
			if int(prog[i]) < int(o["count"]):
				prog[i] = int(prog[i]) + 1
				if not changed.has(qid):
					changed.append(qid)
	return changed


## Подходит ли событие e цели o.
func _matches(o: Dictionary, t: String, e: Dictionary) -> bool:
	var ot := str(o["type"])
	match t:
		"kill":
			if ot == "kill":
				return str(o["target"]) == "*" or str(o["target"]) == str(e.get("encounter", ""))
			if ot == "kill_any":
				return (o["target"] as Array).has(str(e.get("encounter", "")))
		"visit", "dungeon_clear":
			return ot == t and (str(o["target"]) == "*" or str(o["target"]) == str(e.get("zone", "")))
		"talk", "escort":
			return ot == t and str(o["target"]) == str(e.get("npc", ""))
		"tbs_clear":
			return ot == t and str(o["target"]) == str(e.get("mission", ""))
	return false


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
	var rew: Dictionary = q["rewards"].duplicate(true)
	var cid: String = gd.quest_chain.get(qid, "")
	var finishes_chain := false
	if cid != "":
		var c: Dictionary = gd.chains[cid]
		finishes_chain = c["steps"][(c["steps"] as Array).size() - 1] == qid
		if finishes_chain:
			rew = _merge_rewards(rew, c.get("rewards_final", {}))
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
	var res := {"ok": true, "error": "", "rewards": rew}
	if finishes_chain:
		chains_cleared[cid] = int(chains_cleared.get(cid, 0)) + 1
		res["chain_completed"] = cid
	return res


static func _merge_rewards(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	out["xp"] = int(a.get("xp", 0)) + int(b.get("xp", 0))
	out["coins"] = int(a.get("coins", 0)) + int(b.get("coins", 0))
	var items: Dictionary = (out.get("items", {}) as Dictionary).duplicate()
	for id in b.get("items", {}):
		items[id] = int(items.get(id, 0)) + int(b["items"][id])
	if not items.is_empty():
		out["items"] = items
	return out


# ---------- цепочки ----------

## Цепочка пройдена хотя бы раз (счётчик сохраняется при сбросе) либо все шаги сданы сейчас.
func _chain_cleared(cid: String) -> bool:
	if int(chains_cleared.get(cid, 0)) > 0:
		return true
	for step in gd.chains[cid]["steps"]:
		if not completed.has(step):
			return false
	return true


func chain_of(qid: String) -> String:
	return str(gd.quest_chain.get(qid, ""))


## Индекс текущего шага цепочки: первый шаг, который не сдан. Равен числу шагов, если цепочка пройдена.
func chain_step(cid: String, now: float) -> int:
	var c: Dictionary = gd.chains.get(cid, {})
	if c.is_empty():
		return -1
	var steps: Array = c["steps"]
	for i in steps.size():
		if str(c.get("reset", "none")) == "daily":
			if int(daily_done.get(steps[i], -1)) != day_of(now):
				return i
		elif not completed.has(steps[i]):
			return i
	return steps.size()


## "none" (не начата), "active" (идёт), "done" (пройдена, пока не сброшена).
func chain_state(cid: String, now: float) -> String:
	var c: Dictionary = gd.chains.get(cid, {})
	if c.is_empty():
		return "none"
	var idx := chain_step(cid, now)
	var n: int = (c["steps"] as Array).size()
	if idx >= n:
		return "done"
	if idx > 0:
		return "active"
	return "active" if active.has(c["steps"][0]) else "none"


## Сброс цепочки предметом (reset: item): предмет расходуется, прогресс шагов стирается, взятые шаги отменяются.
func reset_chain(cid: String, inv: Inventory, now: float) -> Dictionary:
	var c: Dictionary = gd.chains.get(cid, {})
	if c.is_empty():
		return {"ok": false, "error": "unknown_chain"}
	if str(c.get("reset", "none")) != "item":
		return {"ok": false, "error": "not_resettable"}
	if chain_state(cid, now) != "done":
		return {"ok": false, "error": "not_done"}
	if not inv.take_material(str(c["reset_item"]), 1):
		return {"ok": false, "error": "no_item"}
	for step in c["steps"]:
		completed.erase(step)
		active.erase(step)
	return {"ok": true, "error": ""}


## Дистанционное взятие: без NPC, если цепочка разрешает и герой достиг порога уровня.
func accept_remote(qid: String, level: int, now: float) -> Dictionary:
	var err := _remote_error(qid, level)
	if err != "":
		return {"ok": false, "error": err}
	return accept(qid, level, now)


## Дистанционная сдача: без NPC, если цепочка разрешает и герой достиг порога уровня.
func turn_in_remote(qid: String, ctx: Dictionary) -> Dictionary:
	var err := _remote_error(qid, int(ctx["level"]))
	if err != "":
		return {"ok": false, "error": err}
	return turn_in(qid, ctx, "")


func _remote_error(qid: String, level: int) -> String:
	if not gd.quests.has(qid):
		return "unknown_quest"
	var cid := chain_of(qid)
	if cid != "" and not bool(gd.chains[cid].get("remote", false)):
		return "remote_not_allowed"
	if level < int(gd.rules["quests"]["remote_min_level"]):
		return "remote_level"
	return ""


## Зона, куда нужно идти по заданию: цель первой невыполненной цели, либо NPC сдачи, если всё выполнено.
## Пустая строка, если места нет (сбор материалов, уровень, любое столкновение).
func objective_zone(qid: String, inv: Inventory, hero_level: int) -> String:
	if not active.has(qid):
		return ""
	var q: Dictionary = gd.quests[qid]
	if objectives_done(qid, inv, hero_level):
		return str(gd.npcs[q["turn_in"]]["zone"])
	var objs: Array = q["objectives"]
	for i in objs.size():
		var o: Dictionary = objs[i]
		if objective_count(qid, i, inv, hero_level) >= int(o["count"]):
			continue
		match str(o["type"]):
			"kill":
				if gd.encounters.has(str(o["target"])):
					return str(gd.encounters[o["target"]]["zone"])
			"kill_any":
				return str(gd.encounters[(o["target"] as Array)[0]]["zone"])
			"visit", "dungeon_clear":
				return str(o["target"])
			"talk", "escort":
				return str(gd.npcs[o["target"]]["zone"])
		return ""
	return ""


# ---------- журнал, избранное, трекер ----------

## Записи журнала. filter: {"category": "main", "state": "active"} (любой ключ необязателен).
## Запись: {id, name, category, region, state, step, steps, level_min, favorite, reset}.
func journal(filter: Dictionary, level: int, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cid in gd.chains:
		var c: Dictionary = gd.chains[cid]
		if filter.has("category") and str(c["category"]) != str(filter["category"]):
			continue
		var st := chain_state(cid, now)
		if st == "none" and (level < int(c["level_min"])):
			continue
		if filter.has("state") and st != str(filter["state"]):
			continue
		out.append({"id": cid, "name": c["name"], "category": c["category"], "region": c.get("region", ""), "state": st,
			"step": chain_step(cid, now), "steps": (c["steps"] as Array).size(), "level_min": int(c["level_min"]),
			"favorite": favorites.has(cid), "reset": str(c.get("reset", "none"))})
	return out


func toggle_favorite(cid: String) -> Dictionary:
	if not gd.chains.has(cid):
		return {"ok": false, "error": "unknown_chain"}
	if favorites.has(cid):
		favorites.erase(cid)
		return {"ok": true, "error": "", "favorite": false}
	if favorites.size() >= int(gd.rules["quests"]["max_favorites"]):
		return {"ok": false, "error": "too_many_favorites"}
	favorites.append(cid)
	return {"ok": true, "error": "", "favorite": true}


## Трекер для экрана: активные шаги избранных цепочек. Запись: {chain, quest, name, state, objectives: [{text, count, need}], zone}.
func tracker(inv: Inventory, hero_level: int, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cid in favorites:
		var c: Dictionary = gd.chains[cid]
		for step in c["steps"]:
			if not active.has(step):
				continue
			var objs: Array = []
			for i in (gd.quests[step]["objectives"] as Array).size():
				var o: Dictionary = gd.quests[step]["objectives"][i]
				objs.append({"text": o["text"], "count": objective_count(step, i, inv, hero_level), "need": int(o["count"])})
			out.append({"chain": cid, "quest": step, "name": gd.quests[step]["name"], "state": state(step, inv, hero_level, now),
				"objectives": objs, "zone": objective_zone(step, inv, hero_level)})
	return out


# ---------- сохранение ----------

func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "completed": completed.duplicate(), "daily_done": daily_done.duplicate(),
		"daily_accepted": daily_accepted.duplicate(), "chains_cleared": chains_cleared.duplicate(), "favorites": favorites.duplicate()}


func load_dict(d: Dictionary) -> void:
	active = (d.get("active", {}) as Dictionary).duplicate(true)
	completed = (d.get("completed", {}) as Dictionary).duplicate()
	daily_done = (d.get("daily_done", {}) as Dictionary).duplicate()
	daily_accepted = (d.get("daily_accepted", {}) as Dictionary).duplicate()
	chains_cleared = (d.get("chains_cleared", {}) as Dictionary).duplicate()
	favorites = (d.get("favorites", []) as Array).duplicate()
