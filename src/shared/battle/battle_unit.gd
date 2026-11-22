class_name BattleUnit
extends RefCounted
## Боец в бою: герой или наёмник. Чистые данные, без сцен.

enum Reach { MELEE, RANGED }

var id := 0
var side := 0
var slot := 0
var max_hp := 100
var hp := 100
var atk := 10
var def := 0
var ap := 100
var ap_regen := 50
var reach := Reach.MELEE
var acted := false


func is_alive() -> bool:
	return hp > 0


func column() -> int:
	return slot % BattleRules.GRID_COLS


static func make(p_id: int, p_side: int, p_slot: int, stats: Dictionary = {}) -> BattleUnit:
	var u := BattleUnit.new()
	u.id = p_id
	u.side = p_side
	u.slot = p_slot
	u.max_hp = int(stats.get("hp", 100))
	u.hp = u.max_hp
	u.atk = int(stats.get("atk", 10))
	u.def = int(stats.get("def", 0))
	u.ap_regen = int(stats.get("ap_regen", 50))
	u.ap = int(stats.get("ap", 100))
	u.reach = int(stats.get("reach", Reach.MELEE))
	return u
