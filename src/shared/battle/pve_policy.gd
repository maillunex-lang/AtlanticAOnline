class_name PvePolicy
extends RefCounted
## Состояние лицензий и очков PvE на игровую сессию.

var config: Dictionary
var auto_points: int
var auto_pass_used := false
var any_auto_used := false
var _battle_open := false


func _init(p_config: Dictionary) -> void:
	config = p_config
	auto_points = int(config["auto_start_points"])


func begin_battle() -> void:
	_battle_open = true
	auto_pass_used = false
	any_auto_used = false


func enable_full_auto(licensed: bool) -> bool:
	if not _battle_open or not licensed:
		return false
	if auto_pass_used:
		return true
	var cost := int(config["auto_cost"])
	if auto_points < cost:
		return false
	auto_points -= cost
	auto_pass_used = true
	return true


func finish_battle(result: String) -> void:
	if not _battle_open:
		return
	_battle_open = false
	if result in ["win", "lose", "draw"] and not any_auto_used and not auto_pass_used:
		auto_points = mini(int(config["auto_points_cap"]), auto_points + int(config["auto_manual_reward"]))


func apply_losses(squad: Squad, wallet: Dictionary, sim: BattleSim, result: String, blessed: bool) -> Dictionary:
	var losses := {"coins": 0, "xp": 0}
	if blessed or result == "draw":
		return losses
	var defeat := result in ["lose", "flee"]
	var percent := int(config["loss_pct"])
	if defeat:
		losses.coins = maxi(0, int(wallet.get("coins", 0))) * percent / 100
		wallet["coins"] = int(wallet.get("coins", 0)) - int(losses.coins)
	for unit in sim.units:
		if unit.side != BattleRules.SIDE_A or not unit.participated or (not defeat and unit.is_alive()):
			continue
		var merc := squad.hero if unit.is_hero else squad.by_uid(unit.id - 1)
		if merc != null:
			var amount := Progression.death_loss(merc.level, merc.xp, squad.gd, merc.xp_table(squad.gd))
			merc.xp -= amount
			losses.xp += amount
	return losses


func victory_xp(amount: int, blessed: bool) -> int:
	return amount * (100 + int(config["blessing_xp_pct"])) / 100 if blessed else amount
