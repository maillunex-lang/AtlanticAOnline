class_name ItemCell
extends Button
## Ячейка предмета или материала с количеством (сумка, формация). Сцена scenes/ui/item_cell.tscn.

@onready var icon_rect: TextureRect = %Icon
@onready var badge_label: Label = %BadgeLabel


func setup(icon: Texture2D, badge := "", selected := false, tip := "") -> void:
	icon_rect.texture = icon
	badge_label.text = badge
	badge_label.visible = badge != ""
	tooltip_text = tip
	add_theme_stylebox_override("normal", UiKit.slot(selected))
	add_theme_stylebox_override("hover", UiKit.slot(true))
	add_theme_stylebox_override("pressed", UiKit.slot(true))
