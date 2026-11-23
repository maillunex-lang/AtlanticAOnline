class_name DunesMap
extends RefCounted

const SPEED := 330.0
const FEET_RADIUS := 16.0
const DUNES := "z_dunes"
const CANYON := "z_canyon"
const ZONES := ["z_oasis", DUNES, CANYON]
const COMBAT_ZONES := [DUNES, CANYON]
const CANYON_PACK_TILES := [Vector2i(113, 113), Vector2i(119, 117), Vector2i(113, 119),
	Vector2i(151, 113), Vector2i(151, 119), Vector2i(122, 112)]
const CANYON_CONTACT_TILE := Vector2i(145, 109)
const CANYON_QUEST := "q_drop_canyon"
const CANYON_ENCOUNTER := "enc_canyon_mummies"

const PACK_TILES := [Vector2i(85, 110), Vector2i(85, 104), Vector2i(85, 116),
	Vector2i(79, 104), Vector2i(79, 116), Vector2i(78, 110)]
const SAID_TILE := Vector2i(50, 109)

static func encounter(zone: String) -> String:
	return CANYON_ENCOUNTER if zone == CANYON else "enc_dunes_drifters"


static func quest(zone: String) -> String:
	return CANYON_QUEST if zone == CANYON else "q_drop_dunes"


static func contact_tile(zone: String) -> Vector2i:
	return CANYON_CONTACT_TILE if zone == CANYON else SAID_TILE


static func pack_tiles(zone: String) -> Array:
	return CANYON_PACK_TILES if zone == CANYON else PACK_TILES


static func pack_id(zone: String, index: int) -> String:
	return ("canyon_pack_%d" if zone == CANYON else "dunes_pack_%d") % (index + 1)


static func point(tile: Vector2i, tile_px: float) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * tile_px
