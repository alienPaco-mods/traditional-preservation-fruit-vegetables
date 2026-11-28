# Changelog: Traditional Preservation (Fruits and Vegetables)

## 0.0.26
- **The Kraut Barrel is TP Core's Brine Barrel now** (user, 2026-11-28; ROADMAP section 9, step c): the station, its
  stages, the press and Unseal, the starter, the brine tank, the action, the entity, the barrel's tiles and icons, its
  World and its menu and window moved to Core 0.1.83 as a refactor. Nothing changes in play but the name (Brine Barrel,
  Brine Barrel Info). This mod registers the kraut on it (`BrineBarrel.kind`: heads and extras, the ferment, hot and
  keep curves on its ledger, the portions, stale heads soft, Kraut Brine, the look by head kind) and gives its words
  and rows (`...KrautUI.lua`, split out of the main UI file). Its shredded cabbage and turnip overlays stay this mod's
  tiles. Pre-release: a barrel from an older build is lost (new save key `tpBrineBarrel`, new tiles). Needs Core 0.1.83.
- test_menu loads Core's barrel files; every test unchanged otherwise.

- Kraut brine dragged onto the brine tank in the window pours in, as Pour In Brine (Core 0.1.83).
## 0.0.25
- **Fix: Drain Brine no longer throws an error in the Kraut Barrel window** (seen in game, 2026-11-28). Draining
  clears the barrel's record in place while the window still holds the status it worked out before, so for a frame
  its band read the brine litres from the emptied record (`litresText` on nil). The band now reads them from that
  same status. The drain itself was never affected. test_menu.
- **Kraut Brine has its own colour** (user, 2026-11-28): DarkSeaGreen, a cloudy pale grey-green, in containers and the
  barrel's brine tank, so it no longer looks like Salt's Brine (Khaki). Its mouldy brine stays DarkOliveGreen.

## 0.0.24
- **Kraut brine** (user, 2026-11-27, art/kraut_brine_mock.png): a barrel makes 0.15 L of brine a head at Salt and
  Compress (a barrel sealed before this has its batch's). **Draw Starter** takes 1 L at most off a ready barrel with
  kraut in it; once the last portion is out the brine stays (a **Brine** stage: it ages as Kraut Brine) and **Drain
  Brine** takes it all, after which the barrel can be picked up. **Pour In Brine** (up to 9 L) on an empty barrel, then
  **Put Back** fresh Sauerkraut or Sauer Turnip (menu or drag onto the barrel, as many as the brine covers, 0.15 L a
  portion): each keeps its own age and keeps by place again; the oldest sets when the barrel spoils, and stale
  portions are refused. **Kraut Brine** is a Beverage on TP Core's FluidAgeing (its age goes with it when poured),
  mouldy in about 3 weeks at 20 C. **Back-slopping**: an **Add Starter** slot while packing takes 1 L of good brine,
  used at Salt and Compress, the batch 25% faster (sandbox *Kraut starter bonus*). The window shows the slot, a brine
  tank, the Brine band and the Draw Starter and Drain Brine buttons. Console: `TPFV.give("krautBrine")`, and the
  barrel kit brings a jar of brine, 4 empty jars and a bucket.
  **Unseal** (user): the plank and stone stay on after Salt and Compress until Unseal lifts them off and gives them
  back, once the barrel is ready, spoiled or down to brine (never mid-ferment); nothing else returns them. Pressed, a
  barrel is shut (no Take, Draw Starter, Drain or Put Back: "Unseal it first"), takes no new heads or starter and
  stays where it is. The tile shows the cloth, board and stone only while they are on; unsealed it shows the shreds of
  what is left in it (cabbage, turnip or mixed), and nothing once only brine is left. A barrel sealed before this has them on. Put Back needs
  neither.

## 0.0.23
- **Pack straight from the cauldron** (user, 2026-11-27): the Stone Hearth's menu, its cauldron holding paste, has
  **Pack Tomato Paste** and **Add to the Crock**; a crock's and an empty jar's own menus list a cauldron near by as a
  source beside the pots. **All Jars** (on every Pack Tomato Paste menu) packs one empty vessel after another, each
  its own salt crust and cap, as many as the paste fills. An emptied cauldron forgets the paste's age.

## 0.0.22
- **Tomato paste** (user, 2026-11-27, ROADMAP §8 phase 4): tomatoes cooked down in a pot or the cauldron (Pulp Tomatoes into a Pot,
  on a tomato's or the pot's own menu; TP Core's pot route, 3 hours, to a fifth of the pulp; a pot scorches 2 hours on, Scrape Out gives it back; cooked paste not
  packed ages on TP Core's FluidAgeing, a week at 20 C, its age carried when poured: side agent's catch), packed under a salt crust into a clay jar or pot or a glass jar, optionally capped
  with oil or fat (a row per type carried: Olive or Vegetable Oil, Lard, Clarified Butter, Tallow): a Crock of
  Tomato Paste, 10 portions of 5 tomatoes at most (50 tomatoes a crock), keeping by place (180 / 240 days in a
  cellar, a capped one twice). Spoon Out Tomato Paste for a dish (70 kcal, hunger -10, -5 unhappiness, -5 boredom).
  Add to the Crock tops up a started crock (1 salt, 1 seal use on a sealed one, per addition; age averaged by
  portions; a salt-crust crock may be capped on an addition, a whole cap, and is sealed from then on, its share of
  keeping carried over; the crock holds one cap's food at most, however often refreshed; never into a rotten crock, Empty the Crock instead; Pack Tomato Paste on an empty vessel's own menu too, with All Pots; on the crock's own menu too, Add Tomato Paste, with All Pots as one addition); packing and adding take part portions too, so no scrap stays in the pot.
  Icons `tools/build_food_icons.py`; console `TPFV.kit("paste")`; tests `test_paste.lua`. Needs TP Core 0.1.75.

## 0.0.21
- **Stale heads make soft kraut, head by head** (user, 2026-11-22: wilted cabbage gives a poor brine). A head
  already stale at Salt and Compress makes a soft portion: in the barrel it keeps as a soft batch does (2/3 as long),
  and a kind's soft portions are taken first. A mixed batch comes out mixed. Kraut Barrel Info shows the stale heads
  under the cells while packing (a drag says how many it holds), then the soft portions left. Heads packed before
  this version and batches already sealed are as before. README, guide; tests in `test_barrel.lua`, `test_menu.lua`.

## 0.0.20
- **Fixed: a favourite shovel didn't count for the clamp** (Dig Clamp, earth, unearth, level): it is kept, so a
  favourite is fine, as in vanilla's crafting. Needs TP Core 0.1.58.


## 0.0.19
- **Docs:** README and guide say a storage's keeping factor counts on the stale days too (the code always did; the
  pole's x0.75 makes garlic's 30 stale days 40). Only the temperature stops mattering once a vegetable is stale.
- **A vegetable's tooltip says how it keeps** (user, 2026-11-21): TP Core's keeping lines (how long it keeps where it
  is, the temperature, how fast it ages), then the storage it lies in with its factors ("In the Onion and Garlic Pole:
  ageing x0.75, curing x1.5") and its cure ("Curing (dry): 40%, about 6 days more here", "not curing here", "Cured
  (dry)"). Read-only, from the new `M.forecast(item, place)`; tests in `test_cellar.lua`. Needs TP Core 0.1.57.
- **Stale vegetables go off in weeks, not years** (user, session 78: realism the goal, from the tooltip's "rotten in
  about 1327 days" for a fridge potato). Each crop's rotten day is its fresh days plus its own stale days (`M.STALE_DAYS`:
  potato 45, turnip, beet, garlic 30, carrots, cabbage, onion 21, leek 10, sweet potato, pumpkin 14), and the stale
  stretch runs at a day a day wherever it lies, only frost stopping it (TP Core's `staleShare`, here 0). Fresh days are
  as before. A potato rots 73 days after new in a warm room (vanilla's 280), 195 in a basement.
- **Frost** moves a crop 1/12 of the way to its new rotten day an hour: about 6 days for a potato (was 23: an hour
  made it stale), about 2 for a carrot (was 0.7). 12 hours still ruin any crop.
- **Sweet potatoes and pumpkins chill in a fridge** too, as in a cold basement: 30 days (cured sweet potato 45,
  cured pumpkin 60), no longer vanilla's fridge floor of 140 (user, session 78).
- In a running save each vegetable takes its new rotten day at its next look; one already further past stale than its
  stale days rots then. Golden `cellar_report` re-recorded (frost months, chilled crops).

## 0.0.18
- **In TP Core's station report** (written on each save, for the long-save log): the Kraut Barrel window take part
  (`StationReport.add`). Needs TP Core 0.1.56.

## 0.0.17
- **No grass between clamps in a row** (user, session 77): the worked ground and trenches run a little past the
  clamp's west end, into the square before. The game draws a square's grass over anything of the tile before it that
  reaches in to the south or east, so a strip of it showed between two clamps; the next clamp's ground, reaching
  back, now fills it.
- The worked ground's speckle repeats with each tile (by position, not at random) and the grime goes on the heap
  only, so where one clamp's ground overlaps the next no lighter band shows; it has a solid base, so no grass shows
  through at its edges, and no dark edge from the resize.

## 0.0.16
- **Clamps in a row join up in game** (user, session 77): the clamp has its own depth texture for B42
  (`common/media/depthmaps/DEPTH_traditionalpreservationfruitvegetables_01.png`, computed by `tools/build_tileset.py`
  from the heap's shape: the worked ground, the trenches and the earthed dome). Without one the game's default let a
  neighbouring floor draw over the trenches, leaving a step where two clamps met.
- **The clamp is solid** (user): walked round, not over (`solidtrans`, as the Kraut Barrel); its loot window still
  opens from the next square.
- Needs TP Core 0.1.54.

## 0.0.15
- **The clamp** (ROADMAP section 8 phase 3; user, session 77; art `art/clamp_mock.png`): roots heaped on bare ground
  under straw, drainage trenches either side, a storage like the crates (no Info window, open the whole time, capacity
  75). Takes potatoes, turnips, sugar beets, carrots and cabbages only. **Dig a Clamp** from the right-click menu, as
  vanilla's Dig Furrow (user: the build menu's hammering didn't fit): a shovel (kept) and 6 hay, 30 minutes, on bare
  dirt under the sky by vanilla's furrow rule, the grass removed first (a furrow digs through it; TP Core's
  `Ground.diggable`); no build menu entry, not
  movable, **Level the Clamp** once empty. What lies in it is at TP
  Core's **StrawClamp** place, earthed up its **EarthedClamp** place, and keeps and freezes there by the cellar's rules.
  **Earth Up** (30 minutes) and **Take Down Soil** (20) with a shovel. Earthed over above 8 C its crops **sweat**: they
  age 1.5 times as fast. No rain rule; the trenches show rainwater while vanilla's puddles are up. The
  trenches run the tile's whole length on each side, so clamps in a row share one trench line (user). Console
  `TPFV.clamp()`, `TPFV.earth(on)`, `TPFV.kit("clamp")`; `TPFV.veg()` notes a crop in an earthed clamp. Tiles 22-25.
  Earthed up is the container's type (`clamp`, `earthedclamp`, saved with the object), item modData `tpfvSweat`. Tests: `test_clamp.lua`.
- `tools/cellar_report.lua`: a column under straw and one earthed up (the clamp's crops only), and the room's and
  day's means start at the season's (January's first row moved by a day or so in a shut room; a leek in an aired room
  keeps its 60 days from 1 January). Golden re-recorded.
- Dug with hay only, not a dried sheaf, which still holds its grain (session 77, put to the user).
- **The storages take only what they help** (user, session 77): the Onion and Garlic Pole garlic, onions and their
  braids; the Vegetable Crate (Hay) potatoes, turnips, cabbages, sweet potatoes and pumpkins; the Vegetable Crate
  (Sand) carrots, sugar beets, leeks and turnips; nothing cooked (`M.storageTakes`, read from `M.STORAGE_BONUS`; their
  accept functions set by the World on each one it sees). What already lies in one stays.
- **Own loot-window icons** (user, session 77; `art/container_icons_mock.png`): the Clamp, the Onion and Garlic Pole
  and both Vegetable Crates show their own icon on the loot window's button, not vanilla's shelves; the Clamp's
  follows its state (the straw heap, or the soil dome and "Clamp (Earthed Up)" once earthed up)
  (`Container_<Name>.png`, from the builder; TP Core's `UI.containerIcon`).
- Needs TP Core 0.1.53.

## 0.0.14
- **Kraut freezes** (ROADMAP NEXT 1, step 3; user, session 76): a portion of Sauerkraut or Sauer Turnip out of the
  barrel freezes at -3 C (salt and acid), on TP Core's Frost ledger by place, and frozen through (6 h in all) goes
  soft: the days it has left to stale and to rotten count 2/3, as the barrel's soft kraut. Once. Looked at as the
  vegetables are (carried, in containers as they are shown). Sandbox *Vegetables freeze* covers it. Item modData
  `tpfvKrautFrost`, `tpfvKrautSoft`. `TPFV.frost(hours)` softens kraut near you from 6 hours.
- Vegetables' frost now goes through TP Core's `Frost.see` and `Frost.bite` (no change in game). Needs TP Core 0.1.52.

## 0.0.13
- **Frost** (ROADMAP NEXT 1, step 2; user, session 76): every crop the cellar keeps freezes at its own point, on TP
  Core's Frost ledger by place: potato, sweet potato, pumpkin -1 C; carrots, sugar beet, turnip -1.5 C; cabbage -3 C;
  garlic and onion -3.5 C (braids too); leek -10 C. Every hour at or below it moves the vegetable 1/12 of the way to
  rotten (`M.FROST_RUIN_HOURS` 12), never past it. A basement never freezes, nor a place by a lit fire or banked
  embers; a powered fridge never, a powered freezer keeps vanilla's rules; a Vegetable Crate (Hay) counts half the
  hours. Loot too, from its first look. Sandbox *Vegetables freeze* (on). Item modData `tpfvFrost`.
- Console: `TPFV.frost(hours)` freezes the kept vegetables near you; `TPFV.veg()` shows each one's frozen hours, its
  freezing point and whether it freezes there now. `tools/cellar_report.lua` counts frost (golden re-recorded: from
  November every unheated room, aired room and porch ruins nearly every crop within days; basements unchanged).
- Needs TP Core 0.1.51.

## 0.0.12
- **Kraut Barrel Info on the settled window language** (`art/kraut_info_mock.png`), as the Salting Tub's: a state band
  (Empty, Packing with the salt it seals with, Fermenting with when it is ready, Too warm in red with the hours above
  27°C, stopped in the cold, Ready or Soft with how long it keeps, Spoiled); the Station block with its outline icon,
  the speed and the hours too warm while it sours; the heads as cells, cabbage and turnip patterns split by share, the
  mix under them, a line of history beside them; the Souring bar; notes.
- **What it was spiked with** (user, session 72, `art/kraut_spiked_mock.png` B): the apples and carrots show under the
  cells as their icons with counts (TP Core's counts line) while packing, fermenting and once ready, until the last
  portion: every portion carries its share of them.
- **Drag onto the barrel to pack**: cabbages, turnips, apples and carrots dragged onto its cells pack as the menu's
  Pack (the heads first, so they make room for the apples and carrots); a full or sealed barrel, a rotten piece or
  anything else is refused with the reason.
- **Buttons**: Salt and Compress (greyed with the reason) and Unpack (n) while packing; once ready one button a kraut,
  Take Sauerkraut (n) and Take Sauer Turnip (n), each opening One and All (n) (TP Core's menu button); Empty the
  Spoiled Barrel. The right-click menu keeps everything.
- The old window's rows (Stage, Place, Portions, Kept, Next) and their strings are gone. Needs TP Core 0.1.48.

## 0.0.11
- Temperatures in the game's text read with the degree sign ("12°C", was "12 C"), as TP Core 0.1.37's.

## 0.0.10
- The window rows read the station's full name and Info (Kraut Barrel Info), as vanilla's Fireplace Info and
  Generator Info; the window's title is the bare name. The short "Vessel Info", "Tub Info" and the like are gone.

## 0.0.9
- **Info in the main menu too** (user, session 53): every station's Info row is also at the bottom of the main right-click menu, besides its submenu (TP Core's `UI.topInfo`). Barrel Info.

## 0.0.8
- **Info windows open from the right-click menu only** (user, session 53): a left click on a station is vanilla's again, as for every vanilla workstation (a container opens its loot window). Barrel Info is in the barrel's menu.

## 0.0.7
- **A kraut barrel with anything in it can't be picked up** (2026-11-19): packing, fermenting or holding kraut, it
  stays where it is and its time goes by its place; empty, it picks up as before. No process needs it moved.

## 0.0.6
- **Aired rooms** (2026-11-19, TP Core 0.1.15): onions and garlic dry cure by moving air: an aired room as under a roof
  (1), **a shut room not at all** (was 0.6); a lit fire still draws air through a room (1), banked embers don't. Crates,
  the root cellar and the kraut barrel read TP Core's new place temperatures. Tools: shut room and aired room columns.
  Needs TP Core 0.1.15.

## 0.0.5
- **Vegetables by a fire** (TP Core 0.1.11): within 2 tiles of a lit fireplace, antique oven or campfire a vegetable is at 28 C (banked embers 24 C). Sweet potatoes and pumpkins cure there in autumn; a potato doesn't (too warm); keeping counts as a warm room. Garlic and onions dry by a lit fire indoors as on a porch (1), by banked embers as the place under them (user, 2026-11-18); a fire that ran out part way shares the stretch by time. README, guide 7. Needs TP Core 0.1.11.
- **The kraut barrel takes 20 heads at least** (was 30; still 60 at most): a smaller harvest can make kraut, and the long seal still makes a full barrel worth it. README, guide 7, Workshop text, the barrel's help and tooltip.
- **Fix: no Cooking xp from packing and unpacking** (review): packing paid 1 xp a piece as it went in, and Unpack gives every piece back, so packing again paid again. The same xp (1 a piece) now comes at Salt and Compress, with its 10.
- **Fix: the Kraut Barrel minds doorways** (`OnIsValid = TraditionalPreservationCore.doorFits`, as every TP station; Core's test_doors caught it).

## 0.0.4
- The kraut barrel gives the **Plank** back with the Flat Stone (the last portion, or emptying a spoiled barrel); only the cloth is used up.
- The Drying Pole is now the **Onion and Garlic Pole** (display name only; the entity and its container keep their ids).
- The Vegetable Crate (Hay) takes hay only: `Base.Straw2` was vanilla's drinking straw. Hay comes from a farm's hay bales.

## 0.0.3
- Sweet potatoes and pumpkins join the cellar, with a hot cure (20 to 32 C: 7 and 10 days; cured, twice as long).
- Two storages, containers from their tiles as Fish & Meat's Stockfish Pallet: the Drying Pole (garlic and onions
  hung; their cure counts 1.5, their keeping 0.75) the Vegetable Crate (Hay) (35; warm and hot cures 1.5; potatoes,
  turnips, cabbages, sweet potatoes, pumpkins keep 0.75) and the Vegetable Crate (Sand) (35, a sack of sand; carrots,
  beets, leeks, turnips keep 0.75). Each shows its contents in three steps, built from vanilla's vegetable icons.
- A sweet potato is chilled in a basement (30 days, 45 cured; 240 cured in a cool room); a pumpkin keeps 30 days in
  a warm room, 60 cured.
- The dry cure slows in the cold, as Fish & Meat's dry cure: full from 20 C, a fifth at 4 C and below.
- Garlic and onions cure by moving air: under a roof or in a loft at full speed, the open air 0.75, a closed room
  0.6. Cured garlic keeps 70 days in a fridge (it sprouts there) but 210 near 0 C. The crate gives carrots, beets
  and leeks no keeping bonus.
- Garlic and Onion Braids: Braid (2 to 10 bulbs) and Unbraid; only lighter to carry.
- Console `kit("storage")`, `give` braids, `veg` names the storage. The cure ledger is `...Cellar` + `Cure` (was
  `WarmCure`).

## 0.0.2
- The kraut barrel: a standing barrel (Woodwork 3: 6 planks, 10 nails, 4 twine), worked from its right-click menu with
  a Barrel Info window. Pack 30 to 60 cabbages and turnips in any mix (All with the number held, then One), apples and
  carrots up to one each per five heads, unpack before sealing (packed pieces go on ageing at vanilla's pace until then); Salt and Compress takes a use of salt per five heads, a cloth, a plank and a flat stone and
  seals it. Sours by place temperature (28 days at 18 C, 120 at 4 C, stopped at 0 C), soft after 48 h above 27 C (keeps 2/3 as long), spoiled after
  120 h. Ready kraut keeps in the barrel by place (180 days at 8 C) and comes out a portion a head as Sauerkraut or
  Sauer Turnip, a head's own kind (a cabbage as Sauerkraut, a turnip as Sauer Turnip) with the apples and carrots
  shared over every head, no mood (a way of keeping cabbage, not a treat); the last portion
  gives the stone back. The barrel's art (in the Salting Tub's wood and iron) shows cabbage, turnip or mixed shreds while packing, then the cloth, board and stone. Replaces the template's Kraut Barrel station and batch. Sandbox *Kraut ferment (days at 18 C)*
  replaces *Processing time*. Console `barrel`, `age` and `fast` for the barrel, `kit("barrel")`, `give` kraut. Season
  table `tools/kraut_report.lua` replaces the template's.

## 0.0.1
- New mod, made by `tp new` on 2026-11-18 from TP Core's template.
- The root cellar: vanilla potatoes, turnips, sugar beets, carrots, cabbages, leeks, garlic and onions keep by place
  on TP Core's PlaceKeeping, never worse than vanilla; potatoes cure in 7 days at 10 to 20 C, garlic and onions in 14
  days anywhere dry. Sandbox *Vegetables keep by place*. Console `cellar`, `veg`, `keep`, `cure`, `give` by crop,
  `kit("cellar")`. Season table `tools/cellar_report.lua`.
