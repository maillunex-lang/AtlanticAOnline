extends SceneTree

const PRESENCE := preload("res://tools/smoke_zone_presence.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var clients: Array[Node] = []
	for slot in ["FIRST", "SECOND", "THIRD"]:
		var client := PRESENCE.PilotClient.new()
		var key := NetConfig.parse_login_key(OS.get_environment("ATLANTIC_SMOKE_" + slot))
		if client.setup(self, port, key) != OK:
			quit(1)
			return
		clients.append(client)
	if not await _wait_for(func(): return clients.all(func(client): return client.connected)):
		return
	for client in clients:
		client.send("enter")
	if not await _wait_for(func(): return clients.all(func(client): return client.last == ["z_oasis", 3, ""] and client.neighbors.size() == 2)):
		return
	for client in clients:
		client.transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
		await create_timer(0.15).timeout
	print("WP-70 accounts PASS: three distinct simultaneous accounts")
	quit()


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	printerr("WP-70 accounts FAIL: incomplete session or presence")
	quit(1)
	return false
