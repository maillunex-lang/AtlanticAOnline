extends GdUnitTestSuite


func test_same_protocol_version_is_compatible() -> void:
	assert_bool(NetConfig.is_compatible(NetConfig.PROTOCOL_VERSION)).is_true()


func test_other_protocol_version_is_rejected() -> void:
	assert_bool(NetConfig.is_compatible(NetConfig.PROTOCOL_VERSION + 1)).is_false()


func test_server_starts_and_listens() -> void:
	var server := auto_free(ServerMain.new()) as ServerMain
	add_child(server)
	assert_int(server.start(17777, ":memory:")).is_equal(OK)
	server.peer.close()


func test_session_packet_round_trips_only_for_its_message_type() -> void:
	var secret := PackedByteArray()
	secret.resize(NetConfig.SECRET_BYTES)
	secret.fill(42)
	var packet := NetConfig.encode_session(NetConfig.LOGIN_KEY, secret)
	assert_bool(NetConfig.decode_session(packet, NetConfig.LOGIN_KEY) == secret).is_true()
	assert_bool(NetConfig.decode_session(packet, NetConfig.RESUME_SESSION).is_empty()).is_true()
	assert_bool(NetConfig.decode_session(packet.slice(0, -1), NetConfig.LOGIN_KEY).is_empty()).is_true()
	packet.encode_u32(0, NetConfig.PROTOCOL_VERSION + 1)
	assert_bool(NetConfig.decode_session(packet, NetConfig.LOGIN_KEY).is_empty()).is_true()


func test_local_login_key_accepts_only_full_hexadecimal_value() -> void:
	var key := "aB".repeat(NetConfig.SECRET_BYTES)
	assert_int(NetConfig.parse_login_key(" " + key + " ").size()).is_equal(NetConfig.SECRET_BYTES)
	assert_bool(NetConfig.parse_login_key("a".repeat(63)).is_empty()).is_true()
	assert_bool(NetConfig.parse_login_key("g".repeat(64)).is_empty()).is_true()
	assert_bool(NetConfig.parse_login_key("0x" + "a".repeat(62)).is_empty()).is_true()
	assert_bool(NetConfig.parse_login_key("+" + "a".repeat(63)).is_empty()).is_true()
