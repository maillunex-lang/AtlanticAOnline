"""Scale the original Kenney atlas to the 64 px world grid."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def main():
    with Image.open(ROOT / "demo/assets/atlas/world.png") as original:
        atlas = original.convert("RGBA").resize(
            (original.width * 4, original.height * 4), Image.Resampling.NEAREST
        )
    atlas.save(ROOT / "assets/world/world_atlas_64.png")


if __name__ == "__main__":
    main()
