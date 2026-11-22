extends GdUnitTestSuite


func test_base_value_and_missing_stat() -> void:
	var sb := StatBlock.new({"atk": 10})
	assert_int(sb.value("atk")).is_equal(10)
	assert_int(sb.value("nothing")).is_equal(0)


func test_flat_then_percent() -> void:
	var sb := StatBlock.new({"atk": 10})
	sb.add_modifier("a", "atk", StatBlock.Kind.FLAT, 10)
	sb.add_modifier("b", "atk", StatBlock.Kind.PERCENT, 50)
	assert_int(sb.value("atk")).is_equal(30)  # (10 + 10) * 150 / 100


func test_percent_modifiers_stack_additively() -> void:
	var sb := StatBlock.new({"def": 100})
	sb.add_modifier("a", "def", StatBlock.Kind.PERCENT, 20)
	sb.add_modifier("b", "def", StatBlock.Kind.PERCENT, 30)
	assert_int(sb.value("def")).is_equal(150)


func test_same_id_replaces_instead_of_stacking() -> void:
	var sb := StatBlock.new({"atk": 100})
	sb.add_modifier("rally", "atk", StatBlock.Kind.PERCENT, 15, 2)
	sb.add_modifier("rally", "atk", StatBlock.Kind.PERCENT, 15, 2)
	assert_int(sb.modifier_count()).is_equal(1)
	assert_int(sb.value("atk")).is_equal(115)


func test_negative_percent_is_clamped_and_value_never_negative() -> void:
	var sb := StatBlock.new({"atk": 100})
	sb.add_modifier("a", "atk", StatBlock.Kind.PERCENT, -500)
	assert_int(sb.value("atk")).is_equal(10)  # не ниже -90%
	sb.add_modifier("b", "atk", StatBlock.Kind.FLAT, -1000)
	assert_int(sb.value("atk")).is_equal(0)


func test_timed_modifier_expires_after_given_ticks() -> void:
	var sb := StatBlock.new({"atk": 100})
	sb.add_modifier("buff", "atk", StatBlock.Kind.PERCENT, 50, 2)
	assert_array(sb.tick()).is_empty()
	assert_int(sb.value("atk")).is_equal(150)
	assert_array(sb.tick()).is_equal(["buff"])
	assert_int(sb.value("atk")).is_equal(100)


func test_permanent_modifier_never_expires() -> void:
	var sb := StatBlock.new({"atk": 10})
	sb.add_modifier("gear", "atk", StatBlock.Kind.FLAT, 5)
	for i in 10:
		sb.tick()
	assert_int(sb.value("atk")).is_equal(15)


func test_remove_modifier() -> void:
	var sb := StatBlock.new({"atk": 10})
	sb.add_modifier("x", "atk", StatBlock.Kind.FLAT, 5)
	assert_int(sb.remove_modifier("x")).is_equal(1)
	assert_int(sb.value("atk")).is_equal(10)
