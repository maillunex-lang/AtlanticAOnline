class_name BattleSim
extends RefCounted
## Детерминированная симуляция пошагового боя. Не знает про сцены, сеть и UI.
## Сервер использует её как источник истины, клиент для предпросмотра.
##
## Модель очков действий (AP), правила оригинала (docs/plan/COMBAT_REVISION.md):
## в начале хода стороны каждый боец получает AP (оглушённые нет). Действуют до active_cap
## бойцов с наибольшим AP, у которых AP >= порога. Боец делает одно действие
## (attack, skill, guard, wait) и может один раз передвинуться (move). Действия тратят AP,
## AP может уходить в минус. Ход закрывается сам, когда все действующие сходили, либо end_turn().
## Три хода подряд физических попаданий оглушают бойца. Гибель героя означает поражение стороны.
##
## Навыки (action "skill") берутся из словаря skills: id -> SkillDef. Бонусы и штрафы
## хранятся модификаторами в StatBlock бойца и сгорают в конце хода его стороны.

enum Winner { NONE = -1, SIDE_A = 0, SIDE_B = 1, DRAW = 2 }

var rules: BattleRules
var units: Array[BattleUnit] = []
var current_side := BattleRules.SIDE_A
var round_number := 1
var side_turns: Array[int] = [0, 0]
var active_ids: Array[int] = []
var active_count := 0
var acted_count := 0
var idle_turns := 0
var winner: int = Winner.NONE
var events_log: Array[Dictionary] = []

var skills: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _init(p_rules: BattleRules, p_units: Array[BattleUnit], p_seed: int, p_skills: Dictionary = {}, p_first_side := 0) -> void:
	rules = p_rules
	current_side = p_first_side
	units = p_units
	skills = p_skills
	_rng.seed = p_seed
	for unit in units:
		unit.ap = clampi(unit.ap, rules.ap_min, rules.ap_max)
	_begin_turn()


## Подать действие. Формат:
##   {"type": "attack", "actor": id, "target": id}
##   {"type": "skill",  "actor": id, "skill": id, "target": id}  (target нужен не всем навыкам)
##   {"type": "move",   "actor": id, "slot": 0..8}   (один раз за ход, не завершает действие)
##   {"type": "guard",  "actor": id}
##   {"type": "wait",   "actor": id}
## Возвращает {"ok": bool, "error": String, "events": Array}.
func submit(action: Dictionary) -> Dictionary:
	var can := can_act(int(action.get("actor", -1)))
	if can != "":
		return _fail(can)
	var actor := unit_by_id(int(action.get("actor", -1)))

	var mark := events_log.size()
	match str(action.get("type", "")):
		"attack":
			var err := _do_attack(actor, action)
			if err != "":
				return _fail(err)
		"skill":
			var err := _do_skill(actor, action)
			if err != "":
				return _fail(err)
		"move":
			var err := _do_move(actor, action)
			if err != "":
				return _fail(err)
		"guard":
			actor.ap = maxi(rules.ap_min, actor.ap - rules.guard_cost)
			actor.guarding = true
			_emit({"type": "guard", "actor": actor.id})
		"wait":
			_emit({"type": "wait", "actor": actor.id})
		_:
			return _fail("bad_action")

	idle_turns = 0
	if str(action.get("type", "")) != "move":
		actor.acted = true
		acted_count += 1
	_check_victory()
	if winner == Winner.NONE and acted_count >= active_count:
		_close_turn()
	return {"ok": true, "error": "", "events": events_log.slice(mark)}


## "" если боец может действовать сейчас, иначе код причины. Те же проверки делает submit().
func can_act(actor_id: int) -> String:
	if winner != Winner.NONE:
		return "battle_over"
	var actor := unit_by_id(actor_id)
	if actor == null:
		return "unknown_unit"
	if actor.side != current_side:
		return "wrong_side"
	if not actor.is_alive():
		return "dead"
	if not active_ids.has(actor_id):
		return "not_active"
	if actor.acted:
		return "already_acted"
	return ""


## "" если хватает очков действий и навык не на перезарядке. skill_id "" означает обычную атаку.
func can_afford(actor_id: int, skill_id := "") -> String:
	var a := unit_by_id(actor_id)
	if a == null:
		return "unknown_unit"
	if a.ap < rules.ap_act_threshold:
		return "no_ap"
	if skill_id == "":
		return ""
	if not skills.has(skill_id) or not a.skill_ids.has(skill_id):
		return "unknown_skill"
	if a.cooldowns.has(skill_id):
		return "on_cooldown"
	if a.mp < (skills[skill_id] as SkillDef).cost_mp:
		return "no_mp"
	return ""


## Нужна ли навыку выбранная цель (иначе он действует на всех или на себя).
func skill_needs_target(skill_id: String) -> bool:
	if not skills.has(skill_id):
		return false
	var sk: SkillDef = skills[skill_id]
	return sk.target in [SkillDef.Target.ENEMY_ONE, SkillDef.Target.ENEMY_COLUMN, SkillDef.Target.ALLY_ONE, SkillDef.Target.ALLY_DEAD]


func can_hit_with_skill(actor: BattleUnit, skill: SkillDef, target: BattleUnit) -> bool:
	return not target.flying or skill.magic or _weapon_hits_flying(actor)


## Допустимые цели для обычной атаки (skill_id "") или навыка. Пусто, если цель не нужна или её нет.
func legal_targets(actor_id: int, skill_id := "") -> Array[int]:
	var out: Array[int] = []
	var a := unit_by_id(actor_id)
	if a == null or not a.is_alive():
		return out
	if skill_id == "":
		for u in alive_units(1 - a.side):
			if not hit_set(actor_id, u.id).is_empty():
				out.append(u.id)
		return out
	if not skills.has(skill_id):
		return out
	var sk: SkillDef = skills[skill_id]
	if sk.targets_enemies() and sk.target != SkillDef.Target.ENEMY_ALL:
		for u in alive_units(1 - a.side):
			if can_hit_with_skill(a, sk, u) and (sk.ranged or u.column() == _front_column(u.side)):
				out.append(u.id)
	elif sk.target == SkillDef.Target.ALLY_ONE:
		for u in alive_units(a.side):
			out.append(u.id)
	elif sk.target == SkillDef.Target.ALLY_DEAD:
		for u in units:
			if _can_revive(a, u):
				out.append(u.id)
	return out


func _can_revive(actor: BattleUnit, target: BattleUnit) -> bool:
	if target.side != actor.side or target.is_alive() or target.is_hero:
		return false
	for ally in alive_units(target.side):
		if ally.slot == target.slot:
			return false
	return true


## Порядок фиксирован: выбранная цель первой, затем остальные клетки шаблона.
func hit_set(actor_id: int, target_id: int) -> Array[int]:
	var hits: Array[int] = []
	var actor := unit_by_id(actor_id)
	var target := unit_by_id(target_id)
	if actor == null or not actor.is_alive() or target == null or not target.is_alive() or target.side == actor.side:
		return hits
	var pattern := actor.attack_pattern
	if pattern == "":
		pattern = "bow" if actor.reach == BattleUnit.Reach.RANGED else "sword"
	var hits_flying := _weapon_hits_flying(actor)
	if target.flying and not hits_flying:
		return hits

	var formation: Dictionary = {}
	for u in alive_units(target.side):
		formation[u.slot] = u
	var col := target.column()
	var row := target.slot / BattleRules.GRID_COLS
	if pattern not in ["bow", "gun", "instrument", "cannon", "whip"]:
		var front := _front_column(target.side)
		if col != front:
			var cover: BattleUnit = formation.get(row * BattleRules.GRID_COLS + front)
			if hits_flying or cover == null or not cover.flying:
				return hits
			for depth in range(front + 1, col):
				var blocker: BattleUnit = formation.get(row * BattleRules.GRID_COLS + depth)
				if blocker != null and not blocker.flying:
					return hits

	hits.append(target.id)
	match pattern:
		"dual_sword", "cannon":
			var offsets := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]
			if pattern == "cannon":
				offsets.append(Vector2i(-1, 0))
			for offset: Vector2i in offsets:
				_append_hit(hits, formation, row + offset.y, col + offset.x, hits_flying)
		"spear", "armor_fist", "instrument":
			_append_hit(hits, formation, row, col + 1, hits_flying)
		"gun":
			for depth in BattleRules.GRID_COLS:
				if depth != col:
					_append_hit(hits, formation, row, depth, hits_flying)
		"axe", "power_saw", "whip":
			for direction in [-1, 1]:
				var next_row: int = row + direction
				while _append_hit(hits, formation, next_row, col, hits_flying):
					next_row += direction
	return hits


func _weapon_hits_flying(actor: BattleUnit) -> bool:
	if actor.attack_pattern == "":
		return actor.reach == BattleUnit.Reach.RANGED
	return actor.attack_pattern in ["dual_sword", "bow", "gun", "instrument", "whip", "staff"]


func _append_hit(hits: Array[int], formation: Dictionary, row: int, col: int, hits_flying: bool) -> bool:
	if row < 0 or row >= BattleRules.GRID_ROWS or col < 0 or col >= BattleRules.GRID_COLS:
		return false
	var unit: BattleUnit = formation.get(row * BattleRules.GRID_COLS + col)
	if unit == null:
		return false
	if hits_flying or not unit.flying:
		hits.append(unit.id)
	return true


## Закончить ход досрочно (оставшиеся бойцы не действуют).
func end_turn() -> Dictionary:
	if winner != Winner.NONE:
		return _fail("battle_over")
	var mark := events_log.size()
	_close_turn()
	return {"ok": true, "error": "", "events": events_log.slice(mark)}


func unit_by_id(id: int) -> BattleUnit:
	for u in units:
		if u.id == id:
			return u
	return null


func alive_units(side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.side == side and u.is_alive():
			out.append(u)
	return out


## Снимок состояния: для переподключения клиента и сохранения.
func to_dict() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append({
			"id": u.id, "side": u.side, "slot": u.slot, "hp": u.hp, "ap": u.ap, "mp": u.mp, "acted": u.acted,
			"flying": u.flying, "attack_pattern": u.attack_pattern, "moved": u.moved, "guarding": u.guarding, "stunned": u.stunned, "combo": u.combo,
			"combo_skill": u.combo_skill, "combo_skill_turn": u.combo_skill_turn,
			"stats": u.stats.to_dict(), "cooldowns": u.cooldowns.duplicate(),
		})
	return {
		"side": current_side, "round": round_number, "side_turns": side_turns.duplicate(), "active": active_ids.duplicate(),
		"acted": acted_count, "winner": winner, "units": us,
	}


func _begin_turn() -> void:
	side_turns[current_side] += 1
	var alive := alive_units(current_side)
	var missing := BattleRules.SLOTS_PER_SIDE - alive.size()
	var candidates: Array[BattleUnit] = []
	for u in alive:
		u.acted = false
		u.moved = false
		u.guarding = false
		u.hit_phys = false
		u.mp = mini(u.max_mp, u.mp + maxi(1, u.max_mp * rules.mp_regen_pct / 100))
		for sid in u.cooldowns.keys():
			u.cooldowns[sid] -= 1
			if u.cooldowns[sid] <= 0:
				u.cooldowns.erase(sid)
		if u.stunned:
			u.stunned = false
			u.combo = 0
			_emit({"type": "stun_ended", "unit": u.id})
			continue
		u.ap = clampi(u.ap + u.stat("ap_regen") + missing * rules.ap_gain_per_missing, rules.ap_min, rules.ap_max)
		if u.ap >= rules.ap_act_threshold:
			candidates.append(u)
	# Сильнейшие по AP; при равенстве раньше тот, у кого меньше слот, затем id.
	candidates.sort_custom(func(x: BattleUnit, y: BattleUnit) -> bool:
		if x.ap != y.ap:
			return x.ap > y.ap
		if x.slot != y.slot:
			return x.slot < y.slot
		return x.id < y.id)
	active_ids.clear()
	for i in mini(candidates.size(), rules.active_cap):
		active_ids.append(candidates[i].id)
	active_count = active_ids.size()
	acted_count = 0
	_emit({"type": "turn_started", "side": current_side, "round": round_number, "side_turns": side_turns.duplicate(), "active": active_ids.duplicate()})
	if active_ids.is_empty():
		idle_turns += 1
		if idle_turns >= rules.max_idle_turns:
			winner = Winner.DRAW
			_emit({"type": "battle_ended", "winner": winner})
			return
		_emit({"type": "turn_skipped", "side": current_side})
		_close_turn()


func _close_turn() -> void:
	for u in alive_units(current_side):
		var expired := u.stats.tick()
		if not expired.is_empty():
			_emit({"type": "modifiers_expired", "unit": u.id, "ids": expired})
	# Комбо: бойцы противника, получившие физический удар в этом ходу, копят счётчик.
	for u in alive_units(1 - current_side):
		if u.hit_phys:
			u.combo += 1
			if u.combo >= rules.stun_combo:
				u.combo = 0
				u.stunned = true
				_emit({"type": "stunned", "unit": u.id})
		else:
			u.combo = 0
		u.hit_phys = false
	_emit({"type": "turn_ended", "side": current_side})
	if current_side == BattleRules.SIDE_B:
		round_number += 1
		if round_number > rules.max_rounds:
			winner = Winner.DRAW
			_emit({"type": "battle_ended", "winner": winner})
			return
	current_side = 1 - current_side
	_begin_turn()


func _do_attack(actor: BattleUnit, action: Dictionary) -> String:
	if can_afford(actor.id) != "":
		return "no_ap"
	var target := unit_by_id(int(action.get("target", -1)))
	if target == null or not target.is_alive() or target.side == actor.side:
		return "bad_target"
	var hits := hit_set(actor.id, target.id)
	if hits.is_empty():
		return "unreachable"
	actor.ap = maxi(rules.ap_min, actor.ap - rules.attack_cost)
	var power := 100
	if actor.attack_pattern != "":
		var empty_slots := BattleRules.SLOTS_PER_SIDE - alive_units(actor.side).size()
		power += mini(empty_slots, rules.attack_empty_slot_cap) * rules.attack_empty_slot_pct
	for id in hits:
		var victim := unit_by_id(id)
		var physical := actor.attack_pattern != "staff"
		var hit := _deal_damage(actor, victim, power, physical)
		_emit({"type": "attack", "actor": actor.id, "target": id, "damage": hit.damage,
			"crit": hit.crit, "missed": hit.missed, "killed": not victim.is_alive(), "primary": id == target.id})
		if physical and not hit.missed and victim.is_alive() and actor.stat("multi_hit") > 0:
			var chance := actor.stat("multi_hit") + victim.combo * rules.multi_hit_combo_pct
			if _roll_chance(chance):
				var extra := _deal_damage(actor, victim, power * rules.multi_hit_power_pct / 100, true)
				_emit({"type": "damage", "source": actor.id, "target": id, "damage": extra.damage,
					"crit": extra.crit, "missed": extra.missed, "killed": not victim.is_alive(), "multi_hit": true})
	return ""


func _do_skill(actor: BattleUnit, action: Dictionary) -> String:
	var sid := str(action.get("skill", ""))
	if not skills.has(sid) or not actor.skill_ids.has(sid):
		return "unknown_skill"
	var sk: SkillDef = skills[sid]
	if actor.cooldowns.has(sid):
		return "on_cooldown"
	var afford := can_afford(actor.id, sid)
	if afford != "":
		return afford
	var targets: Array[BattleUnit] = []
	if sk.target == SkillDef.Target.SELF:
		targets.append(actor)
	elif sk.target == SkillDef.Target.ENEMY_ALL:
		for u in alive_units(1 - actor.side):
			if can_hit_with_skill(actor, sk, u):
				targets.append(u)
	elif sk.target == SkillDef.Target.ALLY_ALL:
		targets = alive_units(actor.side)
	else:
		var t := unit_by_id(int(action.get("target", -1)))
		if t == null:
			return "bad_target"
		if sk.target == SkillDef.Target.ALLY_DEAD:
			if not _can_revive(actor, t):
				return "bad_target"
			targets.append(t)
		elif not t.is_alive():
			return "bad_target"
		elif sk.targets_enemies():
			if t.side == actor.side:
				return "bad_target"
			if not can_hit_with_skill(actor, sk, t) or (not sk.ranged and t.column() != _front_column(t.side)):
				return "unreachable"
			if sk.target == SkillDef.Target.ENEMY_COLUMN:
				for u in alive_units(t.side):
					if u.column() == t.column() and can_hit_with_skill(actor, sk, u):
						targets.append(u)
			else:
				targets.append(t)
		else:
			if t.side != actor.side:
				return "bad_target"
			targets.append(t)
	actor.ap = maxi(rules.ap_min, actor.ap - sk.cost_ap)
	actor.mp -= sk.cost_mp
	if sk.cooldown > 0:
		actor.cooldowns[sid] = sk.cooldown + 1
	var level := int(actor.skill_levels.get(sid, 1))
	var power := sk.power_pct * (100 + _skill_level_bonus_pct(level)) / 100
	_emit({"type": "skill", "actor": actor.id, "skill": sid, "targets": targets.map(func(u): return u.id)})
	for t in targets:
		match sk.effect:
			SkillDef.Effect.DAMAGE:
				var combo := would_combo(actor, sk, t)
				var hit := _deal_damage(actor, t, power + (sk.combo_bonus_pct if combo else 0), not sk.magic)
				if not hit.missed:
					_mark_skill(actor, sk, t)
				_emit({"type": "damage", "source": actor.id, "target": t.id, "damage": hit.damage,
					"crit": hit.crit, "missed": hit.missed, "killed": not t.is_alive(), "combo": combo and not hit.missed})
			SkillDef.Effect.HEAL:
				var amount := _skill_attack(actor, not sk.magic) * power / 100
				var before := t.hp
				t.hp = mini(t.max_hp, t.hp + amount)
				_emit({"type": "heal", "source": actor.id, "target": t.id, "amount": t.hp - before})
			SkillDef.Effect.REVIVE:
				t.hp = clampi(t.max_hp * power / 100, 1, t.max_hp)
				t.ap = 0
				t.acted = true
				t.stunned = false
				t.guarding = false
				t.combo = 0
				t.hit_phys = false
				t.combo_skill = ""
				t.combo_skill_turn = -1
				t.stats.clear_temporary()
				_emit({"type": "revive", "source": actor.id, "target": t.id, "hp": t.hp})
			SkillDef.Effect.MODIFY:
				if sk.targets_enemies():
					_mark_skill(actor, sk, t)
				t.stats.add_modifier(sk.id, sk.mod_stat, sk.mod_kind, sk.mod_value, sk.mod_turns, actor.id)
				_emit({"type": "modify", "source": actor.id, "target": t.id, "stat": sk.mod_stat, "value": sk.mod_value, "turns": sk.mod_turns})
	return ""


func would_combo(actor: BattleUnit, skill: SkillDef, target: BattleUnit) -> bool:
	return (skill.combo_from != "" and target.combo_skill == skill.combo_from
		and target.combo_skill_turn == side_turns[actor.side])


func _mark_skill(actor: BattleUnit, skill: SkillDef, target: BattleUnit) -> void:
	target.combo_skill = skill.id
	target.combo_skill_turn = side_turns[actor.side]


func _skill_attack(actor: BattleUnit, physical: bool) -> int:
	if physical or actor.attack_pattern == "staff":
		return actor.stat("atk")
	return actor.stat("atk") + actor.stat("intelligence")


func _roll_chance(chance: int) -> bool:
	return chance >= 100 or (chance > 0 and _rng.randi_range(1, 100) <= chance)


## Прирост силы навыка за уровень навыка (в процентах), берётся из BattleRules.
func _skill_level_bonus_pct(level: int) -> int:
	return (level - 1) * rules.skill_power_per_level_pct


## Расчёт урона: сила в процентах от атаки, защита, разброс, критический удар. Порядок бросков фиксирован.
func _deal_damage(actor: BattleUnit, target: BattleUnit, power_pct: int, physical: bool) -> Dictionary:
	if physical and not _roll_chance(rules.hit_chance_pct + actor.stat("accuracy") - target.stat("evasion")):
		return {"damage": 0, "crit": false, "missed": true}
	var raw := _skill_attack(actor, physical) * power_pct / 100
	var def := target.stat("def" if physical else "magic_def")
	if target.guarding:
		def = def * (100 + rules.guard_def_pct) / 100
	var base := raw * rules.def_scale / (rules.def_scale + def)
	var roll := 100
	if rules.variance_pct > 0:
		roll = _rng.randi_range(100 - rules.variance_pct, 100 + rules.variance_pct)
	var dmg := base * roll / 100
	var crit := _roll_chance(rules.crit_chance_pct + actor.stat("crit") - target.stat("crit_resist"))
	if crit:
		dmg = dmg * rules.crit_mult_pct / 100
	dmg = maxi(1, dmg)
	target.hp = maxi(0, target.hp - dmg)
	if physical:
		target.hit_phys = true
	return {"damage": dmg, "crit": crit, "missed": false}


func _do_move(actor: BattleUnit, action: Dictionary) -> String:
	var slot := int(action.get("slot", -1))
	if slot < 0 or slot >= BattleRules.SLOTS_PER_SIDE or slot == actor.slot:
		return "bad_slot"
	if actor.moved:
		return "already_moved"
	if actor.ap < rules.ap_act_threshold:
		return "no_ap"
	actor.moved = true
	actor.ap = maxi(rules.ap_min, actor.ap - rules.move_cost)
	var other: BattleUnit = null
	for u in alive_units(actor.side):
		if u.slot == slot:
			other = u
	var from := actor.slot
	actor.slot = slot
	if other != null:
		other.slot = from
	_emit({"type": "move", "actor": actor.id, "from": from, "to": slot, "swapped": other.id if other != null else -1})
	return ""


## Передняя занятая колонка стороны: ближняя атака бьёт только по ней.
func _front_column(side: int) -> int:
	var best := BattleRules.GRID_COLS
	for u in alive_units(side):
		best = mini(best, u.column())
	return best


## Сторона проиграла, если погиб её герой (если герой есть) либо никого не осталось.
func side_lost(side: int) -> bool:
	var has_hero := false
	for u in units:
		if u.side == side and u.is_hero:
			has_hero = true
			if u.is_alive():
				return false
	return has_hero or alive_units(side).is_empty()


func _check_victory() -> void:
	var a := side_lost(BattleRules.SIDE_A)
	var b := side_lost(BattleRules.SIDE_B)
	if a and b:
		winner = Winner.DRAW
	elif b:
		winner = Winner.SIDE_A
	elif a:
		winner = Winner.SIDE_B
	if winner != Winner.NONE:
		_emit({"type": "battle_ended", "winner": winner})


func _emit(e: Dictionary) -> void:
	events_log.append(e)


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code, "events": []}
