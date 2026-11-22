class_name Squad
extends RefCounted
## Отряд наёмников игрока: найм, отставка, улучшение ступени.
## Кошелёк передаётся словарём {"coins": int, "shards": int} и изменяется на месте.

var gd: GameData
var mercs: Array[Mercenary] = []
var _next_uid := 1


func _init(p_gd: GameData) -> void:
	gd = p_gd


func count_of(def_id: String) -> int:
	var n := 0
	for m in mercs:
		if m.def_id == def_id:
			n += 1
	return n


func by_uid(uid: int) -> Mercenary:
	for m in mercs:
		if m.uid == uid:
			return m
	return null


## "" если можно нанять, иначе код ошибки.
func can_recruit(def_id: String) -> String:
	if not gd.mercs.has(def_id):
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
func retire(uid: int, wallet: Dictionary) -> Dictionary:
	var m := by_uid(uid)
	if m == null:
		return _fail("unknown_merc")
	var d: MercenaryDef = gd.mercs[m.def_id]
	var shards := int(gd.rules["retire_shards"][d.tier]) + m.level / 2 * int(gd.rules["retire_shards_per_2_levels"])
	wallet["shards"] = int(wallet.get("shards", 0)) + shards
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
	for m in mercs:
		m.grant_hero_level_points()


func _add(def_id: String) -> Mercenary:
	var m := Mercenary.new(_next_uid, def_id, gd)
	_next_uid += 1
	mercs.append(m)
	return m


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
