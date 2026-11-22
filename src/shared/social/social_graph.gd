class_name SocialGraph
extends RefCounted
## Друзья, заявки в друзья и чёрный список. Дружба взаимная. Блокировка убирает дружбу и заявки в обе стороны.

var gd: GameData
var _friends: Dictionary = {}
var _incoming: Dictionary = {}
var _blocked: Dictionary = {}


func _init(p_gd: GameData) -> void:
	gd = p_gd


func friends_of(pid: String) -> Array:
	return (_friends.get(pid, {}) as Dictionary).keys()


func requests_for(pid: String) -> Array:
	return (_incoming.get(pid, {}) as Dictionary).keys()


func blocked_by(pid: String) -> Array:
	return (_blocked.get(pid, {}) as Dictionary).keys()


func are_friends(a: String, b: String) -> bool:
	return (_friends.get(a, {}) as Dictionary).has(b)


## True, если blocker заблокировал target.
func is_blocked(blocker: String, target: String) -> bool:
	return (_blocked.get(blocker, {}) as Dictionary).has(target)


func request(from: String, to: String) -> Dictionary:
	if from == to:
		return _fail("self")
	if is_blocked(to, from) or is_blocked(from, to):
		return _fail("blocked")
	if are_friends(from, to):
		return _fail("already_friends")
	var limit := int(gd.social["friends"]["max_friends"])
	if friends_of(from).size() >= limit:
		return _fail("friend_limit")
	if (_incoming.get(from, {}) as Dictionary).has(to):
		return accept(from, to)  # встречные заявки сразу превращаются в дружбу
	if (_incoming.get(to, {}) as Dictionary).has(from):
		return _fail("already_requested")
	if requests_for(to).size() >= int(gd.social["friends"]["max_requests"]):
		return _fail("target_inbox_full")
	_put(_incoming, to, from)
	return {"ok": true, "error": "", "friends": false}


## accepter принимает заявку от requester.
func accept(accepter: String, requester: String) -> Dictionary:
	if not (_incoming.get(accepter, {}) as Dictionary).has(requester):
		return _fail("no_request")
	var limit := int(gd.social["friends"]["max_friends"])
	if friends_of(accepter).size() >= limit or friends_of(requester).size() >= limit:
		return _fail("friend_limit")
	(_incoming[accepter] as Dictionary).erase(requester)
	_put(_friends, accepter, requester)
	_put(_friends, requester, accepter)
	return {"ok": true, "error": "", "friends": true}


func decline(decliner: String, requester: String) -> bool:
	return (_incoming.get(decliner, {}) as Dictionary).erase(requester)


func remove_friend(a: String, b: String) -> bool:
	if not are_friends(a, b):
		return false
	(_friends[a] as Dictionary).erase(b)
	(_friends[b] as Dictionary).erase(a)
	return true


func block(blocker: String, target: String) -> Dictionary:
	if blocker == target:
		return _fail("self")
	if blocked_by(blocker).size() >= int(gd.social["friends"]["max_blocked"]):
		return _fail("block_limit")
	remove_friend(blocker, target)
	(_incoming.get(blocker, {}) as Dictionary).erase(target)
	(_incoming.get(target, {}) as Dictionary).erase(blocker)
	_put(_blocked, blocker, target)
	return {"ok": true, "error": ""}


func unblock(blocker: String, target: String) -> bool:
	return (_blocked.get(blocker, {}) as Dictionary).erase(target)


func _put(store: Dictionary, key: String, value: String) -> void:
	if not store.has(key):
		store[key] = {}
	(store[key] as Dictionary)[value] = true


func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}
