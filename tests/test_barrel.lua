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
for i = 1, 19 do M.pack(barrel, "cabbage", i / 10, CABBAGE) end
check("packing", M.barrelStage(barrel) == "Packing" and M.headCount(barrel) == 19)
check("cabbages and turnips mix in one barrel", M.packRefusal(barrel) == nil)
check("apples up to one per five heads: 3 for 19", M.extraRoom(19) == 3)
for _ = 1, 3 do M.packExtra(barrel, "apple", 1, APPLE) end
check("a fourth apple refused", M.extraRefusal(barrel, "apple") == "TooMany" and M.extraRefusal(barrel, "carrot") == nil)
local have = { salt = 100, cloth = true, board = true, stone = true }
check("19 heads are too few to salt and compress", M.compressRefusal(barrel, have) == "TooFew")
for _ = 1, 11 do M.pack(barrel, "cabbage", 3, CABBAGE) end
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
    near(portion.calories, 180 + (3 * 95 + 6 * 25) / 60) and near(portion.hunger, -0.24 + (3 * -0.16 + 6 * -0.08) / 60))
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
check("sealed, it is shut: no kraut, no starter, no put back; Unseal is offered", M.takePortion(barrel, "cabbage") == nil
    and M.drawRefusal(barrel) == "Pressed" and M.putBackRefusal(barrel, true) == "Pressed" and M.unsealRefusal(barrel) == nil)
check("Unseal lifts the plank and stone off: once", M.unseal(barrel) and not M.pressed(barrel)
    and M.unsealRefusal(barrel) == "NotPressed")
check("no turnip portion from an all-cabbage barrel", M.takePortion(barrel, "turnip") == nil)
local taken = M.takePortion(barrel, "cabbage")
check("a portion out: the batch's food, its share of keeping", taken.portion.calories == portion.calories and taken.kind == "cabbage"
    and near(taken.ageShare, barrel.keepDays / 180) and M.portionsLeft(barrel) == 59 and not taken.last)
for _ = 1, 58 do M.takePortion(barrel, "cabbage") end
local last = M.takePortion(barrel, "cabbage")
check("the last portion leaves the brine: 9 L of 60 heads, stage Brine",
    last.last == true and M.barrelStage(barrel) == "Brine" and near(M.brineOf(barrel), 9) and barrel.portions == nil)
local drained = M.drainBrine(barrel)
check("Drain Brine takes all of it, the barrel empty and open", near(drained, 9) and M.barrelStage(barrel) == "Empty"
    and M.packRefusal(barrel) == nil)
check("a barrel emptied with its press still on takes no new heads", M.packRefusal({ stage = "Empty", press = true }) == "Pressed"
    and M.starterRefusal({ press = true }) == "Pressed" and M.drainBrine({ stage = "Brine", brine = 2, press = true }) == 0)

-- Too warm
local hot = {}
for _ = 1, 30 do M.pack(hot, "turnip", 0, CABBAGE) end
M.compress(hot, ledger)
hot.press = false  -- opened, as Unseal would
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
soft.press = false  -- opened, as Unseal would
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
mixed.press = false
mixed.workHours = M.FERMENT_HOURS
M.updateBarrel(mixed, ledger, "Sheltered")
check("ready: 20 Sauerkraut and 10 Sauer Turnip", M.portionsLeft(mixed, "cabbage") == 20 and M.portionsLeft(mixed, "turnip") == 10)
local turnipOut = M.takePortion(mixed, "turnip")
check("a turnip portion: a turnip's food", turnipOut.kind == "turnip" and near(turnipOut.portion.calories, 70 + 9.5))
for _ = 1, 9 do M.takePortion(mixed, "turnip") end
check("the turnips gone, the cabbage still there", M.takePortion(mixed, "turnip") == nil and M.barrelStage(mixed) == "Ready")
for _ = 1, 19 do M.takePortion(mixed, "cabbage") end
check("the last of all leaves its 4.5 L of brine", M.takePortion(mixed, "cabbage").last == true and M.barrelStage(mixed) == "Brine"
    and near(M.brineOf(mixed), 4.5))

-- Stale heads make soft kraut, head by head (user, 2026-11-22): 4 of 20 cabbages stale at sealing (one went stale
-- while the barrel stood packed), 10 fresh turnips; the soft ones of a kind come out first, further on.
local staled = {}
for _ = 1, 3 do M.pack(staled, "cabbage", 8, CABBAGE, 100, 7) end
M.pack(staled, "cabbage", 6.5, CABBAGE, 100, 7)
for _ = 1, 16 do M.pack(staled, "cabbage", 1, CABBAGE, 100, 7) end
for _ = 1, 10 do M.pack(staled, "turnip", 1, TURNIP, 100, 28) end
M.pack(staled, "cabbage", 8, CABBAGE)
check("stale heads while packing: 3 now, 4 a day later", M.staleHeads(staled, 100) == 3 and M.staleHeads(staled, 124) == 4)
M.compress(staled, ledger, 124)
staled.press = false  -- opened, as Unseal would
check("sealed: 4 soft cabbages, no soft turnips (an old head without its stale age isn't counted)",
    M.softLeft(staled, "cabbage") == 4 and M.softLeft(staled, "turnip") == 0 and M.softLeft(staled) == 4)
staled.workHours = M.FERMENT_HOURS
M.updateBarrel(staled, ledger, "Basement")
staled.keepDays = 60
local firstOut = M.takePortion(staled, "cabbage")
check("the soft portions first, kept a soft batch's pace", firstOut.soft == true
    and near(firstOut.ageShare, 60 * M.SOFT_KEEP / M.KEEP_DAYS) and M.softLeft(staled, "cabbage") == 3)
for _ = 1, 3 do M.takePortion(staled, "cabbage") end
local fifth = M.takePortion(staled, "cabbage")
check("then the rest as usual", fifth.soft == false and near(fifth.ageShare, 60 / M.KEEP_DAYS) and M.softLeft(staled) == 0)
check("a turnip from a fresh lot isn't soft", M.takePortion(staled, "turnip").soft == false)
staled.keepDays = 170
staled.softHeads = { cabbage = 1 }
check("late in the barrel a soft portion comes out past fresh, never past rotten",
    near(M.takePortion(staled, "cabbage").ageShare, 170 * M.SOFT_KEEP / M.KEEP_DAYS))

-- A barrel by a fire is 28 C: too warm
check("by a fire is too warm for kraut", M.hotRate(M.placeTemperatureAt(ledger, "Fireside")) == 1)

-- Frost on a portion out of the barrel (user, session 76): it freezes at -3 C, and frozen through (6 h) it goes soft,
-- the days it has left counting 2/3, once; the sandbox off, no harm.
local Frost = require "TraditionalPreservationCore/Frost"
local function portion()
    local self = { fullType = M.KRAUTS.cabbage.product, offAge = 14, offAgeMax = 28, age = 2, modData = {} }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:getModData() return self.modData end
    function self:isCooked() return self.cooked == true end
    function self:isBurnt() return false end
    return self
end
local frostHour = Frost.ledger().lastHour
local function frostWeather(hours, celsius)
    for _ = 1, hours * 6 do
        frostHour = frostHour + 1 / 6
        Frost.recordWeather(frostHour, celsius)
    end
end
frostWeather(1, 5)
local out, cold, cellar, off = portion(), portion(), portion(), portion()
M.keepKraut(out, frostHour, "Open")
M.keepKraut(cold, frostHour, "Open")
M.keepKraut(cellar, frostHour, "Basement")
M.keepKraut(off, frostHour, "Open")
check("a portion's first look starts its frost record", out.modData[M.KRAUT_FROST_KEY] ~= nil)
check("vegetables' own point doesn't matter: kraut freezes at -3 C", M.KRAUT_FREEZE_C == -3)
frostWeather(5, -2)
M.keepKraut(cold, frostHour, "Open")
check("-2 C doesn't freeze kraut", cold.modData[M.KRAUT_FROST_KEY].age == 0 and cold.offAge == 14)
frostWeather(5, -5)
M.keepKraut(out, frostHour, "Open")
check("five hours at -5 C: not yet frozen through", not out.modData[M.KRAUT_SOFT_KEY] and out.offAge == 14)
frostWeather(1.5, -5)
M.keepKraut(out, frostHour, "Open")
M.keepKraut(cellar, frostHour, "Basement")
SandboxVars = { TraditionalPreservationFruitVegetables = { FrostDamage = false } }
M.keepKraut(off, frostHour, "Open")
SandboxVars = nil
check("frozen through it goes soft: 12 days left to stale count 8, 26 to rotten 17.3",
    out.modData[M.KRAUT_SOFT_KEY] == true and near(out.offAge, 10) and near(out.offAgeMax, 2 + 26 / 1.5))
check("soft only once", M.softenKraut(out) == false and near(out.offAge, 10))
check("a basement never freezes it", cellar.modData[M.KRAUT_FROST_KEY].age == 0 and cellar.offAge == 14)
check("the sandbox off: no harm", not off.modData[M.KRAUT_SOFT_KEY] and off.offAge == 14)
check("anything else is left alone", M.keepKraut({ getFullType = function() return "Base.Cabbage" end }) == nil)
local cooked = portion()
cooked.cooked = true
check("cooked kraut keeps vanilla's clock: no frost record", M.keepKraut(cooked, frostHour, "Open") == nil and cooked.modData[M.KRAUT_FROST_KEY] == nil)

-- The brine and the starter (user, 2026-11-27)
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local fresh = {}
check("a starter only while empty or packing, once", M.addStarter(fresh) and M.starterRefusal(fresh) == "HasStarter")
for _ = 1, 40 do M.pack(fresh, "cabbage", 0.5, CABBAGE, H.hours) end
local back = M.unpack({ stage = "Packing", heads = {}, starter = true }, H.hours)
check("Unpack gives the starter back as 1 L of brine", #back == 1 and back[1].brine == 1)
ledger.seasonTemperature, ledger.groundTemperature = 18, 18
M.compress(fresh, ledger, H.hours)
local here = M.barrelStatus(fresh, ledger, "Basement")
check("sealed with a starter: used, 6 L of brine for 40 heads, 25% faster than the place's own rate", fresh.starter == nil
    and fresh.starterUsed and near(M.brineOf(fresh), 6) and near(here.rate, M.fermentRate(here.temperature) * 1.25, 0.001))
fresh.workHours = M.FERMENT_HOURS
M.updateBarrel(fresh, ledger, "Basement")
check("then ready", M.barrelStage(fresh) == "Ready")
M.unseal(fresh)
check("no brine drained while kraut is in; a starter drawn once, 1 L", M.drainBrine(fresh) == 0
    and M.drawStarter(fresh) == 1 and near(M.brineOf(fresh), 5) and M.drawRefusal(fresh) == "Drawn" and M.drawStarter(fresh) == 0)
check("put back on a full barrel: what its 5 L cover (33) less the 40 in, none", M.putBackRoom(fresh) == 0
    and M.putBackRefusal(fresh, true) == "Covered")
for _ = 1, 10 do M.takePortion(fresh, "cabbage") end
check("10 out: room for 3 back", M.putBackRoom(fresh) == 3)
check("a stale portion isn't put back", M.putBackRefusal(fresh, false) == "Stale")
check("a fresh one goes back, with its own clock", M.putBack(fresh, "cabbage", CABBAGE, 7, false, ledger)
    and M.portionsLeft(fresh) == 31 and #fresh.pieces == 31 and near(fresh.keepDays, 90))
weather(10, 8)
ledger.groundTemperature = 8
M.updateBarrel(fresh, ledger, "Basement")
check("the barrel keeps by its oldest piece: the one put back half through, older by the days since", fresh.keepDays > 90
    and fresh.keepDays < 120)
local first = M.takePortion(fresh, "cabbage")
check("the oldest comes out first, as far into its days as it is", near(first.ageShare, fresh.keepDays / 180, 0.05) or first.ageShare > 0.5)
local lastOut
for _ = 1, 30 do lastOut = M.takePortion(fresh, "cabbage") or lastOut end
check("not unsealed mid-ferment, but once ready", M.unsealRefusal({ stage = "Fermenting" }) == "Fermenting"
    and M.unsealRefusal({ stage = "Ready" }) == nil)
check("emptied: 5 L of brine left, aging as Kraut Brine", M.barrelStage(fresh) == "Brine" and near(M.brineOf(fresh), 5)
    and fresh[FluidAgeing.KEY] ~= nil)
check("brine only takes kraut back as it covers (33)", M.putBackRoom(fresh) == 33)
check("a barrel of brine takes more poured in, up to 9 L", near(M.pourBrine(fresh, 6), 4) and near(M.brineOf(fresh), 9)
    and M.pourRefusal(fresh) == "Full")
weather(25, 20)
ledger.groundTemperature, ledger.seasonTemperature = 20, 20
M.updateBarrel(fresh, ledger, "Sheltered")
check("three weeks at 20 C: mouldy, nothing goes back, nothing poured in", fresh.brineSpoiled == true
    and M.putBackRoom(fresh) == 0 and M.pourRefusal(fresh) == "Mouldy")
local litres, fluid = M.drainBrine(fresh)
check("drained as rotten brine, the barrel empty", near(litres, 9) and fluid == M.ROTTEN_BRINE and M.barrelStage(fresh) == "Empty")
check("an empty barrel takes good brine poured in", near(M.pourBrine(fresh, 2), 2) and M.barrelStage(fresh) == "Brine")
check("a barrel sealed before the press was recorded has it on", M.pressed({ stage = "Ready" }) and not M.pressed({}))
local reopened = { stage = "Brine", brine = 1.5, press = false }
M.putBack(reopened, "cabbage", CABBAGE, 2, false, ledger)
check("an unsealed barrel of brine with kraut put back stays unsealed", M.barrelStage(reopened) == "Ready" and not M.pressed(reopened)
    and reopened.press == false)

local old = { stage = "Ready", portions = { cabbage = 30 }, headCounts = { cabbage = 40 }, keepDays = 5, keepMarks = {} }
check("a barrel sealed before brine: its batch's, 0.15 L a head it was sealed with", near(M.brineOf(old), 6) and old.brine == nil)
M.brineOf(old, true)
check("written down when it is brought up to now", near(old.brine, 6))
check("Kraut Brine goes off in 3 weeks at 20 C, about 2 months at 8, never frozen",
    near(M.BRINE_SPOIL_HOURS / M.brineRate(20) / 24, 21) and near(21 / M.brineRate(8), 60) and M.brineRate(-1) == 0)

H.done()
