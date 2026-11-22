class_name Inventory
extends RefCounted
## Сумка игрока: экипировка (ограниченное число мест) и материалы (стеки).

var gd: GameData
var items: Array[Item] = []
var materials: Dictionary = {}
var _next_uid := 1


func _init(p_gd: GameData) -> void:
	gd = p_gd


func capacity() -> int:
	return int(gd.rules["inventory_capacity"])


func is_full() -> bool:
	return items.size() >= capacity()


func item_by_uid(uid: int) -> Item:
	for i in items:
		if i.uid == uid:
			return i
	return null


func material_count(id: String) -> int:
	return int(materials.get(id, 0))


## Создать экипировку и положить в сумку. null, если нет места или тип неизвестен.
func add_equipment(def_id: String) -> Item:
	if not gd.items.has(def_id) or not (gd.items[def_id] as ItemDef).is_equip() or is_full():
		return null
	var it := Item.new(_next_uid, def_id)
	_next_uid += 1
	items.append(it)
	return it


## Вернуть в сумку уже существующий предмет (например, снятый с наёмника).
func put_back(it: Item) -> bool:
	if is_full():
		return false
	items.append(it)
	return true


## Добавить материал. Возвращает сколько реально добавлено (стек ограничен).
func add_material(id: String, count: int) -> int:
	if not gd.items.has(id) or (gd.items[id] as ItemDef).kind != "material" or count <= 0:
		return 0
	var cap := int(gd.rules["material_stack_max"])
	var before := material_count(id)
	materials[id] = mini(cap, before + count)
	return int(materials[id]) - before


func take_material(id: String, count: int) -> bool:
	if material_count(id) < count:
		return false
	materials[id] -= count
	if materials[id] == 0:
		materials.erase(id)
	return true


## Принять результат броска добычи ([{"item": id, "count": n}]). Что не поместилось, возвращается.
func add_drops(drops: Array) -> Array:
	var lost: Array = []
	for d in drops:
		var def: ItemDef = gd.items[d["item"]]
		if def.is_equip():
			for n in int(d["count"]):
				if add_equipment(d["item"]) == null:
					lost.append({"item": d["item"], "count": 1})
		else:
			var added := add_material(d["item"], int(d["count"]))
			if added < int(d["count"]):
				lost.append({"item": d["item"], "count": int(d["count"]) - added})
	return lost
