class_name StatBlock
extends RefCounted
## Лист статов: базовые значения и стекающиеся модификаторы. Без узлов сцены, детерминированный.
## Итог = (база + сумма плоских) * (100 + сумма процентов) / 100, не меньше 0.
## Модификатор с тем же id и статом заменяет прежний (обновляет срок), разные id суммируются.
## turns: сколько ходов СВОЕЙ стороны модификатор переживает (счёт в конце хода стороны), -1 бессрочно.

enum Kind { FLAT, PERCENT }

const MIN_PERCENT := -90

class Modifier extends RefCounted:
	var id := ""
	var stat := ""
	var kind := Kind.FLAT
	var value := 0
	var turns := -1
	var source := -1

	func to_dict() -> Dictionary:
		return {"id": id, "stat": stat, "kind": kind, "value": value, "turns": turns, "source": source}

var base: Dictionary = {}
var _mods: Array[Modifier] = []


func _init(p_base: Dictionary = {}) -> void:
	for k in p_base:
		base[str(k)] = int(p_base[k])


func add_modifier(id: String, stat: String, kind: int, value: int, turns := -1, source := -1) -> void:
	remove_modifier(id, stat)
	var m := Modifier.new()
	m.id = id
	m.stat = stat
	m.kind = kind
	m.value = value
	m.turns = turns
	m.source = source
	_mods.append(m)


func remove_modifier(id: String, stat := "") -> int:
	var removed := 0
	for i in range(_mods.size() - 1, -1, -1):
		if _mods[i].id == id and (stat == "" or _mods[i].stat == stat):
			_mods.remove_at(i)
			removed += 1
	return removed


func clear_temporary() -> void:
	for i in range(_mods.size() - 1, -1, -1):
		if _mods[i].turns > 0:
			_mods.remove_at(i)


## Снять временные модификаторы: положительные (бафы) или отрицательные (дебафы). Возвращает число снятых.
func dispel(positive: bool) -> int:
	var removed := 0
	for i in range(_mods.size() - 1, -1, -1):
		if _mods[i].turns > 0 and ((_mods[i].value > 0) == positive) and _mods[i].value != 0:
			_mods.remove_at(i)
			removed += 1
	return removed


func modifier_count() -> int:
	return _mods.size()


func has_modifier(id: String) -> bool:
	for m in _mods:
		if m.id == id:
			return true
	return false


func value(stat: String) -> int:
	var flat := 0
	var pct := 0
	for m in _mods:
		if m.stat != stat:
			continue
		if m.kind == Kind.FLAT:
			flat += m.value
		else:
			pct += m.value
	pct = maxi(pct, MIN_PERCENT)
	return maxi(0, (int(base.get(stat, 0)) + flat) * (100 + pct) / 100)


## Конец хода владельца: уменьшить сроки, убрать истёкшие. Возвращает id убранных.
func tick() -> Array[String]:
	var expired: Array[String] = []
	for i in range(_mods.size() - 1, -1, -1):
		var m := _mods[i]
		if m.turns > 0:
			m.turns -= 1
			if m.turns == 0:
				expired.append(m.id)
				_mods.remove_at(i)
	return expired


func to_dict() -> Dictionary:
	var arr: Array = []
	for m in _mods:
		arr.append(m.to_dict())
	return {"base": base.duplicate(), "mods": arr}
