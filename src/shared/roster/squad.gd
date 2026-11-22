class_name Squad
extends RefCounted
## Отряд наёмников игрока: найм, отставка, улучшение ступени.
## Кошелёк передаётся словарём {"coins": int, "shards": int} и изменяется на месте.

var gd: GameData
var mercs: Array[Mercenary] = []
## Номера комнат начинаются с нуля.
var rooms: Dictionary = {}
var _starter_guards_claimed := false
## Герой отряда: не занимает место наёмника (в отряде герой и до squad_max наёмников).
var hero: Mercenary = null
var _next_uid := 1


func _init(p_gd: GameData) -> void:
	gd = p_gd


## Создать героя: по id класса (`warden`) или по оружию (`sword`, берётся первый включённый класс этого оружия).
## Герой нужен один раз. Класс должен быть доступен (`GameData.class_status`).
func create_hero(class_or_weapon: String) -> Mercenary:
	var cid := class_or_weapon if gd.classes.has(class_or_weapon) else gd.default_class_for_weapon(class_or_weapon)
	if hero != null or cid == "" or gd.class_status(cid) != "":
		return null
	hero = Mercenary.new(0, gd.hero_def_id(cid), gd)
	return hero


## Улучшение героя (результат квестовых цепочек 100, 120, 130 уровня): открывает 4-й и 5-й навык, на 130 таланты (WP-46).
## Порядок обязателен. Коды ошибок: no_hero, bad_upgrade, already_done, level_too_low, previous_required.
func complete_hero_upgrade(level: int) -> String:
	if hero == null:
		return "no_hero"
	var order := [100, 120, 130]
	if not order.has(level):
		return "bad_upgrade"
	if hero.hero_upgrades.has(level):
		return "already_done"
	if hero.level < level:
		return "level_too_low"
	var idx := order.find(level)
	if idx > 0 and not hero.hero_upgrades.has(order[idx - 1]):
		return "previous_required"
	hero.hero_upgrades.append(level)
	return ""


## Смена класса героя за «карту смены класса». Теряются все навыки (очки возвращаются), нужно заново пройти улучшения 100 и 120,
## оружие другого типа снимается в сумку. Уровень, опыт, очки характеристик и экипировка остальных слотов остаются.
## Ошибки: no_hero, class_unavailable, same_class, no_item, inventory_full.
func change_class(class_id: String, inv: Inventory) -> String:
	if hero == null:
		return "no_hero"
	if gd.class_status(class_id) != "":
		return "class_unavailable"
	if class_id == hero.class_id:
		return "same_class"
	if inv.material_count("class_change_card") < 1:
		return "no_item"
	var new_def: MercenaryDef = gd.mercs[gd.hero_def_id(class_id)]
	var old_weapon: Item = hero.equipped.get("weapon")
	var unequip := old_weapon != null and (gd.items[old_weapon.def_id] as ItemDef).weapon != new_def.weapon
	if unequip and inv.is_full():
		return "inventory_full"
	inv.take_material("class_change_card", 1)
	if unequip:
		hero.equipped.erase("weapon")
		inv.items.append(old_weapon)
	var spent := -1
	for sid in hero.skill_levels:
		spent += int(hero.skill_levels[sid])
	hero.skill_points += maxi(0, spent)
	hero.skill_levels = {new_def.skill_ids[0]: 1}
	hero.specialization = ""
	hero.hero_upgrades = hero.hero_upgrades.filter(func(l: int) -> bool: return l > 120)
	hero.def_id = new_def.id
	hero.class_id = class_id
	return ""


## Бонус героя всему отряду (класс героя): {"hp_pct", "atk_pct", "def_pct", "ap_regen"}; пустой без героя.
func formation_bonus() -> Dictionary:
	if hero == null:
		return {}
	return (gd.classes[hero.class_id]["squad_bonus"] as Dictionary).duplicate()


func all_mercenaries() -> Array[Mercenary]:
	var out := mercs.duplicate()
	var room_ids := rooms.keys()
	room_ids.sort()
	for room in room_ids:
		out.append(rooms[room])
	return out


func room_of(uid: int) -> int:
	for room in rooms:
		if rooms[room].uid == uid:
			return int(room)
	return -1


func set_enabled(uid: int, enabled: bool) -> String:
	var merc := by_uid(uid)
	if merc == null or not mercs.has(merc):
		return "not_in_formation"
	merc.enabled = enabled
	return ""


func move_to_room(uid: int, room: int) -> String:
	if room < 0 or room >= int(gd.rules["formation"]["rooms"]):
		return "bad_room"
	var merc := by_uid(uid)
	if merc == null or not mercs.has(merc):
		return "not_in_formation"
	var index := mercs.find(merc)
	if rooms.has(room):
		var incoming: Mercenary = rooms[room]
		incoming.enabled = true
		mercs[index] = incoming
	else:
		mercs.remove_at(index)
	merc.enabled = true
	rooms[room] = merc
	return ""


func restore_from_room(room: int) -> String:
	if not rooms.has(room):
		return "empty_room"
	if mercs.size() >= int(gd.rules["squad_max"]):
		return "squad_full"
	var merc: Mercenary = rooms[room]
	mercs.append(merc)
	rooms.erase(room)
	return ""


func claim_starter_guards() -> void:
	if _starter_guards_claimed or hero == null:
		return
	_starter_guards_claimed = true
	for def_id in gd.rules["formation"]["starter_guards"]:
		for room in int(gd.rules["formation"]["rooms"]):
			if not rooms.has(room):
				var guard := Mercenary.new(_next_uid, def_id, gd)
				_next_uid += 1
				rooms[room] = guard
				break


func disabled_count() -> int:
	return mercs.filter(func(merc): return not merc.enabled).size()


func formation_ap_bonus() -> int:
	var formation: Dictionary = gd.rules.get("formation", {})
	return disabled_count() * int(formation.get("ap_per_disabled", 0))


func formation_battle_xp(xp: int, disabled_count: int) -> int:
	var rate := 100 + disabled_count * int(gd.rules["formation"]["xp_pct_per_disabled"])
	return xp * rate / 100


func award_formation_battle_xp(xp: int, participant_uids: Array, disabled_count: int) -> Dictionary:
	var amount := formation_battle_xp(xp, disabled_count)
	var result := {"hero_levels": 0 if hero == null else hero.add_xp(amount, gd), "levels": {}}
	for i in int(result.hero_levels):
		on_hero_level_up()
	for merc in all_mercenaries():
		if participant_uids.has(merc.uid):
			result.levels[merc.uid] = merc.add_xp(amount, gd)
	return result


## Раздать опыт за бой. Герой получает 100%, участники-наёмники 100%, остальные bench_xp_pct.
## Уровни героя дают очки всем наёмникам. Возвращает {"hero_levels": n, "levels": {uid: n}}.
func award_battle_xp(xp: int, participant_uids: Array = [], hero_participates := true) -> Dictionary:
	var result := {"hero_levels": 0, "levels": {}}
	if hero != null:
		var hero_xp := xp if hero_participates else xp * int(gd.rules["bench_xp_pct"]) / 100
		var n := hero.add_xp(hero_xp, gd)
		for i in n:
			on_hero_level_up()
		result["hero_levels"] = n
	for m in mercs:
		var amount := xp if participant_uids.has(m.uid) else xp * int(gd.rules["bench_xp_pct"]) / 100
		result["levels"][m.uid] = m.add_xp(amount, gd)
	return result


func count_of(def_id: String) -> int:
	var n := 0
	for m in all_mercenaries():
		if m.def_id == def_id:
			n += 1
	return n


func by_uid(uid: int) -> Mercenary:
	for m in all_mercenaries():
		if m.uid == uid:
			return m
	return null


## "" если можно нанять, иначе код ошибки.
func can_recruit(def_id: String) -> String:
	if not gd.mercs.has(def_id) or (gd.mercs[def_id] as MercenaryDef).tier == "hero":
		return "unknown_def"
	if mercs.size() >= int(gd.rules["squad_max"]):
		return "squad_full"
	if count_of(def_id) >= (gd.mercs[def_id] as MercenaryDef).squad_limit:
		return "squad_limit"
	return ""


## Найм за монеты или за выполненный квест (via: "coins" или "quest").
func recruit(def_id: String, via: String, wallet: Dictionary, done_quests: Array = []) -> Dictionary:
	var err := can_recruit(def_id)
	if err != "":
		return _fail(err)
	var d: MercenaryDef = gd.mercs[def_id]
	match via:
		"coins":
			if d.recruit_coins <= 0:
				return _fail("not_for_sale")
			if int(wallet.get("coins", 0)) < d.recruit_coins:
				return _fail("no_coins")
			wallet["coins"] -= d.recruit_coins
		"quest":
			if d.recruit_quest == "" or not done_quests.has(d.recruit_quest):
				return _fail("quest_not_done")
		_:
			return _fail("bad_method")
	return {"ok": true, "error": "", "merc": _add(def_id)}


## Найм из случайного набора. Если наёмник не поместился (отряд полон или лимит типа), он превращается в осколки.
func recruit_from_pack(pack_id: String, wallet: Dictionary, state: RecruitPack.State, rng: RandomNumberGenerator) -> Dictionary:
	var pack := RecruitPack.find_pack(gd, pack_id)
	if pack.is_empty():
		return _fail("unknown_pack")
	if int(wallet.get("coins", 0)) < int(pack["cost_coins"]):
		return _fail("no_coins")
	wallet["coins"] -= int(pack["cost_coins"])
	var def_id := RecruitPack.roll(pack, state, rng)
	if can_recruit(def_id) == "":
		return {"ok": true, "error": "", "def_id": def_id, "merc": _add(def_id), "shards": 0}
	var tier := (gd.mercs[def_id] as MercenaryDef).tier
	var shards := int(gd.rules["duplicate_shards"].get(tier, 0))
	wallet["shards"] = int(wallet.get("shards", 0)) + shards
	return {"ok": true, "error": "", "def_id": def_id, "merc": null, "shards": shards}


## Отставка: наёмник уходит, игрок получает осколки.
func retire(uid: int, wallet: Dictionary, inv: Inventory = null) -> Dictionary:
	var m := by_uid(uid)
	if m == null:
		return _fail("unknown_merc")
	if not m.equipped.is_empty():
		# Экипировка возвращается в сумку. Без сумки или без места отставка невозможна.
		if inv == null or inv.items.size() + m.equipped.size() > inv.capacity():
			return _fail("unequip_first")
		for slot in m.equipped.keys():
			inv.items.append(m.equipped[slot])
		m.equipped.clear()
	var d: MercenaryDef = gd.mercs[m.def_id]
	var shards := int(gd.rules["retire_shards"][d.tier]) + m.level / 2 * int(gd.rules["retire_shards_per_2_levels"])
	wallet["shards"] = int(wallet.get("shards", 0)) + shards
	rooms.erase(room_of(uid))
	mercs.erase(m)
	return {"ok": true, "error": "", "shards": shards}


## Повысить ступень: тип меняется на следующий, уровень и очки сохраняются.
func upgrade(uid: int, wallet: Dictionary) -> Dictionary:
	var m := by_uid(uid)
	if m == null:
		return _fail("unknown_merc")
	var d: MercenaryDef = gd.mercs[m.def_id]
	if d.upgrades_to == "":
		return _fail("no_upgrade")
	if m.level < d.upgrade_level:
		return _fail("level_too_low")
	if int(wallet.get("shards", 0)) < d.upgrade_cost:
		return _fail("no_shards")
	var next: MercenaryDef = gd.mercs[d.upgrades_to]
	if count_of(next.id) >= next.squad_limit:
		return _fail("squad_limit")
	wallet["shards"] -= d.upgrade_cost
	m.def_id = next.id
	return {"ok": true, "error": "", "merc": m}


func on_hero_level_up() -> void:
	for m in all_mercenaries():
		m.grant_hero_level_points()


func _add(def_id: String) -> Mercenary:
	var m := Mercenary.new(_next_uid, def_id, gd)
	_next_uid += 1
	mercs.append(m)
	return m


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
