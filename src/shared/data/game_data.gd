class_name GameData
extends RefCounted
## Загрузка и проверка игровых данных из data/*.json.

var weapons: Dictionary = {}
var skills: Dictionary = {}
var mercs: Dictionary = {}
## Классы героя (data/classes.json): id -> описание; для включённых классов в mercs лежит тип героя `hero_<id>`.
var classes: Dictionary = {}
var class_order: Array[String] = []
var rules: Dictionary = {}
var items: Dictionary = {}
var equipment_sets: Dictionary = {}
var equipment_catalog_errors: Array[String] = []
var recipes: Array = []
var life_skills: Dictionary = {}
var loot: Array = []
var monsters: Dictionary = {}
var encounters: Dictionary = {}
var town_services: Dictionary = {}
var tactical_missions: Dictionary = {}
var world: Dictionary = {}
## Манифест чанков мира (data/chunks.json), генерируется tools/gen_world.gd из tools/world_layout.json.
var chunk_manifest: Dictionary = {}
## Регионы мира (data/regions.json): id -> описание; части мира и порядок регионов.
var regions: Dictionary = {}
var parts: Dictionary = {}
var region_order: Array[String] = []
var start_region := ""
var npcs: Dictionary = {}
var dialogues: Dictionary = {}
var quests: Dictionary = {}
## Суточные системы: дневник (id -> дело), ежедневное исследование, события с наградой за вход (id -> событие).
var diary: Dictionary = {}
## Таблицы опыта (data/xp_tables.json): имя -> массив «опыт до следующего уровня».
var xp_tables: Dictionary = {}
var exploration: Dictionary = {}
var events: Dictionary = {}
## Цепочки заданий (data/chains.json): id -> описание, и обратный индекс шаг -> цепочка.
var chains: Dictionary = {}
var quest_chain: Dictionary = {}
var social: Dictionary = {}


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
	if FileAccess.file_exists(path + "/classes.json"):
		var cl: Array = (_read(path + "/classes.json") as Dictionary)["classes"]
		cl.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
		for c in cl:
			gd.classes[str(c["id"])] = c
			gd.class_order.append(str(c["id"]))
			if bool(c["enabled"]):
				var sk: Dictionary = c["skills"]
				var d := {"id": "hero_" + str(c["id"]), "name": c["name"], "weapon": c["weapon"], "tier": "hero", "hp": c["hp"], "atk": c["atk"],
					"def": c["def"], "ap_regen": c["ap_regen"], "growth_x10": c["growth_x10"], "squad_limit": 1,
					"skills": (sk["base"] as Array) + (sk["slot4"] as Array) + (sk["spec"] as Array)}
				if c.has("attributes"):
					d["attributes"] = c["attributes"]
				var md := MercenaryDef.from_dict(d)
				gd.mercs[md.id] = md
	gd.rules = _read(path + "/progression.json")
	for i in _read(path + "/items.json"):
		var idef := ItemDef.from_dict(i)
		gd.items[idef.id] = idef
	gd.recipes = _read(path + "/recipes.json")
	if FileAccess.file_exists(path + "/life_skills.json"):
		gd.life_skills = _read(path + "/life_skills.json")
	gd.loot = _read(path + "/loot.json")
	var equipment_path := path + "/equipment_sets.json"
	if FileAccess.file_exists(equipment_path):
		EquipmentCatalog.load_into(gd, _read(equipment_path))
	for m in _read(path + "/monsters.json"):
		gd.monsters[str(m["id"])] = m
	for e in _read(path + "/encounters.json"):
		gd.encounters[str(e["id"])] = e
	var missions_path := path + "/tactical_missions.json"
	if FileAccess.file_exists(missions_path):
		for mission in _read(missions_path):
			gd.tactical_missions[str(mission["id"])] = mission
	gd.world = _read(path + "/world.json")
	if FileAccess.file_exists(path + "/town_services.json"):
		gd.town_services = _read(path + "/town_services.json")
	if FileAccess.file_exists(path + "/chunks.json"):
		gd.chunk_manifest = _read(path + "/chunks.json")
	var reg_path := path + "/regions.json"
	if FileAccess.file_exists(reg_path):
		var rd: Dictionary = _read(reg_path)
		gd.start_region = str(rd.get("start_region", ""))
		for part in rd["parts"]:
			gd.parts[str(part["id"])] = part
		var sorted_regions: Array = (rd["regions"] as Array).duplicate()
		sorted_regions.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
		for r in sorted_regions:
			gd.regions[str(r["id"])] = r
			gd.region_order.append(str(r["id"]))
	for n in _read(path + "/npcs.json"):
		gd.npcs[str(n["id"])] = n
	for d in _read(path + "/dialogues.json"):
		gd.dialogues[str(d["id"])] = d
	for q in _read(path + "/quests.json"):
		gd.quests[str(q["id"])] = q
	if FileAccess.file_exists(path + "/xp_tables.json"):
		gd.xp_tables = (_read(path + "/xp_tables.json") as Dictionary)["tables"]
	var diary_path := path + "/diary.json"
	if FileAccess.file_exists(diary_path):
		for it in _read(diary_path):
			gd.diary[str(it["id"])] = it
	if FileAccess.file_exists(path + "/exploration.json"):
		gd.exploration = _read(path + "/exploration.json")
	if FileAccess.file_exists(path + "/events.json"):
		for e in _read(path + "/events.json"):
			gd.events[str(e["id"])] = e
	var chains_path := path + "/chains.json"
	if FileAccess.file_exists(chains_path):
		for c in _read(chains_path):
			gd.chains[str(c["id"])] = c
			for step in c["steps"]:
				gd.quest_chain[str(step)] = str(c["id"])
	gd.social = _read(path + "/social.json")
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
		if (s.effect == SkillDef.Effect.REVIVE) != (s.target == SkillDef.Target.ALLY_DEAD):
			errs.append("skill %s: несовместимая цель воскрешения" % id)
		if s.combo_from != "" and (not skills.has(s.combo_from) or s.combo_from == id or s.combo_bonus_pct <= 0 or not s.targets_enemies() or s.effect != SkillDef.Effect.DAMAGE):
			errs.append("skill %s: неверная связка навыков" % id)
		if s.effect == SkillDef.Effect.MODIFY and not s.passive and (s.mod_stat == "" or s.mod_turns <= 0):
			errs.append("skill %s: модификатор без стата или срока" % id)
		errs.append_array(_validate_skill_extras(s))
	for id in mercs:
		var m: MercenaryDef = mercs[id]
		if not WeaponType.is_valid(m.weapon):
			errs.append("merc %s: неизвестное оружие %s" % [id, m.weapon])
		if m.rank != "" and (m.tier == "hero" or not MercenaryDef.RANK_XP_TABLE.has(m.rank)):
			errs.append("merc %s: неверный ранг %s" % [id, m.rank])
		if m.skill_ids.is_empty() or (m.skill_ids.size() > max_skills and m.tier != "hero"):
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
	var previous_promotion := 0
	for stage: Dictionary in rules.get("promotions", []):
		var level := int(stage.get("level", 0))
		var material: ItemDef = items.get(stage.get("material", ""))
		if level <= previous_promotion or int(stage.get("count", 0)) <= 0 or int(stage.get("growth_pct", 0)) <= 0:
			errs.append("promotions: неверный порог %d" % level)
		if material == null or material.kind != "material":
			errs.append("promotions: нет материала для порога %d" % level)
		previous_promotion = level
	if int(rules.get("promotion_high_rank_extra", 0)) < 0:
		errs.append("promotions: отрицательная доплата ранга")
	for p in rules.get("packs", []):
		for tier in p["pool"]:
			for mid in p["pool"][tier]:
				if not mercs.has(mid):
					errs.append("pack %s: нет наёмника %s" % [p["id"], mid])
	var formation: Dictionary = rules.get("formation", {})
	var rooms := int(formation.get("rooms", 0))
	var battle_rooms := int(formation.get("battle_rooms", 0))
	if rooms < 0 or battle_rooms < 0 or battle_rooms > rooms or int(formation.get("pve_swaps", 0)) < 0:
		errs.append("formation: неверные лимиты резерва")
	for guard_id in formation.get("starter_guards", []):
		var guard: MercenaryDef = mercs.get(guard_id)
		if guard == null or guard.tier == "hero" or guard.level_cap <= 0:
			errs.append("formation: неверный страж %s" % guard_id)
	var battle_loot: Dictionary = rules.get("battle_loot", {})
	if not battle_loot.is_empty():
		if battle_loot["body_turns"] <= 0 or battle_loot["lucky_turns"] <= 0 or battle_loot["search_cost"] < 0 or battle_loot["jackpot_threshold"] <= 0:
			errs.append("battle_loot: неверная длительность, цена обыска или порог джекпота")
		if not items.has(battle_loot["lucky_item"]):
			errs.append("battle_loot: неизвестный предмет счастливой добычи")
		for item_id in battle_loot["jackpot_items"]:
			var item: ItemDef = items.get(item_id)
			if item == null or item.kind != "material":
				errs.append("battle_loot: неверный материал джекпота %s" % item_id)
	errs.append_array(_validate_items())
	errs.append_array(_validate_world())
	errs.append_array(_validate_town_services())
	errs.append_array(_validate_tactics())
	errs.append_array(_validate_life_skills())
	errs.append_array(_validate_quests())
	errs.append_array(_validate_social())
	return errs


func _validate_items() -> Array[String]:
	var errs: Array[String] = equipment_catalog_errors.duplicate()
	var craft: Dictionary = rules.get("crafting", {})
	if int(craft.get("max_level", 0)) <= 0 or float(craft.get("tick_seconds", 0)) <= 0 \
			or int(craft.get("max_workload", 0)) <= 0 or int(craft.get("battle_workload", -1)) < 0:
		errs.append("crafting: неверные лимиты или интервал")
	var titles: Array = craft.get("titles", [])
	if titles.is_empty() or int(titles[0].get("level", 0)) != 1:
		errs.append("crafting: нет начальной ступени умения")
	var last_title := 0
	for title: Dictionary in titles:
		var level := int(title.get("level", 0))
		if level <= last_title or level > int(craft.get("max_level", 0)) or str(title.get("name", "")).is_empty():
			errs.append("crafting: неверная ступень %d" % level)
		last_title = level
	var e: Dictionary = rules["enhance"]
	if int(e["normal_max_plus"]) < 1 or int(e["normal_max_plus"]) > int(e["max_plus"]):
		errs.append("enhance.normal_max_plus: неверный предел")
	for k in ["chance", "coins", "stones"]:
		if (e[k] as Array).size() != int(e["max_plus"]):
			errs.append("enhance.%s: длина не равна max_plus" % k)
	for slot in rules["equip_slots"]:
		if not ItemDef.SLOTS.has(slot):
			errs.append("неизвестный слот %s" % slot)
	var set_slots := {}
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
		if it.star_rank != 0:
			if it.kind != "material" or it.star_rank < 1 or it.star_rank > 5 or it.stats.is_empty():
				errs.append("item %s: неверный звёздный камень" % id)
			for stat in it.stats:
				if stat not in ["atk", "def", "hp"] or int(it.stats[stat]) <= 0:
					errs.append("item %s: неверный бонус звёздного камня %s" % [id, stat])
		if it.set_id != "":
			if not it.is_equip() or not equipment_sets.has(it.set_id):
				errs.append("item %s: неизвестный комплект %s" % [id, it.set_id])
				continue
			if it.level_req != int(equipment_sets[it.set_id]["level"]):
				errs.append("item %s: уровень отличается от комплекта" % id)
			if not set_slots.has(it.set_id):
				set_slots[it.set_id] = {}
			set_slots[it.set_id][it.slot] = true
	for id in equipment_sets:
		var equipment_set: Dictionary = equipment_sets[id]
		if int(equipment_set["level"]) <= 0:
			errs.append("equipment set %s: неверный уровень" % id)
		if (set_slots.get(id, {}) as Dictionary).size() != int(equipment_set["pieces"]):
			errs.append("equipment set %s: число слотов не совпадает с комплектом" % id)
		for threshold in equipment_set["bonuses"]:
			if int(threshold) < 2 or int(threshold) > int(equipment_set["pieces"]):
				errs.append("equipment set %s: неверный порог бонуса" % id)
		var source := str(equipment_set["source_loot"])
		if source != "" and LootTable.find(self, source).is_empty():
			errs.append("equipment set %s: неизвестная таблица добычи %s" % [id, source])
	var recipe_ids := {}
	for r in recipes:
		if recipe_ids.has(r["id"]):
			errs.append("recipe %s: повтор идентификатора" % r["id"])
		recipe_ids[r["id"]] = true
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


## Регион зоны (пустая строка, если зоны нет).
## Тип героя класса (`hero_<id>`); пустая строка, если класс выключен или неизвестен.
func hero_def_id(class_id: String) -> String:
	var id := "hero_" + class_id
	return id if classes.has(class_id) and mercs.has(id) else ""


## Первый включённый класс для оружия (так работает `Squad.create_hero("sword")`).
func default_class_for_weapon(weapon: String) -> String:
	for id in class_order:
		if bool(classes[id]["enabled"]) and classes[id]["weapon"] == weapon:
			return id
	return ""


## "" если класс можно выбрать при создании героя, иначе код: unknown, disabled (ждёт оружия или навыков), region_locked (стартовый регион ещё не открыт).
func class_status(class_id: String) -> String:
	if not classes.has(class_id):
		return "unknown"
	if not bool(classes[class_id]["enabled"]):
		return "disabled"
	var reg := str(classes[class_id]["start_region"])
	if regions.has(reg) and regions[reg]["status"] != "active":
		return "region_locked"
	return ""


## Регион, в котором игрок с этим героем может стартовать (для создания героя).
func region_of_zone(zone_id: String) -> String:
	for z in world["zones"]:
		if z["id"] == zone_id:
			return str(z.get("region", ""))
	return ""


## Города и форпосты: зоны с бюро путешествий (в них можно телепортироваться, в них нет врагов).
static func is_settlement(zone_type: String) -> bool:
	return zone_type == "town" or zone_type == "outpost"


func _validate_regions() -> Array[String]:
	var errs: Array[String] = []
	if regions.size() != 13:
		errs.append("regions: должно быть 13 регионов, найдено %d" % regions.size())
	if not regions.has(start_region):
		errs.append("regions: нет стартового региона %s" % start_region)
	var orders := {}
	var counts := {}
	for id in regions:
		var r: Dictionary = regions[id]
		if not parts.has(r["part"]):
			errs.append("region %s: неизвестная часть %s" % [id, r["part"]])
		if orders.has(int(r["order"])):
			errs.append("region %s: порядок %d уже занят" % [id, int(r["order"])])
		orders[int(r["order"])] = true
		var band: Array = r["level_band"]
		if band.size() != 2 or int(band[0]) > int(band[1]) or int(band[0]) < 1:
			errs.append("region %s: неверная полоса уровней" % id)
		if not ["active", "planned"].has(str(r["status"])):
			errs.append("region %s: неизвестный статус %s" % [id, r["status"]])
		var pos: Array = r.get("map_pos", [])
		if pos.size() != 2 or int(pos[0]) < 0 or int(pos[0]) > 1000 or int(pos[1]) < 0 or int(pos[1]) > 1000:
			errs.append("region %s: map_pos должен быть в пределах 0..1000" % id)
		counts[id] = {"town": 0, "zones": 0}
	for z in world["zones"]:
		var rid := str(z.get("region", ""))
		if not regions.has(rid):
			errs.append("zone %s: неизвестный регион %s" % [z["id"], rid])
			continue
		counts[rid]["zones"] += 1
		if is_settlement(str(z["type"])):
			counts[rid]["town"] += 1
		var band: Array = regions[rid]["level_band"]
		var capital_access := is_settlement(str(z["type"])) and bool(z.get("capital", false)) \
			and int(z["min_level"]) == int(rules["world"]["capital_free_level"])
		if not capital_access and (int(z["min_level"]) < int(band[0]) or int(z["min_level"]) > int(band[1])):
			errs.append("zone %s: уровень %d вне полосы региона %s" % [z["id"], int(z["min_level"]), rid])
	for id in regions:
		var active: bool = regions[id]["status"] == "active"
		if active and counts[id]["town"] == 0:
			errs.append("region %s: активному региону нужен хотя бы один город" % id)
		if not active and counts[id]["zones"] > 0:
			errs.append("region %s: в плановом регионе есть зоны, измените статус на active" % id)
	var zone_by_id := {}
	for z in world["zones"]:
		zone_by_id[z["id"]] = z
	if zone_by_id.has(world["start_zone"]) and str(zone_by_id[world["start_zone"]].get("region", "")) != start_region:
		errs.append("regions: стартовая зона не в стартовом регионе")
	# Связность: из стартового города достижимы все зоны (уровни не учитываются).
	var g := WorldGraph.new(world)
	var reach := g.reachable(g.start_zone)
	for z in world["zones"]:
		if not reach.has(str(z["id"])):
			errs.append("zone %s: недостижима из стартового города" % z["id"])
	# Переходы между регионами обязаны быть явными (море или портал).
	for e in world["edges"]:
		if zone_by_id.has(e["a"]) and zone_by_id.has(e["b"]):
			var cross: bool = zone_by_id[e["a"]].get("region", "") != zone_by_id[e["b"]].get("region", "")
			var kind := str(e.get("kind", "path"))
			if cross and not ["sea", "portal"].has(kind):
				errs.append("путь %s-%s между регионами должен иметь kind sea или portal" % [e["a"], e["b"]])
			if not cross and kind != "path":
				errs.append("путь %s-%s внутри региона должен иметь kind path" % [e["a"], e["b"]])
	return errs


func _validate_world() -> Array[String]:
	var errs: Array[String] = []
	var zone_ids := {}
	for z in world["zones"]:
		zone_ids[z["id"]] = z
		if not ["town", "outpost", "field", "dungeon"].has(z["type"]):
			errs.append("zone %s: неизвестный тип %s" % [z["id"], z["type"]])
		if z["type"] == "dungeon":
			var cfg: Dictionary = z.get("dungeon", {})
			if cfg.is_empty():
				errs.append("zone %s: нет описания подземелья" % z["id"])
			else:
				if not items.has(cfg["key"]):
					errs.append("zone %s: нет предмета-ключа %s" % [z["id"], cfg["key"]])
				if cfg.has("replay"):
					var replay: Dictionary = cfg["replay"]
					if int(replay.get("coins", 0)) <= 0 or int(replay.get("cooldown_seconds", 0)) <= 0:
						errs.append("zone %s: некорректные правила повторного входа" % z["id"])
				for st in cfg["stages"]:
					if not encounters.has(st) or encounters[st]["zone"] != z["id"]:
						errs.append("zone %s: неверный этап %s" % [z["id"], st])
				if LootTable.find(self, cfg["reward_loot"]).is_empty():
					errs.append("zone %s: нет таблицы награды %s" % [z["id"], cfg["reward_loot"]])
	errs.append_array(_validate_regions())
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
		elif is_settlement(str(zone_ids[en["zone"]]["type"])):
			errs.append("encounter %s: в городе нет врагов" % id)
		var groups := EncounterFactory.groups(en)
		if groups.size() > int(rules.get("pve", {}).get("max_groups", 3)):
			errs.append("encounter %s: слишком много групп" % id)
		for group in groups:
			if group.is_empty() or group.size() > BattleRules.SLOTS_PER_SIDE:
				errs.append("encounter %s: число врагов в группе вне 1..9" % id)
			var slots := {}
			for m in group:
				if not monsters.has(m["monster"]):
					errs.append("encounter %s: нет монстра %s" % [id, m["monster"]])
				var slot := int(m["slot"])
				if slots.has(slot) or slot < 0 or slot >= BattleRules.SLOTS_PER_SIDE:
					errs.append("encounter %s: неверный или повторный слот %s" % [id, m["slot"]])
				slots[slot] = true
		if LootTable.find(self, en["loot"]).is_empty():
			errs.append("encounter %s: нет таблицы добычи %s" % [id, en["loot"]])
	return errs


func _validate_tactics() -> Array[String]:
	var errors: Array[String] = []
	for id in tactical_missions:
		var mission: Dictionary = tactical_missions[id]
		var field := Rect2i(Vector2i.ZERO, Vector2i(int(mission.get("width", 0)), int(mission.get("height", 0))))
		if not field.has_area() or int(mission.get("round_limit", 0)) <= 0:
			errors.append("tactics %s: неверные размеры или лимит раундов" % id)
		var occupied := {}
		for wall in mission.get("blocked", []):
			if not _tactics_point_valid(wall, field):
				errors.append("tactics %s: препятствие вне поля" % id)
			else:
				occupied[TacticalBattle.cell(wall)] = true
		var abilities: Dictionary = mission.get("abilities", {})
		for ability in abilities.values():
			if int(ability.get("area", 0)) not in [5, 7] or int(ability.get("range", 0)) <= 0 or int(ability.get("power_pct", 0)) <= 0 or int(ability.get("mp", -1)) < 0 or int(ability.get("cooldown", -1)) < 0:
				errors.append("tactics %s: неверный навык" % id)
		var enemy_ids := {}
		var unit_ids := {}
		var allies := 0
		for unit in mission.get("units", []):
			var unit_id := int(unit.get("id", 0))
			var allied: bool = unit.has("mercenary")
			if unit_ids.has(unit_id) or unit_id <= 0 or int(unit.get("move", 0)) <= 0 or int(unit.get("range", 0)) <= 0 or int(unit.get("hp", 0)) <= 0:
				errors.append("tactics %s: неверные параметры бойца %d" % [id, unit_id])
			unit_ids[unit_id] = true
			if allied:
				allies += 1
				if not mercs.has(unit["mercenary"]) or unit.has("monster"):
					errors.append("tactics %s: неизвестный союзник" % id)
			else:
				enemy_ids[unit_id] = true
				if not monsters.has(unit.get("monster", "")):
					errors.append("tactics %s: неизвестный враг" % id)
			if not _tactics_point_valid(unit.get("cell"), field) or occupied.has(TacticalBattle.cell(unit["cell"])):
				errors.append("tactics %s: занятая или недопустимая клетка бойца" % id)
			else:
				occupied[TacticalBattle.cell(unit["cell"])] = true
			if unit.has("ability") and not abilities.has(unit["ability"]):
				errors.append("tactics %s: не найден навык бойца" % id)
		if allies == 0 or enemy_ids.is_empty():
			errors.append("tactics %s: пустая сторона" % id)
		for goal in mission.get("objectives", []):
			match goal.get("type", ""):
				"defeat":
					if not enemy_ids.has(int(goal.get("unit", 0))):
						errors.append("tactics %s: цель не ссылается на врага" % id)
				"occupy":
					if not _tactics_point_valid(goal.get("cell"), field) or goal["cell"] in mission.get("blocked", []):
						errors.append("tactics %s: неверная клетка цели" % id)
				_:
					errors.append("tactics %s: неизвестная цель" % id)
	return errors


func _tactics_point_valid(point: Variant, field: Rect2i) -> bool:
	return point is Array and point.size() == 2 and field.has_point(TacticalBattle.cell(point))


func _validate_life_skills() -> Array[String]:
	var errors: Array[String] = []
	if life_skills.is_empty():
		return errors
	var fishing: Dictionary = life_skills.get("fishing", {})
	var cooking: Dictionary = life_skills.get("cooking", {})
	var spots: Dictionary = fishing.get("spots", {})
	var bait := str(fishing.get("bait", ""))
	var ingredient := str(cooking.get("ingredient", ""))
	var ration := str(cooking.get("output", ""))
	if int(life_skills.get("version", 0)) != 1 or not _is_town_material(bait) or spots.is_empty() \
			or int(fishing.get("xp_per_rank", 0)) <= 0 or float(fishing.get("min_seconds", 0)) <= 0 \
			or float(fishing.get("seconds_saved_per_rank", -1)) < 0:
		errors.append("life_skills: неверные правила рыбалки")
	for id in spots:
		var spot: Dictionary = spots[id]
		if not npcs.has(id) or not _is_town_material(str(spot.get("catch", ""))) or spot.get("catch") == bait \
				or int(spot.get("count", 0)) <= 0 or int(spot.get("xp", 0)) <= 0 or float(spot.get("seconds", 0)) <= 0:
			errors.append("life_skills: неверная точка рыбалки %s" % id)
	if not _is_town_material(ingredient) or not _is_town_material(ration) or ingredient == ration \
			or int(cooking.get("ingredient_count", 0)) <= 0 or int(cooking.get("will", 0)) <= 0:
		errors.append("life_skills: неверный рецепт пайка")
	return errors


func _validate_town_services() -> Array[String]:
	var errors: Array[String] = []
	if town_services.is_empty():
		return errors
	var catalog: Dictionary = town_services["services"]
	for service_list in town_services["profiles"].values():
		for id in service_list:
			if not catalog.has(id):
				errors.append("town_services: неизвестная служба %s" % id)
	for districts in town_services["districts"].values():
		for district in districts:
			for id in district["services"]:
				if not catalog.has(id):
					errors.append("town_services: неизвестная служба района %s" % id)
	for row in catalog["shop"]["stock"]:
		if not _is_town_material(str(row["item"])) or int(row["count"]) <= 0 or int(row["coins"]) < 0:
			errors.append("town_services: неверное предложение магазина")
	for row in catalog["exchange"]["rates"]:
		if not _is_town_material(str(row["from"])) or not _is_town_material(str(row["to"])) or row["from"] == row["to"] or int(row["count"]) <= 0 or int(row["reward"]) <= 0:
			errors.append("town_services: неверный обмен")
	for id in catalog["recruiter"]["offers"]:
		if not mercs.has(id) or mercs[id].recruit_coins <= 0:
			errors.append("town_services: неверный наёмник %s" % id)
	if int(catalog["bank"]["lot"]) <= 0:
		errors.append("town_services: неверный размер операции банка")
	for dialogue in dialogues.values():
		for node in dialogue["nodes"].values():
			for choice in node["choices"]:
				var service: String = choice.get("do", {}).get("service", "")
				if service != "" and not catalog.has(service):
					errors.append("town_services: неизвестная служба диалога %s" % service)
	return errors


func _is_town_material(id: String) -> bool:
	return items.has(id) and (items[id] as ItemDef).kind == "material"


func _validate_quests() -> Array[String]:
	var errs: Array[String] = []
	var zone_by_id := {}
	for z in world["zones"]:
		zone_by_id[z["id"]] = z
	for id in npcs:
		var n: Dictionary = npcs[id]
		if not zone_by_id.has(n["zone"]):
			errs.append("npc %s: нет зоны %s" % [id, n["zone"]])
			continue
		var z: Dictionary = zone_by_id[n["zone"]]
		if not is_settlement(str(z["type"])) and z["type"] != "field" and not (z["type"] == "dungeon" and n.get("kind") == "mechanism" and n["roles"].is_empty()):
			errs.append("npc %s: зона не поддерживает NPC" % id)
		for r in n["roles"]:
			if r != "quest" and not (z.get("services", []) as Array).has(r):
				errs.append("npc %s: в зоне %s нет службы %s" % [id, n["zone"], r])
		if not dialogues.has(n["dialogue"]):
			errs.append("npc %s: нет диалога %s" % [id, n["dialogue"]])
	for id in dialogues:
		var d: Dictionary = dialogues[id]
		if not (d["nodes"] as Dictionary).has(d["start"]):
			errs.append("dialogue %s: нет стартового узла" % id)
		for nid in d["nodes"]:
			for c in d["nodes"][nid]["choices"]:
				if c.has("next") and not (d["nodes"] as Dictionary).has(c["next"]):
					errs.append("dialogue %s: узел %s ведёт в несуществующий %s" % [id, nid, c["next"]])
				var required_quest: String = c.get("requires", {}).get("quest", {}).get("id", "")
				if required_quest != "" and not quests.has(required_quest):
					errs.append("dialogue %s: нет квеста %s" % [id, required_quest])
				var activity: String = c.get("do", {}).get("activity", "")
				if activity != "" and not quests.get(required_quest, {}).get("objectives", []).any(
						func(o): return o["type"] == "activity" and o["target"] == activity):
					errs.append("dialogue %s: действие %s не связано с целью квеста" % [id, activity])
	for id in quests:
		var q: Dictionary = quests[id]
		if q.has("dialogue"):
			if not q["dialogue"] is Dictionary:
				errs.append("quest %s: dialogue должен быть объектом" % id)
			else:
				for phase in ["accepted", "active", "ready", "completed"]:
					var line: Variant = q["dialogue"].get(phase)
					if not line is String or line.strip_edges().is_empty():
						errs.append("quest %s: отсутствует реплика %s" % [id, phase])
		for k in ["giver", "turn_in"]:
			if not npcs.has(q[k]):
				errs.append("quest %s: нет NPC %s" % [id, q[k]])
		for pre in q.get("prereq", []):
			if not quests.has(pre):
				errs.append("quest %s: нет предшествующего %s" % [id, pre])
		if (q["objectives"] as Array).is_empty():
			errs.append("quest %s: нет целей" % id)
		for o in q["objectives"] + q.get("legacy_objectives", []):
			var t := str(o["target"]) if not o["target"] is Array else ""
			match str(o["type"]):
				"kill":
					if t != "*" and not encounters.has(t):
						errs.append("quest %s: нет столкновения %s" % [id, t])
				"kill_any", "quest_drop":
					if not o["target"] is Array or (o["target"] as Array).is_empty():
						errs.append("quest %s: %s требует список столкновений" % [id, o["type"]])
					else:
						for e in o["target"]:
							if not encounters.has(str(e)):
								errs.append("quest %s: нет столкновения %s" % [id, e])
					if o["type"] == "quest_drop" and (str(o.get("item_name", "")).strip_edges().is_empty() or int(o["count"]) < 1):
						errs.append("quest %s: у трофея нужны название и количество" % id)
				"tbs_clear":
					if not tactical_missions.has(t):
						errs.append("quest %s: нет миссии %s" % [id, t])
				"escort":
					if not npcs.has(t):
						errs.append("quest %s: нет NPC %s" % [id, t])
				"visit", "dungeon_clear":
					if not zone_by_id.has(t):
						errs.append("quest %s: нет зоны %s" % [id, t])
				"talk":
					if not npcs.has(t):
						errs.append("quest %s: нет NPC %s" % [id, t])
				"collect":
					if not items.has(t):
						errs.append("quest %s: нет предмета %s" % [id, t])
				"activity":
					var parts := t.split("@")
					var valid := t in ["equip", "formation", "recruit", "key_ruins", "map_route", "cargo_manifest", "signal_test", "se_water_mark", "se_echo_survey", "se_echo_seal",
						"se_market_bridge", "se_market_weights", "se_market_purchase",
						"se_dock_ledger", "se_dock_post", "se_river_gauge", "se_sluice_winch", "sa_fog_stake", "sa_pass_cargo", "sa_terrace_gauge"]
					if parts.size() == 2:
						valid = parts[0] in ["guard", "move", "ranged", "area", "support", "control"] and zone_by_id.has(parts[1])
					if not valid or int(o["count"]) < 1:
						errs.append("quest %s: неизвестное действие %s" % [id, t])
				"reach_level":
					pass
				_:
					errs.append("quest %s: неизвестный тип цели %s" % [id, o["type"]])
		for iid in q["rewards"].get("items", {}):
			if not items.has(iid):
				errs.append("quest %s: нет предмета награды %s" % [id, iid])
	errs.append_array(_validate_chunks())
	errs.append_array(_validate_chains())
	errs.append_array(_validate_daily())
	errs.append_array(_validate_xp())
	errs.append_array(_validate_classes())
	for id in mercs:
		var m: MercenaryDef = mercs[id]
		if m.recruit_quest != "" and not quests.has(m.recruit_quest):
			errs.append("merc %s: нет квеста найма %s" % [id, m.recruit_quest])
	return errs


## Чанки мира: манифест, зоны чанков, размеры зон, связность зон, старт героя.
func _validate_chunks() -> Array[String]:
	var errs: Array[String] = []
	if chunk_manifest.is_empty():
		return errs
	var grid := ChunkGrid.from_rules(rules)
	errs.append_array(ChunkManifest.validate(chunk_manifest, grid))
	var zone_by_id := {}
	for z in world["zones"]:
		zone_by_id[z["id"]] = z
	var by_zone := {}
	for c in chunk_manifest["chunks"]:
		var zid := str(c["zone"])
		if not zone_by_id.has(zid):
			errs.append("chunks: зона %s чанка (%d, %d) не описана в world.json" % [zid, int(c["x"]), int(c["y"])])
			continue
		if not by_zone.has(zid):
			by_zone[zid] = []
		(by_zone[zid] as Array).append(Vector2i(int(c["x"]), int(c["y"])))
	for zid in by_zone:
		var list: Array = by_zone[zid]
		var t := str(zone_by_id[zid]["type"])
		var limit := 4 if is_settlement(t) else 16
		if t != "dungeon" and list.size() > limit:
			errs.append("chunks: зона %s занимает %d чанков, максимум %d для типа %s" % [zid, list.size(), limit, t])
		var reach := {list[0]: true}
		var stack: Array = [list[0]]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if list.has(nb) and not reach.has(nb):
					reach[nb] = true
					stack.append(nb)
		if reach.size() != list.size():
			errs.append("chunks: чанки зоны %s не связаны между собой" % zid)
		if not zone_by_id[zid].has("region"):
			errs.append("chunks: у зоны %s нет региона" % zid)
	for id in chunk_manifest.get("zones", {}):
		if not by_zone.has(id):
			errs.append("chunks: у зоны %s из manifest.zones нет чанков" % id)
	var st: Array = chunk_manifest["start"]
	var start_chunk := grid.coord_of(Vector2(float(st[0]), float(st[1])) * grid.tile_px)
	var found := false
	for c in chunk_manifest["chunks"]:
		if Vector2i(int(c["x"]), int(c["y"])) == start_chunk:
			found = str(c["zone"]) == str(world["start_zone"])
	if not found:
		errs.append("chunks: старт героя должен лежать в чанке стартовой зоны")
	return errs


func _validate_daily() -> Array[String]:
	var errs: Array[String] = []
	var t: Dictionary = rules.get("time", {})
	if int(t.get("reset_hour", -1)) < 0 or int(t.get("reset_hour", 24)) > 23:
		errs.append("time: reset_hour должен быть 0..23")
	if int(t.get("weekly_reset_weekday", 0)) < 1 or int(t.get("weekly_reset_weekday", 8)) > 7:
		errs.append("time: weekly_reset_weekday должен быть 1..7")
	if absi(int(t.get("utc_offset_hours", 99))) > 14:
		errs.append("time: utc_offset_hours вне -14..14")
	for id in diary:
		var it: Dictionary = diary[id]
		if int(it["max_times"]) < 1:
			errs.append("diary %s: max_times должен быть больше 0" % id)
		for k in ["bonus_xp_per_level", "dungeon_points", "home_points", "min_level"]:
			if int(it[k]) < 0:
				errs.append("diary %s: %s не может быть отрицательным" % [id, k])
	var cal: Array = exploration.get("calendar", [])
	if exploration.is_empty() or cal.size() != 31:
		errs.append("exploration: календарь должен содержать 31 день")
	for i in cal.size():
		if int(cal[i]["day"]) != i + 1:
			errs.append("exploration: день %d стоит не на своём месте" % int(cal[i]["day"]))
		errs.append_array(_check_reward("exploration день %d" % (i + 1), cal[i]["reward"]))
	for key in exploration.get("monthly", {}):
		if (exploration["monthly"][key] as Array).size() != 31:
			errs.append("exploration: календарь месяца %s должен содержать 31 день" % key)
	errs.append_array(_check_reward("exploration month_prize", exploration.get("month_prize", {})))
	for id in events:
		var e: Dictionary = events[id]
		if float(e["end"]) <= float(e["start"]):
			errs.append("event %s: конец раньше начала" % id)
		errs.append_array(_check_reward("event %s" % id, e["login_reward"]))
	return errs


## Классы героя: 13 штук по ролям (5 ближних, 6 дальних, 2 посоха), группы, стартовые регионы, оружие и навыки включённых.
func _validate_classes() -> Array[String]:
	var errs: Array[String] = []
	if classes.is_empty():
		return errs
	var roles := {"melee": 0, "ranged": 0, "staff": 0}
	var orders := {}
	var bonus_keys := {"hp_pct": 10, "atk_pct": 10, "def_pct": 10, "ap_regen": 10}
	for id in classes:
		var c: Dictionary = classes[id]
		if not roles.has(c["role"]):
			errs.append("class %s: неизвестная роль %s" % [id, c["role"]])
		else:
			roles[c["role"]] += 1
		if not ["scion", "atlantian", "hero"].has(c["group"]):
			errs.append("class %s: неизвестная группа %s" % [id, c["group"]])
		if orders.has(int(c["order"])):
			errs.append("class %s: порядок %d уже занят" % [id, int(c["order"])])
		orders[int(c["order"])] = true
		if not regions.has(str(c["start_region"])):
			errs.append("class %s: нет стартового региона %s" % [id, c["start_region"]])
		for k in c["squad_bonus"]:
			if not bonus_keys.has(k):
				errs.append("class %s: неизвестный бонус отряду %s" % [id, k])
			elif int(c["squad_bonus"][k]) < 0 or int(c["squad_bonus"][k]) > int(bonus_keys[k]):
				errs.append("class %s: бонус %s вне 0..%d" % [id, k, int(bonus_keys[k])])
		if not bool(c["enabled"]):
			continue
		if not weapons.has(c["weapon"]):
			errs.append("class %s: нет оружия %s (класс включён)" % [id, c["weapon"]])
			continue
		var sk: Dictionary = c["skills"]
		var base: Array = sk["base"]
		if base.is_empty() or base.size() > 40:
			errs.append("class %s: пул свободных навыков героя 1-40, найдено %d" % [id, base.size()])
		for pool in ["base", "slot4", "spec"]:
			for sid in sk[pool]:
				if not skills.has(sid):
					errs.append("class %s: нет навыка %s" % [id, sid])
				elif (skills[sid] as SkillDef).weapon != c["weapon"]:
					errs.append("class %s: навык %s другого оружия" % [id, sid])
		var seen := {}
		for pool in ["base", "slot4", "spec"]:
			for sid in sk[pool]:
				if seen.has(sid):
					errs.append("class %s: навык %s повторяется в пулах" % [id, sid])
				seen[sid] = true
		if not mercs.has("hero_" + str(id)):
			errs.append("class %s: нет типа героя" % id)
	if roles["melee"] != 5 or roles["ranged"] != 6 or roles["staff"] != 2:
		errs.append("classes: ожидается 5 ближних, 6 дальних и 2 посоха, найдено %s" % str(roles))
	if classes.size() != 13:
		errs.append("classes: должно быть 13 классов, найдено %d" % classes.size())
	return errs


const SKILL_STATS := ["atk", "def", "magic_def", "hp", "crit", "crit_resist", "accuracy", "evasion", "ap_regen", "intelligence", "strength", "dexterity"]


## Проверка расширений навыка (WP-47): пассивки, многократные удары, пробитие, вампиризм, статусы.
func _validate_skill_extras(s: SkillDef) -> Array[String]:
	var errs: Array[String] = []
	if s.passive:
		if s.passive_mods.is_empty():
			errs.append("skill %s: пассивка без бонусов" % s.id)
		if s.cost_ap != 0 or s.cost_mp != 0 or s.cooldown != 0:
			errs.append("skill %s: пассивка не имеет цены и перезарядки" % s.id)
		for m in s.passive_mods:
			if not SKILL_STATS.has(str(m.get("stat", ""))):
				errs.append("skill %s: неизвестный стат пассивки %s" % [s.id, m.get("stat", "")])
			elif int(m.get("value", 0)) <= 0 or int(m.get("value", 0)) > 30:
				errs.append("skill %s: бонус пассивки вне 1..30" % s.id)
	elif s.mod_stat != "" and not SKILL_STATS.has(s.mod_stat):
		errs.append("skill %s: неизвестный стат модификатора %s" % [s.id, s.mod_stat])
	if s.hits < 1 or s.hits > 5 or (s.hits > 1 and s.effect != SkillDef.Effect.DAMAGE):
		errs.append("skill %s: число ударов %d" % [s.id, s.hits])
	if s.hits * s.power_pct > 400:
		errs.append("skill %s: суммарная сила %d выше 400%%" % [s.id, s.hits * s.power_pct])
	if s.pierce_pct < 0 or s.pierce_pct > 60 or s.lifesteal_pct < 0 or s.lifesteal_pct > 60 or s.mp_burn < 0:
		errs.append("skill %s: пробитие, вампиризм или сжигание магии вне пределов" % s.id)
	if (s.pierce_pct > 0 or s.lifesteal_pct > 0 or s.mp_burn > 0 or s.status_kind != "") and s.effect != SkillDef.Effect.DAMAGE:
		errs.append("skill %s: свойства урона у навыка без урона" % s.id)
	if s.status_kind != "":
		if not ["stun", "dot"].has(s.status_kind) or s.status_chance < 1 or s.status_chance > 100:
			errs.append("skill %s: неверный статус" % s.id)
		if s.status_kind == "dot" and (s.status_power <= 0 or s.status_turns < 1 or s.status_turns > 5):
			errs.append("skill %s: яд без силы или срока" % s.id)
	if not ["active", "passive", "legion", "combo"].has(s.group) or (s.passive != (s.group == "passive")):
		errs.append("skill %s: группа %s" % [s.id, s.group])
	return errs


## Таблицы опыта: наличие, положительные значения, ссылки ступеней и типов наёмников, пределы уровня, доля потерь.
func _validate_xp() -> Array[String]:
	var errs: Array[String] = []
	for name in ["hero", "dcb", "a", "s"]:
		if not xp_tables.has(name):
			errs.append("xp_tables: нет таблицы %s" % name)
			continue
		var t: Array = xp_tables[name]
		for i in t.size():
			if int(t[i]) <= 0:
				errs.append("xp_tables.%s: уровень %d требует опыта не больше 0" % [name, i + 1])
				break
	var by_tier: Dictionary = rules.get("xp_table_by_tier", {})
	for tier in ["hero", "basic", "advanced", "elite"]:
		if not xp_tables.has(str(by_tier.get(tier, ""))):
			errs.append("xp_table_by_tier: у ступени %s нет таблицы" % tier)
	for id in mercs:
		var m: MercenaryDef = mercs[id]
		if m.xp_table != "" and not xp_tables.has(m.xp_table):
			errs.append("merc %s: нет таблицы опыта %s" % [id, m.xp_table])
	if xp_tables.has("hero") and int(rules["max_level"]) > (xp_tables["hero"] as Array).size() + 1:
		errs.append("progression: max_level больше таблицы героя")
	var permille := int(rules.get("death_xp_loss_permille", -1))
	if permille < 0 or permille > 1000:
		errs.append("progression: death_xp_loss_permille должен быть 0..1000")
	return errs


func _check_reward(label: String, reward: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	for iid in reward.get("items", {}):
		if not items.has(iid):
			errs.append("%s: нет предмета награды %s" % [label, iid])
	return errs


func _validate_chains() -> Array[String]:
	var errs: Array[String] = []
	var cats: Array = rules["quests"].get("chain_categories", [])
	var seen := {}
	for id in chains:
		var c: Dictionary = chains[id]
		if not cats.has(c["category"]):
			errs.append("chain %s: неизвестная категория %s" % [id, c["category"]])
		if str(c.get("region", "")) != "" and not regions.has(str(c["region"])):
			errs.append("chain %s: неизвестный регион %s" % [id, c["region"]])
		if (c["steps"] as Array).is_empty():
			errs.append("chain %s: нет шагов" % id)
		for step in c["steps"]:
			if not quests.has(step):
				errs.append("chain %s: нет задания %s" % [id, step])
			elif seen.has(step):
				errs.append("chain %s: задание %s уже в цепочке %s" % [id, step, seen[step]])
			seen[step] = id
		for pre in c.get("prereq_chains", []):
			if not chains.has(pre):
				errs.append("chain %s: нет цепочки-условия %s" % [id, pre])
		var reset := str(c.get("reset", "none"))
		if not ["none", "daily", "item"].has(reset):
			errs.append("chain %s: неизвестный сброс %s" % [id, reset])
		if reset == "item" and not items.has(str(c.get("reset_item", ""))):
			errs.append("chain %s: нет предмета сброса" % id)
		if reset == "daily":
			if (c["steps"] as Array).size() != 1:
				errs.append("chain %s: ежедневная цепочка из одного шага" % id)
			elif quests.has(c["steps"][0]) and quests[c["steps"][0]]["kind"] != "daily":
				errs.append("chain %s: шаг ежедневной цепочки должен быть kind daily" % id)
		if quests.has(c["steps"][0]) and int(c["level_min"]) > int(quests[c["steps"][0]]["level_min"]):
			errs.append("chain %s: level_min выше уровня первого шага" % id)
		for iid in (c.get("rewards_final", {}) as Dictionary).get("items", {}):
			if not items.has(iid):
				errs.append("chain %s: нет предмета награды %s" % [id, iid])
	for qid in quests:
		if not seen.has(qid):
			errs.append("quest %s: не входит ни в одну цепочку" % qid)
	for id in chains:
		var visiting := {}
		if _chain_cycle(id, visiting):
			errs.append("chain %s: цикл условий" % id)
	return errs


func _chain_cycle(id: String, visiting: Dictionary) -> bool:
	if visiting.has(id):
		return true
	visiting[id] = true
	for pre in chains[id].get("prereq_chains", []):
		if chains.has(pre) and _chain_cycle(str(pre), visiting.duplicate()):
			return true
	return false


func _validate_social() -> Array[String]:
	var errs: Array[String] = []
	var g: Dictionary = social["guild"]
	if (g["levels_xp"] as Array).size() != (g["member_caps"] as Array).size():
		errs.append("guild: levels_xp и member_caps разной длины")
	var p: Dictionary = social["pvp"]
	for k in ["up_wins", "down_losses"]:
		if (p[k] as Array).size() != int(p["tiers"]):
			errs.append("pvp.%s: длина не равна числу ступеней" % k)
	if int((p["down_losses"] as Array)[0]) != 0:
		errs.append("pvp: с первой ступени понижать некуда")
	if int((p["up_wins"] as Array)[int(p["tiers"]) - 1]) != 0:
		errs.append("pvp: с высшей ступени повышать некуда")
	for z in world["zones"]:
		if z["type"] == "dungeon" and int(z["dungeon"]["max_players"]) > int(social["party"]["max_size"]):
			errs.append("zone %s: лимит подземелья больше размера группы" % z["id"])
	return errs


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Нет файла данных: " + path)
		return null
	return JSON.parse_string(f.get_as_text())
