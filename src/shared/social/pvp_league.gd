class_name PvpLeague
extends RefCounted
## Лига PvP: ступени 1..N. Победы подряд повышают ступень, поражения подряд понижают.
## Нужное число побед и поражений зависит от ступени (data/social.json). Ничья серий не меняет.
## Идея лестницы с сериями подсмотрена у лиг оригинальной игры, числа свои.

class State extends RefCounted:
	var tier := 1
	var win_streak := 0
	var loss_streak := 0
	var wins := 0
	var losses := 0
	var draws := 0


## Применить результат матча. Возвращает "promoted", "demoted" или "".
static func apply_result(st: State, result: String, gd: GameData) -> String:
	var p: Dictionary = gd.social["pvp"]
	match result:
		"win":
			st.wins += 1
			st.win_streak += 1
			st.loss_streak = 0
			var need := int((p["up_wins"] as Array)[st.tier - 1])
			if need > 0 and st.win_streak >= need:
				st.tier += 1
				st.win_streak = 0
				return "promoted"
		"loss":
			st.losses += 1
			st.loss_streak += 1
			st.win_streak = 0
			var need_down := int((p["down_losses"] as Array)[st.tier - 1])
			if need_down > 0 and st.loss_streak >= need_down:
				st.tier -= 1
				st.loss_streak = 0
				return "demoted"
		"draw":
			st.draws += 1
	return ""


static func reward_coins(result: String, gd: GameData) -> int:
	return int(gd.social["pvp"]["reward_coins"].get(result, 0))
