class_name DialogueRunner
extends RefCounted
## Диалог с NPC. Содержимое (data/dialogues.json) это граф узлов с выборами. Особые выборы:
## offer_quests раскрывается в задания, которые NPC может выдать, turn_in_quests в задания, которые можно сдать.
## Начало разговора засчитывается как событие talk. Текст показывает клиент, решения проверяет сервер.
## Идея подсмотрена у Dialogue Manager (MIT, Nathan Hoad), формат и код свои.

var gd: GameData
var log: QuestLog
var world: PlayerWorld
var npc_id := ""
var node_id := ""
var running := false
var _shown: Array[Dictionary] = []


func _init(p_gd: GameData, p_log: QuestLog, p_world: PlayerWorld) -> void:
	gd = p_gd
	log = p_log
	world = p_world


## ctx: {"inv": Inventory, "squad": Squad, "wallet": Dictionary, "level": int, "now": float}.
func start(p_npc: String, ctx: Dictionary) -> Dictionary:
	world.update(float(ctx["now"]))
	if world.traveling:
		return _fail("busy")
	if not gd.npcs.has(p_npc):
		return _fail("unknown_npc")
	var npc: Dictionary = gd.npcs[p_npc]
	if npc["zone"] != world.zone_id:
		return _fail("wrong_zone")
	npc_id = p_npc
	var dlg: Dictionary = gd.dialogues[str(npc["dialogue"])]
	node_id = str(dlg["start"])
	running = true
	log.on_event({"type": "talk", "npc": npc_id})
	return {"ok": true, "error": "", "view": _render(ctx)}


func choose(index: int, ctx: Dictionary) -> Dictionary:
	if not running:
		return _fail("not_running")
	if index < 0 or index >= _shown.size():
		return _fail("bad_choice")
	var c: Dictionary = _shown[index]
	var out := {"ok": true, "error": "", "view": {}, "accepted": "", "turned_in": "", "rewards": {}, "service": ""}
	var quest_line := ""
	if c.has("accept"):
		var r := log.accept(str(c["accept"]), int(ctx["level"]), float(ctx["now"]))
		if not r.ok:
			return _fail(str(r.error))
		out["accepted"] = c["accept"]
		quest_line = _quest_line(str(c["accept"]), "accepted")
	elif c.has("turn_in"):
		var r := log.turn_in(str(c["turn_in"]), ctx, npc_id)
		if not r.ok:
			return _fail(str(r.error))
		out["turned_in"] = c["turn_in"]
		out["rewards"] = r["rewards"]
		quest_line = _quest_line(str(c["turn_in"]), "completed")
	elif c.has("quest_detail"):
		var qid := str(c["quest_detail"])
		var state := log.state(qid, ctx.get("inv"), int(ctx["level"]), float(ctx["now"]))
		if state not in ["active", "ready"]:
			return _fail("quest_state_changed")
		quest_line = _quest_line(qid, _visible_phase(qid, state))
	else:
		var do: Dictionary = c.get("do", {})
		if do.has("activity"):
			if not _choice_allowed(c, ctx):
				return _fail("quest_state_changed")
			log.on_event({"type": "activity", "target": do["activity"]})
		if do.has("service"):
			out["service"] = do["service"]
		if c.get("end", false):
			running = false
			_shown = []
			return out
		if c.has("next"):
			node_id = str(c["next"])
	out["view"] = _render(ctx)
	if not quest_line.is_empty():
		out["view"]["quest_line"] = quest_line
	return out


func _render(ctx: Dictionary) -> Dictionary:
	var dlg: Dictionary = gd.dialogues[str(gd.npcs[npc_id]["dialogue"])]
	var node: Dictionary = dlg["nodes"][node_id]
	_shown = []
	var level := int(ctx["level"])
	var now := float(ctx["now"])
	for c in node["choices"]:
		if c.get("offer_quests", false):
			for qid in log.available_from(npc_id, level, now):
				_shown.append({"text": "Задание: " + str(gd.quests[qid]["name"]), "accept": qid})
		elif c.get("turn_in_quests", false):
			for qid in log.ready_at(npc_id, ctx.get("inv"), level, now):
				_shown.append({"text": "Сдать: " + str(gd.quests[qid]["name"]), "turn_in": qid})
		elif _choice_allowed(c, ctx):
			_shown.append(c)
	if node_id == str(dlg["start"]):
		for qid in log.active:
			var quest: Dictionary = gd.quests.get(qid, {})
			if npc_id not in [quest.get("giver"), quest.get("turn_in")]:
				continue
			var state := log.state(qid, ctx.get("inv"), level, now)
			if state in ["active", "ready"] and not _quest_line(qid, _visible_phase(qid, state)).is_empty():
				_shown.append({"text": "Обсудить: " + str(quest["name"]), "quest_detail": qid})
	var texts: Array = []
	for i in _shown.size():
		texts.append({"index": i, "text": _shown[i]["text"]})
	return {"npc": npc_id, "text": str(node["text"]), "choices": texts}


func _quest_line(qid: String, phase: String) -> String:
	var quest: Dictionary = gd.quests[qid]
	if phase == "active" and log.uses_legacy_objectives(qid):
		return "\n".join(log.objectives_for(qid).map(func(o): return str(o["text"])))
	return str(quest.get("dialogue", {}).get(phase, ""))


func _visible_phase(qid: String, state: String) -> String:
	if state == "ready" and npc_id != gd.quests[qid]["turn_in"]:
		return "active"
	return state


func _choice_allowed(choice: Dictionary, ctx: Dictionary) -> bool:
	var requirements: Dictionary = choice.get("requires", {})
	if not _allowed(requirements, ctx):
		return false
	var action: Dictionary = choice.get("do", {})
	if action.has("activity"):
		var qid := str(requirements.get("quest", {}).get("id", ""))
		return log.can_perform_activity(qid, str(action["activity"]), ctx.get("inv"), int(ctx["level"]))
	return true


func _allowed(req: Dictionary, ctx: Dictionary) -> bool:
	if req.has("level_min") and int(ctx["level"]) < int(req["level_min"]):
		return false
	if req.has("quest"):
		var rq: Dictionary = req["quest"]
		if log.state(str(rq["id"]), ctx.get("inv"), int(ctx["level"]), float(ctx["now"])) != str(rq["state"]):
			return false
	return true


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
