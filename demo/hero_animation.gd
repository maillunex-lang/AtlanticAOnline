class_name HeroAnimation
extends AnimatedSprite2D

const HERO_IDS := ["warden", "sharpshooter", "magus"]
const ROOT := "res://assets/heroes/"
static var _frames_by_hero: Dictionary = {}


static func create_for(hero_id: String) -> HeroAnimation:
	if hero_id not in HERO_IDS:
		return null
	var frames := _frames_by_hero.get(hero_id) as SpriteFrames
	if frames == null:
		var path := "%s%s/%s.animation.json" % [ROOT, hero_id, hero_id]
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			return null
		var atlas := load(ROOT + str(data["image"])) as Texture2D
		if atlas == null:
			return null
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for clip: Dictionary in data["clips"]:
			var name := StringName("%s_%s" % [clip["animation"], clip["direction"]])
			frames.add_animation(name)
			frames.set_animation_speed(name, float(clip["fps"]))
			frames.set_animation_loop(name, bool(clip["loop"]))
			for frame_data: Dictionary in clip["frames"]:
				var texture := AtlasTexture.new()
				texture.atlas = atlas
				texture.region = Rect2(frame_data["x"], frame_data["y"], frame_data["w"], frame_data["h"])
				texture.filter_clip = true
				frames.add_frame(name, texture)
		_frames_by_hero[hero_id] = frames
	var animation := HeroAnimation.new()
	animation.sprite_frames = frames
	animation.centered = false
	# Keep the package's (8, 15) foot anchor on the map point or formation cell.
	animation.offset = Vector2(-8, -15)
	animation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return animation


static func facing(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "east" if direction.x > 0.0 else "west"
	return "south" if direction.y > 0.0 else "north"
