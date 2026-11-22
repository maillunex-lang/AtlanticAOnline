class_name SeaFerry
extends RefCounted

const DOCUMENT := "m07_south"
const HARBOR := "z_harbor"
const OASIS := "z_oasis"
const SLUICE := "z_sluice_town"
const COVE := "z_copper_cove"
const CHARTER := "q_se_sluice_charter"

const PORT_CONTACTS := {
	HARBOR: "npc_orvin", OASIS: "npc_yara",
	SLUICE: "npc_sluice_dara", COVE: "npc_cove_ines",
}


static func destination(zone: String) -> String:
	match zone:
		HARBOR:
			return OASIS
		OASIS:
			return HARBOR
		SLUICE:
			return COVE
		COVE:
			return SLUICE
	return ""


static func depart(world: PlayerWorld, log: QuestLog, level: int, now: float) -> Dictionary:
	if world.traveling:
		return {"ok": false, "error": "busy"}
	var port := destination(world.zone_id)
	if port.is_empty():
		return {"ok": false, "error": "wrong_port"}
	if level < required_level(world, world.zone_id):
		return {"ok": false, "error": "level_too_low"}
	if is_expedition_port(world.zone_id):
		if not log.completed.has(CHARTER):
			return {"ok": false, "error": "no_pass"}
	elif not log.active.has(DOCUMENT) and not log.completed.has(DOCUMENT):
		return {"ok": false, "error": "no_pass"}
	return world.travel_to(port, level, now)


static func arrive(world: PlayerWorld, log: QuestLog, now: float) -> bool:
	if not world.traveling or world.destination != destination(world.zone_id) or not world.update(now):
		return false
	world.discovered[world.zone_id] = true
	log.on_event({"type": "visit", "zone": world.zone_id})
	return true


static func is_expedition_port(zone: String) -> bool:
	return zone in [SLUICE, COVE]


static func required_level(world: PlayerWorld, zone: String) -> int:
	return world.graph.min_level(COVE if is_expedition_port(zone) else OASIS)


static func contact_toward(world: PlayerWorld, target_zone: String) -> String:
	var path: Array = world.graph.shortest_path(world.zone_id, target_zone)["path"]
	for i in range(path.size() - 1):
		var port: String = path[i]
		if destination(port) == path[i + 1]:
			return str(PORT_CONTACTS.get(port, ""))
	return ""
