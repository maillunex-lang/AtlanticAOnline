class_name GenLib
extends RefCounted
## Помощники генераторов сцен (tools/gen_*.gd). Сцены создаются один раз, дальше их правят в редакторе Godot.


static func add(parent: Node, node: Node, node_name: String, root: Node, unique := false) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	node.unique_name_in_owner = unique
	return node


static func save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %s: %s" % [path, error_string(err)])
		return
	err = ResourceSaver.save(ps, path)
	print("saved ", path, " -> ", error_string(err))


static func anchors(c: Control, l: float, t: float, r: float, b: float, ol := 0.0, ot := 0.0, orr := 0.0, ob := 0.0) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


static func rect(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


static func label(text: String, size: int, color := Color(0.95, 0.95, 0.97), outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		l.add_theme_constant_override("outline_size", outline)
	return l


static func ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func flat(color: Color, radius := 0, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	return s
