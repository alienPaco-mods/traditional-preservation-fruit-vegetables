# Traditional Preservation (Fruits and Vegetables) — Build 42 prototype (v0.0.21)

Vegetables kept the old way, without electricity. Built: **the root cellar** (vanilla vegetables keep by place, and
potatoes, garlic, onions, sweet potatoes and pumpkins cure), **three storages** (Onion and Garlic Pole, Vegetable Crate (Hay), Vegetable Crate (Sand)) and garlic and onion **braids**, **the clamp** (roots kept outdoors under straw and soil through the winter), and **the kraut barrel** (cabbage and turnip soured in salt).

## The root cellar

Every vanilla **Potato, Turnip, Sugar Beet, Carrot, Cabbage, Leek, Garlic, Onion, Sweet Potato and Pumpkin**, found or grown, keeps by the
temperature of where it is (TP Core's `PlaceKeeping` and its places, as Fish & Meat's Potted Meat and Dairy's butter).
There is no station: a basement is the cellar. A vegetable's tooltip says how long it keeps where it is and how fast
it ages there (TP Core's keeping lines; sandbox *Keeping in item tooltips*), then, in a storage, its factors (*In the
Onion and Garlic Pole: ageing x0.75, curing x1.5*) and, for one that cures, how far along it is (*Curing (dry): 40%,
about 6 days more here*, *not curing here* where it can't, *Cured (dry)*). Read from `M.forecast(item, place)`.

Days fresh at a temperature. The warm room is vanilla's days, except a cabbage's 7 (vanilla's 2 is too short; user, 2026-11-18):

| Crop | Warm room 22 C | Cool room 15 C | Basement 8 C | Fridge 4 C | Vanilla |
|---|---|---|---|---|---|
| Potato | 28 | 60 | 150 (cured 210) | 140 (cured 196) | 28 |
| Turnip | 28 | 28 | 120 | 140 | 28 |
| Sugar Beet | 4 | 14 | 120 | 120 | 4 |
| Carrots | 6 | 14 | 120 | 120 | 6 |
| Cabbage | 7 | 14 | 90 | 90 | 2 |
| Leek | 5 | 10 | 60 | 60 | 5 |
| Garlic, Onion | 14 | 28 | 30 (too damp) | 70 | 14 |
| Garlic, Onion cured | 90 | 180 | 60 | onion 180, garlic 70 (it sprouts); garlic 210 at 0 C (an unheated room in winter) | |
| Sweet Potato | 28 | 120 | 30 (chilled) | 30 (chilled) | 28 |
| Sweet Potato cured | 56 | 240 | 45 (chilled) | 45 (chilled) | |
| Pumpkin | 30 | 45 | 30 (too damp) | 30 (chilled) | 14 |
| Pumpkin cured | twice the uncured everywhere | | | | |

- A day counts as vanilla's days fresh over the place's, on straight lines between the four temperatures. Warmer than
  22 C counts as 22 C; colder than 4 C counts as 4 C. **No place keeps its fresh days worse than vanilla**, and a
  powered fridge never worse than vanilla's fridge at its default (a day counts 0.2), except for a sweet potato and a
  pumpkin: chilled below about 10 C, a fridge is no better for them than a cold basement (user, session 78). Frost is
  apart from that (below).
- **Stale to rotten** (user, session 78: realism the goal): cold storage buys the fresh days; once stale, a vegetable
  goes off in its own days at a day a day whatever the temperature (`M.STALE_DAYS`, TP Core's PlaceKeeping
  `staleShare`, `M.STALE_SHARE` 0); only frost and a storage change that (the pole, a crate: air round each bulb, or
  packing that keeps one rotting root from spreading to the next, so its keeping factor counts on the stale days too): potato 45, turnip, sugar beet, garlic 30, carrots, cabbage, onion 21,
  leek 10, sweet potato, pumpkin 14. That replaces vanilla's rotten day (a potato's 280 left a cellar potato stale
  for years): a potato rots 73 days after it is new in a warm room, 195 in a basement (cured 255).
- Where it is goes by Core's places: a shut room is the 3-day mean, warmer in winter and stuffy in summer, an aired
  room (a window open) the day's mean (both 22 C with the grid on), a basement the ground's 30-day mean a month behind
  (about 5 C in late winter, 13 C in late summer), under a roof the hour's air, a powered fridge 4 C, a freezer stops
  it. **By a fire** (within 2 tiles of a lit fireplace,
  antique oven, brazier, burn barrel or campfire; not an electric or gas stove) it is 28 C, by banked embers 24 C, less under a
  roof or in the open (Core's fire places): for keeping that is a warm room; a sweet potato or a pumpkin cures there
  in autumn, as real growers cured them by the stove; a potato doesn't (too warm). The fire counts while the fuel it
  had at the last look lasts.
- **Curing** is the first part of keeping, not a recipe (`M.CURES`). A potato that has spent 7 days at 10 to 20 C
  (the *warm* cure, counted on a ledger, so unloaded time counts) is cured, and every day after counts 150/210 of an
  uncured one's. A sweet potato (7 days) or a pumpkin (10 days) at 20 to 32 C (the *hot* cure; real curing wants 27
  to 30 C, but an unheated Kentucky room at harvest is 20 to 22) is cured and keeps twice as long. Unpowered, that
  happens in June and July; at the September and October harvest only a room on the grid (22 C) or a place by a fire is warm enough. Garlic and onions
  cure in 14 days in moving air and warmth: an hour counts 1 under a roof (Covered) or in an aired room (a window
  open), 0.75 in the open (sun and rain), 0 in a shut room (still air: it waits for a window), a basement, a fridge or a
  freezer, 1 by a lit fire in a room (it draws air through), by banked embers the air of the place under them
  (`M.CURES.dry.places`),
  times the warmth, as Fish & Meat's dry cure: full from 20 C, a straight line down to a fifth at 4 C and below
  (`M.CURES.dry.curve`, on the cure ledger). Hung in summer they cure in 14 to 19 days; in winter it takes months; while they
  cure somewhere dry they already keep by the cured days (curing is drying), and once cured they keep by them in a
  damp place too.
- **Frost** (`M.FROST_RUIN_HOURS`, TP Core's Frost): each crop freezes at its own point, and every hour at or below it,
  by Core's place temperature, moves it 1/12 of the way to rotten (its fresh days plus its stale days), so 12 hours ruin it;
  never past rotten. Potato, sweet potato, pumpkin -1 C; carrots, sugar beet, turnip -1.5 C; cabbage -3 C; garlic and
  onion -3.5 C (braids too: the bulbs inside freeze); leek -10 C. A basement never freezes, nor a place by a lit fire
  or banked embers while the noted fuel lasts; a powered fridge never, a powered freezer keeps vanilla's rules; a
  Vegetable Crate (Hay) counts half the hours. Loot too, from its first look (vanilla has already aged it from the
  apocalypse). An hour costs a potato about 6 days of its life, a carrot about 2.
  In an unheated house that means November for potatoes and December for most crops; a leek lasts the winter
  everywhere but the open.
- Cooked or burnt vegetables go by vanilla's clock. The sandbox's *Vegetables keep by place* (on) turns it all off,
  frost too; *Vegetables freeze* (on) turns off only the frost.
- The item stays vanilla's: its clock is modData (`tpfvKeep`, or `tpfvKeepCured` once it keeps by the cured days),
  the cure's progress `tpfvCuring`, cured `tpfvCured`, the storage it lay in at the last look `tpfvIn`, its frost record `tpfvFrost` (on Core's
  `TraditionalPreservationCoreFrost` ledger, totals `frostAt<celsius><Place>`). Ledgers:
  `TraditionalPreservationFruitVegetablesCellar<crop>`, `...<crop>Cured`, `...Cure` (totals `warmCure<Place>`,
  `hotCure<Place>`, `dryCure<Place>`). Never rename them once the mod is out.

`luajit tools/cellar_report.lua` prints each crop's days fresh by month and place, put away on the first of each month,
frost counted (golden-checked by `tp test`). It shows the cellar lag: a basement in October is still about 13 C, so a
cabbage put down at harvest keeps about 3 weeks there, and its long keeping starts as the ground cools. It shows the
frost: from November an unheated room, an aired one or a porch ruins nearly every crop within days; the basement
keeps them all winter.

## The storages

Three buildings that hold vegetables, each a container from its tile (`container` and `ContainerCapacity` in the
`.tiles`, as Fish & Meat's Stockfish Pallet). What lies in one, loose or in a braid there, cures or keeps by a
multiplier on top of its place (`M.STORAGE_BONUS`): each look notes the storage (`M.storageOf` walks up through braids
and bags) and the stretch since the last look counts by it, as places do. Each takes only the crops it does something
for (`M.storageTakes`, read from `M.STORAGE_BONUS`), raw, and the pole its braids: its accept function, set by the World
on every storage it sees (it isn't saved); what already lies in one stays. One facing; the World shows what each holds
in three steps by weight (`World.storageLevel`).

| Storage | Build (hammer, saw kept) | Holds | Bonus |
|---|---|---|---|
| **Onion and Garlic Pole** (a T-pole hung with bunches: airy), for garlic and onions | Woodwork 2: 3 planks, 4 nails, 2 twine | 20 | Their dry cure counts 1.5 (about 9 days under a roof, 16 in a room), and their keeping 0.75 (a third longer) |
| **Vegetable Crate (Hay)** (an open crate lined with hay) | Woodwork 1: 3 planks, 4 nails, 4 hay (from a farm's hay bales) | 35 | Warm and hot cures count 1.5 (a potato in about 5 days, a sweet potato 5, a pumpkin 7), and the keeping of potatoes, turnips, cabbages, sweet potatoes and pumpkins 0.75; carrots, beets and leeks get nothing (they were kept in damp sand, not hay) |
| **Vegetable Crate (Sand)** (roots packed in damp sand, tops showing) | Woodwork 1: 3 planks, 4 nails, 1 sack of sand | 35 | Carrots, sugar beets, leeks and turnips keep a third longer (0.75); nothing cures in it |

The place still decides (a potato still needs 10 to 20 C, garlic still doesn't cure in a basement). User, 2026-11-18:
the pole for garlic and onions, the hay crate for the rest, the sand crate for the roots that dry out in hay.

**Braids** (`...Braid.lua`, action `TPBraid`): select 2 to 10 garlic or onions, **Braid Garlic / Braid Onions**: a
Garlic or Onion Braid holding them (a container item: capacity 2, weight reduction 30, only its own bulbs). Only
lighter to carry (user): the bulbs keep and cure inside as loose ones do, and a braid on an Onion and Garlic Pole counts as hung.
**Unbraid** gives them back.

## The clamp

Roots heaped on bare ground under straw, drainage trenches dug either side, then earthed over once hard frost comes
(`...Clamp.lua`, art `WIP/TPCore/art/clamp_mock.png`). A storage like the crates: a container from its tile
(`container = clamp`, capacity 75), no Info window, open the whole time (a real clamp was opened at one end, some taken
and closed again). It takes **potatoes, turnips, sugar beets, carrots and cabbages** only (its accept function,
`M.acceptClamp`, set by the World on every clamp it sees: no leeks, which stay in the ground; no onions or garlic,
which want dry air; no sweet potatoes, which chill).

- **Dig a Clamp** (right-click, as vanilla's Dig Furrow; no build menu): a shovel or spade (kept) and 6 hay, 30
  minutes, on bare dirt under the sky by vanilla's furrow rule (a free square, no plant) with the grass removed first (Remove Grass; TP Core's
  `Ground.diggable`). The action puts the tile's object down with its container (`M.makeClamp`). Not movable: once
  empty, **Level the Clamp** (shovel, 20 minutes) digs it back in, the straw lost.
- **Its place** is TP Core's own, given by its container: **StrawClamp** under straw, halfway from the day's mean to the
  basement's temperature; **EarthedClamp** once earthed up, halfway from the 3-day mean to the basement's. Its crops keep
  on the cellar's curves and freeze at their own points there, as anywhere else.
- **Earth Up** (shovel, 30 minutes on the game clock): the soil from the trenches over the straw, tufts left through
  the ridge to breathe. **Take Down Soil** (20 minutes) takes it off again, in spring or if it went on too early. What
  lies in it catches up at the old place first.
- **Sweating** (user, session 77): earthed over above 8 C (`M.SWEAT_C`), its crops age 1.5 times as fast
  (`M.SWEAT_RATE`), on a second ageing on each keeper's ledger (`<crop>Sweat`), counted only for the stretches spent
  in an earthed clamp (item modData `tpfvSweat`). Earth it up in late November, not at the October harvest.
- **No rain rule** (user): the spring warmth ends its season. The trenches show rainwater while vanilla's puddles are
  up (`IsoPuddles` at `M.CLAMP_WET_PUDDLES` or more), only a look.
- Earthed up or not is the container's type, saved with the object: `clamp` under straw, `earthedclamp` earthed up
  (`Tiles.CLAMP.earthedContainer`); the place, the loot window's title ("Clamp", "Clamp (Earthed Up)") and its icon
  follow it. Never rename them.

`tools/cellar_report.lua` has a column for each: under straw all year, and earthed up all year (in play it is earthed
for the winter only). In the sampled year a potato put in an earthed clamp in December keeps 142 days (the basement's
145), carrots 121; under straw alone frost takes them in days (a December potato 17). Earthed up in October, carrots
keep 29 days against 67 under straw: they sweat.

## Install

`tp install FruitVegetables` copies the mod to `~/Zomboid/mods/TraditionalPreservationFruitVegetables` after its tests pass.

## The kraut barrel

A standing barrel (Build menu, Furniture: hammer and saw kept, 6 planks, 10 nails, 4 twine, Woodwork 3), between
Fish & Meat's Salting Tub and Vinegar's cask. No crafting window: the batch is Lua state in the barrel's movableData
(`tpfvBarrel`), worked from its right-click menu, and the **Kraut Barrel Info** window (TP Core's InfoWindow, from the menu) shows
it, as Fish & Meat's Salting Tub: a state band, the place (with the speed and the hours too warm while it sours), the
heads as cells in the cabbage and turnip patterns (`TPCell_Cabbage.png`, `TPCell_Turnip.png`), what is dragged onto
them packs, and the buttons by stage (Salt and Compress, Unpack; a Take button a kraut opening One / All; Empty). A barrel with anything in it can't be picked up: build or put it
down where it will sour and keep.

| Stage | What you do | What happens |
|---|---|---|
| Empty, Packing | **Pack Cabbage / Pack Turnip** (All with the number held, then One), **Add Apple / Add Carrot** (up to one each per 5 heads). **Unpack the Barrel** gives everything back. Until it is sealed, packed pieces age as if lying out (vanilla's pace), so an unsealed barrel is no cold store | Cabbages and turnips in any mix, 20 to 60 heads, one ferment. Each piece keeps its age and food. Cooking xp 1 a piece, paid at Salt and Compress |
| Salt and Compress | **Salt and Compress**: a use of salt per 5 heads (TP Core's `Uses`, so Salt's empty shakers come back), a cloth (Ripped Sheets, Burlap, Cheesecloth), a Plank and a Flat Stone. Cooking xp 10 | Sealed: nothing more goes in, nothing comes out until it is ready |
| Fermenting | Wait | By the temperature where the barrel stands (Core's places, by a fire too): 28 days at 18 C (sandbox *Kraut ferment*), 120 at 4, 60 at 8, 40 at 13, 21 at 21, 16 at 24, warmer no faster, slower still towards **0 C, where it stops** (user: winter kraut sours slowly in the cold). A head already stale at Salt and Compress makes a soft portion, head by head (user, 2026-11-22: wilted cabbage gives a poor brine): it keeps in the barrel as a soft batch does and the soft ones of a kind are taken first; the window shows the stale heads under the cells while packing (and a drag says so), then the soft portions left (`M.staleHeads`, `M.softLeft`, `barrel.softHeads`). Hours above 27 C count: 48 make it soft (it keeps 2/3 as long), 120 spoil it |
| Ready | **Take Sauerkraut / Take Sauer Turnip** (All, One), a row for each kind left | It keeps in the barrel by place, 180 days at 8 C (4 C 240, 15 C 90, 22 C 30, frozen stops). One portion a head, as its kind (a cabbage as Sauerkraut, a turnip as Sauer Turnip): its own kind's food, plus the apples and carrots shared out over every head, no mood (the kraut is a way of keeping cabbage, not a treat); out of the barrel 14 / 28 days (frozen through at -3 C, 6 h, it goes soft: the days it has left count 2/3), starting as far into them as the barrel is into its 180. The last portion gives the Plank and Flat Stone back (the cloth is used up) |
| Spoiled | **Empty the Spoiled Barrel** | The plank and stone back |

Items: `Sauerkraut` and `SauerTurnip`, vanilla Cabbage and Turnip values in the script (each portion's are set from
its batch), icons recoloured from vanilla's. `luajit tools/kraut_report.lua` prints, for a barrel salted and compressed on the
first of each month, the days to ready by place and the days it keeps after (golden-checked). It shows the cold:
sealed in a basement in October, November or December a barrel is ready in about 47, 60 or 83 days; in an unheated
room (about 0 C in a Kentucky winter) it mostly waits for spring.

## Rebuilding the tileset

`python3 tools/build_tileset.py` (needs Pillow) paints the station and writes `42/media/traditionalpreservationfruitvegetables.tiles`,
`42/media/texturepacks/traditionalpreservationfruitvegetables.pack`, the icons and the generated `42/media/lua/shared/TraditionalPreservationFruitVegetables/Tiles.lua`
(don't edit it by hand). `luajit tests/test_tiles.lua` checks the entity scripts against it.

## Debug commands

In debug mode, `TPFV.help()` in the Lua console lists commands for testing this mod. See `DEVHELP.md`.

## Engineering notes

- The shared core (Weather, Station, UI) is the required TP Core mod (`~/MODS/TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there.
- `tiledef` 5174 was picked by `tp new` as the next free number. Tiles: 0-1 the barrel (S, E), overlays 2-3 cabbage,
  4-5 turnip, 6-7 salted and compressed (cloth, board, stone), 8-9 cabbage and turnip mixed; 10 Onion and Garlic Pole, 11 Vegetable
  Crate (Hay), 18 Vegetable Crate (Sand), their fill steps 12-14, 15-17 and 19-21; 22 the clamp under straw, 23 its
  soil (earthed up), 24 and 25 rainwater in its trenches under straw and earthed (only the trench left in sight).
  The clamp's tiles have their own depth texture, `common/media/depthmaps/DEPTH_<tileset>.png` (the builder computes
  it from the heap's shape; the game reads it only from there; ENGINE_NOTES "Depth").
- Save keys: the barrel's ledger lives in global ModData under `TraditionalPreservationFruitVegetables` (totals
  `ferment<Place>`, `hot<Place>`, `keep<Place>`), its batch in movableData `tpfvBarrel`; the cellar's are above. Never
  rename them once the mod is out.
- Singleplayer only for now.
