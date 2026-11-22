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


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Нет файла данных: " + path)
		return null
	return JSON.parse_string(f.get_as_text())
