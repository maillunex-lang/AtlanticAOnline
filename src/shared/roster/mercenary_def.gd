class_name MercenaryDef
extends RefCounted
## Тип наёмника (данные из data/mercenaries.json). Ступень: basic, advanced, elite.

var id := ""
var name := ""
var weapon := ""
var tier := "basic"
var base := {"hp": 100, "atk": 10, "def": 0, "ap_regen": 50}
## Рост за уровень, умноженный на 10 (12 значит +1.2 за уровень).
var growth_x10 := {"hp": 80, "atk": 10, "def": 6}
var skill_ids: Array[String] = []
var recruit_quest := ""
var recruit_coins := 0
var squad_limit := 99
var upgrades_to := ""
var upgrade_level := 0
var upgrade_cost := 0
var level_cap := 0
## Таблица опыта (hero, dcb, a, s); пусто, значит по ступени (Progression.table_for).
var xp_table := ""
## Пустой ранг сохраняет характеристики и таблицу старых записей.
var rank := ""

const RANK_GROWTH_PCT := {"E": 95, "D": 100, "C": 103, "B": 106, "A": 112, "S": 120}
const RANK_XP_TABLE := {"E": "dcb", "D": "dcb", "C": "dcb", "B": "dcb", "A": "a", "S": "s"}
const LEGACY_RANK := {"basic": "D", "advanced": "B", "elite": "A"}


func display_rank() -> String:
	return rank if rank != "" else str(LEGACY_RANK.get(tier, ""))


func rank_growth_pct() -> int:
	return int(RANK_GROWTH_PCT.get(rank, 100))


static func from_dict(d: Dictionary) -> MercenaryDef:
	var m := MercenaryDef.new()
	m.id = str(d.get("id", ""))
	m.name = str(d.get("name", m.id))
	m.weapon = str(d.get("weapon", ""))
	m.tier = str(d.get("tier", "basic"))
	m.base = {"hp": int(d.get("hp", 100)), "atk": int(d.get("atk", 10)), "def": int(d.get("def", 0)), "ap_regen": int(d.get("ap_regen", 50))}
	for stat in d.get("attributes", {}):
		m.base[stat] = int(d["attributes"][stat])
	var g: Dictionary = d.get("growth_x10", {})
	for k in g:
		m.growth_x10[str(k)] = int(g[k])
	for s in d.get("skills", []):
		m.skill_ids.append(str(s))
	var r: Dictionary = d.get("recruit", {})
	m.recruit_quest = str(r.get("quest", ""))
	m.recruit_coins = int(r.get("coins", 0))
	m.squad_limit = int(d.get("squad_limit", 99))
	m.xp_table = str(d.get("xp_table", ""))
	m.rank = str(d.get("rank", ""))
	m.upgrades_to = str(d.get("upgrades_to", ""))
	m.upgrade_level = int(d.get("upgrade_level", 0))
	m.upgrade_cost = int(d.get("upgrade_cost", 0))
	m.level_cap = int(d.get("level_cap", 0))
	return m
