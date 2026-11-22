class_name PartyService
extends RefCounted
## Реестр групп: один игрок состоит максимум в одной группе. Группа из одного человека распадается.

var gd: GameData
var parties: Dictionary = {}
var _of: Dictionary = {}
var _next := 1


func _init(p_gd: GameData) -> void:
	gd = p_gd


func party_of(pid: String) -> Party:
	return parties.get(_of.get(pid, ""))


func create(leader: String) -> Dictionary:
	if _of.has(leader):
		return {"ok": false, "error": "already_in_party"}
	var p := Party.new("p%d" % _next, leader, gd)
	_next += 1
	parties[p.id] = p
	_of[leader] = p.id
	return {"ok": true, "error": "", "party": p}


func invite(by: String, target: String) -> Dictionary:
	var p := party_of(by)
	if p == null:
		return {"ok": false, "error": "no_party"}
	if _of.has(target):
		return {"ok": false, "error": "target_in_party"}
	return p.invite(by, target)


func accept(pid: String, party_id: String) -> Dictionary:
	if _of.has(pid):
		return {"ok": false, "error": "already_in_party"}
	var p: Party = parties.get(party_id)
	if p == null:
		return {"ok": false, "error": "no_party"}
	var r := p.accept(pid)
	if r.ok:
		_of[pid] = party_id
	return r


func kick(by: String, target: String) -> Dictionary:
	var p := party_of(by)
	if p == null:
		return {"ok": false, "error": "no_party"}
	var r := p.kick(by, target)
	if r.ok:
		_of.erase(target)
	return r


func leave(pid: String) -> bool:
	var p := party_of(pid)
	if p == null:
		return false
	var disband := p.leave(pid)
	_of.erase(pid)
	if disband:
		for m in p.members:
			_of.erase(m)
		parties.erase(p.id)
	return true
