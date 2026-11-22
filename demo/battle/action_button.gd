class_name ActionButton
extends Button
## Строка меню действий бойца: иконка, название, описание и цена в очках действий.

@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var cost_label: Label = %CostLabel


func setup(icon: Texture2D, title: String, detail: String, cost: String, enabled: bool) -> void:
	icon_rect.texture = icon
	title_label.text = title
	detail_label.text = detail
	cost_label.text = cost
	disabled = not enabled
	icon_rect.modulate = Color.WHITE if enabled else Color(0.6, 0.6, 0.65)
