extends GdUnitTestSuite

var gd: GameData


func before_test() -> void:
	gd = GameData.load_dir()


func _rng(seed := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_odds_are_published_and_sum_to_100() -> void:
	var pack := RecruitPack.find_pack(gd, "standard")
	var o := RecruitPack.odds(pack, RecruitPack.State.new())
	assert_float(o.basic + o.advanced).is_equal_approx(100.0, 0.001)
	assert_float(o.advanced).is_equal_approx(10.0, 0.001)
	assert_bool(o.guaranteed).is_false()


func test_pity_guarantees_advanced_and_resets() -> void:
	var pack := RecruitPack.find_pack(gd, "standard")
	var st := RecruitPack.State.new()
	st.pulls_since_advanced = int(pack.pity_after) - 1
	assert_bool(RecruitPack.odds(pack, st).guaranteed).is_true()
	var id := RecruitPack.roll(pack, st, _rng())
	assert_str((gd.mercs[id] as MercenaryDef).tier).is_equal("advanced")
	assert_int(st.pulls_since_advanced).is_equal(0)


func test_never_more_than_pity_without_advanced() -> void:
	var pack := RecruitPack.find_pack(gd, "standard")
	var st := RecruitPack.State.new()
	var rng := _rng(5)
	var streak := 0
	var worst := 0
	for i in 2000:
		var id := RecruitPack.roll(pack, st, rng)
		if (gd.mercs[id] as MercenaryDef).tier == "advanced":
			streak = 0
		else:
			streak += 1
			worst = maxi(worst, streak)
	assert_bool(worst < int(pack.pity_after)).is_true()


func test_roll_is_deterministic_for_same_seed() -> void:
	var pack := RecruitPack.find_pack(gd, "standard")
	var a := RecruitPack.State.new()
	var b := RecruitPack.State.new()
	var ra := _rng(9)
	var rb := _rng(9)
	for i in 50:
		assert_str(RecruitPack.roll(pack, a, ra)).is_equal(RecruitPack.roll(pack, b, rb))


func test_empirical_advanced_rate_near_published_odds() -> void:
	var pack := RecruitPack.find_pack(gd, "standard")
	var st := RecruitPack.State.new()
	var rng := _rng(3)
	var adv := 0
	var n := 10000
	for i in n:
		if (gd.mercs[RecruitPack.roll(pack, st, rng)] as MercenaryDef).tier == "advanced":
			adv += 1
	var rate := float(adv) * 100.0 / n
	assert_bool(rate > 9.0 and rate < 16.0).is_true()  # 10% плюс вклад гарантии


func test_pack_purchase_costs_coins_and_duplicate_becomes_shards() -> void:
	var sq := Squad.new(gd)
	var st := RecruitPack.State.new()
	var w := {"coins": 500}
	var res := sq.recruit_from_pack("standard", w, st, _rng())
	assert_bool(res.ok).is_true()
	assert_int(w.coins).is_equal(0)
	assert_str(sq.recruit_from_pack("standard", w, st, _rng()).error).is_equal("no_coins")
	assert_str(sq.recruit_from_pack("nope", w, st, _rng()).error).is_equal("unknown_pack")
	# Отряд полон: результат превращается в осколки
	var w2 := {"coins": 1000000}
	for i in 8:
		sq.recruit("swordsman", "coins", w2)
	var full := sq.recruit_from_pack("standard", w2, st, _rng())
	assert_object(full.merc).is_null()
	assert_bool(full.shards > 0).is_true()
	assert_int(sq.mercs.size()).is_equal(8)
