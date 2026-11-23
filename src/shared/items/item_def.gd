class_name ItemDef
extends RefCounted
## Описание предмета (data/items.json). kind: equip (экипировка) или material (материал).

const SLOTS: Array[String] = ["weapon", "armor", "helm", "accessory"]

var id := ""
var name := ""
var kind := "equip"
var slot := ""
## Для оружия: тип оружия, совпадающий с типом наёмника.
var weapon := ""
var rarity := "common"
var level_req := 1
var set_id := ""
var star_rank := 0
var star_next := ""
var stats: Dictionary = {}


static func from_dict(d: Dictionary) -> ItemDef:
	var i := ItemDef.new()
	i.id = str(d.get("id", ""))
	i.name = str(d.get("name", i.id))
	i.kind = str(d.get("kind", "equip"))
	i.slot = str(d.get("slot", ""))
	i.weapon = str(d.get("weapon", ""))
	i.rarity = str(d.get("rarity", "common"))
	i.level_req = int(d.get("level_req", 1))
	i.set_id = str(d.get("set_id", ""))
	i.star_rank = int(d.get("star_rank", 0))
	i.star_next = str(d.get("star_next", ""))
	var s: Dictionary = d.get("stats", {})
	for k in s:
		i.stats[str(k)] = int(s[k])
	return i


func is_equip() -> bool:
	return kind == "equip"


func same_star_type(other: ItemDef) -> bool:
	return stats.size() == 1 and other.stats.size() == 1 and stats.keys()[0] in other.stats
