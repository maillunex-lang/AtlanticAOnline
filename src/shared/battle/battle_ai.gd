class_name BattleAI
extends RefCounted
## Простой ИИ: для врагов и для автобоя игрока. Возвращает допустимое действие для бойца
## (или ожидание, если ходить нечем). Выбор детерминирован: без случайных чисел.
##
## Порядок: лечение раненого союзника, полезный бафф, сильнейший навык урона, защита раненого героя, обычная атака, ожидание.


static func choose(sim: BattleSim, actor_id: int) -> Dictionary:
	var a := sim.unit_by_id(actor_id)
	var wait := {"type": "wait", "actor": actor_id}
	if a == null or sim.can_act(actor_id) != "":
		return wait
	var best_damage := ""
	var best_power := 0
	for sid in a.skill_ids:
		if sim.can_afford(actor_id, sid) != "":
			continue
		var sk: SkillDef = sim.skills[sid]
		match sk.effect:
			SkillDef.Effect.REVIVE:
				var t := _pick(sim, actor_id, sid)
				if t != -2:
					return _skill(actor_id, sid, t)
			SkillDef.Effect.HEAL:
				var hurt := _most_hurt_ally(sim, a)
				if hurt != null and float(hurt.hp) / hurt.max_hp <= 0.5:
					return _skill(actor_id, sid, hurt.id if sim.skill_needs_target(sid) else -1)
			SkillDef.Effect.MODIFY:
				if _worth_modifying(sim, a, sk):
					var t := _pick(sim, actor_id, sid)
					if t != -2:
						return _skill(actor_id, sid, t)
			SkillDef.Effect.DAMAGE:
				var targets := _count_targets(sim, a, sk)
				var target_id := _pick(sim, actor_id, sid)
				var value := sk.power_pct * maxi(1, targets)
				if target_id >= 0 and sim.would_combo(a, sk, sim.unit_by_id(target_id)):
					value += sk.combo_bonus_pct
				if value > best_power and target_id != -2:
					best_power = value
					best_damage = sid
	if best_damage != "":
		return _skill(actor_id, best_damage, _pick(sim, actor_id, best_damage))
	if a.is_hero and a.hp * 100 < a.max_hp * 40 and not a.guarding:
		return {"type": "guard", "actor": actor_id}
	if sim.can_afford(actor_id) == "":
		var targets := sim.legal_targets(actor_id)
		if not targets.is_empty():
			return {"type": "attack", "actor": actor_id, "target": _attack_target(sim, actor_id, targets)}
	return wait


static func _skill(actor_id: int, sid: String, target: int) -> Dictionary:
	var d := {"type": "skill", "actor": actor_id, "skill": sid}
	if target >= 0:
		d["target"] = target
	return d


## Цель для навыка: -1 если цель не нужна, -2 если подходящей цели нет, иначе id.
static func _pick(sim: BattleSim, actor_id: int, sid: String) -> int:
	var sk: SkillDef = sim.skills[sid]
	var actor := sim.unit_by_id(actor_id)
	if not sim.skill_needs_target(sid):
		if sk.target == SkillDef.Target.ENEMY_ALL:
			if not sim.alive_units(1 - actor.side).any(func(u): return sim.can_hit_with_skill(actor, sk, u)):
				return -2
		return -1
	var targets := sim.legal_targets(actor_id, sid)
	if targets.is_empty():
		return -2
	if sk.target == SkillDef.Target.ALLY_ONE:
		return _most_hurt_ally(sim, actor).id
	for id in targets:
		if sim.would_combo(actor, sk, sim.unit_by_id(id)):
			return id
	return _weakest(sim, targets)


static func _count_targets(sim: BattleSim, a: BattleUnit, sk: SkillDef) -> int:
	match sk.target:
		SkillDef.Target.ENEMY_ALL:
			return sim.alive_units(1 - a.side).filter(func(u): return sim.can_hit_with_skill(a, sk, u)).size()
		SkillDef.Target.ENEMY_COLUMN:
			var t := sim.legal_targets(a.id, sk.id)
			if t.is_empty():
				return 0
			var best := 0
			for id in t:
				var col := sim.unit_by_id(id).column()
				var n := 0
				for u in sim.alive_units(1 - a.side):
					if u.column() == col and sim.can_hit_with_skill(a, sk, u):
						n += 1
				best = maxi(best, n)
			return best
		_:
			return 1


## Бафф и дебафф применяем, только если эффект ещё не висит (иначе тратим очки впустую).
static func _worth_modifying(sim: BattleSim, a: BattleUnit, sk: SkillDef) -> bool:
	match sk.target:
		SkillDef.Target.SELF:
			return not a.stats.has_modifier(sk.id)
		SkillDef.Target.ALLY_ALL:
			for u in sim.alive_units(a.side):
				if not u.stats.has_modifier(sk.id):
					return true
			return false
		SkillDef.Target.ENEMY_ONE:
			for id in sim.legal_targets(a.id, sk.id):
				if not sim.unit_by_id(id).stats.has_modifier(sk.id):
					return true
			return false
		_:
			return false


static func _most_hurt_ally(sim: BattleSim, a: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for u in sim.alive_units(a.side):
		if best == null or float(u.hp) / u.max_hp < float(best.hp) / best.max_hp:
			best = u
	return best


static func _attack_target(sim: BattleSim, actor_id: int, ids: Array[int]) -> int:
	var best := ids[0]
	var best_count := 0
	for id in ids:
		var count := sim.hit_set(actor_id, id).size()
		if count > best_count or (count == best_count and sim.unit_by_id(id).hp < sim.unit_by_id(best).hp):
			best = id
			best_count = count
	return best


static func _weakest(sim: BattleSim, ids: Array[int]) -> int:
	var best := ids[0]
	for id in ids:
		if sim.unit_by_id(id).hp < sim.unit_by_id(best).hp:
			best = id
	return best
