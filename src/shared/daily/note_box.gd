class_name NoteBox
extends RefCounted
## «Заметки»: уведомления игроку (сброс суток, недельный сброс, награда за вход и т.д.).
## Запись: {id, type, time, read, params}. Текст по типу и параметрам собирает клиент (локализация позже).

var notes: Array[Dictionary] = []
var max_notes := 50
var _next_id := 1


func add(type: String, now: float, params: Dictionary = {}) -> int:
	var id := _next_id
	_next_id += 1
	notes.append({"id": id, "type": type, "time": now, "read": false, "params": params})
	while notes.size() > max_notes:
		notes.remove_at(0)
	return id


func unread_count() -> int:
	var n := 0
	for note in notes:
		if not bool(note["read"]):
			n += 1
	return n


func mark_read(id: int) -> bool:
	for note in notes:
		if int(note["id"]) == id:
			note["read"] = true
			return true
	return false


func mark_all_read() -> void:
	for note in notes:
		note["read"] = true


func to_dict() -> Dictionary:
	return {"notes": notes.duplicate(true), "next_id": _next_id}


func load_dict(d: Dictionary) -> void:
	notes.clear()
	for n in d.get("notes", []):
		notes.append((n as Dictionary).duplicate(true))
	_next_id = int(d.get("next_id", notes.size() + 1))
