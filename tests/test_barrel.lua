-- Checks the kraut barrel's rules (TraditionalPreservationFruitVegetablesBarrel.lua): packing, salting and compressing, the
-- ferment by temperature, too warm, keeping, portions. Run from the mod folder: luajit tests/test_barrel.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables

local CABBAGE = { hunger = -0.24, calories = 180, carbs = 41, proteins = 9, lipids = 0.7 }
local APPLE = { hunger = -0.16, calories = 95, carbs = 25.13, proteins = 0.47, lipids = 0.31 }
local CARROT = { hunger = -0.08, calories = 25, carbs = 6, proteins = 0.6, lipids = 0.15 }

-- Agreed numbers (user, 2026-11-18)
check("28 days at 18 C, 60 at 8, 40 at 13, 21 at 21, 16 at 24", near(M.fermentDays(18), 28) and near(M.fermentDays(8), 60)
    and near(M.fermentDays(13), 40) and near(M.fermentDays(21), 21) and near(M.fermentDays(24), 16))
check("slow in the cold, 120 days at 4 C; stopped at 0 C (user, 2026-11-18); hotter than 24 C no faster",
    near(M.fermentDays(4), 120) and M.fermentDays(0) == nil and M.fermentDays(-5) == nil and M.fermentDays(2) > 120
    and near(M.fermentDays(30), 16))
check("too warm counts above 27 C only", M.hotRate(27) == 0 and M.hotRate(28) == 1)
check("ready kraut: 180 days at 8 C, about a month warm", near(M.KEEP_DAYS / M.keepRate(8), 180) and near(M.KEEP_DAYS / M.keepRate(22), 30))
M.SENSITIVITY = 0
check("sensitivity off: 28 days anywhere, never too warm", near(M.fermentDays(-10), 28) and M.hotRate(40) == 0)
M.SENSITIVITY = 1

-- Packing
local barrel = {}
check("an empty barrel", M.barrelStage(barrel) == "Empty" and M.packRefusal(barrel, "cabbage") == nil)
check("no apple before a head", M.extraRefusal(barrel, "apple") == "NoHeads")
for i = 1, 29 do M.pack(barrel, "cabbage", i / 10, CABBAGE) end
check("packing", M.barrelStage(barrel) == "Packing" and M.headCount(barrel) == 29)
check("cabbages and turnips mix in one barrel", M.packRefusal(barrel) == nil)
check("apples up to one per five heads: 5 for 29", M.extraRoom(29) == 5)
for _ = 1, 5 do M.packExtra(barrel, "apple", 1, APPLE) end
check("a sixth apple refused", M.extraRefusal(barrel, "apple") == "TooMany" and M.extraRefusal(barrel, "carrot") == nil)
local have = { salt = 100, cloth = true, board = true, stone = true }
check("29 heads are too few to salt and compress", M.compressRefusal(barrel, have) == "TooFew")
M.pack(barrel, "cabbage", 3, CABBAGE)
for _ = 1, 6 do M.packExtra(barrel, "carrot", 2, CARROT) end
check("salt: a use per five heads, 6 for 30", M.saltNeeded(30) == 6 and M.compressRefusal(barrel, { salt = 5, cloth = true, board = true, stone = true }) == "NoSalt")
check("a cloth, a board, a stone", M.compressRefusal(barrel, { salt = 6, board = true, stone = true }) == "NoCloth"
    and M.compressRefusal(barrel, { salt = 6, cloth = true, stone = true }) == "NoBoard"
    and M.compressRefusal(barrel, { salt = 6, cloth = true, board = true }) == "NoStone"
    and M.compressRefusal(barrel, { salt = 6, cloth = true, board = true, stone = true }) == nil)
for _ = 31, 60 do M.pack(barrel, "cabbage", 1, CABBAGE) end
check("60 heads fill it", M.packRefusal(barrel) == "Full")

-- Unpacking gives everything back
local copy = {}
for i = 1, 3 do M.pack(copy, "turnip", i, CABBAGE) end
M.packExtra(copy, "apple", 7, APPLE)
local back = M.unpack(copy)
check("unpack: every piece back at its age, the barrel empty", #back == 4 and back[1].fullType == "Base.Turnip"
    and back[3].age == 3 and back[4].fullType == "Base.Apple" and back[4].age == 7 and M.barrelStage(copy) == "Empty")

-- Unsealed, a barrel is no cold store (side agent, 2026-11-18): pieces age as if lying out
local waiting = {}
M.pack(waiting, "cabbage", 0.5, CABBAGE, 100)
M.packExtra(waiting, "apple", 1, APPLE, 100)
local later = M.unpack(waiting, 100 + 10 * 24)
check("ten days packed but not sealed: ten days older on unpacking", near(later[1].age, 10.5) and near(later[2].age, 11))

-- Salting and compressing
local portion = M.portionOf(barrel, "cabbage")
check("a portion: a head's food plus the apples and carrots shared over the heads",
    near(portion.calories, 180 + (5 * 95 + 6 * 25) / 60) and near(portion.hunger, -0.24 + (5 * -0.16 + 6 * -0.08) / 60))
check("no mood on the kraut (user, 2026-11-18)", portion.unhappy == nil and portion.boredom == nil)
local ledger = M.getLedger()
ledger.seasonTemperature, ledger.groundTemperature = 18, 18
M.compress(barrel, ledger)
check("salted and compressed: sealed, fermenting, 60 portions", M.barrelStage(barrel) == "Fermenting" and M.portionsLeft(barrel) == 60
    and M.portionsLeft(barrel, "cabbage") == 60 and M.portionsLeft(barrel, "turnip") == 0 and M.packRefusal(barrel) == "Sealed" and M.extraRefusal(barrel, "apple") == "Sealed"
    and M.compressRefusal(barrel, have) == "Sealed" and barrel.heads == nil)
check("nothing comes back out once sealed", #M.unpack(barrel) == 0 and M.barrelStage(barrel) == "Fermenting")
check("no portion while it ferments", M.takePortion(barrel, "cabbage") == nil)

local function weather(days, celsius)
    for _ = 1, days * 24 do
        H.setHours(H.hours + 1)
        M.advance(ledger, H.hours, celsius)
    end
end

-- A room at 18 C: Sheltered reads the season mean
weather(27, 18)
M.updateBarrel(barrel, ledger, "Sheltered")
check("27 days at 18 C: still fermenting", M.barrelStage(barrel) == "Fermenting" and near(barrel.workHours, 27 * 24, 1))
local status = M.barrelStatus(barrel, ledger, "Sheltered")
check("the status: progress, the rate, a day left", near(status.progress, 27 / 28, 0.01) and near(status.rate, 1, 0.01)
    and near(status.hoursLeft, 24, 1))
weather(1.1, 18)
M.updateBarrel(barrel, ledger, "Sheltered")
check("28 days: ready, not soft", M.barrelStage(barrel) == "Ready" and not barrel.soft and barrel.keepDays == 0)

-- Keeping: in a cellar
weather(30, 8)
ledger.groundTemperature = 8
M.updateBarrel(barrel, ledger, "Basement")
check("ready kraut keeps by place", barrel.keepDays > 0 and barrel.keepDays < 60)

-- Portions
check("no turnip portion from an all-cabbage barrel", M.takePortion(barrel, "turnip") == nil)
local taken = M.takePortion(barrel, "cabbage")
check("a portion out: the batch's food, its share of keeping", taken.portion.calories == portion.calories and taken.kind == "cabbage"
    and near(taken.ageShare, barrel.keepDays / 180) and M.portionsLeft(barrel) == 59 and not taken.last)
for _ = 1, 58 do M.takePortion(barrel, "cabbage") end
local last = M.takePortion(barrel, "cabbage")
check("the last portion empties the barrel (and gives the stone back)", last.last == true and M.barrelStage(barrel) == "Empty")

-- Too warm
local hot = {}
for _ = 1, 30 do M.pack(hot, "turnip", 0, CABBAGE) end
M.compress(hot, ledger)
weather(1, 30)  -- a day in the open at 30 C
M.updateBarrel(hot, ledger, "Open")
weather(1.5, 30)
M.updateBarrel(hot, ledger, "Open")
check("two and a half days above 27 C: still fermenting, soft to come", M.barrelStage(hot) == "Fermenting" and hot.hotHours >= 48)
weather(3, 30)
M.updateBarrel(hot, ledger, "Open")
check("five days above 27 C: spoiled", M.barrelStage(hot) == "Spoiled" and M.takePortion(hot, "turnip") == nil)
check("a spoiled barrel empties (the stone back)", M.emptySpoiled(hot) and M.barrelStage(hot) == "Empty")

local soft = {}
for _ = 1, 30 do M.pack(soft, "cabbage", 0, CABBAGE) end
M.compress(soft, ledger)
soft.workHours = M.FERMENT_HOURS - 1
weather(3, 30)
M.updateBarrel(soft, ledger, "Open")
check("ready after three days above 27 C: soft", M.barrelStage(soft) == "Ready" and soft.soft == true)
check("soft kraut keeps 2/3 as long", near(M.barrelStatus(soft, ledger, "Basement").rate, 1.5 * M.keepRate(M.placeTemperature(ledger, "Basement"))))
local softPortion = M.takePortion(soft, "cabbage")
local item = { modData = {} }
for _, name in ipairs({ "BaseHunger", "HungChange", "Calories", "Carbohydrates", "Proteins", "Lipids", "UnhappyChange",
    "BoredomChange", "OffAge", "OffAgeMax", "Age" }) do
    item["set" .. name] = function(self, x) self[name] = x end
end
M.applyPortion(item, softPortion)
check("a soft portion: its food, no mood, 14 / 28 days", item.UnhappyChange == nil and item.BoredomChange == nil
    and item.OffAge == 14 and item.OffAgeMax == 28 and near(item.HungChange, -0.24) and near(item.Calories, 180))

-- A mixed barrel (user, 2026-11-18): 20 cabbages and 10 turnips, 3 apples; one ferment, each head its own kraut
local TURNIP = { hunger = -0.18, calories = 70, carbs = 14.52, proteins = 2.88, lipids = 0.15 }
local mixed = {}
for _ = 1, 20 do M.pack(mixed, "cabbage", 0, CABBAGE) end
for _ = 1, 10 do M.pack(mixed, "turnip", 0, TURNIP) end
for _ = 1, 3 do M.packExtra(mixed, "apple", 0, APPLE) end
check("30 heads of any mix are enough", M.headCount(mixed) == 30 and M.headCount(mixed, "turnip") == 10
    and M.compressRefusal(mixed, have) == nil)
check("each kind keeps its own food, the apples shared over all 30 heads",
    near(M.portionOf(mixed, "cabbage").calories, 180 + 3 * 95 / 30) and near(M.portionOf(mixed, "turnip").calories, 70 + 3 * 95 / 30)
)
local back = M.unpack({ heads = { { kind = "turnip", age = 1 }, { kind = "cabbage", age = 2 } }, stage = "Packing" })
check("unpacking a mix gives each head back as itself", back[1].fullType == "Base.Turnip" and back[2].fullType == "Base.Cabbage")
M.compress(mixed, ledger)
mixed.workHours = M.FERMENT_HOURS
M.updateBarrel(mixed, ledger, "Sheltered")
check("ready: 20 Sauerkraut and 10 Sauer Turnip", M.portionsLeft(mixed, "cabbage") == 20 and M.portionsLeft(mixed, "turnip") == 10)
local turnipOut = M.takePortion(mixed, "turnip")
check("a turnip portion: a turnip's food", turnipOut.kind == "turnip" and near(turnipOut.portion.calories, 70 + 9.5))
for _ = 1, 9 do M.takePortion(mixed, "turnip") end
check("the turnips gone, the cabbage still there", M.takePortion(mixed, "turnip") == nil and M.barrelStage(mixed) == "Ready")
for _ = 1, 19 do M.takePortion(mixed, "cabbage") end
check("the last of all empties it", M.takePortion(mixed, "cabbage").last == true and M.barrelStage(mixed) == "Empty")

-- A barrel by a fire is 28 C: too warm
check("by a fire is too warm for kraut", M.hotRate(M.placeTemperatureAt(ledger, "Fireside")) == 1)

H.done()
