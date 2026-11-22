extends SceneTree
## Probe the exported server from a separate headless Godot process.

var _network: SceneMultiplayer
var _version := NetConfig.PROTOCOL_VERSION
var _server_version := -1
var _expect_rejection := false


func _initialize() -> void:
	call_deferred("_connect_to_server")


func _connect_to_server() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or not args[0].is_valid_int():
		_fail("Expected the server port")
		return
	_expect_rejection = "--incompatible" in args
	if _expect_rejection:
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
	if _network.send_auth(id, NetConfig.encode_version(_version)) != OK:
		_fail("Could not send client protocol version")


func _receive_version(id: int, packet: PackedByteArray) -> void:
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
	print("WP-02 ENet PASS: protocol v%d" % _server_version)
	quit()


func _authentication_failed(id: int) -> void:
	if _expect_rejection and id == MultiplayerPeer.TARGET_PEER_SERVER:
		print("WP-02 ENet PASS: incompatible version rejected")
		quit()
	else:
		_fail("Server rejected the compatible client")


func _fail(message: String) -> void:
	printerr("WP-02 ENet FAIL: ", message)
	quit(1)
