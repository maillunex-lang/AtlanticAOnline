class_name GuildService
extends RefCounted
## Гильдии: создание за монеты, роли, приглашения, казна, уровень гильдии по вкладам. Один игрок в одной гильдии.
## Роли: leader (один), officer, member. Осады и владение городами отнесены к следующему этапу.

const ROLE_ORDER := {"member": 0, "officer": 1, "leader": 2}

class Guild extends RefCounted:
	var id := ""
	var name := ""
	var members: Dictionary = {}
	var level := 1
	var xp := 0
	var treasury := 0
	var invites: Dictionary = {}

	func leader() -> String:
		for pid in members:
			if members[pid] == "leader":
				return pid
		return ""

var gd: GameData
var guilds: Dictionary = {}
var _of: Dictionary = {}
var _names: Dictionary = {}
var _next := 1


func _init(p_gd: GameData) -> void:
	gd = p_gd


func _r() -> Dictionary:
	return gd.social["guild"]


func guild_of(pid: String) -> Guild:
	return guilds.get(_of.get(pid, ""))


func role_of(pid: String) -> String:
	var g := guild_of(pid)
	return "" if g == null else str(g.members[pid])


func member_cap(g: Guild) -> int:
	return int((_r()["member_caps"] as Array)[g.level - 1])


func create(leader: String, name: String, level: int, wallet: Dictionary) -> Dictionary:
	var n := name.strip_edges()
	if _of.has(leader):
		return _fail("already_in_guild")
	if level < int(_r()["create_min_level"]):
		return _fail("level_too_low")
	if n.length() < int(_r()["name_min"]) or n.length() > int(_r()["name_max"]):
		return _fail("bad_name")
	if _names.has(n.to_lower()):
		return _fail("name_taken")
	if int(wallet.get("coins", 0)) < int(_r()["create_cost"]):
		return _fail("no_coins")
	wallet["coins"] -= int(_r()["create_cost"])
	var g := Guild.new()
	g.id = "g%d" % _next
	_next += 1
	g.name = n
	g.members[leader] = "leader"
	guilds[g.id] = g
	_of[leader] = g.id
	_names[n.to_lower()] = g.id
	return {"ok": true, "error": "", "guild": g}


func invite(by: String, target: String) -> Dictionary:
	var g := guild_of(by)
	if g == null:
		return _fail("no_guild")
	if ROLE_ORDER[g.members[by]] < ROLE_ORDER["officer"]:
		return _fail("no_permission")
	if _of.has(target):
		return _fail("target_in_guild")
	if g.members.size() >= member_cap(g):
		return _fail("guild_full")
	g.invites[target] = true
	return {"ok": true, "error": ""}


func accept(pid: String, guild_id: String) -> Dictionary:
	if _of.has(pid):
		return _fail("already_in_guild")
	var g: Guild = guilds.get(guild_id)
	if g == null or not g.invites.has(pid):
		return _fail("no_invite")
	if g.members.size() >= member_cap(g):
		return _fail("guild_full")
	g.invites.erase(pid)
	g.members[pid] = "member"
	_of[pid] = g.id
	return {"ok": true, "error": ""}


## Исключить. Офицер исключает рядовых, лидер любого, кроме себя.
func kick(by: String, target: String) -> Dictionary:
	var g := guild_of(by)
	if g == null or guild_of(target) != g:
		return _fail("bad_target")
	if by == target:
		return _fail("bad_target")
	if ROLE_ORDER[g.members[by]] <= ROLE_ORDER[g.members[target]] or ROLE_ORDER[g.members[by]] < ROLE_ORDER["officer"]:
		return _fail("no_permission")
	g.members.erase(target)
	_of.erase(target)
	return {"ok": true, "error": ""}


func set_role(by: String, target: String, role: String) -> Dictionary:
	var g := guild_of(by)
	if g == null or guild_of(target) != g or by == target or not ["officer", "member"].has(role):
		return _fail("bad_target")
	if g.members[by] != "leader":
		return _fail("no_permission")
	g.members[target] = role
	return {"ok": true, "error": ""}


func transfer_leadership(by: String, target: String) -> Dictionary:
	var g := guild_of(by)
	if g == null or guild_of(target) != g or by == target:
		return _fail("bad_target")
	if g.members[by] != "leader":
		return _fail("no_permission")
	g.members[by] = "officer"
	g.members[target] = "leader"
	return {"ok": true, "error": ""}


## Выход. Лидер может уйти, только если в гильдии больше никого (гильдия распускается), иначе сначала передаёт руководство.
func leave(pid: String) -> Dictionary:
	var g := guild_of(pid)
	if g == null:
		return _fail("no_guild")
	if g.members[pid] == "leader":
		if g.members.size() > 1:
			return _fail("transfer_first")
		return disband(pid)
	g.members.erase(pid)
	_of.erase(pid)
	return {"ok": true, "error": ""}


func disband(by: String) -> Dictionary:
	var g := guild_of(by)
	if g == null or g.members[by] != "leader":
		return _fail("no_permission")
	for pid in g.members:
		_of.erase(pid)
	_names.erase(g.name.to_lower())
	guilds.erase(g.id)
	return {"ok": true, "error": ""}


## Вклад монет в казну. Часть вклада превращается в опыт гильдии.
func deposit(pid: String, coins: int, wallet: Dictionary) -> Dictionary:
	var g := guild_of(pid)
	if g == null:
		return _fail("no_guild")
	if coins < int(_r()["deposit_min"]):
		return _fail("too_small")
	if int(wallet.get("coins", 0)) < coins:
		return _fail("no_coins")
	wallet["coins"] -= coins
	g.treasury += coins
	add_xp(g, coins * int(_r()["xp_per_coin_pct"]) / 100)
	return {"ok": true, "error": ""}


## Забрать из казны могут лидер и офицеры.
func withdraw(pid: String, coins: int, wallet: Dictionary) -> Dictionary:
	var g := guild_of(pid)
	if g == null:
		return _fail("no_guild")
	if ROLE_ORDER[g.members[pid]] < ROLE_ORDER["officer"]:
		return _fail("no_permission")
	if coins <= 0 or coins > g.treasury:
		return _fail("no_funds")
	g.treasury -= coins
	wallet["coins"] = int(wallet.get("coins", 0)) + coins
	return {"ok": true, "error": ""}


func add_xp(g: Guild, amount: int) -> void:
	g.xp += maxi(0, amount)
	var thresholds: Array = _r()["levels_xp"]
	while g.level < thresholds.size() and g.xp >= int(thresholds[g.level]):
		g.level += 1


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
