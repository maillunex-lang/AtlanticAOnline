class_name ChunkGrid
extends RefCounted
## Сетка чанков мира (WP-22A): чистая логика без сцен, одна и та же на клиенте (потоковая подгрузка) и на сервере (видимость игроков, WP-72).
## Чанк: квадрат `chunk_tiles` x `chunk_tiles` плиток по `tile_px` пикселей мира (плитка 16 px, масштаб x4 = 64 px, чанк 32 плитки = 2048 px).
## Координата чанка (x, y) целая, чанк (0, 0) начинается в точке мира (0, 0).
##
## Подгрузка идёт по расстоянию в пикселях от героя до прямоугольника чанка с гистерезисом: грузим ближе `load_margin`,
## выгружаем только дальше `unload_margin` (unload_margin > load_margin), поэтому на границе чанки не мигают.

var chunk_tiles := 32
var tile_px := 64.0
var load_margin := 1200.0
var unload_margin := 2400.0


static func from_rules(rules: Dictionary) -> ChunkGrid:
	var g := ChunkGrid.new()
	var c: Dictionary = rules.get("chunks", {})
	g.chunk_tiles = int(c.get("chunk_tiles", 32))
	g.tile_px = float(c.get("tile_px", 64))
	g.load_margin = float(c.get("load_margin_px", 1200))
	g.unload_margin = float(c.get("unload_margin_px", 2400))
	return g


func chunk_px() -> float:
	return chunk_tiles * tile_px


func coord_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_px()), floori(pos.y / chunk_px()))


func rect_of(coord: Vector2i) -> Rect2:
	return Rect2(Vector2(coord) * chunk_px(), Vector2(chunk_px(), chunk_px()))


## Расстояние от точки до прямоугольника чанка (0 внутри).
func distance_to(coord: Vector2i, pos: Vector2) -> float:
	var r := rect_of(coord)
	var dx := maxf(maxf(r.position.x - pos.x, 0.0), pos.x - r.end.x)
	var dy := maxf(maxf(r.position.y - pos.y, 0.0), pos.y - r.end.y)
	return Vector2(dx, dy).length()


## План подгрузки. existing: словарь координат чанков, которые есть в мире (ключи Vector2i); loaded: координаты уже загруженных
## (или загружаемых). Возвращает {"load": [...по возрастанию расстояния], "unload": [...по убыванию расстояния]}.
func plan(pos: Vector2, existing: Dictionary, loaded: Array) -> Dictionary:
	var want: Array = []
	var span := ceili(load_margin / chunk_px()) + 1
	var c := coord_of(pos)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var k := Vector2i(c.x + dx, c.y + dy)
			if existing.has(k) and not loaded.has(k) and distance_to(k, pos) <= load_margin:
				want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return distance_to(a, pos) < distance_to(b, pos))
	var drop: Array = []
	for k in loaded:
		if distance_to(k, pos) > unload_margin:
			drop.append(k)
	drop.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return distance_to(a, pos) > distance_to(b, pos))
	return {"load": want, "unload": drop}


## Чанки, видимые игроку на расстоянии `radius_px` (для сервера: кому отправлять события).
func within(pos: Vector2, radius_px: float, existing: Dictionary) -> Array:
	var out: Array = []
	var span := ceili(radius_px / chunk_px()) + 1
	var c := coord_of(pos)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var k := Vector2i(c.x + dx, c.y + dy)
			if existing.has(k) and distance_to(k, pos) <= radius_px:
				out.append(k)
	return out
