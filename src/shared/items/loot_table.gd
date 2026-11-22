class_name LootTable
extends RefCounted
## Таблицы добычи: взвешенные записи, несколько бросков. Бросок делает только сервер.
## Шансы публикуются игроку через odds(). Идея взята у Lootie (MIT), код написан заново.


static func find(gd: GameData, table_id: String) -> Dictionary:
	for t in gd.loot:
		if t["id"] == table_id:
			return t
	return {}


## Шанс каждой записи за ОДИН бросок в процентах (запись с пустым item означает «ничего»).
static func odds(table: Dictionary) -> Array[Dictionary]:
	var total := _total(table)
	var out: Array[Dictionary] = []
	for e in table["entries"]:
		out.append({"item": e["item"], "percent": float(e["weight"]) * 100.0 / total})
	return out


## Результат: [{"item": id, "count": n}]. Одинаковые предметы из разных бросков суммируются.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> Array:
	var total := _total(table)
	var sums := {}
	var order: Array[String] = []
	for r in int(table["rolls"]):
		var pick := rng.randi_range(1, total)
		for e in table["entries"]:
			pick -= int(e["weight"])
			if pick <= 0:
				if e["item"] != "":
					var n := rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
					if not sums.has(e["item"]):
						order.append(e["item"])
					sums[e["item"]] = int(sums.get(e["item"], 0)) + n
				break
	var out: Array = []
	for id in order:
		out.append({"item": id, "count": sums[id]})
	return out


## Копит выбранный материал отдельно. При пороге возвращает накопленное с бонусом.
static func apply_jackpot(drops: Array, selected: String, bank: Dictionary, rules: Dictionary) -> Array:
	if selected not in rules["jackpot_items"]:
		return drops.duplicate(true)
	var out: Array = []
	var amount := int(bank.get(selected, 0))
	for drop in drops:
		if drop["item"] == selected:
			amount += int(drop["count"])
		else:
			out.append(drop)
	if amount >= int(rules["jackpot_threshold"]):
		out.append({"item": selected, "count": amount * (100 + int(rules["jackpot_bonus_pct"])) / 100})
		amount = 0
	bank[selected] = amount
	return out


static func _total(table: Dictionary) -> int:
	var t := 0
	for e in table["entries"]:
		t += int(e["weight"])
	return t
