"""Prepare the game's textures from the supplied stylized fantasy ZIP."""
import argparse
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


OUTPUT = Path(__file__).resolve().parents[1] / "assets/stylized"
SOURCE = "stylized_fantasy_game_assets/assets/"


def read(archive, path):
    with Image.open(BytesIO(archive.read(SOURCE + path))) as source:
        return source.convert("RGBA")


def write(image, path):
    destination = OUTPUT / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, optimize=True)


def fit(image, size):
    image.thumbnail(size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.paste(image, ((size[0] - image.width) // 2, size[1] - image.height))
    return result


def isolate(image, seed):
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= 28 else 0)
    ImageDraw.floodfill(mask, seed, 128)
    component = mask.point(lambda value: 255 if value == 128 else 0)
    image.putalpha(ImageChops.multiply(alpha, component.filter(ImageFilter.MaxFilter(5))))
    return image


def seamless_tile(image):
    size = 64
    edge = 10
    texture = image.resize((size, size), Image.Resampling.BOX)
    mask = Image.new("L", texture.size)
    mask.putdata([
        round(128 * max(0, edge - min(x, size - 1 - x)) / edge)
        for _y in range(size) for x in range(size)
    ])
    texture = Image.composite(ImageOps.mirror(texture), texture, mask)
    return Image.composite(ImageOps.flip(texture), texture, mask.transpose(Image.Transpose.TRANSPOSE))


def prepare_world(archive):
    for name, source in {"grass": "grass_texture", "path": "dirt_path_texture", "water": "water_texture"}.items():
        write(seamless_tile(read(archive, f"world/textures/{source}.png")), f"world/{name}.png")
    for name, source, crop in [
        ("tree", "ancient_tree", None),
        ("port_supplies", "port_props", None),
        ("mossy_rock", "forest_props", (18, 30, 437, 398)),
        ("mushrooms", "forest_props", (441, 24, 643, 214)),
        ("fern", "forest_props", (478, 239, 696, 413)),
        ("ruin_wall", "ruins_props", (0, 7, 420, 563)),
        ("ruin_arch", "ruins_props", (671, 78, 1024, 569)),
    ]:
        image = read(archive, f"world/objects/object_{source}.png")
        if crop:
            image = image.crop(crop)
            if name == "fern":
                ImageDraw.Draw(image).rectangle((191, 0, image.width, 27), fill=(0, 0, 0, 0))
        write(fit(image, (192, 192)), f"world/{name}.png")


def prepare_ui(archive):
    panel = read(archive, "ui/stylized/panels/ui_panel_darkblue_gold.png")
    write(panel.resize((192, 128), Image.Resampling.LANCZOS), "ui/panel.png")
    buttons = read(archive, "ui/stylized/buttons/ui_buttons_states.png")
    for state, bounds in {
        "normal": (24, 94, 502, 263),
        "pressed": (531, 96, 1008, 268),
        "selected": (1034, 72, 1536, 280),
        "disabled": (1558, 92, 2025, 263),
    }.items():
        write(buttons.crop(bounds).resize((192, 64), Image.Resampling.LANCZOS), f"ui/button_{state}.png")
    icons = read(archive, "ui/stylized/icons/ui_icons_sheet.png")
    for name, bounds in {
        "sword": (22, 10, 441, 507),
        "shield": (446, 62, 841, 463),
        "potion_red": (867, 60, 1213, 454),
        "gold": (1233, 91, 1585, 385),
        "map": (1598, 45, 2036, 499),
        "gear": (14, 557, 405, 953),
        "bow": (411, 502, 879, 1012),
        "staff": (820, 462, 1249, 1013),
        "backpack": (1230, 510, 1685, 974),
        "quest": (1698, 531, 2033, 976),
    }.items():
        icon = icons.crop(bounds)
        if name in ("bow", "staff", "gear"):
            seeds = {"bow": (231, 246), "staff": (346, 105), "gear": (196, 78)}
            # Use the targeted component only when the seed lies inside it.
            if icon.getpixel(seeds[name])[3] >= 28:
                icon = isolate(icon, seeds[name])
        write(fit(icon, (96, 96)), f"ui/icons/{name}.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    with ZipFile(parser.parse_args().archive) as archive:
        prepare_world(archive)
        prepare_ui(archive)


if __name__ == "__main__":
    main()
