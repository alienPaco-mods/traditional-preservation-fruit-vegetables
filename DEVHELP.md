# Traditional Preservation (Fruits and Vegetables): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPFV.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPFV.weather()` | The temperature in each place (open air, under an open roof, indoors, a basement), the days a kraut barrel takes to sour there (or stopped, at 0 C or below), TOO WARM above 27 C, and how long ready kraut keeps there. |
| `TPFV.here()` | Which kind of place you're standing in. |
| `TPFV.barrel()` | The nearest loaded kraut barrel: stage, kind, heads, apples, carrots, place and temperature, progress, rate, hours to ready or days it keeps, hours too warm, portions left and soft. |
| `TPFV.age(hours)` | Gives every kraut barrel this many hours of good weather: a fermenting one sours by that much, a ready one keeps that much (in hours of an 8 C cellar). `TPFV.age(672)` finishes a barrel. |
| `TPFV.fast(hours)` | Test timer: a barrel sours in this many hours at 18 C. `TPFV.fast()` goes back to the sandbox time. |
| `TPFV.cellar()` | Days fresh for each vegetable (and cured potatoes, garlic and onions) in every place and a fridge, at today's weather. |
| `TPFV.veg()` | The kept vegetables on you and in containers within 4 tiles: place, rate, age, stale and rotten in, whether cured or curing (hours), and in a storage (pole, hay or sand crate) its keeping and cure factors and the days fresh with them (the first figure is the place alone); its frozen hours in all, its freezing point, and whether it freezes where it is now. |
| `TPFV.keep(days)` | Ages the vegetables on you and within 4 tiles by this many days at their place, and their storage (a crate's three quarters). Doesn't count toward curing. |
| `TPFV.cure()` | Cures the vegetables that cure (potatoes, garlic, onions, sweet potatoes, pumpkins) on you and within 4 tiles now. |
| `TPFV.frost(hours)` | Freezes the kept vegetables on you and within 4 tiles for hours (default 3), as if they had been at or below their freezing point that long: each hour 1/12 of the way to rotten. From 6 hours, Sauerkraut and Sauer Turnip out of the barrel near you go soft. |
| `TPFV.give(name, n)` | Spawns `n` of a vegetable by crop (`cabbage`, `carrots`, `garlic`, `leek`, `onion`, `potato`, `sugarBeet`, `turnip`), `sauerkraut` or `sauerTurnip` (a plain head's values), `garlicBraid` or `onionBraid` (empty). `TPFV.give()` lists them. |
| `TPFV.kit(kind)` | Gives what a test of `kind` needs: `"barrel"` (a hammer, a saw, 7 planks, 10 nails and 4 twine to build the Kraut Barrel, Woodwork 3, and one for its board; 30 cabbages, 6 apples, 6 carrots, 30 turnips, 2 salt shakers, a ripped sheet and a flat stone), `"cellar"` (3 of each kept vegetable), `"storage"` (a hammer, a saw, 9 planks, 12 nails, 2 twine, 4 hay and a sack of sand for the three storages; 10 potatoes, 4 sweet potatoes, 2 pumpkins, 10 garlic, 10 onions, 6 carrots, 6 sugar beets). `TPFV.kit()` or `TPFV.kit("?")` lists the kinds. |

**Typical check (cellar):** `TPFV.kit("cellar")`, put them in a crate in a basement, `TPFV.cellar()`, `TPFV.keep(30)`, `TPFV.veg()`.

**Typical check (barrel):** `TPFV.kit("barrel")`, build the barrel, Pack Cabbage > All (30), Add Apple, Salt and Compress, `TPFV.barrel()`, `TPFV.age(672)`, `TPFV.barrel()` (Ready), Take Sauerkraut.

**Typical check (frost):** `TPFV.give("potato", 2)`, drop one outside on a frosty night (`TPC.weather()` shows the open air), keep one in a basement, wait a few in-game hours, `TPFV.veg()`: the outside one has frozen hours and is stale, the basement one none. `TPFV.frost(12)` rots any kept vegetable at once.

**Typical check (storages):** `TPFV.kit("storage")`, build the three, put 3 carrots in the sand crate and 3 on the floor beside it, `TPFV.keep(10)`, `TPFV.veg()`: the sand crate's are three quarters as far into their days.
