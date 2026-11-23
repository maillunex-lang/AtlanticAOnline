class_name SeaFerry
extends RefCounted

const DOCUMENT := "m07_south"
const HARBOR := "z_harbor"
const OASIS := "z_oasis"
const SLUICE := "z_sluice_town"
const COVE := "z_copper_cove"
const NORTH := "z_north_quay"
const EXPEDITION_COMPLETE := "q_sa_expedition_end"
const CHARTER := "q_se_sluice_charter"

const PORT_CONTACTS := {
	HARBOR: "npc_orvin", OASIS: "npc_yara",
	SLUICE: "npc_sluice_dara", COVE: "npc_cove_ines", NORTH: "npc_north_elva",
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
		NORTH:
			return COVE
	return ""


static func ports_from(zone: String) -> Array[String]:
	if zone == COVE:
		return [SLUICE, NORTH]
	var other := destination(zone)
	return [] if other.is_empty() else [other]


static func is_northern_route(from: String, to: String) -> bool:
	return (from == NORTH and to == COVE) or (from == COVE and to == NORTH)


static func depart(world: PlayerWorld, log: QuestLog, level: int, now: float, requested := "") -> Dictionary:
	if world.traveling:
		return {"ok": false, "error": "busy"}
	var port := destination(world.zone_id) if requested.is_empty() else requested
	if port not in ports_from(world.zone_id):
		return {"ok": false, "error": "wrong_port"}
	if level < required_level(world, world.zone_id, port):
		return {"ok": false, "error": "level_too_low"}
	if is_northern_route(world.zone_id, port):
		if not log.completed.has(EXPEDITION_COMPLETE):
			return {"ok": false, "error": "no_pass"}
	elif is_expedition_port(world.zone_id):
		if not log.completed.has(CHARTER):
			return {"ok": false, "error": "no_pass"}
	elif not log.active.has(DOCUMENT) and not log.completed.has(DOCUMENT):
		return {"ok": false, "error": "no_pass"}
	return world.travel_to(port, level, now)


static func arrive(world: PlayerWorld, log: QuestLog, now: float) -> bool:
	if not world.traveling or world.destination not in ports_from(world.zone_id) or not world.update(now):
		return false
	world.discovered[world.zone_id] = true
	log.on_event({"type": "visit", "zone": world.zone_id})
	return true


static func is_expedition_port(zone: String) -> bool:
	return zone in [SLUICE, COVE]


static func required_level(world: PlayerWorld, zone: String, port := "") -> int:
	if zone == NORTH or port == NORTH:
		return world.graph.min_level(NORTH)
	return world.graph.min_level(COVE if is_expedition_port(zone) else OASIS)


static func contact_toward(world: PlayerWorld, target_zone: String) -> String:
	var path: Array = world.graph.shortest_path(world.zone_id, target_zone)["path"]
	for i in range(path.size() - 1):
		var port: String = path[i]
		if path[i + 1] in ports_from(port):
			return str(PORT_CONTACTS.get(port, ""))
	return ""
