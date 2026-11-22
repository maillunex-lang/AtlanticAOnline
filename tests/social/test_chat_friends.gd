extends GdUnitTestSuite

var gd: GameData
var social: SocialGraph
var chat: ChatService


func before_test() -> void:
	gd = GameData.load_dir()
	social = SocialGraph.new(gd)
	chat = ChatService.new(gd, social)


func _ctx(level := 10, zone := "z_harbor", party := "", guild := "") -> Dictionary:
	return {"level": level, "zone": zone, "party": party, "guild": guild}


func test_social_data_is_consistent() -> void:
	assert_array(gd.validate()).is_empty()


func test_friend_request_accept_and_limits() -> void:
	assert_str(social.request("a", "a").error).is_equal("self")
	var r := social.request("a", "b")
	assert_bool(r.ok).is_true()
	assert_bool(r.friends).is_false()
	assert_str(social.request("a", "b").error).is_equal("already_requested")
	assert_array(social.requests_for("b")).is_equal(["a"])
	assert_bool(social.accept("b", "a").ok).is_true()
	assert_bool(social.are_friends("a", "b") and social.are_friends("b", "a")).is_true()
	assert_str(social.request("a", "b").error).is_equal("already_friends")
	assert_str(social.accept("b", "a").error).is_equal("no_request")


func test_mutual_requests_become_friendship_immediately() -> void:
	social.request("a", "b")
	var r := social.request("b", "a")
	assert_bool(r.friends).is_true()
	assert_bool(social.are_friends("a", "b")).is_true()


func test_decline_and_remove_friend() -> void:
	social.request("a", "b")
	assert_bool(social.decline("b", "a")).is_true()
	assert_array(social.requests_for("b")).is_empty()
	social.request("a", "b")
	social.accept("b", "a")
	assert_bool(social.remove_friend("a", "b")).is_true()
	assert_bool(social.remove_friend("a", "b")).is_false()


func test_friend_limit() -> void:
	gd.social["friends"]["max_friends"] = 2
	for n in ["b", "c"]:
		social.request("a", n)
		social.accept(n, "a")
	assert_str(social.request("a", "d").error).is_equal("friend_limit")


func test_block_breaks_friendship_and_prevents_requests() -> void:
	social.request("a", "b")
	social.accept("b", "a")
	assert_bool(social.block("a", "b").ok).is_true()
	assert_bool(social.are_friends("a", "b")).is_false()
	assert_str(social.request("a", "b").error).is_equal("blocked")
	assert_str(social.request("b", "a").error).is_equal("blocked")
	assert_bool(social.unblock("a", "b")).is_true()
	assert_bool(social.request("b", "a").ok).is_true()


func test_chat_basic_channels_and_history() -> void:
	var r := chat.send("a", "zone", "", "Привет", 0.0, _ctx())
	assert_bool(r.ok).is_true()
	assert_str(r.channel_key).is_equal("zone:z_harbor")
	assert_int(chat.recent("zone:z_harbor").size()).is_equal(1)
	assert_str(chat.send("a", "party", "", "x", 1.0, _ctx()).error).is_equal("no_party")
	assert_str(chat.send("a", "guild", "", "x", 1.0, _ctx()).error).is_equal("no_guild")
	assert_str(chat.send("a", "shout", "", "x", 1.0, _ctx()).error).is_equal("bad_channel")
	assert_str(chat.send("a", "party", "", "ок", 2.0, _ctx(10, "z", "p1")).channel_key).is_equal("party:p1")
	assert_str(chat.send("a", "guild", "", "гильдия", 3.0, _ctx(10, "z", "", "g1")).channel_key).is_equal("guild:g1")


func test_chat_validation() -> void:
	assert_str(chat.send("a", "zone", "", "   ", 0.0, _ctx()).error).is_equal("empty")
	assert_str(chat.send("a", "zone", "", "x".repeat(201), 0.0, _ctx()).error).is_equal("too_long")
	assert_bool(chat.send("a", "zone", "", "x".repeat(200), 0.0, _ctx()).ok).is_true()


func test_world_chat_needs_level_and_has_cooldown() -> void:
	assert_str(chat.send("a", "world", "", "всем", 0.0, _ctx(2)).error).is_equal("level_too_low")
	assert_bool(chat.send("a", "world", "", "всем", 0.0, _ctx(3)).ok).is_true()
	assert_str(chat.send("a", "world", "", "ещё", 2.0, _ctx(3)).error).is_equal("world_cooldown")
	assert_bool(chat.send("a", "world", "", "ещё", 5.0, _ctx(3)).ok).is_true()


func test_rate_limit_and_duplicates() -> void:
	for i in 5:
		assert_bool(chat.send("a", "zone", "", "m%d" % i, float(i), _ctx()).ok).is_true()
	assert_str(chat.send("a", "zone", "", "m5", 6.0, _ctx()).error).is_equal("rate_limited")
	assert_bool(chat.send("a", "zone", "", "m5", 20.0, _ctx()).ok).is_true()  # окно прошло
	assert_str(chat.send("a", "zone", "", "m5", 21.0, _ctx()).error).is_equal("duplicate")
	assert_bool(chat.send("a", "zone", "", "m5", 60.0, _ctx()).ok).is_true()


func test_mute() -> void:
	chat.mute("a", 100.0)
	assert_str(chat.send("a", "zone", "", "привет", 50.0, _ctx()).error).is_equal("muted")
	assert_bool(chat.send("a", "zone", "", "привет", 100.0, _ctx()).ok).is_true()


func test_whisper_respects_blocks_and_uses_shared_key() -> void:
	assert_str(chat.send("a", "whisper", "", "тест", 0.0, _ctx()).error).is_equal("bad_target")
	assert_str(chat.send("a", "whisper", "a", "тест", 0.0, _ctx()).error).is_equal("bad_target")
	var r1 := chat.send("a", "whisper", "b", "привет", 0.0, _ctx())
	var r2 := chat.send("b", "whisper", "a", "ответ", 1.0, _ctx())
	assert_str(r1.channel_key).is_equal(r2.channel_key)
	assert_int(chat.recent(r1.channel_key).size()).is_equal(2)
	social.block("b", "a")
	assert_str(chat.send("a", "whisper", "b", "ещё", 2.0, _ctx()).error).is_equal("blocked_by_target")
	assert_str(chat.send("b", "whisper", "a", "ещё", 3.0, _ctx()).error).is_equal("you_blocked_target")


func test_blocklist_masks_words_case_insensitive() -> void:
	gd.social["chat"]["blocklist"] = ["плохо"]
	var r := chat.send("a", "zone", "", "Это ПЛОХО и плохо", 0.0, _ctx())
	assert_str(r.message.text).is_equal("Это *** и ***")


func test_history_is_capped() -> void:
	gd.social["chat"]["rate_max_messages"] = 1000
	gd.social["chat"]["history_size"] = 3
	for i in 10:
		chat.send("a", "zone", "", "сообщение %d" % i, float(i), _ctx())
	var h := chat.recent("zone:z_harbor")
	assert_int(h.size()).is_equal(3)
	assert_str(h[2].text).is_equal("сообщение 9")
