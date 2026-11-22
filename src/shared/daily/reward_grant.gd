class_name RewardGrant
extends RefCounted
## Выдача награды {"xp", "coins", "items": {id: n}} целиком или не выдача вовсе (общая для заданий, входа, событий).
## ctx: {"inv": Inventory, "squad": Squad (необязательно), "wallet": Dictionary, "level": int}.


## Сколько ячеек сумки займёт награда (материалы место не занимают).
static func slots_needed(gd: GameData, reward: Dictionary) -> int:
	var n := 0
	for id in reward.get("items", {}):
		if (gd.items[id] as ItemDef).is_equip():
			n += int(reward["items"][id])
	return n


static func fits(gd: GameData, inv: Inventory, reward: Dictionary) -> bool:
	return inv.items.size() + slots_needed(gd, reward) <= inv.capacity()


## Выдать награду. Возвращает false и ничего не меняет, если в сумке нет места.
static func apply(gd: GameData, ctx: Dictionary, reward: Dictionary) -> bool:
	var inv: Inventory = ctx["inv"]
	if not fits(gd, inv, reward):
		return false
	var wallet: Dictionary = ctx["wallet"]
	wallet["coins"] = int(wallet.get("coins", 0)) + int(reward.get("coins", 0))
	var drops: Array = []
	for id in reward.get("items", {}):
		drops.append({"item": id, "count": int(reward["items"][id])})
	inv.add_drops(drops)
	if ctx.get("squad") != null and int(reward.get("xp", 0)) > 0:
		(ctx["squad"] as Squad).award_battle_xp(int(reward["xp"]))
	return true


static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	out["xp"] = int(a.get("xp", 0)) + int(b.get("xp", 0))
	out["coins"] = int(a.get("coins", 0)) + int(b.get("coins", 0))
	var items: Dictionary = (out.get("items", {}) as Dictionary).duplicate()
	for id in b.get("items", {}):
		items[id] = int(items.get(id, 0)) + int(b["items"][id])
	if not items.is_empty():
		out["items"] = items
	return out
