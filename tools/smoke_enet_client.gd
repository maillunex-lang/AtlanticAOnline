extends SceneTree
## Probe the exported server from a separate headless Godot process.

var _network: SceneMultiplayer
var _version := NetConfig.PROTOCOL_VERSION
var _server_version := -1
var _expect_rejection := false
var _session_mode := false
var _secret := PackedByteArray()
var _token := PackedByteArray()


func _initialize() -> void:
	call_deferred("_connect_to_server")


func _connect_to_server() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or not args[0].is_valid_int():
		_fail("Expected the server port")
		return
	_session_mode = "--login" in args or "--resume" in args
	_expect_rejection = "--incompatible" in args or "--reject" in args
	if _session_mode:
		_secret = OS.get_environment("ATLANTIC_SMOKE_SECRET").hex_decode()
		if _secret.size() != NetConfig.SECRET_BYTES:
			_fail("Expected a session test secret")
			return
	if "--incompatible" in args:
		_version += 1
	_network = get_multiplayer() as SceneMultiplayer
	_network.auth_callback = _receive_version
	_network.peer_authenticating.connect(_send_version)
	_network.peer_authentication_failed.connect(_authentication_failed)
	_network.connected_to_server.connect(_connected)
	_network.connection_failed.connect(func(): _fail("ENet transport connection failed"))
	create_timer(8.0).timeout.connect(func(): _fail("Protocol handshake timed out"))
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(NetConfig.DEFAULT_HOST, int(args[0])) != OK:
		_fail("Could not create ENet client")
		return
	_network.multiplayer_peer = peer


func _send_version(id: int) -> void:
	var packet := NetConfig.encode_version(_version)
	if _session_mode:
		var kind := NetConfig.RESUME_SESSION if "--resume" in OS.get_cmdline_user_args() else NetConfig.LOGIN_KEY
		packet = NetConfig.encode_session(kind, _secret)
		packet.encode_u32(0, _version)
	if _network.send_auth(id, packet) != OK:
		_fail("Could not send client protocol version")


func _receive_version(id: int, packet: PackedByteArray) -> void:
	if _session_mode:
		_token = NetConfig.decode_session(packet, NetConfig.SESSION_GRANTED)
		if _token.is_empty() or _token == _secret:
			_fail("Expected a fresh session token")
			return
		_server_version = NetConfig.PROTOCOL_VERSION
	else:
		_server_version = NetConfig.decode_version(packet)
	if id != MultiplayerPeer.TARGET_PEER_SERVER or not NetConfig.is_compatible(_server_version):
		_fail("Unexpected server protocol version: %d" % _server_version)
		return
	if _network.complete_auth(id) != OK:
		_fail("Could not finish protocol handshake")


func _connected() -> void:
	if _expect_rejection or _server_version != _version:
		_fail("Connection became active with an incompatible protocol")
		return
	if _session_mode:
		var result := FileAccess.open(OS.get_environment("ATLANTIC_SMOKE_TOKEN_FILE"), FileAccess.WRITE)
		if result == null:
			_fail("Could not save token for the next test")
			return
		result.store_string(_token.hex_encode())
		result.close()
		_network.multiplayer_peer.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
		await create_timer(0.3).timeout
		print("WP-70 ENet PASS: session granted")
		quit()
		return
	print("WP-02 ENet PASS: protocol v%d" % _server_version)
	quit()


func _authentication_failed(id: int) -> void:
	if _expect_rejection and id == MultiplayerPeer.TARGET_PEER_SERVER:
		print("WP-70 ENet PASS: session rejected" if _session_mode else "WP-02 ENet PASS: incompatible version rejected")
		quit()
	else:
		_fail("Server rejected the compatible client")


func _fail(message: String) -> void:
	printerr("WP-02 ENet FAIL: ", message)
	quit(1)
