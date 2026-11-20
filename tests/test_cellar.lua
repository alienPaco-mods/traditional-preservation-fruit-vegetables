-- Checks the root cellar (TraditionalPreservationFruitVegetablesCellar.lua): vegetables keep by place, never worse than
-- vanilla, and potatoes, garlic and onions cure. Run from the mod folder: luajit tests/test_cellar.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables

local function vegetable(fullType, offAge, offAgeMax, age)
    local self = { fullType = fullType, offAge = offAge, offAgeMax = offAgeMax, age = age or 0, modData = {} }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getContainer() return self.container end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getDisplayName() return self.fullType end
    function self:isCooked() return self.cooked == true end
    function self:isBurnt() return self.burnt == true end
    return self
end

-- The agreed days fresh (2026-11-18), vanilla's days in a warm room
local CROPS = M.CROPS
check("a potato: 28 days in a warm room, 60 in a cool one, 150 in a basement, 140 in a fridge",
    near(M.daysFresh(CROPS.potato, 22), 28) and near(M.daysFresh(CROPS.potato, 15), 60)
    and near(M.daysFresh(CROPS.potato, 8), 150) and near(M.daysFresh(CROPS.potato, 4), 140))
check("a cabbage: 7 days warm (vanilla's 2, user 2026-11-18), 14 cool, 90 in a basement",
    near(M.daysFresh(CROPS.cabbage, 22), 7) and near(M.daysFresh(CROPS.cabbage, 15), 14) and near(M.daysFresh(CROPS.cabbage, 8), 90))
check("carrots and sugar beets 120 in a basement, turnips too",
    near(M.daysFresh(CROPS.carrots, 8), 120) and near(M.daysFresh(CROPS.sugarBeet, 8), 120) and near(M.daysFresh(CROPS.turnip, 8), 120))
check("a leek 60 in a basement", near(M.daysFresh(CROPS.leek, 8), 60))
check("garlic and onions: a basement is too damp, 30 days, about a cool room's",
    near(M.daysFresh(CROPS.garlic, 8), 30) and near(M.daysFresh(CROPS.onion, 15), 28))
check("cured potatoes 210 in a basement", near(M.daysFresh(CROPS.potato, 8, true), 210))
check("a sweet potato is chilled in a basement: 30 days, 45 cured; 240 cured in a cool room",
    near(M.daysFresh(CROPS.sweetPotato, 8), 30) and near(M.daysFresh(CROPS.sweetPotato, 8, true), 45)
    and near(M.daysFresh(CROPS.sweetPotato, 15, true), 240))
check("a pumpkin in a warm room: 30 days, 60 cured", near(M.daysFresh(CROPS.pumpkin, 22), 30) and near(M.daysFresh(CROPS.pumpkin, 22, true), 60))
check("cured garlic in a fridge (4 C): 70 days, it sprouts; near 0 C and dry, a winter attic: 210; a cured onion 180 at 4 C",
    near(M.daysFresh(CROPS.garlic, 4, true), 70) and near(M.daysFresh(CROPS.garlic, 0, true), 210)
    and near(M.daysFresh(CROPS.garlic, -5, true), 210) and near(M.daysFresh(CROPS.onion, 4, true), 180))
check("cured garlic 180 in a cool room, 90 in a warm one, 60 in a basement",
    near(M.daysFresh(CROPS.garlic, 15, true), 180) and near(M.daysFresh(CROPS.garlic, 22, true), 90)
    and near(M.daysFresh(CROPS.garlic, 8, true), 60))
check("between the points a day counts by a straight line", near(CROPS.cabbage.keeper.ageRate(18.5), (2 / 14 + 2 / 7) / 2))

-- Never worse than vanilla (user, 2026-11-18)
local worst = 0
for _, name in ipairs(M.CROP_NAMES) do
    local crop = CROPS[name]
    for celsius = -30, 45 do
        worst = math.max(worst, crop.keeper.ageRate(celsius))
        if crop.curedKeeper then worst = math.max(worst, crop.curedKeeper.ageRate(celsius)) end
    end
    check(name .. ": a fridge never worse than vanilla's (0.2 a day)", crop.keeper.ageRate(4) <= M.VANILLA_FRIDGE_RATE + 1e-9)
end
check("no crop anywhere ages faster than vanilla", worst <= 1 + 1e-9)
check("hotter than a warm room is a warm room (vanilla's for a potato), colder than a fridge is a fridge",
    CROPS.cabbage.keeper.ageRate(35) == 2 / 7 and CROPS.potato.keeper.ageRate(35) == 1 and CROPS.cabbage.keeper.ageRate(-10) == CROPS.cabbage.keeper.ageRate(4))

-- Keeping: a cabbage in a basement
local ledger = CROPS.cabbage.keeper.ledger()
ledger.seasonTemperature, ledger.groundTemperature, ledger.temperature = 5, 5, 5
local cabbage = vegetable("Base.Cabbage", 2, 4, 0.5)
M.keepVegetable(cabbage, 0, "Basement")
check("the first look starts its clock from the age it has", cabbage.modData[M.CELLAR_KEY].base == 0.5)
check("vanilla's days are left alone", cabbage.offAge == 2 and cabbage.offAgeMax == 4)
local basementRate = CROPS.cabbage.keeper.rate("Basement", ledger)
CROPS.cabbage.keeper.recordWeather(240, 5)
cabbage.age = 10   -- vanilla's own clock ran on between looks
M.keepVegetable(cabbage, 240, "Basement")
check("ten days in a basement count as the basement's ten", near(cabbage.age, 0.5 + 10 * basementRate, 1e-3) and cabbage.age < 2)

local cooked = vegetable("Base.Potato", 28, 280, 3)
cooked.cooked = true
check("a cooked potato goes by vanilla's clock", M.keepVegetable(cooked, 240) == nil and cooked.modData[M.CELLAR_KEY] == nil)
check("a vegetable the cellar doesn't keep is left alone", M.keepVegetable(vegetable("Base.Tomato", 3, 5), 240) == nil)
SandboxVars = { TraditionalPreservationFruitVegetables = { CellarByPlace = false } }
check("the sandbox off: vanilla's clock", M.keepVegetable(vegetable("Base.Potato", 28, 280), 240) == nil)
SandboxVars = nil

-- Curing: a potato 7 days at 10 to 20 C
local cureLedger = M.cureLedger()
M.recordCellarWeather(240, 15)   -- every ledger recorded up to now, as the game's ten-minute readings keep them
local potato = vegetable("Base.Potato", 28, 280, 1)
M.keepVegetable(potato, 240, "Sheltered")
check("a new potato starts curing", potato.modData[M.CURING_KEY] ~= nil and not potato.modData[M.CURED])
local hour = 240
local function weather(hours, celsius)
    for _ = 1, hours * 6 do
        hour = hour + 1 / 6
        M.recordCellarWeather(hour, celsius)
    end
end
cureLedger.seasonTemperature = 15
for _, name in ipairs(M.CROP_NAMES) do
    local cropLedger = CROPS[name].keeper.ledger()
    cropLedger.seasonTemperature, cropLedger.groundTemperature = 15, 10
end
weather(6 * 24, 15)
M.keepVegetable(potato, hour, "Sheltered")
check("six days at 15 C: not cured yet", not potato.modData[M.CURED] and near(potato.modData[M.CURING_KEY].age, 144, 0.5))
weather(24, 15)
local ageBefore = potato.age
M.keepVegetable(potato, hour, "Sheltered")
check("the seventh day cures it", potato.modData[M.CURED] == true and potato.modData[M.CURING_KEY] == nil
    and potato.modData[M.CELLAR_KEY] == nil and potato.modData[M.CURED_KEY] ~= nil)
check("its age, brought up to now, carries over to the cured clock",
    potato.age > ageBefore and near(potato.modData[M.CURED_KEY].base, potato.age, 1e-6))
check("the cured keeper keeps it now", M.keeperOf(potato) == CROPS.potato.curedKeeper)

local coldPotato = vegetable("Base.Potato", 28, 280, 0)
M.cureLedger().groundTemperature = 0   -- a winter basement: about 6 C, under the band
M.keepVegetable(coldPotato, hour, "Basement")
weather(14 * 24, 5)
M.keepVegetable(coldPotato, hour, "Basement")
check("a cold basement doesn't cure a potato", not coldPotato.modData[M.CURED])

-- Garlic cures in 14 days in moving air (an aired room or under a roof), slower in the open, never in still air
check("the dry cure by place: covered and an aired room 1, open 0.75, a shut room, basement and fridge 0",
    M.dryCurePlace("Covered") == 1 and M.dryCurePlace("AiredRoom") == 1 and M.dryCurePlace("Open") == 0.75
    and M.dryCurePlace("Sheltered") == 0 and M.dryCurePlace("Basement") == 0 and M.dryCurePlace("Fridge") == 0)
-- A summer spell: every place but the basement above 20 C, where the dry cure runs at full speed.
local function season(celsius)
    local ledger = M.cureLedger()
    ledger.seasonTemperature, ledger.groundTemperature = celsius, celsius
    ledger.threeDayTemperature, ledger.dayTemperature = celsius, celsius
end
season(25)
local garlic = vegetable("Base.Garlic", 14, 28, 0)
M.keepVegetable(garlic, hour, "AiredRoom")
weather(13 * 24, 25)
M.keepVegetable(garlic, hour, "Basement")
check("13 warm days in an aired room: still curing", not garlic.modData[M.CURED] and near(garlic.modData[M.CURING_KEY].age, 13 * 24, 0.5))
weather(17 * 24, 25)
M.keepVegetable(garlic, hour, "Sheltered")
check("17 days in a basement don't count", not garlic.modData[M.CURED])
weather(24, 25)
M.keepVegetable(garlic, hour, "Covered")
check("a day in a shut room counts nothing: still curing", not garlic.modData[M.CURED] and near(garlic.modData[M.CURING_KEY].age, 13 * 24, 0.5))
weather(36, 25)
M.keepVegetable(garlic, hour, "Covered")
check("a day and a half under a roof cures it", garlic.modData[M.CURED] == true)
season(0)
local frozen = vegetable("Base.Garlic", 14, 28, 0)
M.keepVegetable(frozen, hour, "AiredRoom")
weather(14 * 24, 0)
M.keepVegetable(frozen, hour, "AiredRoom")
check("the cold slows it: 14 days in a freezing aired room count a fifth, as Fish & Meat's dry cure",
    not frozen.modData[M.CURED] and frozen.modData[M.CURING_KEY].age < 14 * 24 * 0.3 and frozen.modData[M.CURING_KEY].age > 14 * 24 * 0.15)
check("the dry cure's warmth: a fifth at 4 C and below, full from 20 C", M.CURES.dry.ageing.rate(-5) == 0.2
    and M.CURES.dry.ageing.rate(4) == 0.2 and near(M.CURES.dry.ageing.rate(12), 0.6) and M.CURES.dry.ageing.rate(25) == 1)
season(25)
local onion = vegetable("Base.Onion", 14, 28, 0)
M.keepVegetable(onion, 0, "Fridge")
M.keepVegetable(onion, 20 * 24, "Sheltered")
check("a fridge doesn't cure an onion", not onion.modData[M.CURED])
local drying = vegetable("Base.Onion", 14, 28, 0)
M.keepVegetable(drying, 2000, "AiredRoom")
check("an onion curing in an aired room keeps by the cured days (curing is drying)", M.keeperOf(drying) == CROPS.onion.curedKeeper
    and drying.modData[M.CELLAR_KEY] == nil and not drying.modData[M.CURED])
local shut = vegetable("Base.Onion", 14, 28, 0)
M.keepVegetable(shut, 2000, "Sheltered")
check("one in a shut room doesn't cure: the damp keeper", M.keeperOf(shut) == CROPS.onion.keeper)
M.keepVegetable(drying, 2001, "Basement")
check("taken down to a basement before it is cured: the damp keeper", M.keeperOf(drying) == CROPS.onion.keeper
    and drying.modData[M.CURED_KEY] == nil)
local damp = vegetable("Base.Garlic", 14, 28, 0)
M.keepVegetable(damp, 2000, "Basement")
check("garlic put straight into a basement keeps by the damp days", M.keeperOf(damp) == CROPS.garlic.keeper)
M.keepVegetable(garlic, 1000 + 32.5 * 24, "Basement")
check("cured garlic keeps by the cured days in a basement too", M.keeperOf(garlic) == CROPS.garlic.curedKeeper)
check("cabbages, carrots and leeks don't cure", CROPS.cabbage.cure == nil and CROPS.carrots.cure == nil and CROPS.leek.cure == nil
    and cabbage.modData[M.CURING_KEY] == nil)

-- The storages (user, 2026-11-18): a Drying Pole speeds the dry cure and keeps hung garlic and onions longer; a
-- Vegetable Crate speeds the other cures and keeps every crop but garlic and onions 4/3 as long; the place still decides
local function container(kind, holder)
    return { getType = function() return kind end, getContainingItem = function() return holder end }
end
local crate = container("haycrate")
check("a crate is a storage, and so is a braid on a pole", (function()
    local inCrate = vegetable("Base.Carrots", 6, 8)
    inCrate.container = crate
    local braid = { getContainer = function() return container("dryingpole") end }
    local inBraid = vegetable("Base.Garlic", 14, 28)
    inBraid.container = container("Container", braid)
    return M.storageOf(inCrate) == "hayCrate" and M.storageOf(inBraid) == "pole" and M.storageOf(vegetable("Base.Carrots", 6, 8)) == nil
end)())
check("the sand crate keeps carrots, beets, leeks and turnips a third longer, nothing else, and cures nothing",
    M.storageKeepFactor(CROPS.carrots, "sandCrate") == 0.75 and M.storageKeepFactor(CROPS.sugarBeet, "sandCrate") == 0.75
    and M.storageKeepFactor(CROPS.leek, "sandCrate") == 0.75 and M.storageKeepFactor(CROPS.turnip, "sandCrate") == 0.75
    and M.storageKeepFactor(CROPS.potato, "sandCrate") == 1 and M.storageCureFactor(CROPS.potato, "sandCrate") == 1
    and M.storageOf({ getContainer = function() return container("sandcrate") end }) == "sandCrate")
check("carrots, beets and leeks get no bonus in the hay crate (damp sand was theirs)", M.storageKeepFactor(CROPS.carrots, "hayCrate") == 1
    and M.storageKeepFactor(CROPS.sugarBeet, "hayCrate") == 1 and M.storageKeepFactor(CROPS.leek, "hayCrate") == 1
    and M.storageKeepFactor(CROPS.turnip, "hayCrate") == 0.75)
check("the bonuses: pole 1.5 to garlic's and onions' cure and 0.75 to their keeping; crate 1.5 to the other cures, 0.75 to its crops",
    M.storageKeepFactor(CROPS.cabbage, "hayCrate") == 0.75 and M.storageKeepFactor(CROPS.potato, "hayCrate") == 0.75
    and M.storageKeepFactor(CROPS.garlic, "hayCrate") == 1 and M.storageKeepFactor(CROPS.onion, "hayCrate") == 1
    and M.storageKeepFactor(CROPS.garlic, "pole") == 0.75 and M.storageKeepFactor(CROPS.cabbage, "pole") == 1
    and M.storageCureFactor(CROPS.onion, "pole") == 1.5 and M.storageCureFactor(CROPS.potato, "hayCrate") == 1.5
    and M.storageCureFactor(CROPS.pumpkin, "hayCrate") == 1.5 and M.storageCureFactor(CROPS.potato, "pole") == 1
    and M.storageCureFactor(CROPS.garlic, "hayCrate") == 1)

local function storedPair(fullType, offAge, offAgeMax, storage)
    local loose, stored = vegetable(fullType, offAge, offAgeMax, 0), vegetable(fullType, offAge, offAgeMax, 0)
    stored.container = container(storage)
    return loose, stored
end
local loose, crateTurnip = storedPair("Base.Turnip", 28, 280, "haycrate")
M.keepVegetable(loose, hour, "Basement")
M.keepVegetable(crateTurnip, hour, "Basement")
weather(10 * 24, 5)
M.keepVegetable(loose, hour, "Basement")
M.keepVegetable(crateTurnip, hour, "Basement")
check("ten days in a crate count three quarters of the basement's", loose.age > 0 and near(crateTurnip.age, loose.age * 0.75, 1e-6))

season(25)
local hung, poled = storedPair("Base.Onion", 14, 28, "dryingpole")
local roomPoled = select(2, storedPair("Base.Onion", 14, 28, "dryingpole"))
M.keepVegetable(hung, hour, "Covered")
M.keepVegetable(poled, hour, "Covered")
M.keepVegetable(roomPoled, hour, "Sheltered")
weather(6 * 24, 25)
M.keepVegetable(hung, hour, "Covered")
M.keepVegetable(poled, hour, "Covered")
check("an onion on the pole cures half again as fast", near(poled.modData[M.CURING_KEY].age, 1.5 * hung.modData[M.CURING_KEY].age))
weather(4 * 24, 25)
M.keepVegetable(poled, hour, "Covered")
M.keepVegetable(hung, hour, "Covered")
check("on the pole under a roof it is cured in 10 days, loose it isn't", poled.modData[M.CURED] == true and not hung.modData[M.CURED])
weather(5 * 24, 25)
M.keepVegetable(roomPoled, hour, "Sheltered")
check("on the pole in a shut room: 15 days do nothing (still air)", not roomPoled.modData[M.CURED]
    and near(roomPoled.modData[M.CURING_KEY].age, 0, 1e-6))

local spread, cratePotato = storedPair("Base.Potato", 28, 280, "haycrate")
M.cureLedger().groundTemperature, M.cureLedger().seasonTemperature = 15, 15   -- a mild autumn room, after the cold crate test
M.cureLedger().threeDayTemperature, M.cureLedger().dayTemperature = 15, 15
M.keepVegetable(spread, hour, "Sheltered")
M.keepVegetable(cratePotato, hour, "Sheltered")
weather(5 * 24, 15)
M.keepVegetable(spread, hour, "Sheltered")
M.keepVegetable(cratePotato, hour, "Sheltered")
check("five days at 15 C in the crate cure a potato, not on a shelf", cratePotato.modData[M.CURED] == true and not spread.modData[M.CURED])

-- By a fire (user, 2026-11-18: kept food reads the fire places): TP Core's Fire.placeOf says where the holder stands,
-- each look notes the fire's fuel. By a lit fire the dry cure's air is a porch's; banked embers keep the room's.
local Fire = require "TraditionalPreservationCore/Fire"
local Weather = require "TraditionalPreservationCore/Weather"
check("the dry cure's air by a fire: lit 1, embers the room's, under a roof or in the open that place's",
    M.dryCurePlace(Fire.PLACE) == 1 and M.dryCurePlace(Fire.EMBERS, "Sheltered") == 0
    and M.dryCurePlace(Fire.EMBERS .. "AiredRoom") == 1
    and M.dryCurePlace(Fire.EMBERS, "Basement") == 0 and M.dryCurePlace(Fire.EMBERS .. "Covered") == 1
    and M.dryCurePlace(Fire.PLACE .. "Open") == 0.75)
local placeOf, fuelHours, weatherPlaceOf = Fire.placeOf, Fire.fuelHours, Weather.placeOf
local firePlace, fuel = Fire.PLACE, 1e9
Fire.placeOf = function() return firePlace, {} end
Fire.fuelHours = function() return fuel end
Weather.placeOf = function() return "Sheltered" end
local function byTheFire(fullType, offAge, offAgeMax)
    local item = vegetable(fullType, offAge, offAgeMax, 0)
    local holder = { getSquare = function() return {} end }
    function item:getWorldItem() return holder end
    return item
end
M.cureLedger().groundTemperature, M.cureLedger().seasonTemperature = 15, 15   -- an October room, under the hot cure's 20 C
M.cureLedger().threeDayTemperature, M.cureLedger().dayTemperature = 15, 15
local stoveSweet, roomSweet = byTheFire("Base.SweetPotato", 28, 280), vegetable("Base.SweetPotato", 28, 280, 0)
local stovePotato = byTheFire("Base.Potato", 28, 280)
for _, item in ipairs({ stoveSweet, stovePotato }) do M.keepVegetable(item, hour) end
M.keepVegetable(roomSweet, hour, "Sheltered")
check("a vegetable by a fire takes the fire's place and its fuel", stoveSweet.modData[M.CELLAR_KEY].fluidAge.place == Fire.PLACE
    and stoveSweet.modData[M.CURING_KEY].fireUntil == hour + fuel)
weather(7 * 24 + 1, 15)   -- an hour over: the test's ten-minute steps fall a hair short of 168
for _, item in ipairs({ stoveSweet, stovePotato }) do M.keepVegetable(item, hour) end
M.keepVegetable(roomSweet, hour, "Sheltered")
check("an October sweet potato by the stove cures in its 7 days; in the room it doesn't",
    stoveSweet.modData[M.CURED] == true and not roomSweet.modData[M.CURED])
check("a potato by the stove doesn't: 28 C is over its cool cure", not stovePotato.modData[M.CURED])
check("by the fire it keeps as in a warm room (the curves stop at 22 C)",
    near(CROPS.potato.keeper.rate(Fire.PLACE, CROPS.potato.keeper.ledger()), CROPS.potato.keeper.ageRate(22)))

season(25)
local stoveOnion, embersOnion, outOnion = byTheFire("Base.Onion", 14, 28), byTheFire("Base.Onion", 14, 28), byTheFire("Base.Onion", 14, 28)
M.keepVegetable(stoveOnion, hour)
firePlace = Fire.EMBERS
M.keepVegetable(embersOnion, hour)
fuel = 3.5 * 24
firePlace = Fire.PLACE
M.keepVegetable(outOnion, hour)
weather(7 * 24, 25)
firePlace = "Sheltered"
for _, item in ipairs({ stoveOnion, embersOnion, outOnion }) do M.keepVegetable(item, hour) end
check("a week by a lit fire dries an onion as a porch (the fire draws air); by embers as the shut room, not at all",
    near(stoveOnion.modData[M.CURING_KEY].age, 7 * 24, 0.5) and near(embersOnion.modData[M.CURING_KEY].age, 0, 0.5))
check("a fire out half way: the porch's air half the week, the shut room's still air the other half",
    near(outOnion.modData[M.CURING_KEY].age, 0.5 * 7 * 24, 0.5))
Fire.placeOf, Fire.fuelHours, Weather.placeOf = placeOf, fuelHours, weatherPlaceOf

-- Frost (user, session 76): each crop freezes at its own point; an hour at or below it costs 1/12 of its life up to
-- rotten, a hay crate halves the hours, a basement never freezes, the sandbox can turn it off.
local Frost = require "TraditionalPreservationCore/Frost"
check("the freezing points: potatoes, sweet potatoes, pumpkins -1 C; carrots, beets, turnips -1.5; cabbage -3; garlic, onion -3.5; leek -10",
    CROPS.potato.freezeC == -1 and CROPS.sweetPotato.freezeC == -1 and CROPS.pumpkin.freezeC == -1
    and CROPS.carrots.freezeC == -1.5 and CROPS.sugarBeet.freezeC == -1.5 and CROPS.turnip.freezeC == -1.5
    and CROPS.cabbage.freezeC == -3 and CROPS.garlic.freezeC == -3.5 and CROPS.onion.freezeC == -3.5 and CROPS.leek.freezeC == -10)
local function frostWeather(hours, celsius)
    for _ = 1, hours * 6 do
        hour = hour + 1 / 6
        M.recordCellarWeather(hour, celsius)
        Frost.recordWeather(hour, celsius)
    end
end
frostWeather(1, 5)
local openPotato, cellarPotato, leekOut = vegetable("Base.Potato", 28, 42, 1), vegetable("Base.Potato", 28, 42, 1), vegetable("Base.Leek", 5, 8, 1)
local hayPotato, offPotato = vegetable("Base.Potato", 28, 42, 1), vegetable("Base.Potato", 28, 42, 1)
hayPotato.container = crate
for _, item in ipairs({ openPotato, leekOut, hayPotato, offPotato }) do M.keepVegetable(item, hour, "Open") end
M.keepVegetable(cellarPotato, hour, "Basement")
check("the first look starts a frost record", openPotato.modData[M.FROST_KEY] ~= nil and openPotato.modData[M.FROST_KEY].age == 0)
local function keptAge(item)
    local clock = item.modData[M.keeperOf(item).keepingRules.modDataKey]
    return clock.base + clock.fluidAge.age / 24
end
local before = {}
for _, item in ipairs({ openPotato, cellarPotato, leekOut, hayPotato, offPotato }) do before[item] = item.age end
frostWeather(3, -5)
SandboxVars = { TraditionalPreservationFruitVegetables = { FrostDamage = false } }
M.keepVegetable(offPotato, hour, "Open")
SandboxVars = nil
local keepingOnly = offPotato.age - before[offPotato]
for _, item in ipairs({ openPotato, leekOut, hayPotato }) do M.keepVegetable(item, hour, "Open") end
M.keepVegetable(cellarPotato, hour, "Basement")
check("three hours at -5 C in the open cost a potato a quarter of its life to rotten (42 days: 10.5)",
    near(openPotato.age - before[openPotato], keepingOnly + 3 / 12 * 42, 0.05))
check("in a hay crate half of that", near(hayPotato.age - before[hayPotato], keepingOnly * 0.75 + 1.5 / 12 * 42, 0.05))
check("a leek takes no harm at -5 C", leekOut.age - before[leekOut] < 0.5)
check("a basement never freezes", cellarPotato.age - before[cellarPotato] < 0.5)
check("the sandbox off: frost does no harm, but the record goes on", keepingOnly < 0.5 and offPotato.modData[M.FROST_KEY].age > 2.9)
check("the keeping clock carries the frost, so the next look keeps it", near(keptAge(openPotato), openPotato.age, 1e-6))
frostWeather(24, -5)
M.keepVegetable(openPotato, hour, "Open")
check("a day of frost: rotten, and no older than that", near(openPotato.age, 42, 1e-6))

H.done()
