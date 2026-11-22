class_name MenuScreen
extends Control
## Главное меню на весь экран. Оболочка: вкладки сверху, страницы в узле Pages (сцены tab_*.tscn), монеты и «Закрыть».
## Состояние игры живёт в DemoMain, страницы только показывают его и вызывают общую игровую логику.

signal closed

const PAGES := ["squad", "bag", "forge", "quests", "map", "settings"]

var main: DemoMain
var tab := "squad"
var sel_member := 0
var sel_slot := ""
var sel_item := -1
var sel_forge_item := -1
var message := ""

@onready var coins_label: Label = %CoinsLabel
@onready var close_button: Button = %CloseButton
@onready var pages_node: Control = %Pages


func setup(p_main: DemoMain, start_tab: String) -> void:
	main = p_main
	tab = start_tab
	for id in PAGES:
		var b: Button = get_node("%%Tab%sButton" % str(id).capitalize())
		b.pressed.connect(set_tab.bind(id))
	close_button.pressed.connect(func(): closed.emit())
	rebuild()


func set_tab(t: String) -> void:
	tab = t
	message = ""
	rebuild()


func rebuild() -> void:
	coins_label.text = "Монеты: %d" % int(main.wallet["coins"])
	for id in PAGES:
		var b: Button = get_node("%%Tab%sButton" % str(id).capitalize())
		b.disabled = id == tab
		var page: Control = get_node("%%Tab%s" % str(id).capitalize())
		page.visible = id == tab
		if id == tab:
			page.rebuild(self)


## Освободить детей контейнера сразу (чтобы не накапливались до конца кадра).
static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
