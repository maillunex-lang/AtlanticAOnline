extends GdUnitTestSuite

var gd: GameData
var ps: PartyService
var gs: GuildService


func before_test() -> void:
	gd = GameData.load_dir()
	ps = PartyService.new(gd)
	gs = GuildService.new(gd)


func _party(leader := "a") -> Party:
	return ps.create(leader).party


func test_party_create_invite_accept() -> void:
	var p := _party()
	assert_str(ps.create("a").error).is_equal("already_in_party")
	assert_str(ps.invite("b", "c").error).is_equal("no_party")
	assert_bool(ps.invite("a", "b").ok).is_true()
	assert_str(ps.accept("c", p.id).error).is_equal("no_invite")
	assert_bool(ps.accept("b", p.id).ok).is_true()
	assert_array(p.members).is_equal(["a", "b"])
	assert_str(ps.accept("b", p.id).error).is_equal("already_in_party")


func test_party_size_limit_and_one_party_per_player() -> void:
	var p := _party()
	for n in ["b", "c"]:
		ps.invite("a", n)
		ps.accept(n, p.id)
	assert_str(ps.invite("a", "d").error).is_equal("party_full")
	var other: Party = ps.create("x").party
	assert_str(ps.invite("x", "b").error).is_equal("target_in_party")
	assert_str(other.id).is_not_equal(p.id)


func test_only_leader_can_invite_kick_transfer() -> void:
	var p := _party()
	ps.invite("a", "b")
	ps.accept("b", p.id)
	assert_str(p.invite("b", "c").error).is_equal("not_leader")
	assert_str(ps.kick("b", "a").error).is_equal("not_leader")
	assert_str(p.transfer("b", "a").error).is_equal("not_leader")
	assert_bool(p.transfer("a", "b").ok).is_true()
	assert_str(p.leader).is_equal("b")


func test_kick_removes_member_from_registry() -> void:
	var p := _party()
	ps.invite("a", "b")
	ps.accept("b", p.id)
	assert_str(ps.kick("a", "a").error).is_equal("bad_target")
	assert_bool(ps.kick("a", "b").ok).is_true()
	assert_object(ps.party_of("b")).is_null()
	assert_bool(ps.create("b").ok).is_true()


func test_leader_leaving_passes_leadership_and_last_member_disbands() -> void:
	var p := _party()
	for n in ["b", "c"]:
		ps.invite("a", n)
		ps.accept(n, p.id)
	ps.leave("a")
	assert_str(p.leader).is_equal("b")
	assert_object(ps.party_of("a")).is_null()
	ps.leave("c")  # осталась группа из одного, она распадается
	assert_object(ps.party_of("b")).is_null()
	assert_bool(ps.parties.is_empty()).is_true()
	assert_bool(ps.leave("zzz")).is_false()


func test_party_xp_bonus() -> void:
	var p := _party()
	assert_int(p.xp_for(100)).is_equal(100)
	ps.invite("a", "b")
	ps.accept("b", p.id)
	assert_int(p.xp_bonus_pct()).is_equal(10)
	ps.invite("a", "c")
	ps.accept("c", p.id)
	assert_int(p.xp_for(100)).is_equal(120)


func _guild(leader := "a", name := "Стражи Зари") -> GuildService.Guild:
	var w := {"coins": 20000}
	return gs.create(leader, name, 20, w).guild


func test_guild_creation_rules() -> void:
	assert_str(gs.create("a", "Стражи", 14, {"coins": 99999}).error).is_equal("level_too_low")
	assert_str(gs.create("a", "Ст", 20, {"coins": 99999}).error).is_equal("bad_name")
	assert_str(gs.create("a", "x".repeat(17), 20, {"coins": 99999}).error).is_equal("bad_name")
	assert_str(gs.create("a", "Стражи", 20, {"coins": 100}).error).is_equal("no_coins")
	var w := {"coins": 15000}
	var g: GuildService.Guild = gs.create("a", "Стражи", 20, w).guild
	assert_int(w.coins).is_equal(5000)
	assert_str(gs.role_of("a")).is_equal("leader")
	assert_str(gs.create("a", "Другая", 20, {"coins": 99999}).error).is_equal("already_in_guild")
	assert_str(gs.create("b", "СТРАЖИ", 20, {"coins": 99999}).error).is_equal("name_taken")
	assert_int(g.level).is_equal(1)


func test_guild_invite_accept_and_roles() -> void:
	var g := _guild()
	assert_bool(gs.invite("a", "b").ok).is_true()
	assert_str(gs.accept("c", g.id).error).is_equal("no_invite")
	assert_bool(gs.accept("b", g.id).ok).is_true()
	assert_str(gs.role_of("b")).is_equal("member")
	assert_str(gs.invite("b", "c").error).is_equal("no_permission")  # рядовой не приглашает
	assert_bool(gs.set_role("a", "b", "officer").ok).is_true()
	assert_bool(gs.invite("b", "c").ok).is_true()
	assert_str(gs.set_role("b", "a", "member").error).is_equal("no_permission")
	assert_str(gs.set_role("a", "a", "member").error).is_equal("bad_target")
	assert_str(gs.invite("a", "b").error).is_equal("target_in_guild")


func test_guild_member_cap_grows_with_level() -> void:
	var g := _guild()
	gd.social["guild"]["member_caps"][0] = 2
	gs.invite("a", "b")
	gs.accept("b", g.id)
	assert_str(gs.invite("a", "c").error).is_equal("guild_full")
	g.level = 2
	assert_bool(gs.invite("a", "c").ok).is_true()


func test_kick_permissions() -> void:
	var g := _guild()
	for n in ["b", "c", "d"]:
		gs.invite("a", n)
		gs.accept(n, g.id)
	gs.set_role("a", "b", "officer")
	assert_str(gs.kick("c", "d").error).is_equal("no_permission")
	assert_str(gs.kick("b", "a").error).is_equal("no_permission")  # офицер не исключает лидера
	assert_bool(gs.kick("b", "c").ok).is_true()
	assert_object(gs.guild_of("c")).is_null()
	assert_str(gs.kick("a", "a").error).is_equal("bad_target")
	assert_bool(gs.kick("a", "b").ok).is_true()


func test_leader_cannot_leave_until_transfer_and_alone_leader_disbands() -> void:
	var g := _guild()
	gs.invite("a", "b")
	gs.accept("b", g.id)
	assert_str(gs.leave("a").error).is_equal("transfer_first")
	assert_bool(gs.transfer_leadership("a", "b").ok).is_true()
	assert_str(gs.role_of("a")).is_equal("officer")
	assert_str(gs.role_of("b")).is_equal("leader")
	assert_bool(gs.leave("a").ok).is_true()
	assert_bool(gs.leave("b").ok).is_true()  # последний, гильдия распущена
	assert_bool(gs.guilds.is_empty()).is_true()
	assert_bool(gs.create("z", "Стражи Зари", 20, {"coins": 99999}).ok).is_true()  # имя снова свободно


func test_treasury_deposit_withdraw_and_guild_levels() -> void:
	var g := _guild()
	var w := {"coins": 20000}
	assert_str(gs.deposit("a", 50, w).error).is_equal("too_small")
	assert_str(gs.deposit("a", 999999, w).error).is_equal("no_coins")
	assert_bool(gs.deposit("a", 10000, w).ok).is_true()
	assert_int(g.treasury).is_equal(10000)
	assert_int(g.xp).is_equal(1000)  # 10% вклада
	assert_int(g.level).is_equal(2)
	gs.invite("a", "b")
	gs.accept("b", g.id)
	assert_str(gs.withdraw("b", 100, {"coins": 0}).error).is_equal("no_permission")
	assert_str(gs.withdraw("a", 999999, w).error).is_equal("no_funds")
	assert_bool(gs.withdraw("a", 4000, w).ok).is_true()
	assert_int(g.treasury).is_equal(6000)
	gs.add_xp(g, 100000)
	assert_int(g.level).is_equal(5)  # потолок уровней


func test_only_leader_can_disband() -> void:
	var g := _guild()
	gs.invite("a", "b")
	gs.accept("b", g.id)
	assert_str(gs.disband("b").error).is_equal("no_permission")
	assert_bool(gs.disband("a").ok).is_true()
	assert_object(gs.guild_of("b")).is_null()
