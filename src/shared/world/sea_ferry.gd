class_name SeaFerry
extends RefCounted

const DOCUMENT := "m07_south"
const HARBOR := "z_harbor"
const OASIS := "z_oasis"


static func destination(zone: String) -> String:
	match zone:
		HARBOR:
			return OASIS
		OASIS:
			return HARBOR
	return ""


static func depart(world: PlayerWorld, log: QuestLog, level: int, now: float) -> Dictionary:
	if world.traveling:
		return {"ok": false, "error": "busy"}
	var port := destination(world.zone_id)
	if port.is_empty():
		return {"ok": false, "error": "wrong_port"}
	if level < world.graph.min_level(OASIS):
		return {"ok": false, "error": "level_too_low"}
	if not log.active.has(DOCUMENT) and not log.completed.has(DOCUMENT):
		return {"ok": false, "error": "no_pass"}
	return world.travel_to(port, level, now)


static func arrive(world: PlayerWorld, log: QuestLog, now: float) -> bool:
	if not world.traveling or world.destination != destination(world.zone_id) or not world.update(now):
		return false
	log.on_event({"type": "visit", "zone": world.zone_id})
	return true
