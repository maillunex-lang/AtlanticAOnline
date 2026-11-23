extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	var seller := _client(port, "ATLANTIC_SMOKE_SECRET")
	var buyer := _client(port, "ATLANTIC_SMOKE_SECRET_SECOND")
	var rival := _client(port, "ATLANTIC_SMOKE_SECRET_THIRD")
	if not await _wait(func(): return seller._ready_to_play and buyer._ready_to_play and rival._ready_to_play, "sessions"):
		return
	for client in [seller, buyer, rival]:
		client._travel_button.pressed.emit()
	if not await _wait(func(): return seller.map.zone_id == "z_rome" and buyer.map.zone_id == "z_rome" and rival.map.zone_id == "z_rome", "Rome"):
		return
	for client in [seller, buyer, rival]:
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
	_press(seller, "Мои лоты")
	assert(_button(seller, "Стальной меч +0 · 150 монет") != null)
	_press(buyer, "Обновить")
	if not await _wait(func(): return buyer._auction_state.lots.size() == 1, "buyer's listing"):
		return
	_press(buyer, "Мои лоты")
	assert(_button(buyer, "Стальной меч +0 · 150 монет") == null)
	_press(buyer, "Все лоты")
	for filters in [["стальной", 1, "20", "149"], ["стальной", 2, "20", "150"],
			["стальной", 1, "19", "150"], ["броня", 1, "20", "150"], [" СТАЛЬНОЙ ", 1, "20", "150"]]:
		_press(buyer, "Поиск и фильтры" if _button(buyer, "Поиск и фильтры") != null else "Фильтры · включены")
		var controls := buyer._info.choice_list
		(controls.get_child(0) as LineEdit).text = filters[0]
		var limits := controls.get_child(1)
		(limits.get_child(0) as OptionButton).select(filters[1])
		(limits.get_child(1) as LineEdit).text = filters[2]
		(limits.get_child(2) as LineEdit).text = filters[3]
		_press(buyer, "Применить")
		assert((_button(buyer, "Стальной меч +0 · 150 монет") != null) == (filters[0] == " СТАЛЬНОЙ "))
	_press(buyer, "Фильтры · включены")
	_press(buyer, "Сбросить")
	assert(_button(buyer, "Поиск и фильтры") != null)
	_press(rival, "Обновить")
	if not await _wait(func(): return rival._auction_state.lots.size() == 1, "second buyer sees lot"):
		return
	var seller_peer := seller._network.get_unique_id()
	if not await _wait(func(): return buyer._remote_heroes.has(seller_peer), "seller present before disconnect"):
		return
	seller._transport.disconnect_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if not await _wait(func(): return not buyer._remote_heroes.has(seller_peer), "seller offline"):
		return
	seller.queue_free()
	var receipts := {}
	for contestant in [buyer, rival]:
		var peer_id: int = contestant._network.get_unique_id()
		contestant._channel.auction_updated.connect(func(receipt: Dictionary): receipts[peer_id] = receipt, CONNECT_ONE_SHOT)
		_press(contestant, "Стальной меч +0 · 150 монет")
	# Both requests are queued before waiting for any reply.
	_press(buyer, "Купить")
	_press(rival, "Купить")
	if not await _wait(func(): return receipts.size() == 2, "both buy replies"):
		return
	var winner: DunesPilotClient
	var rejected := 0
	for contestant in [buyer, rival]:
		var receipt: Dictionary = receipts[contestant._network.get_unique_id()]
		assert(receipt.lots.is_empty())
		if receipt.error == "missing_lot":
			assert(receipt.coins == 1000 and receipt.items.size() == 1)
			rejected += 1
		else:
			assert(receipt.error.is_empty() and receipt.coins == 850 and receipt.items.size() == 2)
			assert(receipt.items[1].def_id == "w_sword_2" and receipt.items[0].uid != receipt.items[1].uid)
			winner = contestant
	assert(rejected == 1 and winner != null)
	rival = rival if winner == buyer else buyer
	buyer = winner
	seller = _client(port, "ATLANTIC_SMOKE_SECRET")
	if not await _wait(func(): return seller._ready_to_play and seller.map.zone_id == "z_rome", "seller reconnects in Rome"):
		return
	if not await _wait(func(): return seller.hud.interact_button.visible and seller.hud.interact_button.text.contains("Квинт"), "seller can talk after reconnect"):
		return
	seller.hud.interact_button.pressed.emit()
	if not await _wait(func(): return seller._auction_state.get("coins") == 1150, "offline seller paid once"):
		return
	assert(seller._auction_state.lots.is_empty() and seller._auction_state.items.is_empty())
	_press(buyer, "Выставить из сумки")
	_press(buyer, "Стальной меч +0")
	(buyer._info.choice_list.get_child(0) as LineEdit).text = "200"
	_press(buyer, "Выставить лот")
	if not await _wait(func(): return buyer._auction_state.lots.size() == 1, "return listing"):
		return
	_press(buyer, "Мои лоты")
	_press(buyer, "Стальной меч +0 · 200 монет")
	_press(buyer, "Снять лот")
	if not await _wait(func(): return buyer._auction_state.returns.size() == 1, "return stored"):
		return
	_press(buyer, "К получению")
	_press(buyer, "Стальной меч +0")
	_press(buyer, "Забрать в сумку")
	if not await _wait(func(): return buyer._auction_state.returns.is_empty() and buyer._auction_state.items.size() == 2, "return claimed"):
		return
	_press(buyer, "Выставить из сумки")
	_press(buyer, "Стальной меч +0")
	(buyer._info.choice_list.get_child(0) as LineEdit).text = "200"
	_press(buyer, "Начать торги")
	if not await _wait(func(): return buyer._auction_state.lots.size() == 1, "bid listing"):
		return
	_press(seller, "Обновить")
	if not await _wait(func(): return _button(seller, "Стальной меч +0 · Старт 200") != null, "start price"):
		return
	_press(seller, "Стальной меч +0 · Старт 200")
	_press(seller, "Сделать ставку")
	if not await _wait(func(): return seller._auction_state.coins == 950, "reserved bid"):
		return
	_press(rival, "Обновить")
	if not await _wait(func(): return _button(rival, "Стальной меч +0 · Ставка 200") != null, "leading bid shown"):
		return
	_press(rival, "Стальной меч +0 · Ставка 200")
	_press(rival, "Сделать ставку")
	if not await _wait(func(): return rival._auction_state.coins == 799, "outbid"):
		return
	_press(seller, "Обновить")
	if not await _wait(func(): return seller._auction_state.coins == 1150, "bid refunded"):
		return
	print("WP-90 auction PASS: offline seller paid once, two buyers raced, one received the item, cancellation returned it, competing bids reserved and refunded coins")
	quit()


func _client(port: int, secret: String) -> DunesPilotClient:
	var client := DunesPilotClient.new()
	root.add_child(client)
	client.start(port, NetConfig.parse_login_key(OS.get_environment(secret)))
	return client


func _button(client: DunesPilotClient, label: String) -> Button:
	return _find_button(client._info.choice_list, label)


func _find_button(parent: Node, label: String) -> Button:
	for choice in parent.get_children():
		if choice is Button and choice.text == label:
			return choice
		var nested := _find_button(choice, label)
		if nested != null:
			return nested
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
