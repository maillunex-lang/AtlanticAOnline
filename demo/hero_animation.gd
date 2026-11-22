class_name HeroAnimation
extends AnimatedSprite2D

const ROOT := "res://assets/heroes/"
static var _assets_by_hero: Dictionary = {}


static func create_for(hero_id: String) -> HeroAnimation:
	var asset: Dictionary = _assets_by_hero.get(hero_id, {})
	if asset.is_empty():
		var path := "%s%s/%s.animation.json" % [ROOT, hero_id, hero_id]
		if not FileAccess.file_exists(path):
			return null
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			return null
		var atlas := load(ROOT + str(data["image"]).trim_prefix("assets/heroes/")) as Texture2D
		if atlas == null:
			return null
		var frames := SpriteFrames.new()
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
		asset = {
			"frames": frames,
			"anchor": Vector2(data["anchor"][0], data["anchor"][1]),
			"frame_width": float(data["frame_size"][0]),
		}
		_assets_by_hero[hero_id] = asset
	var animation := HeroAnimation.new()
	animation.sprite_frames = asset["frames"]
	animation.centered = false
	animation.offset = -asset["anchor"]
	animation.scale = Vector2.ONE * (Art.CHAR / float(asset["frame_width"]))
	animation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return animation


static func facing(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "east" if direction.x > 0.0 else "west"
	return "south" if direction.y > 0.0 else "north"
