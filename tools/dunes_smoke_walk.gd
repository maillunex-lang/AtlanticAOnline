extends RefCounted
## Планирует тестовую ходьбу через проходимые клетки и ждёт серверные позиции.

var terrain := DunesTerrain.new(GameData.load_dir())


func walk(tree: SceneTree, read: Callable, move: Callable, tile: Vector2i, reach := 0.1, arrived_early := Callable()) -> bool:
	var current: Vector2 = read.call()
	var start := Vector2i((current / terrain.grid.tile_px).floor())
	var path := _path(start, tile)
	for point: Vector2i in path:
		var destination := terrain.point(point)
		move.call(destination)
		var radius := reach if point == tile else 0.1
		var duration := (read.call() as Vector2).distance_to(destination) / DunesMap.SPEED
		var deadline := Time.get_ticks_msec() + ceili(duration * 1000.0) + 3000
		while (read.call() as Vector2).distance_to(destination) > radius:
			if arrived_early.is_valid() and arrived_early.call():
				return true
			if Time.get_ticks_msec() >= deadline:
				printerr("Waypoint ", point, ", path ", path, ", start ", current)
				return false
			await tree.process_frame
	return not path.is_empty()


func _path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	var index := 0
	while index < queue.size() and not parents.has(target):
		var cell := queue[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not parents.has(next) and not terrain.blocked(terrain.point(next)):
				parents[next] = cell
				queue.append(next)
	if not parents.has(target):
		return []
	var cells: Array[Vector2i] = [target]
	var current := target
	var previous := Vector2i.ZERO
	while current != start:
		var parent: Vector2i = parents[current]
		var direction := current - parent
		if previous != Vector2i.ZERO and direction != previous:
			cells.push_front(current)
		previous = direction
		current = parent
	if target != start:
		cells.push_front(start)
	return cells
