class_name BattleUnit
extends RefCounted
## Боец в бою: герой или наёмник. Чистые данные, без сцен.

enum Reach { MELEE, RANGED }

var id := 0
var side := 0
var slot := 0
var reserve_room := -1
var enemy_wave := 0
var participated := true
var formation_ap_bonus := 0
var max_hp := 100
var hp := 100
## Запас очков действий: растёт в начале хода стороны, тратится действиями, может уходить в минус.
var ap := 50
var mp := 100
var max_mp := 100
var reach := Reach.MELEE
var attack_pattern := ""
var flying := false
var combo_skill := ""
var combo_skill_turn := -1
## Закончил действовать в этом ходу (атака, навык, защита или ожидание).
var acted := false
var moved := false
## Герой: его гибель означает поражение стороны.
var is_hero := false
## В обороне до начала своего следующего хода (повышенная защита).
var guarding := false
## Оглушён: пропускает следующий ход и не получает AP.
var stunned := false
## Счётчик физических попаданий подряд по ходам (3 вызывают оглушение).
var combo := 0
## Получил физический удар в текущем ходу противника (для счётчика комбо).
var hit_phys := false
## Атака, защита, ap_regen и прочие статы с модификаторами. Читать через stat().
var stats := StatBlock.new()
var skill_ids: Array[String] = []
## Уровни изученных навыков: id -> 1..N. Повышают силу навыка.
var skill_levels: Dictionary = {}
## Остаток перезарядки навыков в ходах своей стороны.
var cooldowns: Dictionary = {}


func is_alive() -> bool:
	return hp > 0


func stat(name: String) -> int:
	return stats.value(name)


func column() -> int:
	return slot % BattleRules.GRID_COLS


static func make(p_id: int, p_side: int, p_slot: int, stats: Dictionary = {}) -> BattleUnit:
	var u := BattleUnit.new()
	u.id = p_id
	u.side = p_side
	u.slot = p_slot
	u.max_hp = int(stats.get("hp", 100))
	u.hp = u.max_hp
	u.stats = StatBlock.new({
		"atk": int(stats.get("atk", 10)),
		"def": int(stats.get("def", 0)),
		"ap_regen": int(stats.get("ap_regen", 50)),
	})
	for stat in ["strength", "dexterity", "vitality", "intelligence", "magic_def", "accuracy", "evasion", "crit", "crit_resist", "multi_hit"]:
		u.stats.base[stat] = int(stats.get(stat, 0))
	u.ap = int(stats.get("ap", 50))
	u.max_mp = int(stats.get("mp", 100))
	u.mp = u.max_mp
	u.is_hero = bool(stats.get("hero", false))
	u.reach = int(stats.get("reach", Reach.MELEE))
	u.attack_pattern = str(stats.get("attack_pattern", ""))
	u.flying = bool(stats.get("flying", false))
	return u


## Боец из наёмника: статы по уровню, оружие определяет дальность, навыки берутся изученные.
static func from_mercenary(m: Mercenary, gd: GameData, p_id: int, p_side: int, p_slot: int, squad_bonus: Dictionary = {}) -> BattleUnit:
	var d: MercenaryDef = gd.mercs[m.def_id]
	var st := m.compute_stats(gd)
	var weapon: Dictionary = gd.weapons[d.weapon]
	st["reach"] = Reach.RANGED if weapon["reach"] == "ranged" else Reach.MELEE
	st["attack_pattern"] = weapon.get("attack_pattern", d.weapon)
	st["hero"] = d.tier == "hero"
	var u := make(p_id, p_side, p_slot, st)
	for sid in m.skill_levels:
		u.skill_ids.append(sid)
	u.skill_levels = m.skill_levels.duplicate()
	u.apply_squad_bonus(squad_bonus)
	return u


## Бонус героя отряду: hp_pct, atk_pct, def_pct (проценты) и ap_regen (плоско). Постоянный, не сгорает по ходам.
func apply_squad_bonus(bonus: Dictionary) -> void:
	if bonus.is_empty():
		return
	var hp_pct := int(bonus.get("hp_pct", 0))
	if hp_pct != 0:
		max_hp = max_hp * (100 + hp_pct) / 100
		hp = max_hp
	if int(bonus.get("atk_pct", 0)) != 0:
		stats.add_modifier("squad_bonus", "atk", StatBlock.Kind.PERCENT, int(bonus["atk_pct"]))
	if int(bonus.get("def_pct", 0)) != 0:
		stats.add_modifier("squad_bonus", "def", StatBlock.Kind.PERCENT, int(bonus["def_pct"]))
	if int(bonus.get("ap_regen", 0)) != 0:
		stats.add_modifier("squad_bonus", "ap_regen", StatBlock.Kind.FLAT, int(bonus["ap_regen"]))
