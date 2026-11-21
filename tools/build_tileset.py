#!/usr/bin/env python3
"""Builds the Kraut Barrel tileset (42/media/*.tiles and texturepacks/*.pack), its icons and the generated Tiles.lua.

The barrel is a standing kraut barrel (a kadka, about 50 L): straight oak staves narrowing to the top, three iron
hoops, in the Salting Tub's wood and iron (Fish & Meat) so the two read as one cooper's work, the tub widening where
the barrel narrows.
Its stages are attached sprites layered on top by the World: shredded cabbage, turnip or both mixed at the rim while
it is being packed, then the cloth, the lid board and the weighting stone once it is weighed down. The shapes are this mod's own;
the stave and hoop pieces are TP Core's pzart (light_at, stave_edges, hoop_bands).

Usage: python3 tools/build_tileset.py [game folder]
Needs Pillow, and the game's UI2.pack for the item icons (vanilla's Cabbage and Turnip, recoloured). Deterministic: a rerun with no change gives byte-identical files.
"""
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import pzart  # noqa: E402

MOD = "TraditionalPreservationFruitVegetables"
NAME = "traditionalpreservationfruitvegetables"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 8
PAGE_SIZE = 512
SS = 4

# Tile index -> facing. S and E, as the entity script's faces. A round barrel looks the same both ways; the two
# faces only differ in their grain.
FACES = ["S", "E"]
GROUP, CUSTOM = "Kraut", "Barrel"
# Each overlay is FACE_COUNT tiles from its base, one per facing.
OVERLAYS = {"cabbage": 2, "turnip": 4, "weighted": 6, "mixed": 8}
# The storages: one facing each, a container from the tile (as Fish & Meat's Stockfish Pallet), and what they hold
# shown in LEVELS steps by weight from their first overlay.
STORAGES = {
    "pole": {"tile": 10, "overlay": 12, "group": "Drying", "custom": "Pole", "container": "dryingpole", "capacity": 20},
    "hayCrate": {"tile": 11, "overlay": 15, "group": "Hay", "custom": "Crate", "container": "haycrate", "capacity": 35},
    "sandCrate": {"tile": 18, "overlay": 19, "group": "Sand", "custom": "Crate", "container": "sandcrate", "capacity": 35},
}
LEVELS = 3
# The clamp (ROADMAP section 8 phase 3, art/clamp_mock.png): a storage dug into bare ground, its container a place of
# its own (TP Core's Clamp / EarthedClamp). Its tile is the heap under straw with the drainage trenches dug; earthing
# it up lays the soil dome over it as an overlay; rainwater stands in the trenches while vanilla's puddles are up, one
# overlay a cover (only the trench the heap leaves in sight). No fill levels: the crops are under the cover.
# Earthing up switches its container's type (saved with the object) to earthedContainer: the place, the loot window's
# title and icon follow it.
CLAMP = {"tile": 22, "earthed": 23, "wet": 24, "wetEarthed": 25, "group": "Root", "custom": "Clamp", "container": "clamp",
         "earthedContainer": "earthedclamp", "capacity": 75}

FOOT_X, FOOT_Y = pzart.FOOT
HEIGHT, BASE_RX, RIM_RX = 46, 29.0, 25.0
SQUASH = 0.5
TOP = FOOT_Y - HEIGHT
INNER = RIM_RX - 3
STAVES = 8
HOOPS = [(0.08, 3.0), (0.5, 2.4), (0.88, 2.6)]  # height as a fraction of the barrel, half the band's width

# The Salting Tub's colours: deep reddish wood, dark seams, iron with rust patches.
STAVE = (130, 84, 50)
INSIDE_WOOD = (110, 74, 46)
SEAM = (38, 22, 14, 255)
IRON = (70, 71, 75)
IRON_LIT = (104, 105, 110)
RUST = (84, 60, 44)
RUST_CHANCE = 0.07
SHADOW = (0, 0, 0, 110)
FOOT_SHADE = 0.55
WOOD_WEATHER = 0.2
OVERLAY_WEATHER = 0.15
CABBAGE = (196, 206, 150)
MIXED_GREEN = (160, 180, 110)  # the cabbage in a mixed barrel, a shade deeper to stand out on the turnip
TURNIP = (226, 214, 178)
LINEN = (190, 184, 166)
BOARD = (150, 112, 70)
STONE = (128, 126, 120)

TILE_PROPS = {}
for storage in STORAGES.values():
    TILE_PROPS[storage["tile"]] = [("BlocksPlacement", ""), ("CanScrap", ""), ("container", storage["container"]),
                                   ("ContainerCapacity", str(storage["capacity"])), ("CustomName", storage["custom"]),
                                   ("GroupName", storage["group"]), ("IsLow", ""), ("IsMoveAble", ""), ("Material", "Wood"),
                                   ("Material2", "Nails"), ("PickUpWeight", "50"), ("ScrapSize", "Small")]
# Not moveable: a heap of earth, levelled once empty (the mod's Level the Clamp).
TILE_PROPS[CLAMP["tile"]] = [("BlocksPlacement", ""), ("container", CLAMP["container"]),
                             ("ContainerCapacity", str(CLAMP["capacity"])), ("CustomName", CLAMP["custom"]),
                             ("GroupName", CLAMP["group"])]
for index, facing in enumerate(FACES):
    # The engine only links the facings of tiles with a GroupName, and that link lets a moved station rotate.
    TILE_PROPS[index] = [("BlocksPlacement", ""), ("CustomName", CUSTOM), ("Facing", facing), ("GroupName", GROUP),
                         ("IsMoveAble", ""), ("PickUpWeight", "100"), ("solidtrans", "")]


def box(cx, cy, rx, ry):
    return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]


def poly(draw, points, colour):
    draw.polygon([(x * SS, y * SS) for x, y in points], fill=colour)


def line(draw, start, end, colour, width):
    draw.line([start[0] * SS, start[1] * SS, end[0] * SS, end[1] * SS], fill=colour, width=max(1, int(width * SS)))


def barrel_point(level, angle, out=0.0):
    """A point on the barrel's side, level being its height as a fraction of the barrel's; out pushes it outward."""
    rx = BASE_RX + (RIM_RX - BASE_RX) * level + out
    return (FOOT_X + rx * math.cos(angle), FOOT_Y - HEIGHT * level + rx * SQUASH * math.sin(angle))


def paint_body(rng):
    """The shadow, the staves darkening to the ground, then three iron hoops."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box(FOOT_X + 1, FOOT_Y + 1, BASE_RX + 2, (BASE_RX + 2) * SQUASH), fill=SHADOW)
    levels = [0.0, 1.0]
    edges = pzart.stave_edges(rng, STAVES, 0.8, 1.2)
    for first, second in zip(edges, edges[1:]):
        tone = pzart.light_at((first + second) / 2) * rng.uniform(0.95, 1.05)
        left = [barrel_point(level, first) for level in levels]
        right = [barrel_point(level, second) for level in levels]
        poly(draw, left + right[::-1], pzart.tint(STAVE, tone))
        for _ in range(4):
            across = first + (second - first) * rng.random()
            start = rng.random()
            end = min(1.0, start + rng.uniform(0.1, 0.3))
            line(draw, barrel_point(start, across), barrel_point(end, across), pzart.tint(STAVE, tone * rng.uniform(0.88, 1.05)), 0.4)
        draw.line([(x * SS, y * SS) for x, y in left], fill=SEAM, width=max(1, SS * 3 // 4))
    layer = pzart.darken_down(layer, TOP, FOOT_Y, FOOT_SHADE, SS)
    draw = ImageDraw.Draw(layer)
    for level, half_height in HOOPS:
        for first, second, colour, tone in pzart.hoop_bands(rng, RUST_CHANCE, IRON, RUST):
            low, high = HEIGHT * level - half_height, HEIGHT * level + half_height
            points = []
            for z, angle in ((high, first), (high, second), (low, second), (low, first)):
                x, y = barrel_point(level, angle, 0.7)
                points.append((x, y + HEIGHT * level - z))
            poly(draw, points, pzart.tint(colour, tone))
            line(draw, points[0], points[1], pzart.tint(IRON_LIT, tone), 0.5)
            line(draw, points[2], points[3], pzart.tint(IRON, tone * 0.45), 1)
    return layer


def paint_inside(rng):
    """The rim, then the far wall's staves running down into the dark."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box(FOOT_X, TOP, RIM_RX, RIM_RX * SQUASH), fill=pzart.tint(STAVE, 1.1))
    inside = pzart.new_layer(SS)
    idraw = ImageDraw.Draw(inside)
    depth, floor_rx = 22.0, INNER * 0.9

    def ring(cy, radius, angle):
        return (FOOT_X + radius * math.cos(angle), cy + radius * SQUASH * math.sin(angle))

    idraw.ellipse(box(FOOT_X, TOP, INNER, INNER * SQUASH), fill=pzart.tint(INSIDE_WOOD, 0.6))
    edges = pzart.stave_edges(rng, STAVES, 0.85, 1.15, start=math.pi)
    for first, second in zip(edges, edges[1:]):
        tone = pzart.inside_light((first + second) / 2) * rng.uniform(0.95, 1.05)
        poly(idraw, [ring(TOP, INNER, first), ring(TOP, INNER, second), ring(TOP + depth, floor_rx, second), ring(TOP + depth, floor_rx, first)],
             pzart.tint(INSIDE_WOOD, tone))
        line(idraw, ring(TOP, INNER, second), ring(TOP + depth, floor_rx, second), SEAM, 0.6)
    idraw.ellipse(box(FOOT_X, TOP + depth, floor_rx, floor_rx * SQUASH), fill=pzart.tint(INSIDE_WOOD, 0.4))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).ellipse(box(FOOT_X, TOP, INNER, INNER * SQUASH), fill=255)
    inside.putalpha(ImageChops.multiply(inside.getchannel("A"), mask))
    layer.alpha_composite(inside)
    return layer


def paint_barrel(facing):
    rng = random.Random(3 + FACES.index(facing))
    layer = paint_body(rng)
    layer.alpha_composite(paint_inside(rng))
    return pzart.weather(pzart.shrink(layer), random.Random(11 + FACES.index(facing)), WOOD_WEATHER, streaks=True)


def paint_shreds(colour, seed, other=None):
    """The barrel packed to the rim: a mound of shredded leaves or roots, flecked lighter and darker. With other, a
    mixed barrel: each shred one colour or the other at random over a ground of the other's paler colour, so the two
    read apart at the game's size."""
    rng = random.Random(seed)
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    y = TOP + 1.5
    ground = colour if other is None else other
    draw.ellipse(box(FOOT_X, y, INNER, INNER * SQUASH), fill=pzart.tint(ground, 0.9))
    for _ in range(260):
        angle = rng.uniform(0, 2 * math.pi)
        reach = math.sqrt(rng.random()) * (INNER - 1.5)
        x, cy = FOOT_X + reach * math.cos(angle), y + reach * SQUASH * math.sin(angle)
        turn = rng.uniform(0, math.pi)
        length = rng.uniform(1.5, 3.5)
        tone = rng.uniform(0.75, 1.12) * (1.05 - 0.1 * math.sin(angle))
        if other is not None and rng.random() < 0.5:
            # A mixed barrel's cabbage shreds, darker and broader so they show on the pale turnip.
            line(draw, (x, cy), (x + length * math.cos(turn), cy + length * SQUASH * math.sin(turn)), pzart.tint(MIXED_GREEN, tone), 1.1)
            continue
        line(draw, (x, cy), (x + length * math.cos(turn), cy + length * SQUASH * math.sin(turn)), pzart.tint(colour if other is None else other, tone), 0.7)
    return pzart.weather(pzart.shrink(layer), random.Random(seed + 1), OVERLAY_WEATHER)


def paint_weighted(seed):
    """Weighed down: a linen cloth over the kraut, a round board on it and a flat stone on the board."""
    rng = random.Random(seed)
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    y = TOP + 2
    draw.ellipse(box(FOOT_X, y, INNER, INNER * SQUASH), fill=pzart.tint(LINEN, 0.92))
    for _ in range(18):
        angle = rng.uniform(0, 2 * math.pi)
        reach = rng.uniform(0.6, 0.95) * INNER
        x, cy = FOOT_X + reach * math.cos(angle), y + reach * SQUASH * math.sin(angle)
        line(draw, (x, cy), (FOOT_X + reach * 0.8 * math.cos(angle), y + reach * 0.8 * SQUASH * math.sin(angle)), pzart.tint(LINEN, 0.75), 0.5)
    board_rx = INNER * 0.78
    draw.ellipse(box(FOOT_X, y - 1.5, board_rx, board_rx * SQUASH), fill=pzart.tint(BOARD, 0.7))
    draw.ellipse(box(FOOT_X, y - 2.5, board_rx, board_rx * SQUASH), fill=pzart.tint(BOARD, 1.0))
    for offset in (-5, 0, 5):
        line(draw, (FOOT_X + offset - board_rx * 0.6, y - 2.5 + offset * SQUASH * 0.2), (FOOT_X + offset + board_rx * 0.6, y - 2.5 + offset * SQUASH * 0.2),
             pzart.tint(BOARD, 0.7), 0.4)
    stone_y = y - 5
    draw.ellipse(box(FOOT_X + 1, stone_y + 2, 9, 4), fill=(0, 0, 0, 70))
    draw.ellipse(box(FOOT_X, stone_y, 9, 5), fill=pzart.tint(STONE, 0.8))
    draw.ellipse(box(FOOT_X - 1, stone_y - 1.2, 7.5, 3.8), fill=pzart.tint(STONE, 1.05))
    return pzart.weather(pzart.shrink(layer), random.Random(seed + 1), OVERLAY_WEATHER)


FRAME_WOOD = (138, 100, 62)
HAY = (206, 178, 96)
STALK = (150, 140, 92)


def corner(x, y, z=0.0):
    px, py = pzart.project(x, y, z)
    return (px * SS, py * SS)


def block(draw, x0, x1, y0, y1, z0, z1, colour):
    """A box in tile units (z in pixels): its two front faces and its top, lit from the left."""
    faces = [
        ([corner(x0, y1, z0), corner(x1, y1, z0), corner(x1, y1, z1), corner(x0, y1, z1)], 0.85),
        ([corner(x1, y0, z0), corner(x1, y1, z0), corner(x1, y1, z1), corner(x1, y0, z1)], 0.62),
        ([corner(x0, y0, z1), corner(x1, y0, z1), corner(x1, y1, z1), corner(x0, y1, z1)], 1.0),
    ]
    for polygon, shade in faces:
        draw.polygon(polygon, fill=pzart.tint(colour, shade))


def finish(layer, seed, depth=WOOD_WEATHER):
    return pzart.hard_edges(pzart.weather(pzart.shrink(layer), random.Random(seed), depth))


# Vanilla's own vegetable icons, scaled down and laid out in clusters, as vanilla's shop produce is painted
# (food_01_32 to 39): (pack, icon).
VEG_ICONS = {
    "potato": ("UI.pack", "Item_Potato"), "carrots": ("UI.pack", "Item_Carrots"), "onion": ("UI.pack", "Item_Onion"),
    "pumpkin": ("UI.pack", "Item_Pumpkin"), "leek": ("UI.pack", "Item_Leek"), "cabbage": ("UI2.pack", "Item_Cabbage"),
    "turnip": ("UI2.pack", "Item_Turnip"), "garlic": ("UI2.pack", "Item_Garlic"), "sweetPotato": ("UI2.pack", "Item_SweetPotato"),
}
VEG_IMAGES = {}


def read_veg_icons(game):
    packs = {}
    for name, (pack, icon) in VEG_ICONS.items():
        packs.setdefault(pack, {})[icon] = name
    for pack, icons in packs.items():
        found = pzart.extract_sprites(game / "media" / "texturepacks" / pack, set(icons))
        for icon, name in icons.items():
            VEG_IMAGES[name] = found[icon].convert("RGBA")


def paste_icon(layer, name, centre, size, flip=False):
    """A vanilla vegetable icon, size tile pixels across, its middle at centre (supersampled pixels)."""
    icon = VEG_IMAGES[name].resize((int(size * SS), int(size * SS)), Image.LANCZOS)
    if flip:
        icon = icon.transpose(Image.FLIP_LEFT_RIGHT)
    layer.alpha_composite(icon, (int(centre[0] - icon.width / 2), int(centre[1] - icon.height / 2)))


POLE_Z = 70
ARM = 0.32


def paint_pole():
    """A T-pole: a post on a cross foot, a cross arm along the tile with pegs for the bunches."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    block(draw, -0.2, 0.2, -0.03, 0.03, 0, 3, FRAME_WOOD)
    block(draw, -0.03, 0.03, -0.2, 0.2, 0, 3, FRAME_WOOD)
    block(draw, -0.03, 0.03, -0.03, 0.03, 0, POLE_Z, FRAME_WOOD)
    block(draw, -ARM, ARM, -0.025, 0.025, POLE_Z - 4, POLE_Z, FRAME_WOOD)
    return finish(layer, 71)


def paint_bunch(layer, rng, x, kind):
    """A bunch hanging from the arm: a cord, the dry stalks gathered in a knot, then bulbs (vanilla's icon) in a
    cluster below it."""
    draw = ImageDraw.Draw(layer)
    top = corner(x, 0, POLE_Z - 4)
    knot = (top[0], top[1] + 5 * SS)
    draw.line([top, knot], fill=pzart.tint(STALK, 0.7), width=SS)
    bulbs = []
    for row, count in ((0, 2), (1, 3), (2, 2)):
        for i in range(count):
            bx = knot[0] + (i - (count - 1) / 2) * 5 * SS + rng.uniform(-1, 1) * SS
            by = knot[1] + (7 + row * 5) * SS + rng.uniform(-1, 1) * SS
            bulbs.append((by, bx))
    for by, bx in bulbs:
        draw.line([knot, (bx, by - 3 * SS)], fill=pzart.tint(STALK, rng.uniform(0.8, 1.05)), width=max(1, SS // 2))
    for by, bx in sorted(bulbs):
        paste_icon(layer, kind, (bx, by), rng.uniform(8, 9.5), rng.random() < 0.5)


def paint_pole_bunches(level):
    """Bunches of garlic and onions along the arm: two, four or six."""
    rng = random.Random(100 + level)
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    count = level * 2
    for i in range(count):
        x = -ARM + 0.04 + (2 * ARM - 0.08) * (i + 0.5) / 6 if count == 6 else -ARM + 0.04 + (2 * ARM - 0.08) * (i + 0.5) / count
        paint_bunch(layer, rng, x, "garlic" if i % 2 == 0 else "onion")
    return finish(layer, 110 + level, OVERLAY_WEATHER)


CRATE = (-0.46, 0.46, -0.46, 0.46)  # the whole floor tile, as vanilla's composter
CRATE_Z = 24


SAND = (148, 124, 92)  # damp sand


def paint_crate(lining="hay"):
    """An open crate of slats, lined with hay, or filled with damp sand."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    x0, x1, y0, y1 = CRATE
    block(draw, x0, x1, y0, y1, 0, CRATE_Z, FRAME_WOOD)
    # The inside: the far walls darker, the hay bedding at the bottom.
    draw.polygon([corner(x0 + 0.03, y0 + 0.03, CRATE_Z), corner(x1 - 0.03, y0 + 0.03, CRATE_Z),
                  corner(x1 - 0.03, y1 - 0.03, CRATE_Z), corner(x0 + 0.03, y1 - 0.03, CRATE_Z)], fill=pzart.tint(FRAME_WOOD, 0.45))
    rng = random.Random(72)
    if lining == "sand":
        draw.polygon([corner(x0 + 0.03, y0 + 0.03, CRATE_Z - 4), corner(x1 - 0.03, y0 + 0.03, CRATE_Z - 4),
                      corner(x1 - 0.03, y1 - 0.03, CRATE_Z - 4), corner(x0 + 0.03, y1 - 0.03, CRATE_Z - 4)], fill=pzart.tint(SAND, 0.95))
        for _ in range(700):
            x, y = rng.uniform(x0 + 0.04, x1 - 0.04), rng.uniform(y0 + 0.04, y1 - 0.04)
            px, py = corner(x, y, CRATE_Z - 4)
            r = rng.uniform(0.4, 1.0) * SS
            draw.ellipse([px - r, py - r * 0.5, px + r, py + r * 0.5], fill=pzart.tint(SAND, rng.uniform(0.78, 1.15)))
    for _ in range(420 if lining == "hay" else 0):
        x, y = rng.uniform(x0 + 0.04, x1 - 0.04), rng.uniform(y0 + 0.04, y1 - 0.04)
        a = corner(x, y, CRATE_Z - 2)
        b = (a[0] + rng.uniform(-6, 6) * SS, a[1] + rng.uniform(-3, 3) * SS)
        draw.line([a, b], fill=pzart.tint(HAY, rng.uniform(0.75, 1.1)), width=max(1, SS // 2))
    for step in range(1, 3):
        z = CRATE_Z * step / 3
        draw.line([corner(x0, y1, z), corner(x1, y1, z)], fill=pzart.tint(FRAME_WOOD, 0.5), width=SS)
        draw.line([corner(x1, y0, z), corner(x1, y1, z)], fill=pzart.tint(FRAME_WOOD, 0.38), width=SS)
    return finish(layer, 73)


CRATE_MIX = ["potato", "potato", "carrots", "turnip", "pumpkin", "cabbage", "sweetPotato", "leek"]  # garlic and onions hang on the pole


def paint_crate_produce(level):
    """Roots and heads in the hay, as vanilla's shop produce: its icons small, in clusters of one kind, a layer more
    with each level, back to front, wisps of hay tucked between."""
    rng = random.Random(120 + level)
    layer = pzart.new_layer(SS)
    x0, x1, y0, y1 = CRATE
    pieces = []
    for layer_index in range(level):
        z = CRATE_Z - 7 + layer_index * 3
        for _ in range(8):
            kind = rng.choice(CRATE_MIX)
            cx, cy = rng.uniform(x0 + 0.1, x1 - 0.1), rng.uniform(y0 + 0.1, y1 - 0.1)
            for _ in range(rng.randint(3, 5)):
                x = max(x0 + 0.06, min(x1 - 0.06, cx + rng.uniform(-0.07, 0.07)))
                y = max(y0 + 0.06, min(y1 - 0.06, cy + rng.uniform(-0.07, 0.07)))
                pieces.append((z, x + y, x, y, kind))
    for z, _, x, y, kind in sorted(pieces):
        paste_icon(layer, kind, corner(x, y, z + 4), rng.uniform(10, 12) if kind != "cabbage" else 13, rng.random() < 0.5)
    draw = ImageDraw.Draw(layer)
    for _ in range(40 * level):
        x, y = rng.uniform(x0 + 0.04, x1 - 0.04), rng.uniform(y0 + 0.04, y1 - 0.04)
        a = corner(x, y, CRATE_Z - 4 + level * 3)
        draw.line([a, (a[0] + rng.uniform(-5, 5) * SS, a[1] + rng.uniform(-2, 2) * SS)], fill=pzart.tint(HAY, rng.uniform(0.8, 1.1)), width=max(1, SS // 2))
    return finish(layer, 130 + level, OVERLAY_WEATHER)


SAND_MIX = ["carrots", "carrots", "leek", "turnip"]  # roots in sand; beets have no vanilla icon


def paint_sand_produce(level):
    """Roots pushed into damp sand where there was room, their tops showing: vanilla's icons scattered, mixed and a
    little tilted in size, with the sand heaped over their lower half, more with each level."""
    rng = random.Random(140 + level)
    layer = pzart.new_layer(SS)
    x0, x1, y0, y1 = CRATE
    pieces = []
    for _ in range(10 + level * 10):
        x, y = rng.uniform(x0 + 0.07, x1 - 0.07), rng.uniform(y0 + 0.07, y1 - 0.07)
        pieces.append((x + y, x, y, rng.choice(SAND_MIX), rng.uniform(0.85, 1.15)))
    for _, x, y, kind, scale in sorted(pieces):
        centre = corner(x, y, CRATE_Z - 1)
        size = (11 if kind != "leek" else 13) * scale
        paste_icon(layer, kind, (centre[0] + rng.uniform(-1, 1) * SS, centre[1] - size * SS * rng.uniform(0.15, 0.35)), size, rng.random() < 0.5)
        draw = ImageDraw.Draw(layer)
        # Sand heaped round the root's lower half.
        w = rng.uniform(4, 6) * SS
        draw.ellipse([centre[0] - w, centre[1] - 1.5 * SS, centre[0] + w, centre[1] + 2.5 * SS], fill=pzart.tint(SAND, rng.uniform(0.88, 1.1)))
    return finish(layer, 150 + level, OVERLAY_WEATHER)


# The clamp, after the old guides' section: roots heaped in a triangle, straw over them, soil over the straw,
# drainage trenches either side. A height field splatted back to front, lit from the left.
CLAMP_LENGTH = 0.44  # half the ridge's length, in tiles
# Each cover: half width (tiles), top (pixels), half length. About 70 px to a metre; one tile can't hold a real
# clamp's 2 m, so the dome keeps its shape lower. Under straw the heap is smaller and pointed, so earthing up grows it.
CLAMP_SHAPES = {"straw": (0.235, 28, 0.36), "soil": (0.31, 42, CLAMP_LENGTH)}
TRENCH_IN, TRENCH_OUT = 0.34, 0.44  # the drainage trenches along both long sides, from the middle line (tiles)
TRENCH_DEPTH = 4
# The trenches and the worked ground run the tile's whole length on each side, so clamps in a row share one trench
# line each side (user, session 77).
TRENCH_END = 0.5
STRAW = (196, 168, 104)
SOIL = (104, 80, 56)
TRENCH = (62, 46, 32)
WATER = (84, 98, 104)  # muddy rainwater, the sky in it
CLAMP_LIGHT = (-0.55, 0.45, 0.70)


def clamp_height(x, y, cover):
    """The heap: under straw a pointed ridge with straight sides and hipped ends, under soil a rounded dome. 0 off it."""
    width, top, length = CLAMP_SHAPES[cover]
    if cover == "straw":
        reach = min(1 - abs(y) / width, 2.2 * (1 - abs(x) / length))
        return top * min(1.0, reach * 1.1) if reach > 0 else 0.0
    d = ((abs(x) / length) ** 3 + (abs(y) / width) ** 2) ** 0.5
    return top * (1 - d * d) ** 0.55 if d < 1 else 0.0


def clamp_shade(x, y, cover, step=0.005):
    gx = (clamp_height(x + step, y, cover) - clamp_height(x - step, y, cover)) / (2 * step) / 60
    gy = (clamp_height(x, y + step, cover) - clamp_height(x, y - step, cover)) / (2 * step) / 60
    normal = (-gx, -gy, 1.0)
    dot = sum(a * b for a, b in zip(normal, CLAMP_LIGHT))
    dot /= math.sqrt(sum(c * c for c in normal)) * math.sqrt(sum(c * c for c in CLAMP_LIGHT))
    return 0.5 + 0.62 * max(0.0, dot)


def splat(draw, x, y, z, colour):
    px, py = pzart.project(x, y, z)
    draw.ellipse([px * SS - 2, py * SS - 1, px * SS + 2, py * SS + 1], fill=colour)


def paint_trenches(layer, seed, wet):
    """The ground worked round the heap, and the drainage trenches dug along both long sides, end to end of the tile:
    sunk below it, so the far bank shows lit; with rain, water standing level in their floor."""
    draw = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    step = 0.003
    points = []
    y = -TRENCH_OUT - 0.03
    while y <= TRENCH_OUT + 0.03:
        x = -TRENCH_END
        while x <= TRENCH_END:
            points.append((x + y, x, y))
            x += step
        y += step
    points.sort()
    middle, half = (TRENCH_IN + TRENCH_OUT) / 2, (TRENCH_OUT - TRENCH_IN) / 2
    for _, x, y in points:
        if TRENCH_IN <= abs(y) <= TRENCH_OUT:
            across = (abs(y) - middle) / half
            far_bank = across * (1 if y > 0 else -1) < -0.4
            colour = pzart.tint(SOIL, 0.85) if far_bank else pzart.tint(TRENCH, 0.8)
            z = -TRENCH_DEPTH * (1 - across * across)
            shade = rng.uniform(0.85, 1.12)
            glint = rng.random() < 0.06
            if wet and abs(across) < 0.7:
                colour, z, shade = pzart.tint(WATER, 1.25 if glint else 1.0), -TRENCH_DEPTH * 0.51, 1.0
            splat(draw, x, y, z, pzart.tint(colour, shade))
        else:
            splat(draw, x, y, 0, pzart.tint(SOIL, rng.uniform(0.95, 1.2)))


def paint_heap(layer, cover, seed):
    """The heap from the back of the tile to the front, so nearer points paint over: straw in strips laid from the
    ridge down with loose stalks, or soil in clods with straw vents through the ridge."""
    draw = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    strips = [random.Random(seed + 1).uniform(0.8, 1.12) for _ in range(200)]
    clods = pzart.soft_noise(rng, (160, 100), 3, 3)
    width = CLAMP_SHAPES[cover][0]
    step = 0.0035 if cover == "straw" else 0.002
    points = []
    y = -width
    while y <= width:
        x = -CLAMP_LENGTH
        while x <= CLAMP_LENGTH:
            z = clamp_height(x, y, cover)
            if z > 0:
                points.append((x + y, x, y, z))
            x += step
        y += step
    points.sort()
    for _, x, y, z in points:
        light = clamp_shade(x, y, cover)
        if cover == "straw":
            strip = strips[int((x + CLAMP_LENGTH) * 220) % len(strips)]
            colour = pzart.tint(STRAW, light * strip * rng.uniform(0.94, 1.04))
        else:
            grain = clods.getpixel((int((x + CLAMP_LENGTH) / (2 * CLAMP_LENGTH) * 159), int((y + width) / (2 * width) * 99))) / 255
            colour = pzart.tint(SOIL, light * (0.82 + 0.3 * grain) * rng.uniform(0.92, 1.06))
        # A short column down from the surface, so steep slopes close up.
        px, py = pzart.project(x, y, z)
        draw.rectangle([px * SS - 2, py * SS - 1, px * SS + 2, py * SS + 6], fill=colour)
    if cover == "straw":
        for _ in range(260):
            x, y = rng.uniform(-CLAMP_LENGTH * 0.95, CLAMP_LENGTH * 0.95), rng.uniform(-width * 0.9, width * 0.9)
            z = clamp_height(x, y, cover)
            if z <= 2:
                continue
            fall = -1 if y < 0 else 1
            a = pzart.project(x, y, z)
            b = pzart.project(x + rng.uniform(-0.01, 0.01), y + fall * 0.05, max(0, clamp_height(x, y + fall * 0.05, cover)))
            draw.line([a[0] * SS, a[1] * SS, b[0] * SS, b[1] * SS],
                      fill=pzart.tint(STRAW, clamp_shade(x, y, cover) * rng.uniform(0.7, 1.2)), width=max(1, SS // 2))
    else:
        for vx in (-0.2, 0.2):
            base = pzart.project(vx, 0, clamp_height(vx, 0, cover) - 1)
            for _ in range(14):
                angle = rng.uniform(-0.9, 0.9)
                tip = (base[0] + math.sin(angle) * rng.uniform(4, 8), base[1] - math.cos(angle) * rng.uniform(5, 9))
                draw.line([base[0] * SS, base[1] * SS, tip[0] * SS, tip[1] * SS],
                          fill=pzart.tint(STRAW, rng.uniform(0.75, 1.15)), width=max(1, SS // 2))


def paint_clamp(cover, wet=False):
    layer = pzart.new_layer(SS)
    paint_trenches(layer, 210, wet)
    paint_heap(layer, cover, 200 if cover == "straw" else 220)
    return pzart.hard_edges(pzart.weather(pzart.shrink(layer), random.Random(230), 0.15))


def changed(base, over):
    """The pixels of over that differ from base: an overlay that leaves the rest of base showing."""
    mask = ImageChops.difference(base.convert("RGBA"), over.convert("RGBA")).convert("L").point(lambda v: 255 if v else 0)
    out = Image.new("RGBA", over.size, (0, 0, 0, 0))
    out.paste(over, (0, 0), mask)
    return out


def paint_braid_icon(kind):
    """A braid for the item icon: a plait of dry stalks down the middle with bulbs (vanilla's icon) on both sides."""
    size = 32
    layer = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line([(16 * SS, 1 * SS), (16 * SS, 29 * SS)], fill=pzart.tint(STALK, 0.8), width=2 * SS)
    for i in range(5):
        side = -1 if i % 2 == 0 else 1
        paste_icon(layer, kind, ((16 + side * 5) * SS, (8 + i * 5) * SS), 12, side > 0)
    return layer.resize((size, size), Image.LANCZOS)


# Item icons: vanilla's own, repainted the pale straw of fermented kraut, keeping their light and dark.
ICONS = [("Sauerkraut", "Item_Cabbage", (222, 210, 150)), ("SauerTurnip", "Item_Turnip", (232, 220, 170))]


def write_icons(folder, game):
    folder.mkdir(parents=True, exist_ok=True)
    vanilla = pzart.extract_sprites(game / "media/texturepacks/UI2.pack", {source for _, source, _ in ICONS})
    for name, source, colour in ICONS:
        icon = vanilla[source]
        pzart.recolour(icon, lambda x, y, icon=icon: icon.getpixel((x, y))[3] > 0, colour, False, random.Random(7), (0.9, 1.1)).save(folder / f"Item_{name}.png")


def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "STATIONS": [prefix + str(index) for index in range(len(FACES))],
        "OVERLAYS": OVERLAYS,
        "STORAGES": {key: {"tile": prefix + str(storage["tile"]), "overlay": storage["overlay"], "container": storage["container"],
                           "capacity": storage["capacity"]} for key, storage in STORAGES.items()},
        "LEVELS": LEVELS,
        "CLAMP": {"tile": prefix + str(CLAMP["tile"]), "earthed": prefix + str(CLAMP["earthed"]), "wet": prefix + str(CLAMP["wet"]),
                  "wetEarthed": prefix + str(CLAMP["wetEarthed"]), "container": CLAMP["container"],
                  "earthedContainer": CLAMP["earthedContainer"], "capacity": CLAMP["capacity"]},
    }


def main():
    default_game = Path.home() / ".local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else default_game
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    write_icons(media / "textures", game)
    read_veg_icons(game)
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    tiles = {index: paint_barrel(facing) for index, facing in enumerate(FACES)}
    for face in range(len(FACES)):
        tiles[OVERLAYS["cabbage"] + face] = paint_shreds(CABBAGE, 21 + face)
        tiles[OVERLAYS["turnip"] + face] = paint_shreds(TURNIP, 31 + face)
        tiles[OVERLAYS["weighted"] + face] = paint_weighted(41 + face)
        tiles[OVERLAYS["mixed"] + face] = paint_shreds(CABBAGE, 51 + face, TURNIP)
    tiles[STORAGES["pole"]["tile"]] = paint_pole()
    tiles[STORAGES["hayCrate"]["tile"]] = paint_crate("hay")
    tiles[STORAGES["sandCrate"]["tile"]] = paint_crate("sand")
    for level in range(LEVELS):
        tiles[STORAGES["pole"]["overlay"] + level] = paint_pole_bunches(level + 1)
        tiles[STORAGES["hayCrate"]["overlay"] + level] = paint_crate_produce(level + 1)
        tiles[STORAGES["sandCrate"]["overlay"] + level] = paint_sand_produce(level + 1)
    thatched, earthed = paint_clamp("straw"), paint_clamp("soil")
    tiles[CLAMP["tile"]] = thatched
    tiles[CLAMP["earthed"]] = earthed
    tiles[CLAMP["wet"]] = changed(thatched, paint_clamp("straw", True))
    tiles[CLAMP["wetEarthed"]] = changed(earthed, paint_clamp("soil", True))
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    icon = tiles[0].copy()
    icon.alpha_composite(tiles[OVERLAYS["weighted"]])
    pzart.write_build_icon(icon, media / "textures" / "Item_KrautBarrel.png")
    for name, key in (("DryingPole", "pole"), ("HayCrate", "hayCrate"), ("SandCrate", "sandCrate")):
        storage = STORAGES[key]
        full = tiles[storage["tile"]].copy()
        full.alpha_composite(tiles[storage["overlay"] + LEVELS - 1])
        pzart.write_build_icon(full, media / "textures" / f"Item_{name}.png")
        pzart.write_container_icon(full, media / "textures" / f"Container_{name}.png")
    pzart.write_build_icon(thatched, media / "textures" / "Item_Clamp.png")
    pzart.write_container_icon(thatched, media / "textures" / "Container_Clamp.png")
    earthed_icon = thatched.copy()
    earthed_icon.alpha_composite(earthed)
    pzart.write_container_icon(earthed_icon, media / "textures" / "Container_ClampEarthed.png")
    paint_braid_icon("garlic").save(media / "textures" / "Item_GarlicBraid.png")
    paint_braid_icon("onion").save(media / "textures" / "Item_OnionBraid.png")
    pzart.write_mod_icon(icon, media.parent / "icon.png")
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
