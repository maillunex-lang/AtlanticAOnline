class_name DunesMap
extends RefCounted

const SPEED := 330.0
const FEET_RADIUS := 16.0
const DUNES := "z_dunes"
const ZONES := ["z_oasis", DUNES]
const PACK_TILES := [Vector2i(85, 110), Vector2i(85, 104), Vector2i(85, 116),
	Vector2i(79, 104), Vector2i(79, 116), Vector2i(78, 110)]
const SAID_TILE := Vector2i(50, 109)

static func point(tile: Vector2i, tile_px: float) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * tile_px
