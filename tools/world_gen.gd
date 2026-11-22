class_name WorldGen
extends RefCounted
## Генератор чанков мира (WP-22). Читает раскладку зон (tools/world_layout.json) и темы рельефа (tools/world_themes.json),
## строит сцены чанков 32x32 плитки и манифест data/chunks.json. Рельеф считается по глобальным координатам плитки,
## поэтому непрерывен на границах чанков и зон: на стыках тем плитки перемешиваются рваной границей.
## Используется tools/gen_world.gd и тестами. После генерации сцены правят в редакторе Godot; повторный запуск перезапишет правки.

const TILE_PX := 64

var chunk_tiles := 32
var seed_value := 1
var amap: Dictionary = {}
var tileset: TileSet
var themes: Dictionary = {}
var layout: Dictionary = {}
var spawn_scene: PackedScene
var npc_scene: PackedScene
## id зоны -> id региона (из data/world.json), нужен для каталога сцен.
var zone_region: Dictionary = {}
var out_dir := "res://scenes/world"

var zone_of_chunk: Dictionary = {}
var zone_cfg: Dictionary = {}
var _theme_noise: Dictionary = {}
var _keepout: Array[Rect2] = []
var _jitter := FastNoiseLite.new()


func setup(p_layout: Dictionary, p_themes: Dictionary, p_amap: Dictionary, p_tileset: TileSet, p_spawn: PackedScene, p_npc: PackedScene, p_zone_region: Dictionary) -> void:
	layout = p_layout
	themes = p_themes
	amap = p_amap
	tileset = p_tileset
	spawn_scene = p_spawn
	npc_scene = p_npc
	zone_region = p_zone_region
	chunk_tiles = int(layout.get("chunk_tiles", 32))
	seed_value = int(layout.get("seed", 1))
	_jitter.seed = seed_value + 99
	_jitter.frequency = 0.15
	zone_of_chunk.clear()
	zone_cfg.clear()
	_keepout.clear()
	for z in layout["zones"]:
		zone_cfg[str(z["zone"])] = z
		for c in z["chunks"]:
			zone_of_chunk[Vector2i(int(c[0]), int(c[1]))] = str(z["zone"])
		for b in z.get("buildings", []):
			var t: Array = b["tile"]
			_keepout.append(Rect2(Vector2(int(t[0]) - 1, int(t[1]) - 1), Vector2(5, 6)))
		for s in z.get("signs", []):
			_keepout.append(Rect2(Vector2(int(s[0]) - 1, int(s[1]) - 1), Vector2(3, 3)))
		for n in z.get("npcs", []):
			_keepout.append(Rect2(Vector2(int(n["tile"][0]) - 2, int(n["tile"][1]) - 2), Vector2(5, 5)))
		for s in z.get("spawns", []):
			_keepout.append(Rect2(Vector2(int(s["tile"][0]) - 2, int(s["tile"][1]) - 2), Vector2(5, 5)))
	var st: Array = layout["start"]
	_keepout.append(Rect2(Vector2(int(st[0]) - 2, int(st[1]) - 2), Vector2(5, 5)))
	for name in themes:
		if name.begins_with("_"):
			continue
		var th: Dictionary = themes[name]
		var set := {}
		var k := 0
		for key in ["patch", "lake", "trees"]:
			k += 1
			if th.get(key) != null:
				var n := FastNoiseLite.new()
				n.seed = seed_value * 31 + k * 7 + hash(name) % 1000
				n.frequency = float(th[key]["frequency"])
				set[key] = n
		_theme_noise[name] = set


## Ошибки раскладки (до генерации): неизвестные темы и клетки, пересечения зон, несвязные зоны.
func validate() -> Array[String]:
	var errs: Array[String] = []
	var seen := {}
	for z in layout["zones"]:
		var id := str(z["zone"])
		if not themes.has(z["theme"]):
			errs.append("зона %s: нет темы %s" % [id, z["theme"]])
		for c in z["chunks"]:
			var k := Vector2i(int(c[0]), int(c[1]))
			if seen.has(k):
				errs.append("чанк %s занят зонами %s и %s" % [str(k), seen[k], id])
			seen[k] = id
		if not zone_region.has(id):
			errs.append("зона %s: нет в data/world.json" % id)
		for n in z.get("npcs", []) + z.get("spawns", []):
			if zone_of_chunk.get(_chunk_of_tile(n["tile"]), "") != id:
				errs.append("зона %s: маркер %s вне чанков зоны" % [id, str(n["tile"])])
	for r in layout.get("roads", []):
		if (r["points"] as Array).size() < 2:
			errs.append("дорога из одной точки")
	return errs


func _chunk_of_tile(t: Array) -> Vector2i:
	return Vector2i(floori(float(t[0]) / chunk_tiles), floori(float(t[1]) / chunk_tiles))


func scene_path(coord: Vector2i) -> String:
	var zone: String = zone_of_chunk[coord]
	return "%s/%s/chunk_%d_%d.tscn" % [out_dir, zone_region[zone], coord.x, coord.y]


## Манифест чанков (формат docs/plan/CHUNK_FORMAT.md) с зонами и стартом героя.
func manifest() -> Dictionary:
	var chunks: Array = []
	var coords: Array = zone_of_chunk.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in coords:
		chunks.append({"x": c.x, "y": c.y, "scene": scene_path(c), "zone": zone_of_chunk[c]})
	var zones := {}
	for id in zone_cfg:
		zones[id] = {"color": zone_cfg[id].get("color", "6a8f4e"), "theme": zone_cfg[id]["theme"]}
	return {"chunk_tiles": chunk_tiles, "start": layout["start"], "zones": zones, "chunks": chunks}


func _road_dist(p: Vector2) -> float:
	var best := 1e9
	for r in layout.get("roads", []):
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) - float(r.get("width", 3)) * 0.5)
	return best


func _in_keepout(p: Vector2) -> bool:
	for r in _keepout:
		if r.has_point(p):
			return true
	return false


func theme_name_at(gx: int, gy: int) -> String:
	var own: String = zone_of_chunk.get(Vector2i(floori(float(gx) / chunk_tiles), floori(float(gy) / chunk_tiles)), "")
	var ox := _jitter.get_noise_2d(gx, gy) * 4.0
	var oy := _jitter.get_noise_2d(gx + 5000, gy + 5000) * 4.0
	var z: String = zone_of_chunk.get(Vector2i(floori((gx + ox) / chunk_tiles), floori((gy + oy) / chunk_tiles)), own)
	if z == "":
		z = own
	return str(zone_cfg[z]["theme"]) if zone_cfg.has(z) else "meadow"


func _pick(list: Array, r: float) -> String:
	var total := 0.0
	for e in list:
		total += float(e[1])
	var acc := 0.0
	for e in list:
		acc += float(e[1]) / total
		if r <= acc:
			return str(e[0])
	return str(list[list.size() - 1][0])


func _t(layer: TileMapLayer, x: int, y: int, tile_name: String) -> void:
	var c: Array = amap[tile_name]
	layer.set_cell(Vector2i(x, y), 0, Vector2i(int(c[0]), int(c[1])))


func _in_rects(rects: Array, gx: int, gy: int) -> bool:
	for r in rects:
		if gx >= int(r[0]) and gy >= int(r[1]) and gx <= int(r[2]) and gy <= int(r[3]):
			return true
	return false


## Собирает узел чанка. Узел готов к упаковке в PackedScene (owner у детей выставлен).
func build_chunk(coord: Vector2i) -> Node2D:
	var zone: String = zone_of_chunk[coord]
	var zc: Dictionary = zone_cfg[zone]
	var tint := Color(str(themes[zc["theme"]].get("tint", "ffffff")))
	var root := Node2D.new()
	root.set_script(load("res://demo/world/location_chunk.gd"))
	root.name = "chunk_%d_%d" % [coord.x, coord.y]
	root.set("zone_id", zone)
	root.set("size_tiles", Vector2i(chunk_tiles, chunk_tiles))
	root.set("minimap_color", Color(str(zc.get("color", "6a8f4e"))))
	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ground.modulate = tint
	GenLib.add(root, ground, "Ground", root)
	var objects := TileMapLayer.new()
	objects.tile_set = tileset
	objects.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	objects.modulate = tint
	GenLib.add(root, objects, "Objects", root)
	var rng := RandomNumberGenerator.new()
	var origin := coord * chunk_tiles
	for y in chunk_tiles:
		for x in chunk_tiles:
			var gx := origin.x + x
			var gy := origin.y + y
			rng.seed = hash(Vector2i(gx, gy)) + seed_value
			var th_name := theme_name_at(gx, gy)
			var th: Dictionary = themes[th_name]
			var noise: Dictionary = _theme_noise[th_name]
			var center := Vector2(gx + 0.5, gy + 0.5)
			var tile_name := _pick(th["ground"], rng.randf())
			var road_d := _road_dist(center)
			var water := _in_rects(zc.get("water", []), gx, gy)
			if road_d <= 0.5:
				tile_name = ["dirt", "dirt_a", "dirt_b"][rng.randi_range(0, 2)]
			elif water:
				tile_name = "water" if (gx + gy) % 2 == 0 else "water_b"
			else:
				if noise.has("lake") and not _in_keepout(center) and road_d > 4.0 and (noise["lake"] as FastNoiseLite).get_noise_2d(gx, gy) > float(th["lake"]["threshold"]):
					tile_name = "water" if (gx + gy) % 2 == 0 else "water_b"
				elif noise.has("patch") and (noise["patch"] as FastNoiseLite).get_noise_2d(gx, gy) > float(th["patch"]["noise_threshold"]):
					var pt: Array = th["patch"]["tiles"]
					tile_name = str(pt[rng.randi_range(0, pt.size() - 1)])
			_t(ground, x, y, tile_name)
			if tile_name.begins_with("water") or road_d <= 3.0 or _in_keepout(center) or not noise.has("trees"):
				continue
			var tr: Dictionary = th["trees"]
			if (noise["trees"] as FastNoiseLite).get_noise_2d(gx, gy) > float(tr["noise_threshold"]) and rng.randf() < float(tr["density"]):
				var kinds: Array = tr["kinds"]
				_t(objects, x, y, str(kinds[rng.randi_range(0, kinds.size() - 1)]))
	_buildings(zc, coord, objects)
	_decorations(zc, origin, root)
	_markers(zc, coord, root)
	return root


func _buildings(zc: Dictionary, coord: Vector2i, objects: TileMapLayer) -> void:
	var origin := coord * chunk_tiles
	for b in zc.get("buildings", []):
		var red: bool = str(b["kind"]) == "house_red"
		var pre := "roof" if red else "roofg"
		var wall: Array = ["wall_window", "wall_door", "wall"] if red else ["wallg_window", "wallg_door", "wallg"]
		var rows: Array = [[pre + "_top_l", pre + "_top_m", pre + "_top_r"], [pre + "_mid_l", pre + "_mid_m", pre + "_mid_r"], wall]
		for ry in 3:
			for rx in 3:
				var cell := Vector2i(int(b["tile"][0]) + rx, int(b["tile"][1]) + ry) - origin
				if cell.x >= 0 and cell.y >= 0 and cell.x < chunk_tiles and cell.y < chunk_tiles:
					_t(objects, cell.x, cell.y, rows[ry][rx])
	for s in zc.get("signs", []):
		var cell := Vector2i(int(s[0]), int(s[1])) - origin
		if cell.x >= 0 and cell.y >= 0 and cell.x < chunk_tiles and cell.y < chunk_tiles:
			_t(objects, cell.x, cell.y, "sign")


func _decorations(zc: Dictionary, origin: Vector2i, root: Node2D) -> void:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(chunk_tiles, chunk_tiles))
	for entry in zc.get("decorations", []):
		var tile: Array = entry["tile"]
		var cell := Vector2i(int(tile[0]), int(tile[1])) - origin
		if not bounds.has_point(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/stylized/world/%s.png" % entry["texture"])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(0.7, 0.7)
		sprite.offset.y = -96
		sprite.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PX
		GenLib.add(root, sprite, "Decoration_%s_%d_%d" % [entry["texture"], cell.x, cell.y], root)


func _markers(zc: Dictionary, coord: Vector2i, root: Node2D) -> void:
	var origin := coord * chunk_tiles
	var i := 1
	for sp in zc.get("spawns", []):
		var cell := Vector2i(int(sp["tile"][0]), int(sp["tile"][1])) - origin
		if cell.x < 0 or cell.y < 0 or cell.x >= chunk_tiles or cell.y >= chunk_tiles:
			continue
		var inst: Marker2D = spawn_scene.instantiate()
		inst.set("encounter_id", sp["encounter"])
		inst.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PX
		GenLib.add(root, inst, "EnemySpawn%d" % i, root)
		i += 1
	for n in zc.get("npcs", []):
		var cell := Vector2i(int(n["tile"][0]), int(n["tile"][1])) - origin
		if cell.x < 0 or cell.y < 0 or cell.x >= chunk_tiles or cell.y >= chunk_tiles:
			continue
		var inst: Marker2D = npc_scene.instantiate()
		inst.set("npc_id", n["npc"])
		inst.set("sprite_name", n.get("sprite", "captain"))
		inst.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PX
		GenLib.add(root, inst, "Npc_%s" % str(n["npc"]), root)
