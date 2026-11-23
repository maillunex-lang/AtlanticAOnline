extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var seller := _client(port, "ATLANTIC_SMOKE_SECRET")
	var buyer := _client(port, "ATLANTIC_SMOKE_SECRET_SECOND")
	if not await _wait(func(): return seller._ready_to_play and buyer._ready_to_play, "sessions"):
		return
	for client in [seller, buyer]:
		client._travel_button.pressed.emit()
	if not await _wait(func(): return seller.map.zone_id == "z_rome" and buyer.map.zone_id == "z_rome", "Rome"):
		return
	for client in [seller, buyer]:
		if not await _wait(func(): return client.hud.interact_button.visible and client.hud.interact_button.text.contains("Квинт"), "auctioneer"):
			return
		client.hud.interact_button.pressed.emit()
		if not await _wait(func(): return client._info != null and client._auction_state.has("coins"), "auction panel"):
			return
	_press(seller, "Выставить из сумки")
	if not await _wait(func(): return _button(seller, "Стальной меч +0") != null, "sell inventory"):
		return
	_press(seller, "Стальной меч +0")
	(seller._info.choice_list.get_child(0) as LineEdit).text = "150"
	_press(seller, "Выставить лот")
	if not await _wait(func(): return seller._auction_state.lots.size() == 1, "listing"):
		return
	_press(buyer, "Обновить")
	if not await _wait(func(): return buyer._auction_state.lots.size() == 1, "buyer's listing"):
		return
	var lot_id := int(buyer._auction_state.lots[0].id)
	_press(buyer, "Стальной меч +0 · 150 монет")
	_press(buyer, "Купить")
	if not await _wait(func(): return buyer._auction_state.coins == 850 and buyer._auction_state.items.size() == 2, "purchase"):
		return
	buyer._request("auction_buy", str(lot_id))
	_press(seller, "Обновить")
	if not await _wait(func(): return seller._auction_state.coins == 1150 and seller._auction_state.lots.is_empty(), "seller paid"):
		return
	_press(buyer, "Обновить")
	if not await _wait(func(): return buyer._auction_state.lots.is_empty() and buyer._auction_state.coins == 850, "no double purchase"):
		return
	print("WP-90 auction PASS: two clients traveled, listed and bought at Quintus")
	quit()


func _client(port: int, secret: String) -> DunesPilotClient:
	var client := DunesPilotClient.new()
	root.add_child(client)
	client.start(port, NetConfig.parse_login_key(OS.get_environment(secret)))
	return client


func _button(client: DunesPilotClient, label: String) -> Button:
	for choice in client._info.choice_list.get_children():
		if choice is Button and choice.text == label:
			return choice
	return null


func _press(client: DunesPilotClient, label: String) -> void:
	var button := _button(client, label)
	assert(button != null, label)
	button.pressed.emit()


func _wait(predicate: Callable, step: String) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	printerr("WP-90 auction FAIL: ", step)
	quit(1)
	return false
