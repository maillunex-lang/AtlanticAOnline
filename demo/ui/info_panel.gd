class_name InfoPanel
extends Control
## Нижняя панель для диалога и итога боя. Сцена scenes/ui/info_panel.tscn: заголовок, список текстов, список кнопок выбора.

@onready var title_label: Label = %TitleLabel
@onready var body_list: VBoxContainer = %BodyList
@onready var choice_list: VBoxContainer = %ChoiceList


func clear() -> void:
	for box in [body_list, choice_list]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()


func set_title(text: String, color := Color("ffe9a8")) -> void:
	title_label.text = text
	title_label.add_theme_color_override("font_color", color)


func add_text(text: String, size := 22) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	body_list.add_child(l)


func add_illustration(texture: Texture2D, height: float) -> void:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size.y = height
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_list.add_child(picture)


func add_choice(text: String, cb: Callable, height := 62.0) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	choice_list.add_child(b)
