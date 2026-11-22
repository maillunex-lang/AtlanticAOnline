class_name GameData
extends RefCounted
## Загрузка и проверка игровых данных из data/*.json.

var weapons: Dictionary = {}
var skills: Dictionary = {}
var mercs: Dictionary = {}
var rules: Dictionary = {}
var items: Dictionary = {}
var recipes: Array = []
var loot: Array = []
var monsters: Dictionary = {}
var encounters: Dictionary = {}
var world: Dictionary = {}


static func load_dir(path := "res://data") -> GameData:
	var gd := GameData.new()
	for w in _read(path + "/weapons.json"):
		gd.weapons[str(w["id"])] = w
	for s in _read(path + "/skills.json"):
		var sd := SkillDef.from_dict(s)
		gd.skills[sd.id] = sd
	for m in _read(path + "/mercenaries.json"):
		var md := MercenaryDef.from_dict(m)
		gd.mercs[md.id] = md
	gd.rules = _read(path + "/progression.json")
	for i in _read(path + "/items.json"):
		var idef := ItemDef.from_dict(i)
		gd.items[idef.id] = idef
	gd.recipes = _read(path + "/recipes.json")
	gd.loot = _read(path + "/loot.json")
	for m in _read(path + "/monsters.json"):
		gd.monsters[str(m["id"])] = m
	for e in _read(path + "/encounters.json"):
		gd.encounters[str(e["id"])] = e
	gd.world = _read(path + "/world.json")
	return gd


## Список ошибок данных. Пустой список означает, что данные согласованы.
func validate() -> Array[String]:
	var errs: Array[String] = []
	var max_skills := int(rules.get("max_skills", 5))
	for id in skills:
		var s: SkillDef = skills[id]
		if not WeaponType.is_valid(s.weapon):
			errs.append("skill %s: неизвестное оружие %s" % [id, s.weapon])
		if s.target < 0 or s.effect < 0:
			errs.append("skill %s: неверная цель или эффект" % id)
		if s.effect == SkillDef.Effect.MODIFY and (s.mod_stat == "" or s.mod_turns <= 0):
			errs.append("skill %s: модификатор без стата или срока" % id)
	for id in mercs:
		var m: MercenaryDef = mercs[id]
		if not WeaponType.is_valid(m.weapon):
			errs.append("merc %s: неизвестное оружие %s" % [id, m.weapon])
		if m.skill_ids.is_empty() or m.skill_ids.size() > max_skills:
			errs.append("merc %s: число навыков %d вне 1..%d" % [id, m.skill_ids.size(), max_skills])
		for sid in m.skill_ids:
			if not skills.has(sid):
				errs.append("merc %s: нет навыка %s" % [id, sid])
			elif (skills[sid] as SkillDef).weapon != m.weapon:
				errs.append("merc %s: навык %s от другого оружия" % [id, sid])
		if m.upgrades_to != "" and not mercs.has(m.upgrades_to):
			errs.append("merc %s: нет цели улучшения %s" % [id, m.upgrades_to])
		if not ["basic", "advanced", "elite", "hero"].has(m.tier):
			errs.append("merc %s: неизвестная ступень %s" % [id, m.tier])
	for p in rules.get("packs", []):
		for tier in p["pool"]:
			for mid in p["pool"][tier]:
				if not mercs.has(mid):
					errs.append("pack %s: нет наёмника %s" % [p["id"], mid])
	errs.append_array(_validate_items())
	errs.append_array(_validate_world())
	return errs


func _validate_items() -> Array[String]:
	var errs: Array[String] = []
	var e: Dictionary = rules["enhance"]
	for k in ["chance", "coins", "stones"]:
		if (e[k] as Array).size() != int(e["max_plus"]):
			errs.append("enhance.%s: длина не равна max_plus" % k)
	for slot in rules["equip_slots"]:
		if not ItemDef.SLOTS.has(slot):
			errs.append("неизвестный слот %s" % slot)
	for id in items:
		var it: ItemDef = items[id]
		if it.is_equip():
			if not ItemDef.SLOTS.has(it.slot):
				errs.append("item %s: неизвестный слот %s" % [id, it.slot])
			if it.slot == "weapon" and not WeaponType.is_valid(it.weapon):
				errs.append("item %s: у оружия нет типа" % id)
			if it.stats.is_empty():
				errs.append("item %s: нет статов" % id)
		elif it.kind != "material":
			errs.append("item %s: неизвестный вид %s" % [id, it.kind])
	for r in recipes:
		if not items.has(r["output"]) or not (items[r["output"]] as ItemDef).is_equip():
			errs.append("recipe %s: неверный результат" % r["id"])
		for m in r["materials"]:
			if not items.has(m) or (items[m] as ItemDef).kind != "material":
				errs.append("recipe %s: неверный материал %s" % [r["id"], m])
	for t in loot:
		for en in t["entries"]:
			if en["item"] != "" and not items.has(en["item"]):
				errs.append("loot %s: нет предмета %s" % [t["id"], en["item"]])
	return errs


func _validate_world() -> Array[String]:
	var errs: Array[String] = []
	var ids := {}
	for c in world["continents"]:
		ids[c["id"]] = true
	var zone_ids := {}
	for z in world["zones"]:
		zone_ids[z["id"]] = z
		if not ids.has(z["continent"]):
			errs.append("zone %s: неизвестный континент" % z["id"])
		if not ["town", "field", "dungeon"].has(z["type"]):
			errs.append("zone %s: неизвестный тип %s" % [z["id"], z["type"]])
		if z["type"] == "dungeon":
			var cfg: Dictionary = z.get("dungeon", {})
			if cfg.is_empty():
				errs.append("zone %s: нет описания подземелья" % z["id"])
			else:
				if not items.has(cfg["key"]):
					errs.append("zone %s: нет предмета-ключа %s" % [z["id"], cfg["key"]])
				for st in cfg["stages"]:
					if not encounters.has(st) or encounters[st]["zone"] != z["id"]:
						errs.append("zone %s: неверный этап %s" % [z["id"], st])
				if LootTable.find(self, cfg["reward_loot"]).is_empty():
					errs.append("zone %s: нет таблицы награды %s" % [z["id"], cfg["reward_loot"]])
	if not zone_ids.has(world["start_zone"]) or zone_ids[world["start_zone"]]["type"] != "town":
		errs.append("стартовая зона должна быть городом")
	for e in world["edges"]:
		if not zone_ids.has(e["a"]) or not zone_ids.has(e["b"]):
			errs.append("путь %s-%s ведёт в несуществующую зону" % [e["a"], e["b"]])
		if float(e["seconds"]) <= 0.0:
			errs.append("путь %s-%s: время должно быть больше 0" % [e["a"], e["b"]])
	for id in encounters:
		var en: Dictionary = encounters[id]
		if not zone_ids.has(en["zone"]):
			errs.append("encounter %s: нет зоны %s" % [id, en["zone"]])
		elif zone_ids[en["zone"]]["type"] == "town":
			errs.append("encounter %s: в городе нет врагов" % id)
		if (en["enemies"] as Array).is_empty() or (en["enemies"] as Array).size() > BattleRules.SLOTS_PER_SIDE:
			errs.append("encounter %s: число врагов вне 1..9" % id)
		var slots := {}
		for m in en["enemies"]:
			if not monsters.has(m["monster"]):
				errs.append("encounter %s: нет монстра %s" % [id, m["monster"]])
			if slots.has(m["slot"]) or int(m["slot"]) < 0 or int(m["slot"]) >= BattleRules.SLOTS_PER_SIDE:
				errs.append("encounter %s: неверный или повторный слот %s" % [id, m["slot"]])
			slots[m["slot"]] = true
		if LootTable.find(self, en["loot"]).is_empty():
			errs.append("encounter %s: нет таблицы добычи %s" % [id, en["loot"]])
	return errs


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Нет файла данных: " + path)
		return null
	return JSON.parse_string(f.get_as_text())
