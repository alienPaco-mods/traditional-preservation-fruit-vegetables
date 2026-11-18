# Changelog: Traditional Preservation (Fruits and Vegetables)

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
