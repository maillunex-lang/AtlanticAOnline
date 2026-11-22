class_name RecruitPack
extends RefCounted
## Платный набор со случайным результатом. Шансы публикуются через odds() и должны показываться игроку.
## Гарантия: после pity_after безуспешных попыток выпадает продвинутый наёмник.
## Бросок выполняет только сервер (клиенту результат не доверяем).

class State extends RefCounted:
	var pulls_since_advanced := 0

	func to_dict() -> Dictionary:
		return {"pulls_since_advanced": pulls_since_advanced}


static func find_pack(gd: GameData, pack_id: String) -> Dictionary:
	for p in gd.rules.get("packs", []):
		if p["id"] == pack_id:
			return p
	return {}


## Шансы в процентах для показа игроку. Учитывает гарантию.
static func odds(pack: Dictionary, state: State) -> Dictionary:
	if state.pulls_since_advanced >= int(pack["pity_after"]) - 1:
		return {"basic": 0, "advanced": 100, "guaranteed": true}
	var w: Dictionary = pack["weights"]
	var total := 0
	for k in w:
		total += int(w[k])
	return {"basic": float(w["basic"]) * 100.0 / total, "advanced": float(w["advanced"]) * 100.0 / total, "guaranteed": false}


static func roll(pack: Dictionary, state: State, rng: RandomNumberGenerator) -> String:
	var tier := "basic"
	if state.pulls_since_advanced >= int(pack["pity_after"]) - 1:
		tier = "advanced"
	else:
		var w: Dictionary = pack["weights"]
		var r := rng.randi_range(1, int(w["basic"]) + int(w["advanced"]))
		tier = "basic" if r <= int(w["basic"]) else "advanced"
	state.pulls_since_advanced = 0 if tier == "advanced" else state.pulls_since_advanced + 1
	var pool: Array = pack["pool"][tier]
	return str(pool[rng.randi_range(0, pool.size() - 1)])
