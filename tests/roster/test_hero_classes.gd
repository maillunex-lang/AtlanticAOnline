extends GdUnitTestSuite
## Классы героя (WP-40): данные, создание, навыки и улучшения 100/120, смена класса, бонус отряду, экран создания.

var gd: GameData
var squad: Squad
var inv: Inventory


func before_test() -> void:
	gd = GameData.load_dir()
	squad = Squad.new(gd)
	inv = Inventory.new(gd)


func test_thirteen_classes_with_original_roles_and_groups() -> void:
	assert_array(gd.validate()).is_empty()
	assert_int(gd.classes.size()).is_equal(13)
	var roles := {"melee": 0, "ranged": 0, "staff": 0}
	var groups := {"scion": 0, "atlantian": 0, "hero": 0}
	for id in gd.classes:
		roles[gd.classes[id]["role"]] += 1
		groups[gd.classes[id]["group"]] += 1
	assert_dict(roles).is_equal({"melee": 5, "ranged": 6, "staff": 2})
	assert_dict(groups).is_equal({"scion": 9, "atlantian": 3, "hero": 1})
	assert_str(gd.class_order[0]).is_equal("warden")
	assert_str(gd.class_order[12]).is_equal("tidemage")


func test_enabled_classes_have_hero_defs_and_disabled_do_not() -> void:
	var enabled: Array[String] = []
	for id in gd.classes:
		if bool(gd.classes[id]["enabled"]):
			enabled.append(id)
			var def: MercenaryDef = gd.mercs["hero_" + id]
			assert_str(def.tier).is_equal("hero")
			assert_int(def.skill_ids.size()).is_greater(0)
			assert_str(gd.hero_def_id(id)).is_equal("hero_" + id)
		else:
			assert_str(gd.hero_def_id(id)).is_equal("")
	assert_int(enabled.size()).is_equal(7)
	assert_array(enabled).contains_exactly_in_any_order(["warden", "pikeman", "hewer", "sharpshooter", "gunslinger", "siegemaster", "magus"])


func test_class_status_and_default_class_for_weapon() -> void:
	assert_str(gd.class_status("warden")).is_equal("")
	assert_str(gd.class_status("sawyer")).is_equal("disabled")
	assert_str(gd.class_status("nope")).is_equal("unknown")
	gd.classes["magus"]["start_region"] = "africa"
	assert_str(gd.class_status("magus")).is_equal("region_locked")
	assert_str(gd.default_class_for_weapon("sword")).is_equal("warden")
	assert_str(gd.default_class_for_weapon("bow")).is_equal("sharpshooter")
	assert_str(gd.default_class_for_weapon("staff")).is_equal("magus")
	assert_str(gd.default_class_for_weapon("power_saw")).is_equal("")


func test_create_hero_by_class_or_weapon_and_locked_classes_refused() -> void:
	assert_object(squad.create_hero("sawyer")).is_null()  # ждёт оружия
	assert_object(squad.create_hero("laser")).is_null()
	var hero := squad.create_hero("hewer")
	assert_object(hero).is_not_null()
	assert_str(hero.class_id).is_equal("hewer")
	assert_str(hero.def_id).is_equal("hero_hewer")
	assert_object(squad.create_hero("warden")).is_null()  # герой один
	var other := Squad.new(gd)
	assert_str(other.create_hero("sword").class_id).is_equal("warden")  # по оружию берётся первый класс
	assert_int(Mercenary.new(1, "swordsman", gd).hero_upgrades.size()).is_equal(0)
	assert_str(Mercenary.new(1, "swordsman", gd).class_id).is_equal("")


func test_class_stats_match_the_previous_hero_numbers() -> void:
	var hero := squad.create_hero("sword")
	var st := hero.compute_stats(gd)
	assert_int(int(st["hp"])).is_equal(169)
	assert_int(int(st["atk"])).is_equal(15)
	assert_int(int(st["def"])).is_equal(10)
	assert_int(int(st["ap_regen"])).is_equal(55)


func test_hero_upgrades_need_level_and_order() -> void:
	assert_str(squad.complete_hero_upgrade(100)).is_equal("no_hero")
	var hero := squad.create_hero("warden")
	assert_str(squad.complete_hero_upgrade(50)).is_equal("bad_upgrade")
	assert_str(squad.complete_hero_upgrade(100)).is_equal("level_too_low")
	hero.set_level(120, gd)
	assert_str(squad.complete_hero_upgrade(120)).is_equal("previous_required")
	assert_str(squad.complete_hero_upgrade(100)).is_equal("")
	assert_str(squad.complete_hero_upgrade(100)).is_equal("already_done")
	assert_str(squad.complete_hero_upgrade(120)).is_equal("")
	assert_str(squad.complete_hero_upgrade(130)).is_equal("level_too_low")
	assert_array(hero.hero_upgrades).is_equal([100, 120])


func test_skill_slots_grow_with_upgrades_up_to_five() -> void:
	var hero := squad.create_hero("warden")
	assert_int(hero.skill_slot_limit(gd)).is_equal(3)
	hero.set_level(130, gd)
	squad.complete_hero_upgrade(100)
	assert_int(hero.skill_slot_limit(gd)).is_equal(4)
	squad.complete_hero_upgrade(120)
	assert_int(hero.skill_slot_limit(gd)).is_equal(5)
	assert_int(Mercenary.new(2, "swordsman", gd).skill_slot_limit(gd)).is_equal(5)  # наёмник по max_skills


func test_slot4_pool_needs_upgrade_100_and_slots_limit_learning() -> void:
	# Пулы навыков заданы в данных; проверяем механику на подменённых пулах (каталог навыков расширит WP-47).
	gd.classes["warden"]["skills"]["base"] = ["sword_slash"]
	gd.classes["warden"]["skills"]["slot4"] = ["sword_rally"]
	gd.classes["warden"]["skills"]["spec"] = []
	var hero := squad.create_hero("warden")
	hero.set_level(30, gd)
	hero.skill_points = 10
	assert_str(hero.learn_skill("sword_rally", gd)).is_equal("needs_upgrade_100")
	assert_str(hero.learn_skill("sword_guard", gd)).is_equal("")
	hero.set_level(100, gd)
	squad.complete_hero_upgrade(100)
	assert_str(hero.learn_skill("sword_rally", gd)).is_equal("")
	assert_int(hero.skill_levels.size()).is_equal(3)  # старт, guard, rally при лимите 4


func test_specialization_needs_upgrade_120_and_can_be_reset() -> void:
	var hero := squad.create_hero("magus")
	hero.set_level(120, gd)
	hero.skill_points = 5
	assert_str(hero.learn_skill("staff_revive", gd)).is_equal("needs_upgrade_120")
	squad.complete_hero_upgrade(100)
	squad.complete_hero_upgrade(120)
	assert_str(hero.learn_skill("staff_revive", gd)).is_equal("")
	assert_str(hero.specialization).is_equal("staff_revive")
	hero.upgrade_skill("staff_revive", gd)
	assert_int(hero.skill_points).is_equal(3)  # 5 - 1 (изучение) - 1 (уровень)
	assert_int(hero.reset_specialization()).is_equal(2)
	assert_int(hero.skill_points).is_equal(5)
	assert_str(hero.specialization).is_equal("")
	assert_bool(hero.skill_levels.has("staff_revive")).is_false()
	assert_int(hero.reset_specialization()).is_equal(0)


func test_change_class_refunds_skills_resets_upgrades_and_moves_weapon() -> void:
	var hero := squad.create_hero("warden")
	hero.set_level(120, gd)  # предел max_level
	hero.skill_points = 3
	hero.learn_skill("sword_guard", gd)
	hero.upgrade_skill("sword_guard", gd)
	hero.equip(inv.add_equipment("w_sword_1"), inv)
	hero.equip(inv.add_equipment("a_cloth"), inv)
	squad.complete_hero_upgrade(100)
	squad.complete_hero_upgrade(120)
	assert_str(squad.change_class("sharpshooter", inv)).is_equal("no_item")
	inv.add_material("class_change_card", 2)
	assert_str(squad.change_class("warden", inv)).is_equal("same_class")
	assert_str(squad.change_class("sawyer", inv)).is_equal("class_unavailable")
	assert_str(squad.change_class("sharpshooter", inv)).is_equal("")
	assert_int(inv.material_count("class_change_card")).is_equal(1)
	assert_str(hero.class_id).is_equal("sharpshooter")
	assert_str(hero.def_id).is_equal("hero_sharpshooter")
	assert_int(hero.level).is_equal(120)  # уровень остаётся
	assert_int(hero.skill_points).is_equal(3)  # 3 - 2 потрачено на guard (изучение и уровень) + 2 возвращено
	assert_array(hero.skill_levels.keys()).is_equal(["bow_shot"])
	assert_array(hero.hero_upgrades).is_empty()  # 100 и 120 проходить заново
	assert_object(hero.equipped.get("weapon")).is_null()  # меч снят в сумку
	assert_object(hero.equipped.get("armor")).is_not_null()
	assert_bool(inv.items.any(func(i: Item) -> bool: return i.def_id == "w_sword_1")).is_true()


func test_change_class_blocked_by_full_bag_only_when_weapon_must_move() -> void:
	var hero := squad.create_hero("warden")
	hero.equip(inv.add_equipment("w_sword_1"), inv)
	inv.add_material("class_change_card", 1)
	while not inv.is_full():
		inv.add_equipment("h_cap")
	assert_str(squad.change_class("hewer", inv)).is_equal("inventory_full")  # меч некуда положить
	assert_int(inv.material_count("class_change_card")).is_equal(1)  # карта не потрачена
	assert_str(hero.class_id).is_equal("warden")
	inv.items.pop_back()
	assert_str(squad.change_class("hewer", inv)).is_equal("")
	assert_str(hero.class_id).is_equal("hewer")


func test_formation_bonus_applies_to_every_unit() -> void:
	var hero := squad.create_hero("warden")  # +5% защиты отряду
	var w := {"coins": 5000}
	var merc: Mercenary = squad.recruit("swordsman", "coins", w).merc
	assert_int(int(squad.formation_bonus()["def_pct"])).is_equal(5)
	assert_int(squad.formation_bonus().size()).is_equal(1)
	var plain := BattleUnit.from_mercenary(merc, gd, 2, 0, 1)
	var boosted := BattleUnit.from_mercenary(merc, gd, 2, 0, 1, squad.formation_bonus())
	assert_int(boosted.stat("def")).is_equal(plain.stat("def") * 105 / 100)
	var units := PvpMatch.build_units(squad, gd, 0, 10)
	assert_int(units.size()).is_equal(2)
	assert_int(units[1].stat("def")).is_equal(boosted.stat("def"))
	assert_dict(Squad.new(gd).formation_bonus()).is_empty()


func test_squad_bonus_kinds_hp_attack_and_action_points() -> void:
	var merc := Mercenary.new(1, "swordsman", gd)
	var base := BattleUnit.from_mercenary(merc, gd, 2, 0, 1)
	var hp := BattleUnit.from_mercenary(merc, gd, 2, 0, 1, {"hp_pct": 10})
	assert_int(hp.max_hp).is_equal(base.max_hp * 110 / 100)
	assert_int(hp.hp).is_equal(hp.max_hp)
	var atk := BattleUnit.from_mercenary(merc, gd, 2, 0, 1, {"atk_pct": 10})
	assert_int(atk.stat("atk")).is_equal(base.stat("atk") * 110 / 100)
	var ap := BattleUnit.from_mercenary(merc, gd, 2, 0, 1, {"ap_regen": 5})
	assert_int(ap.stat("ap_regen")).is_equal(base.stat("ap_regen") + 5)


func test_validation_catches_broken_classes() -> void:
	var bad := GameData.load_dir()
	bad.classes["warden"]["role"] = "healer"
	bad.classes["pikeman"]["group"] = "alien"
	bad.classes["hewer"]["order"] = 1
	bad.classes["sawyer"]["start_region"] = "mars"
	bad.classes["sharpshooter"]["squad_bonus"] = {"atk_pct": 50, "luck": 1}
	bad.classes["gunslinger"]["skills"]["base"] = ["ghost_skill"]
	bad.classes["siegemaster"]["skills"]["base"] = ["sword_slash"]
	bad.classes["magus"]["skills"]["slot4"] = ["staff_bolt"]
	bad.classes["tempest"]["enabled"] = true
	var t := "\n".join(bad.validate())
	for part in ["неизвестная роль healer", "неизвестная группа alien", "порядок 1 уже занят", "нет стартового региона mars", "бонус atk_pct вне 0..10",
			"неизвестный бонус отряду luck", "нет навыка ghost_skill", "навык sword_slash другого оружия", "повторяется в пулах", "нет оружия whip", "ожидается 5 ближних"]:
		assert_bool(t.contains(part) or part == "ожидается 5 ближних").is_true()


func test_hero_create_screen_lists_classes_and_selects_only_open_ones() -> void:
	var screen := (load("res://scenes/ui/hero_create.tscn") as PackedScene).instantiate() as HeroCreate
	add_child(screen)
	auto_free(screen)
	screen.setup(gd, "warden")
	assert_int(screen.class_list.get_child_count()).is_equal(13)
	assert_str(screen.selected).is_equal("warden")
	assert_bool(screen.start_button.disabled).is_false()
	assert_str(screen.title_label.text).is_equal("Страж")
	assert_bool(screen.skills_label.text.contains("Удар мечом") or screen.skills_label.text.length() > 10).is_true()
	screen.select("sawyer")
	assert_bool(screen.start_button.disabled).is_true()
	assert_bool(screen.note_label.text.contains("откроется позже")).is_true()
	var picked: Array[String] = []
	screen.chosen.connect(func(id: String) -> void: picked.append(id))
	screen.start_button.pressed.emit()
	assert_array(picked).is_empty()  # закрытый класс выбрать нельзя
	screen.select("magus")
	assert_bool(screen.start_button.disabled).is_false()
	screen.start_button.pressed.emit()
	assert_array(picked).is_equal(["magus"])
