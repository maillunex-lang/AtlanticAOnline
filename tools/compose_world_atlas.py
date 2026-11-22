"""Build the 64 px Kimi atlas in the existing map's tile order."""
import json
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
TILE = 64
REPLACEMENTS = {
    "grass": "grass_low",
    "grass_tufts": "grass_dense",
    "grass_flowers": "grass_flower",
    "dirt": "dirt_intersection",
    "dirt_a": "dirt_intersection",
    "dirt_b": "dirt_intersection",
    "water": "water_deep",
    "water_b": "water_shallow",
    "tree_round": "tree_oak",
    "tree_pine": "tree_pine",
    "tree_autumn": "tree_birch",
    "bush": "bush",
    "sign": "signpost",
    "fence_h": "rope_fence",
    "mushrooms": "mushrooms",
    "grass_dark": "grass_dense",
    "grass_dark_tufts": "grass_high",
}


STYLIZED = {
    "grass": "grass",
    "grass_tufts": "grass",
    "grass_flowers": "grass",
    "grass_dark": "grass",
    "grass_dark_tufts": "grass",
    "dirt": "path",
    "dirt_a": "path",
    "dirt_b": "path",
    "water": "water",
    "water_b": "water",
    "tree_round": "tree",
    "tree_autumn": "tree",
    "bush": "fern",
    "mushrooms": "mushrooms",
}


def main():
    coordinates = json.loads((ROOT / "tools/atlas_map.json").read_text())["tiles"]
    world = ROOT / "assets/world"
    with Image.open(ROOT / "demo/assets/atlas/world.png") as original:
        atlas = original.convert("RGBA").resize(
            (original.width * 4, original.height * 4), Image.Resampling.NEAREST
        )
    for old_name, new_name in REPLACEMENTS.items():
        x, y = coordinates[old_name]
        with Image.open(world / "tiles_64" / f"{new_name}.png") as tile:
            atlas.paste(tile.convert("RGBA"), (x * TILE, y * TILE))
    for old_name, new_name in STYLIZED.items():
        x, y = coordinates[old_name]
        path = ROOT / "assets/stylized/world" / f"{new_name}.png"
        with Image.open(path) as texture:
            tile = texture.resize((TILE, TILE), Image.Resampling.LANCZOS)
            if old_name in ("grass_dark", "grass_dark_tufts"):
                tile = ImageEnhance.Brightness(tile).enhance(0.85)
            atlas.paste(tile, (x * TILE, y * TILE))
    atlas.save(world / "world_atlas_64.png")


if __name__ == "__main__":
    main()
