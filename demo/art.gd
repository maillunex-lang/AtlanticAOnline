class_name Art
extends RefCounted
## Загрузка текстур демо (CC0, Kenney, см. third_party/ASSETS.md) и соответствие бойцов спрайтам.

const BASE := "res://demo/assets/"
## Масштаб пикселей: плитка 16x16 рисуется как 64x64, персонажи 80x80.
const TILE_SCALE := 4
const TILE := 16 * TILE_SCALE
const CHAR := 80

const HERO_SPRITES := {"sword": "knight", "spear": "knight_helm", "axe": "viking", "gun": "soldier", "bow": "elf", "cannon": "ogre", "staff": "wizard"}
const MERC_SPRITES := {"sword": "knight_helm", "spear": "soldier", "axe": "viking", "gun": "villager", "bow": "elf", "cannon": "lady", "staff": "wizard",
	"whip": "hooded", "dual_sword": "knight", "armor_fist": "ogre", "power_saw": "soldier", "instrument": "captain"}
const MONSTER_SPRITES := {
	"slime": "slime", "wolf": "wolf", "bandit": "bandit", "bandit_archer": "hooded",
	"golem": "stone_golem", "cave_spider": "spider", "ruin_guard": "ruin_guard", "ruin_boss": "ruin_boss",
	"harpy": "harpy", "hill_brute": "viking", "scorpion": "scorpion", "sand_mage": "sand_mage",
	"dune_raider": "dune_raider", "mummy": "mummy", "tomb_boss": "tomb_boss", "tomb_dust_guard": "tomb_dust_guard",
}

static var _cache: Dictionary = {}


static func load_tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(BASE + path)
	return _cache[path]


static func tile(name: String) -> Texture2D:
	return load_tex("tiles/%s.png" % name)


static func icon(name: String) -> Texture2D:
	return load_tex("icons/%s.png" % name)


static func character(name: String) -> Texture2D:
	return load_tex("chars/%s.png" % name)


static func hero_portrait(class_id: String, fallback: Texture2D) -> Texture2D:
	return _hero_image(class_id, "portrait", fallback)


static func hero_formation_sprite(class_id: String, fallback: Texture2D) -> Texture2D:
	return _hero_image(class_id, "south", fallback)


static func _hero_image(class_id: String, image: String, fallback: Texture2D) -> Texture2D:
	for name in [image, "idle_south"]:
		var path := "res://assets/heroes/%s/%s.png" % [class_id, name]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return fallback


## Имя спрайта персонажа для бойца отряда: герой и наёмники выглядят по-разному.
static func merc_sprite(def_id: String, weapon: String) -> String:
	if def_id.begins_with("hero_"):
		return str(HERO_SPRITES.get(weapon, "knight"))
	return str(MERC_SPRITES.get(weapon, "soldier"))


static func monster_sprite(monster_id: String) -> String:
	return str(MONSTER_SPRITES.get(monster_id, "slime"))
