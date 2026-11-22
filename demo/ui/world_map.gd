class_name WorldMapScreen
extends HBoxContainer

const COASTLINES := preload("res://demo/assets/ui/world_coastlines.png")
const ERRORS := {
	"busy": "Герой уже в пути", "already_there": "Вы уже здесь",
	"level_too_low": "Требуется более высокий уровень", "not_town": "Телепорт доступен к поселениям",
	"not_discovered": "Сначала посетите поселение", "no_bureau": "Здесь нет бюро путешествий",
	"no_coins": "Недостаточно монет", "no_license": "Нужна лицензия", "no_will": "Недостаточно воли",
	"no_scene": "Локация ещё не доступна в демо",
}

var menu: MenuScreen
var part := "surface"
var region := ""
var destination := ""
var only_favorites := false
var region_ids: Array[String] = []
var zone_ids: Array[String] = []
var _points := {}
var _next_update := 0.0

@onready var chart: Control = %Chart
@onready var regions: OptionButton = %Regions
@onready var zones: ItemList = %Zones
@onready var current: Label = %Current
@onready var details: Label = %Details
@onready var favorite: Button = %Favorite
@onready var teleport: Button = %Teleport
@onready var bureau: Button = %Bureau
@onready var licensed: CheckButton = %Licensed
@onready var favorites_only: CheckButton = %FavoritesOnly


func _ready() -> void:
	%Surface.pressed.connect(_set_part.bind("surface"))
	%Atlantis.pressed.connect(_set_part.bind("atlantis"))
	regions.item_selected.connect(func(index): _set_region(region_ids[index]))
	zones.item_selected.connect(func(index):
		destination = zone_ids[index]
		menu.message = ""
		_actions())
	favorite.pressed.connect(func(): menu.main.world.toggle_favorite(destination); rebuild(menu))
	teleport.pressed.connect(_travel.bind(false))
	bureau.pressed.connect(_travel.bind(true))
	licensed.toggled.connect(func(enabled):
		menu.main.settings.teleport_license = enabled
		menu.main.settings.save_file()
		_actions())
	favorites_only.toggled.connect(func(enabled): only_favorites = enabled; rebuild(menu))
	chart.draw.connect(_draw_map)
	chart.resized.connect(chart.queue_redraw)
	chart.gui_input.connect(_map_input)


func _process(_delta: float) -> void:
	if menu != null and is_visible_in_tree() and menu.main.now >= _next_update:
		_next_update = menu.main.now + 1.0
		_actions()


func rebuild(p_menu: MenuScreen) -> void:
	menu = p_menu
	var state := menu.main.world
	var gd := menu.main.gd
	if region.is_empty():
		region = state.region()
		part = str(gd.regions.get(region, {}).get("part", "surface"))
	region_ids.clear()
	regions.clear()
	for id in gd.region_order:
		var entry: Dictionary = gd.regions[id]
		if entry["part"] == part:
			region_ids.append(id)
			regions.add_item(str(entry["name"]))
	if region not in region_ids:
		region = region_ids[0] if not region_ids.is_empty() else ""
	regions.select(region_ids.find(region))
	%Surface.disabled = part == "surface"
	%Atlantis.disabled = part == "atlantis"
	licensed.set_pressed_no_signal(menu.main.settings.teleport_license)
	favorites_only.set_pressed_no_signal(only_favorites)
	zones.clear()
	zone_ids.clear()
	for entry in gd.world["zones"]:
		var id := str(entry["id"])
		if (not only_favorites and entry.get("region") != region) or (only_favorites and not state.favorites.has(id)):
			continue
		zone_ids.append(id)
		var kind := {"town": "Город", "outpost": "Форпост", "dungeon": "Подземелье"}.get(str(entry["type"]), "Поле") as String
		var marker := "★ " if state.favorites.has(id) else ""
		var here := " · вы здесь" if id == state.zone_id else ""
		var icon: String = {"town": "shield", "outpost": "shield2", "dungeon": "key"}.get(str(entry["type"]), "sword")
		zones.add_item("%s%s  ·  %s%s" % [marker, entry["name"], kind, here], Art.icon(icon))
	if destination not in zone_ids:
		destination = state.zone_id if state.zone_id in zone_ids else (zone_ids[0] if not zone_ids.is_empty() else "")
	if destination != "":
		zones.select(zone_ids.find(destination))
	_actions()
	chart.queue_redraw()


func _set_part(value: String) -> void:
	part = value
	region = ""
	destination = ""
	# Пустой регион выбирается из открытой вкладки, даже если герой на другой части карты.
	if not menu.main.gd.region_order.is_empty():
		for id in menu.main.gd.region_order:
			if menu.main.gd.regions[id]["part"] == part:
				region = id
				break
		if region == "":
			region = "-"
	rebuild(menu)


func _set_region(id: String) -> void:
	menu.message = ""
	region = id
	destination = ""
	rebuild(menu)


func _actions() -> void:
	var state := menu.main.world
	var now := menu.main.now
	current.text = "Вы здесь: %s     Воля: %d/%d" % [state.graph.zones[state.zone_id]["name"], state.will_at(now), state.will_max()]
	favorite.disabled = destination.is_empty()
	favorite.text = "Убрать ★" if state.favorites.has(destination) else "В избранное ★"
	if destination.is_empty():
		details.text = "Здесь пока нет доступных локаций."
	else:
		var tag := "Открыта" if state.discovered.has(destination) else "Не посещена"
		details.text = "%s · уровень %d. %s" % [tag, state.graph.min_level(destination), menu.message]
	for button in [teleport, bureau]:
		var is_bureau: bool = button == bureau
		var prefix := "Бюро" if is_bureau else "Телепорт"
		var quote := state.map_quote(destination, menu.main.squad.hero.level, now, licensed.button_pressed, int(menu.main.wallet["coins"]), is_bureau)
		var present := menu.main.map.has_zone_scene(destination)
		button.disabled = not quote.ok or not present
		button.text = "%s · %d воли%s" % [prefix, quote.will, " + %d монет" % quote.coins if quote.coins > 0 else ""] if quote.ok else prefix
		var reason := str(quote.get("error", "")) if present else "no_scene"
		button.tooltip_text = ERRORS.get(reason, "") if button.disabled else ""
		if button == teleport and destination != "" and button.disabled and menu.message.is_empty():
			details.text += " " + button.tooltip_text


func _travel(use_bureau: bool) -> void:
	var error := menu.main.map_teleport(destination, use_bureau)
	if error != "":
		menu.message = ERRORS.get(error, error)
		_actions()


func _draw_map() -> void:
	if menu == null:
		return
	var scale_size := chart.size
	chart.draw_rect(Rect2(Vector2.ZERO, scale_size), Color("102a33"))
	for n in 9:
		var t := (n + 1) / 10.0
		chart.draw_line(Vector2(scale_size.x * t, 0), Vector2(scale_size.x * t, scale_size.y), Color("24444c"))
		chart.draw_line(Vector2(0, scale_size.y * t), Vector2(scale_size.x, scale_size.y * t), Color("24444c"))
	if part == "surface":
		chart.draw_texture_rect(COASTLINES, Rect2(Vector2(28, 28), scale_size - Vector2(56, 56)), false)
	_points.clear()
	for id in region_ids:
		var coord: Array = menu.main.gd.regions[id]["map_pos"]
		var at := _chart_pos(coord)
		_points[id] = at
		var active := id == menu.main.world.region()
		chart.draw_circle(at, 16 if id == region else 11, Color("f9cf84") if active else Color("78c9bd") if id == region else Color("477477"))
		if active or id == region:
			chart.draw_arc(at, 21, 0, TAU, 30, Color("f1e5bb"), 2)


func _chart_pos(coords: Array) -> Vector2:
	return Vector2(28, 28) + (chart.size - Vector2(56, 56)) * Vector2(float(coords[0]), float(coords[1])) / 1000.0


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var best := ""
		var best_distance := 27.0
		for id in _points:
			var distance: float = (event.position as Vector2).distance_to(_points[id])
			if distance < best_distance:
				best = id
				best_distance = distance
		if best != "":
			_set_region(best)
