class_name ChatService
extends RefCounted
## Чат: каналы мира, зоны, группы, гильдии и личные сообщения. Ограничения на длину, частоту и повторы,
## заглушка (mute), чёрный список слов, история каналов. Сервер решает, что можно отправить и кому оно уйдёт.

const CHANNELS: Array[String] = ["world", "zone", "party", "guild", "whisper"]

var gd: GameData
var social: SocialGraph
var history: Dictionary = {}
var muted: Dictionary = {}
var _sent: Dictionary = {}
var _last_text: Dictionary = {}
var _last_world: Dictionary = {}
var _next_id := 1


func _init(p_gd: GameData, p_social: SocialGraph) -> void:
	gd = p_gd
	social = p_social


func _rules() -> Dictionary:
	return gd.social["chat"]


## ctx отправителя: {"level": int, "zone": id, "party": id или "", "guild": id или ""}.
## target нужен только для личных сообщений. Возвращает {"ok","error","message","channel_key"}.
func send(sender: String, channel: String, target: String, text: String, now: float, ctx: Dictionary) -> Dictionary:
	if not CHANNELS.has(channel):
		return _fail("bad_channel")
	if float(muted.get(sender, 0.0)) > now:
		return _fail("muted")
	var body := text.strip_edges()
	if body == "":
		return _fail("empty")
	var r := _rules()
	if body.length() > int(r["max_length"]):
		return _fail("too_long")
	var key := ""
	match channel:
		"world":
			if int(ctx["level"]) < int(r["world_min_level"]):
				return _fail("level_too_low")
			if now - float(_last_world.get(sender, -1000000.0)) < float(r["world_cooldown_seconds"]):
				return _fail("world_cooldown")
			key = "world"
		"zone":
			key = "zone:" + str(ctx["zone"])
		"party":
			if str(ctx.get("party", "")) == "":
				return _fail("no_party")
			key = "party:" + str(ctx["party"])
		"guild":
			if str(ctx.get("guild", "")) == "":
				return _fail("no_guild")
			key = "guild:" + str(ctx["guild"])
		"whisper":
			if target == "" or target == sender:
				return _fail("bad_target")
			if social.is_blocked(target, sender):
				return _fail("blocked_by_target")
			if social.is_blocked(sender, target):
				return _fail("you_blocked_target")
			key = "whisper:" + ":".join(PackedStringArray([sender, target]) if sender < target else PackedStringArray([target, sender]))
	var window := float(r["rate_window_seconds"])
	var stamps: Array = _sent.get(sender, [])
	stamps = stamps.filter(func(t): return now - float(t) < window)
	if stamps.size() >= int(r["rate_max_messages"]):
		_sent[sender] = stamps
		return _fail("rate_limited")
	var last: Dictionary = _last_text.get(sender, {})
	if not last.is_empty() and last["text"] == body and now - float(last["time"]) < float(r["duplicate_window_seconds"]):
		return _fail("duplicate")
	stamps.append(now)
	_sent[sender] = stamps
	_last_text[sender] = {"text": body, "time": now}
	if channel == "world":
		_last_world[sender] = now
	var msg := {"id": _next_id, "channel": channel, "from": sender, "to": target, "text": _filter(body), "time": now}
	_next_id += 1
	if not history.has(key):
		history[key] = []
	(history[key] as Array).append(msg)
	while (history[key] as Array).size() > int(r["history_size"]):
		(history[key] as Array).pop_front()
	return {"ok": true, "error": "", "message": msg, "channel_key": key}


func mute(pid: String, until: float) -> void:
	muted[pid] = until


func recent(key: String) -> Array:
	return history.get(key, [])


func _filter(text: String) -> String:
	var out := text
	for w in _rules()["blocklist"]:
		var word := str(w)
		if word == "":
			continue
		var i := out.to_lower().find(word.to_lower())
		while i >= 0:
			out = out.substr(0, i) + str(_rules()["mask"]) + out.substr(i + word.length())
			i = out.to_lower().find(word.to_lower(), i + str(_rules()["mask"]).length())
	return out


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
