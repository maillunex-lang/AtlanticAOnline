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
