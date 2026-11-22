class_name Party
extends RefCounted
## Группа до max_size игроков (по умолчанию 3, как лимит подземелий). Лидер приглашает, исключает и передаёт руководство.
## Бонус опыта растёт с числом участников.

var id := ""
var leader := ""
var members: Array[String] = []
var gd: GameData
var _invites: Dictionary = {}


func _init(p_id: String, p_leader: String, p_gd: GameData) -> void:
	id = p_id
	leader = p_leader
	gd = p_gd
	members.append(p_leader)


func max_size() -> int:
	return int(gd.social["party"]["max_size"])


func has_member(pid: String) -> bool:
	return members.has(pid)


func invite(by: String, target: String) -> Dictionary:
	if by != leader:
		return _fail("not_leader")
	if has_member(target):
		return _fail("already_member")
	if members.size() >= max_size():
		return _fail("party_full")
	_invites[target] = true
	return {"ok": true, "error": ""}


## Принять приглашение. Вызывающий должен сам проверить, что игрок не состоит в другой группе (это делает PartyService).
func accept(pid: String) -> Dictionary:
	if not _invites.has(pid):
		return _fail("no_invite")
	if members.size() >= max_size():
		return _fail("party_full")
	_invites.erase(pid)
	members.append(pid)
	return {"ok": true, "error": ""}


func has_invite(pid: String) -> bool:
	return _invites.has(pid)


func kick(by: String, target: String) -> Dictionary:
	if by != leader:
		return _fail("not_leader")
	if target == leader or not has_member(target):
		return _fail("bad_target")
	members.erase(target)
	return {"ok": true, "error": ""}


func transfer(by: String, target: String) -> Dictionary:
	if by != leader:
		return _fail("not_leader")
	if target == leader or not has_member(target):
		return _fail("bad_target")
	leader = target
	return {"ok": true, "error": ""}


## Выход. Если уходит лидер, руководство получает следующий по очереди. Возвращает true, если группа распалась.
func leave(pid: String) -> bool:
	if not has_member(pid):
		return false
	members.erase(pid)
	if members.is_empty():
		return true
	if leader == pid:
		leader = members[0]
	return members.size() < 2


func xp_bonus_pct() -> int:
	return (members.size() - 1) * int(gd.social["party"]["xp_bonus_pct_per_extra_member"])


## Опыт участнику с учётом бонуса группы.
func xp_for(base_xp: int) -> int:
	return base_xp * (100 + xp_bonus_pct()) / 100


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
