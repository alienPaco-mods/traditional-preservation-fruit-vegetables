#!/usr/bin/env python3
"""Paints the tomato paste icons of Traditional Preservation (Fruits and Vegetables) into 42/media/textures.

The Crock of Tomato Paste is vanilla's fired clay jar or glazed jar with the paste filling its mouth (the region and
the darkness test are Fish & Meat's Crock of Potted Meat), in two seals: a salt crust (pale salt flecks) or a cap of
oil or fat (a thin pale band over the paste). A spooned portion of Tomato Paste is vanilla's bowl of seed paste with
the paste turned a dark brick red. Approved mock: WIP/TPCore/art/tomato_paste_mock.py (user, 2026-11-27: "a darker
red, it's too bloodlike").

Usage: python3 tools/build_food_icons.py [path/to/ProjectZomboid/projectzomboid]
Needs Pillow. Rerun after editing the colours below.
"""
import os
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import pzart  # noqa: E402

GAME = Path.home() / ".local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
ICON_PACKS = ["UI2.pack", "UI.pack"]
PASTE = (112, 40, 20)         # cooked-down tomato: a dark brick red-brown
PASTE_LIGHT = (140, 56, 28)
SALT = (232, 224, 214)
CAP = (236, 214, 150)         # oil or set fat over the paste
# Our crock icon: the vanilla jar it starts from and whether it is capped. The crock's model index picks among them
# in this order (IconsForTexture): clay, glazed; the sealed crock's the same two capped.
CROCKS = {
    "TomatoPaste_Clay": ("Item_ClayJar_Fired", False),
    "TomatoPaste_Glazed": ("Item_ClayJar_Glazed_Fired", False),
    "TomatoPaste_ClayCapped": ("Item_ClayJar_Fired", True),
    "TomatoPaste_GlazedCapped": ("Item_ClayJar_Glazed_Fired", True),
}
BOWL = "Item_Flax_PasteBowl"
# A glass jar (vanilla's Empty Jar and Crafted Jar) holds it too, no lid (user, 2026-11-27): model index 2.
JARS = {"TomatoPaste_Jar": False, "TomatoPaste_JarCapped": True}
GLASS = "Item_GlassJar"


def crock(image, capped):
    """The jar's dark mouth filled with paste lit from the upper left, with salt flecks; capped, its top rows a thin
    pale cap instead."""
    icon = image.convert("RGBA").copy()
    pixels = icon.load()
    dots = random.Random(3)
    for y in range(3, 12):
        for x in range(19, 29):
            r, g, b, a = pixels[x, y]
            if a > 128 and 120 <= r + g + b < 260:
                shade = 1.05 - 0.03 * (y - 3) - 0.012 * (x - 19)
                colour = PASTE_LIGHT if (x + y) % 5 == 0 else PASTE
                if capped and y <= 5:
                    colour, shade = CAP, 1.0 - 0.04 * (y - 3)
                elif not capped and dots.random() < 0.12:
                    colour = SALT
                pixels[x, y] = tuple(max(0, min(255, int(c * shade))) for c in colour) + (255,)
    return icon


def jar(image, capped):
    """Vanilla's empty glass jar filled with paste: the glass's pale, bluish inside turned the paste's red below the
    shoulder, its brightest highlights kept as the glass's shine; capped, a thin pale band on top of the paste."""
    icon = image.convert("RGBA").copy()
    pixels = icon.load()
    rows = [y for y in range(icon.height) if any(pixels[x, y][3] > 128 for x in range(icon.width))]
    top = rows[0] + max(4, (rows[-1] - rows[0]) // 4) if rows else 0
    dots = random.Random(5)
    for y in range(top, icon.height):
        opaque = [x for x in range(icon.width) if pixels[x, y][3] > 128]
        left = opaque[0] if opaque else 0
        for x in range(icon.width):
            r, g, b, a = pixels[x, y]
            lum = (r + g + b) / 3
            if a < 128 or lum < 60:
                continue
            if left + 2 <= x <= left + 3 and lum > 200:
                continue  # the glass's shine, a narrow strip down the left
            if capped and y < top + 2:
                colour = CAP
            else:
                colour = PASTE_LIGHT if dots.random() < 0.12 else PASTE
                if not capped and y < top + 2 and dots.random() < 0.3:
                    colour = SALT
            k = 0.75 + 0.45 * lum / 255
            pixels[x, y] = tuple(max(0, min(255, int(c * k))) for c in colour) + (255,)
    return icon


def paste_bowl(image):
    """The seed paste (a grey-green beige: red and green close) turned the paste's red; the wooden bowl (red well
    above green) stays."""
    icon = image.convert("RGBA").copy()
    pixels = icon.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b, a = pixels[x, y]
            lum = (r + g + b) / 3
            if a >= 128 and abs(r - g) < 22 and lum > 40:
                k = lum / 150
                pixels[x, y] = tuple(max(0, min(255, int(c * k))) for c in PASTE) + (a,)
    return icon


def read_icons(game, wanted):
    icons = {}
    for pack in ICON_PACKS:
        for name in sorted(wanted - icons.keys()):
            try:
                icons.update(pzart.extract_sprites(game / "media/texturepacks" / pack, {name}))
            except SystemExit:
                pass  # not in this pack
    if wanted - icons.keys():
        raise SystemExit(f"icons not found in {ICON_PACKS}: {sorted(wanted - icons.keys())}")
    return icons


def main():
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else GAME
    folder = Path(__file__).resolve().parent.parent / "42" / "media" / "textures"
    icons = read_icons(game, {source for source, _ in CROCKS.values()} | {BOWL, GLASS})
    for name, capped in JARS.items():
        jar(icons[GLASS], capped).save(folder / f"Item_{name}.png")
    for name, (source, capped) in CROCKS.items():
        crock(icons[source], capped).save(folder / f"Item_{name}.png")
    paste_bowl(icons[BOWL]).save(folder / "Item_TomatoPaste.png")
    print(f"wrote {len(CROCKS) + len(JARS) + 1} icons to {folder}")


if __name__ == "__main__":
    main()
