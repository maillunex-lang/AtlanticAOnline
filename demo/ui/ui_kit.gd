class_name UiKit
extends RefCounted
## Пиксельная тема интерфейса (Kenney UI Pack Pixel Adventure, CC0). Панели и кнопки это 9-slice из плиток, увеличенных в 4 раза.
## Размеры под касание: кнопки не ниже 64 px, шрифт не меньше 18.

const MARGIN := 20
static var _theme: Theme = null


static func tex(name: String) -> Texture2D:
	return load("res://demo/assets/ui/%s.png" % name)


static func box(name: String, modulate := Color.WHITE, content := 14.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = MARGIN
	sb.texture_margin_right = MARGIN
	sb.texture_margin_top = MARGIN
	sb.texture_margin_bottom = MARGIN
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content * 0.7
	sb.content_margin_bottom = content * 0.7
	sb.modulate_color = modulate
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", box("btn"))
	t.set_stylebox("hover", "Button", box("btn", Color(1.15, 1.15, 1.15)))
	t.set_stylebox("pressed", "Button", box("btn", Color(0.78, 0.78, 0.82)))
	t.set_stylebox("disabled", "Button", box("btn", Color(0.45, 0.45, 0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(0.95, 0.9, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.72))
	t.set_color("font_outline_color", "Button", Color(0.1, 0.06, 0.03))
	t.set_constant("outline_size", "Button", 4)
	t.set_constant("icon_max_width", "Button", 56)
	t.set_stylebox("panel", "PanelContainer", box("panel_dark", Color.WHITE, 16.0))
	t.set_color("font_color", "Label", Color(0.95, 0.95, 0.97))
	t.set_stylebox("background", "ProgressBar", box("panel_inner", Color.WHITE, 2.0))
	t.set_stylebox("fill", "ProgressBar", box("btn", Color(0.6, 1.0, 0.6), 2.0))
	_theme = t
	return t


static func window() -> StyleBoxTexture:
	return box("panel_dark", Color.WHITE, 18.0)


static func inner() -> StyleBoxTexture:
	return box("panel_inner", Color(0.8, 0.85, 1.0), 12.0)


static func slot(selected := false) -> StyleBoxTexture:
	return box("slot", Color(1.0, 0.9, 0.45) if selected else Color(0.82, 0.88, 1.0), 6.0)


static func button(text: String, min_size := Vector2(150, 68), font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func label(text: String, size := 20, color := Color(0.95, 0.95, 0.97)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func inner_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", inner())
	p.custom_minimum_size = min_size
	return p


## Иконка предмета. Часть иконок временные: подходящего рисунка в наборах нет.
const ITEM_ICONS := {
	"w_sword_1": "sword", "w_sword_2": "sword2", "w_spear_1": "spear", "w_spear_2": "spear", "w_axe_1": "axe", "w_axe_2": "axe2",
	"w_gun_1": "dagger", "w_gun_2": "hammer", "w_bow_1": "bow", "w_bow_2": "arrow", "w_cannon_1": "bomb", "w_cannon_2": "bomb",
	"w_staff_1": "staff", "w_staff_2": "staff2",
	"a_cloth": "shield", "a_chain": "shield2", "a_plate": "shield2",
	"h_cap": "bucket", "h_helm": "bucket", "h_great": "gem",
	"x_ring": "coin", "x_amulet": "potion_blue", "x_charm": "potion_green",
	"enhance_stone": "potion_red", "iron_ore": "pickaxe", "leather": "backpack", "cloth_scrap": "log",
	"key_ruins": "key", "key_tomb": "key",
}


static func item_icon(def_id: String, def: ItemDef = null) -> Texture2D:
	var icon := str(ITEM_ICONS.get(def_id, ""))
	if icon == "" and def != null and def.is_equip():
		if def.slot == "weapon":
			icon = str(ITEM_ICONS.get("w_%s_1" % def.weapon, "sword"))
		else:
			icon = str({"armor": "shield", "helm": "bucket", "accessory": "gem"}.get(def.slot, "coin"))
	return load("res://demo/assets/icons/%s.png" % (icon if icon != "" else "coin"))


const RARITY_COLORS := {"common": Color(0.92, 0.92, 0.95), "uncommon": Color(0.55, 1.0, 0.6), "rare": Color(0.5, 0.75, 1.0), "legendary": Color(1.0, 0.72, 0.35)}


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Поля безопасной области (вырезы экрана) в единицах окна. На ПК и обычных экранах нули.
static func safe_margins(viewport: Viewport) -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return Vector4.ZERO
	var vp := viewport.get_visible_rect().size
	var kx := vp.x / float(screen.x)
	var ky := vp.y / float(screen.y)
	return Vector4(safe.position.x * kx, safe.position.y * ky, (screen.x - safe.end.x) * kx, (screen.y - safe.end.y) * ky)
