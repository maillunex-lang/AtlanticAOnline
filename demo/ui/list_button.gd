class_name ListButton
extends Button
## Строка списка: иконка и текст. Сцена scenes/ui/list_button.tscn используется для бойцов, предметов, рецептов и т.п.

@onready var icon_rect: TextureRect = %Icon
@onready var text_label: Label = %TextLabel


func setup(text: String, icon: Texture2D = null, min_height := 64.0, font_size := 20) -> void:
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", font_size)
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	custom_minimum_size.y = min_height
	icon_rect.modulate = Color.WHITE if not disabled else Color(0.6, 0.6, 0.65)
