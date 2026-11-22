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
	var missions_path := path + "/tactical_missions.json"
	if FileAccess.file_exists(missions_path):
		for mission in _read(missions_path):
			gd.tactical_missions[str(mission["id"])] = mission
	gd.world = _read(path + "/world.json")
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
	errs.append_array(_validate_tactics())
	errs.append_array(_validate_quests())
	errs.append_array(_validate_social())
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


## Регион зоны (пустая строка, если зоны нет).
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
		if int(z["min_level"]) < int(band[0]) or int(z["min_level"]) > int(band[1]):
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
		if z["type"] != "town":
			errs.append("npc %s: NPC живёт только в городе" % id)
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
	for id in quests:
		var q: Dictionary = quests[id]
		for k in ["giver", "turn_in"]:
			if not npcs.has(q[k]):
				errs.append("quest %s: нет NPC %s" % [id, q[k]])
		for pre in q.get("prereq", []):
			if not quests.has(pre):
				errs.append("quest %s: нет предшествующего %s" % [id, pre])
		if (q["objectives"] as Array).is_empty():
			errs.append("quest %s: нет целей" % id)
		for o in q["objectives"]:
			var t := str(o["target"]) if not o["target"] is Array else ""
			match str(o["type"]):
				"kill":
					if t != "*" and not encounters.has(t):
						errs.append("quest %s: нет столкновения %s" % [id, t])
				"kill_any":
					if not o["target"] is Array or (o["target"] as Array).is_empty():
						errs.append("quest %s: kill_any требует список столкновений" % id)
					else:
						for e in o["target"]:
							if not encounters.has(str(e)):
								errs.append("quest %s: нет столкновения %s" % [id, e])
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
