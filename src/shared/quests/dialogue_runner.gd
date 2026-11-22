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
	if c.has("accept"):
		var r := log.accept(str(c["accept"]), int(ctx["level"]), float(ctx["now"]))
		if not r.ok:
			return _fail(str(r.error))
		out["accepted"] = c["accept"]
	elif c.has("turn_in"):
		var r := log.turn_in(str(c["turn_in"]), ctx, npc_id)
		if not r.ok:
			return _fail(str(r.error))
		out["turned_in"] = c["turn_in"]
		out["rewards"] = r["rewards"]
	else:
		var do: Dictionary = c.get("do", {})
		if do.has("service"):
			out["service"] = do["service"]
		if c.get("end", false):
			running = false
			_shown = []
			return out
		if c.has("next"):
			node_id = str(c["next"])
	out["view"] = _render(ctx)
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
		elif _allowed(c.get("requires", {}), ctx):
			_shown.append(c)
	var texts: Array = []
	for i in _shown.size():
		texts.append({"index": i, "text": _shown[i]["text"]})
	return {"npc": npc_id, "text": str(node["text"]), "choices": texts}


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
