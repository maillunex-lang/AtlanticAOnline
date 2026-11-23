class_name TombCheckpoint
extends RefCounted
## Offline checkpoint at the tomb's gates, discoveries and completed encounters.

const FIGHTER_FIELDS := ["level", "enabled", "bonus_points", "skill_points", "allocated", "skill_levels",
	"skill_books", "xp", "hero_upgrades", "mercenary_promotions", "specialization"]
const CRAFT_FIELDS := ["skills", "workload", "analyzed_day", "auto_recipe", "auto_elapsed"]


static func capture(main: DemoMain) -> Dictionary:
	var mercs: Array = []
	var rooms := {}
	for merc in main.squad.mercs:
		mercs.append(_fighter(merc))
	for room in main.squad.rooms:
		rooms[room] = _fighter(main.squad.rooms[room])
	return {
		"fishing_xp": main.fishing.xp,
		"will": main.world.will_snapshot(main.now),
		"voyage": {"destination": main.world.destination, "arrive_at": main.world.arrive_at} if main.world.traveling else {},
		"dungeon_cleared_at": main.dungeon_cleared_at.duplicate(),
		"run": main._dungeon_run.snapshot() if main._dungeon_run != null else {},
		"zone": main.world.zone_id, "position": main.map.hero.position, "now": main.now,
		"quests": main.log.to_dict(), "wallet": main.wallet.duplicate(true),
		"bank_coins": main.town_services.bank_coins,
		"hero": _fighter(main.squad.hero), "mercs": mercs, "rooms": rooms,
		"formation": main.formation.duplicate(), "discovered": main.world.discovered.duplicate(),
		"items": main.inv.items.map(_item), "materials": main.inv.materials.duplicate(),
		"item_sequence": main.inv._next_uid, "fighter_sequence": main.squad._next_uid,
		"tutorial_recruit_claimed": main.squad.tutorial_recruit_claimed,
		"crafting": _fields(main.inv.crafting, CRAFT_FIELDS),
	}


static func restore(main: DemoMain, saved: Dictionary) -> void:
	if saved.is_empty() or saved.get("hero", {}).get("def_id") != main.squad.hero.def_id:
		return
	var zone := str(saved.get("zone", ""))
	if not main.map.has_zone_scene(zone):
		return
	main.now = float(saved["now"])
	main.dungeon_cleared_at = saved.get("dungeon_cleared_at", {}).duplicate()
	main.fishing.stop()
	main.fishing.xp = maxi(0, int(saved.get("fishing_xp", 0)))
	main.world.restore_will_snapshot(saved.get("will", {}))
	main.log.load_dict(saved["quests"])
	main.wallet = saved["wallet"].duplicate()
	main.town_services.bank_coins = int(saved.get("bank_coins", 0))
	main.formation = saved["formation"].duplicate()
	main.world.discovered = saved["discovered"].duplicate()
	main.inv.items.clear()
	for entry in saved["items"]:
		main.inv.items.append(_load_item(entry))
	main.inv.materials = saved["materials"].duplicate()
	main.inv._next_uid = int(saved["item_sequence"])
	main.squad._next_uid = int(saved["fighter_sequence"])
	main.squad.tutorial_recruit_claimed = bool(saved["tutorial_recruit_claimed"])
	_apply_fields(main.inv.crafting, saved["crafting"], CRAFT_FIELDS)
	main.squad.hero = _load_fighter(saved["hero"], main.gd)
	main.squad.mercs.clear()
	for entry in saved["mercs"]:
		main.squad.mercs.append(_load_fighter(entry, main.gd))
	main.squad.rooms.clear()
	for room in saved["rooms"]:
		main.squad.rooms[room] = _load_fighter(saved["rooms"][room], main.gd)
	main._dungeon_run = DungeonRun.restore(main.gd, saved["run"])
	var voyage: Dictionary = saved.get("voyage", {})
	var port := str(voyage.get("destination", ""))
	main.world.traveling = not port.is_empty() and port in SeaFerry.ports_from(zone) and main.map.has_zone_scene(port)
	main.world.destination = port if main.world.traveling else ""
	main.world.arrive_at = float(voyage.get("arrive_at", 0.0)) if main.world.traveling else 0.0
	main.map.frozen = main.world.traveling
	main._busy_ui = main.world.traveling
	main.map.arrive_at(saved["position"], zone)


static func _fields(object: Object, keys: Array) -> Dictionary:
	var data := {}
	for key in keys:
		data[key] = object.get(key)
	return data.duplicate(true)


static func _apply_fields(object: Object, data: Dictionary, keys: Array) -> void:
	var copy := data.duplicate(true)
	for key in keys:
		object.set(key, copy[key])


static func _item(item: Item) -> Dictionary:
	return {"uid": item.uid, "def_id": item.def_id, "plus": item.plus, "fail_streak": item.fail_streak, "star_stone": item.star_stone, "seal_opened": item.seal_opened}


static func _load_item(data: Dictionary) -> Item:
	var item := Item.new(int(data["uid"]), str(data["def_id"]))
	item.plus = int(data["plus"])
	item.fail_streak = int(data["fail_streak"])
	item.star_stone = str(data.get("star_stone", ""))
	item.seal_opened = bool(data.get("seal_opened", false))
	return item


static func _fighter(merc: Mercenary) -> Dictionary:
	var data := _fields(merc, FIGHTER_FIELDS)
	data["uid"] = merc.uid
	data["def_id"] = merc.def_id
	data["equipped"] = {}
	for slot in merc.equipped:
		data["equipped"][slot] = _item(merc.equipped[slot])
	return data


static func _load_fighter(data: Dictionary, gd: GameData) -> Mercenary:
	var merc := Mercenary.new(int(data["uid"]), str(data["def_id"]), gd)
	_apply_fields(merc, data, FIGHTER_FIELDS)
	for slot in data["equipped"]:
		var saved_item: Dictionary = data["equipped"][slot]
		var item := _load_item(saved_item)
		if not saved_item.has("seal_opened") and item.has_seal(gd):
			item.seal_opened = true
		merc.equipped[slot] = item
	return merc
