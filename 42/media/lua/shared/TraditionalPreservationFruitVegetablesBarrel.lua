-- Traditional Preservation (Fruits and Vegetables) B42: the kraut barrel. One batch at a time, of cabbages, turnips or
-- any mix of the two (one ferment, as a real barrel). Heads are packed in (Pack), with apples and carrots if wanted, up
-- to one of each per five heads; until it is salted and compressed everything can come back out (Unpack). Salt and
-- Compress needs at least BARREL_MIN heads, a use of salt per five heads, a cloth, a board and a flat stone: it seals
-- the barrel and the ferment starts, and nothing more goes in. The ferment runs by the temperature where the barrel stands (Core's
-- places, by a fire too): FERMENT_HOURS at 18 C, slower when cool down to a stop at 0 C, faster when warm. Too warm
-- spoils it: HOT_SOFT_HOURS above HOT_C before it is ready leave it soft (it keeps 2/3 as long), HOT_SPOIL_HOURS
-- spoil it. The kraut carries no mood of its own: it is a way of keeping cabbage, not a treat (user, 2026-11-18).
-- Ready kraut stays in the barrel and keeps by place (KEEP_DAYS in an 8 C cellar) and is taken out a portion at a
-- time, one a head (a cabbage's as Sauerkraut, a turnip's as Sauer Turnip), each with its own kind's food and the
-- apples and carrots shared out over all the heads. The last
-- portion, or emptying a spoiled barrel, gives the board and stone back (the cloth is used up). Out of the barrel a
-- portion keeps by vanilla's clock; frozen through (TP Core's Frost, KRAUT_FREEZE_C) it goes soft: the days it has
-- left count 2/3 (user, session 76). Required by TraditionalPreservationFruitVegetables.lua.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Station = require "TraditionalPreservationCore/Station"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Frost = require "TraditionalPreservationCore/Frost"

M.BARREL_KEY = "tpfvBarrel"   -- the barrel's record in its movableData; never rename once the mod is out
M.BARREL_MIN, M.BARREL_MAX = 20, 60   -- 20 (user, 2026-11-18: the long seal makes bigger barrels pay anyway)
M.HEADS_PER_SALT = 5
M.HEADS_PER_EXTRA = 5         -- one apple and one carrot at most per five heads
M.FERMENT_HOURS = 28 * 24     -- at 18 C; the sandbox's Ferment days
M.HOT_C = 27
M.HOT_SOFT_HOURS = 48
M.HOT_SPOIL_HOURS = 5 * 24
M.KEEP_DAYS = 180             -- ready kraut in an 8 C cellar
M.PORTION_DAYS = { 14, 28 }   -- a portion out of the barrel, fresh and rotten; it comes out as far into its fresh
                              -- days as the barrel is into KEEP_DAYS
M.SOFT_KEEP = 1.5             -- a soft batch's keeping counts half again: it keeps 2/3 as long (user, 2026-11-18)
-- A portion out of the barrel: salt and acid keep it liquid below water's 0 C. Item modData: its frost record, and soft.
M.KRAUT_FREEZE_C = -3
M.KRAUT_FROST_KEY = "tpfvKrautFrost"
M.KRAUT_SOFT_KEY = "tpfvKrautSoft"
M.PACK_XP = 1                 -- Cooking, a piece packed, paid when the barrel is salted and compressed
M.COMPRESS_XP = 10            -- Cooking, salting and compressing a barrel

M.KRAUT_KINDS = { "cabbage", "turnip" }
M.KRAUTS = {
    cabbage = { head = "Base.Cabbage", product = "TraditionalPreservationFruitVegetables.Sauerkraut" },
    turnip = { head = "Base.Turnip", product = "TraditionalPreservationFruitVegetables.SauerTurnip" },
}
M.EXTRAS = { apple = "Base.Apple", carrot = "Base.Carrots" }
M.KRAUT_OF_HEAD = {}
for kind, kraut in pairs(M.KRAUTS) do M.KRAUT_OF_HEAD[kraut.head] = kind end
M.KRAUT_OF_PRODUCT = {}
for kind, kraut in pairs(M.KRAUTS) do M.KRAUT_OF_PRODUCT[kraut.product] = kind end
M.KRAUT_FROST = Frost.point(M.KRAUT_FREEZE_C)
M.EXTRA_OF_TYPE = {}
for extra, fullType in pairs(M.EXTRAS) do M.EXTRA_OF_TYPE[fullType] = extra end
M.CLOTHS = { ["Base.RippedSheets"] = true, ["Base.BurlapPiece"] = true, ["Base.CheeseCloth"] = true }
M.BOARD = "Base.Plank"      -- back with the stone once the barrel is empty
M.STONE = "Base.FlatStone"

-- Rates. The ferment: days at 4, 8, 13, 18, 21 and 24 C are 120, 60, 40, 28, 21 and 16; slower still towards 0 C,
-- where it stops (user, 2026-11-18: winter kraut sours slowly in the cold); warmer than 24 C as 24 C. A share of
-- FERMENT_HOURS an hour.
local FERMENT_CURVE = { { 0, 0 }, { 4, 28 / 120 }, { 8, 28 / 60 }, { 13, 28 / 40 }, { 18, 1 }, { 21, 28 / 21 }, { 24, 28 / 16 } }
-- Too warm: an hour above HOT_C counts one.
local HOT_CURVE = { { M.HOT_C, 0 }, { M.HOT_C + 0.5, 1 } }
-- Keeping, days of age a day: a cellar's 8 C one, a fridge's 4 C 0.75 (about 8 months), a cool room 2 (3 months), a
-- warm room 6 (a month), frozen nothing.
local KEEP_CURVE = { { -2, 0 }, { 4, 0.75 }, { 8, 1 }, { 15, 2 }, { 22, 6 }, { 28, 9 } }

function M.fermentRate(celsius)
    if M.SENSITIVITY == 0 then return 1 end
    return math.max(Weather.scaled(Weather.curve(FERMENT_CURVE, celsius), M.SENSITIVITY, 0), 0)
end

-- Off: never too warm.
function M.hotRate(celsius)
    if M.SENSITIVITY == 0 then return 0 end
    return Weather.curve(HOT_CURVE, celsius)
end

function M.keepRate(celsius)
    if M.SENSITIVITY == 0 then return 1 end
    return Weather.curve(KEEP_CURVE, celsius)
end

M.PROCESSES.ferment = function(celsius) return M.fermentRate(celsius) end
M.PROCESSES.hot = function(celsius) return M.hotRate(celsius) end
M.PROCESSES.keep = function(celsius) return M.keepRate(celsius) end

-- Days a batch takes to be ready at a temperature (nil: it doesn't work there).
function M.fermentDays(celsius)
    local rate = M.fermentRate(celsius)
    return rate > 0 and M.FERMENT_HOURS / rate / 24 or nil
end

-- Empty, Packing, Fermenting, Ready or Spoiled.
function M.barrelStage(barrel)
    return barrel.stage or "Empty"
end

-- Heads in a packing barrel, of one kind or (kind nil) all; a compressed one's portions are counted by M.portionsLeft.
function M.headCount(barrel, kind)
    local count = 0
    for _, head in ipairs(barrel.heads or {}) do
        if not kind or head.kind == kind then count = count + 1 end
    end
    if not barrel.heads and barrel.headCounts then
        for headKind, n in pairs(barrel.headCounts) do
            if not kind or headKind == kind then count = count + n end
        end
    end
    return count
end

-- Portions still in a ready barrel, of one kind or (kind nil) all.
function M.portionsLeft(barrel, kind)
    local count = 0
    for portionKind, n in pairs(barrel.portions or {}) do
        if not kind or portionKind == kind then count = count + n end
    end
    return count
end

function M.extraCount(barrel, extra)
    local list = barrel.extras and barrel.extras[extra]
    return list and #list or 0
end

function M.saltNeeded(heads)
    return math.ceil(heads / M.HEADS_PER_SALT)
end

-- How many of an extra the heads allow.
function M.extraRoom(heads)
    return math.floor(heads / M.HEADS_PER_EXTRA)
end

-- Why a head can't go in ("Sealed", "Full"), or nil. Cabbages and turnips mix.
function M.packRefusal(barrel)
    local stage = M.barrelStage(barrel)
    if stage ~= "Empty" and stage ~= "Packing" then return "Sealed" end
    if M.headCount(barrel) >= M.BARREL_MAX then return "Full" end
end

-- Why an apple or a carrot can't go in ("Sealed", "NoHeads", "TooMany"), or nil.
function M.extraRefusal(barrel, extra)
    if M.barrelStage(barrel) ~= "Packing" then return M.barrelStage(barrel) == "Empty" and "NoHeads" or "Sealed" end
    if M.extraCount(barrel, extra) >= M.extraRoom(M.headCount(barrel)) then return "TooMany" end
end

-- Why it can't be salted and compressed ("Sealed", "TooFew", "NoSalt", "NoCloth", "NoBoard", "NoStone"), or nil. have: what
-- the player has in reach { salt = uses, cloth, board, stone = true/false }.
function M.compressRefusal(barrel, have)
    local stage = M.barrelStage(barrel)
    if stage ~= "Packing" and stage ~= "Empty" then return "Sealed" end
    local heads = M.headCount(barrel)
    if heads < M.BARREL_MIN then return "TooFew" end
    if (have.salt or 0) < M.saltNeeded(heads) then return "NoSalt" end
    if not have.cloth then return "NoCloth" end
    if not have.board then return "NoBoard" end
    if not have.stone then return "NoStone" end
end

-- A packed piece as kept: its age, the hour it went in and its food. food: { hunger, calories, carbs, proteins, lipids }.
-- Until the barrel is salted and compressed a piece ages as it would lying out (vanilla's pace, Food Spoilage
-- included), so an unsealed barrel is no cold store: Unpack gives it back that much older.
function M.pack(barrel, kind, age, food, hour)
    barrel.stage = "Packing"
    barrel.heads = barrel.heads or {}
    table.insert(barrel.heads, { kind = kind, age = age, hour = hour, food = food })
end

function M.packExtra(barrel, extra, age, food, hour)
    barrel.extras = barrel.extras or {}
    barrel.extras[extra] = barrel.extras[extra] or {}
    table.insert(barrel.extras[extra], { age = age, hour = hour, food = food })
end

-- A packed piece's age now: what it had, plus the days since it went in at vanilla's pace.
function M.packedAge(piece, now)
    if not piece.hour or not now then return piece.age end
    return piece.age + math.max(now - piece.hour, 0) / 24 * FluidAgeing.foodRotSpeed()
end

local function clear(barrel)
    for key in pairs(barrel) do barrel[key] = nil end
end

-- Everything packed comes back out at its age now: { { fullType, age } ... }, the barrel empty again. Only before it
-- is salted and compressed.
function M.unpack(barrel, now)
    if M.barrelStage(barrel) ~= "Packing" then return {} end
    local back = {}
    for _, head in ipairs(barrel.heads or {}) do
        table.insert(back, { fullType = M.KRAUTS[head.kind].head, age = M.packedAge(head, now) })
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        for _, piece in ipairs((barrel.extras or {})[extra] or {}) do
            table.insert(back, { fullType = M.EXTRAS[extra], age = M.packedAge(piece, now) })
        end
    end
    clear(barrel)
    return back
end

local FOOD_FIELDS = { "hunger", "calories", "carbs", "proteins", "lipids" }

-- One portion's food for a kind: its own heads' food a head, plus the apples and carrots shared out over every head.
-- Nil for a kind not packed.
function M.portionOf(barrel, kind)
    local heads, ofKind = M.headCount(barrel), M.headCount(barrel, kind)
    if ofKind == 0 then return nil end
    local portion = {}
    for _, field in ipairs(FOOD_FIELDS) do portion[field] = 0 end
    local function add(piece, share)
        for _, field in ipairs(FOOD_FIELDS) do portion[field] = portion[field] + (piece.food[field] or 0) * share end
    end
    for _, head in ipairs(barrel.heads or {}) do
        if head.kind == kind then add(head, 1 / ofKind) end
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        for _, piece in ipairs((barrel.extras or {})[extra] or {}) do add(piece, 1 / heads) end
    end
    return portion
end

-- Seals a packed barrel and starts the ferment: what was packed becomes its portions.
function M.compress(barrel, ledger)
    barrel.portion, barrel.portions, barrel.headCounts = {}, {}, {}
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local count = M.headCount(barrel, kind)
        if count > 0 then
            barrel.portion[kind] = M.portionOf(barrel, kind)
            barrel.portions[kind] = count
            barrel.headCounts[kind] = count
        end
    end
    barrel.apples = M.extraCount(barrel, "apple")
    barrel.carrots = M.extraCount(barrel, "carrot")
    barrel.heads, barrel.extras = nil, nil
    barrel.stage = "Fermenting"
    barrel.workHours, barrel.hotHours, barrel.soft = 0, 0, nil
    barrel.marks = Weather.mark({}, ledger, "ferment")
    barrel.hotMarks = Weather.mark({}, ledger, "hot")
end

-- Brings a barrel up to now at place: the ferment and the hours too warm while it ferments, then its keeping once ready.
function M.updateBarrel(barrel, ledger, place)
    local stage = M.barrelStage(barrel)
    if stage == "Fermenting" then
        barrel.workHours = barrel.workHours + Fire.catchUp(barrel, barrel.marks, ledger, "ferment", place, M.fermentRate)
        barrel.hotHours = barrel.hotHours + Fire.catchUp(barrel, barrel.hotMarks, ledger, "hot", place, M.hotRate)
        if barrel.hotHours >= M.HOT_SPOIL_HOURS then
            barrel.stage = "Spoiled"
        elseif barrel.workHours >= M.FERMENT_HOURS then
            barrel.stage = "Ready"
            barrel.soft = barrel.hotHours >= M.HOT_SOFT_HOURS or nil
            barrel.keepDays = 0
            barrel.keepMarks = Weather.mark({}, ledger, "keep")
        end
    elseif stage == "Ready" then
        barrel.keepDays = barrel.keepDays
            + Fire.catchUp(barrel, barrel.keepMarks, ledger, "keep", place, M.keepRate) / 24 * M.keepFactor(barrel)
        if barrel.keepDays >= M.KEEP_DAYS then barrel.stage = "Spoiled" end
    end
end

-- How much faster than by KEEP_DAYS a ready barrel's keeping runs: SOFT_KEEP when soft.
function M.keepFactor(barrel)
    return barrel.soft and M.SOFT_KEEP or 1
end

-- How the barrel is doing at place: progress (of the ferment, or of its keeping), the rate there, hours left to
-- ready (nil when stalled), days left to keep, the hours it has been too warm.
function M.barrelStatus(barrel, ledger, place)
    local temperature = M.placeTemperatureAt(ledger, place)
    local stage = M.barrelStage(barrel)
    local status = { place = place, temperature = temperature, stage = stage }
    if stage == "Fermenting" then
        status.rate = M.fermentRate(temperature)
        status.progress = math.min(barrel.workHours / M.FERMENT_HOURS, 1)
        status.hoursLeft = status.rate > 0 and (M.FERMENT_HOURS - barrel.workHours) / status.rate or nil
        status.hotHours = barrel.hotHours
    elseif stage == "Ready" then
        status.rate = M.keepRate(temperature) * M.keepFactor(barrel)
        status.progress = math.min(barrel.keepDays / M.KEEP_DAYS, 1)
        status.daysLeft = status.rate > 0 and (M.KEEP_DAYS - barrel.keepDays) / status.rate or nil
    end
    return status
end

-- A place's temperature, a fire's places included.
function M.placeTemperatureAt(ledger, place)
    if Fire.isFirePlace(place) then return Fire.fireC(place, ledger) end
    return Weather.placeTemperature(ledger, place)
end

-- Takes one portion of a kind out of a ready barrel: { portion, kind, ageShare (of its fresh days), soft, last }, or
-- nil. The last one of all empties the barrel.
function M.takePortion(barrel, kind)
    if M.barrelStage(barrel) ~= "Ready" or M.portionsLeft(barrel, kind) <= 0 then return nil end
    local taken = { portion = barrel.portion[kind], kind = kind, soft = barrel.soft == true,
        ageShare = math.min(barrel.keepDays / M.KEEP_DAYS, 1) }
    barrel.portions[kind] = barrel.portions[kind] - 1
    if M.portionsLeft(barrel) <= 0 then
        taken.last = true
        clear(barrel)
    end
    return taken
end

-- Empties a spoiled barrel. Returns true if it was spoiled.
function M.emptySpoiled(barrel)
    if M.barrelStage(barrel) ~= "Spoiled" then return false end
    clear(barrel)
    return true
end

-- Engine side

function M.barrelOf(station)
    local modData = Station.movableData(station)
    modData[M.BARREL_KEY] = modData[M.BARREL_KEY] or {}
    return modData[M.BARREL_KEY]
end

-- A food's own values, as the barrel keeps them.
function M.foodOf(item)
    return { hunger = item:getHungChange(), calories = item:getCalories(), carbs = item:getCarbohydrates(),
        proteins = item:getProteins(), lipids = item:getLipids() }
end

-- Sets a taken portion's food and age on a new Sauerkraut or Sauer Turnip.
function M.applyPortion(item, taken)
    local portion = taken.portion
    item:setBaseHunger(portion.hunger)
    item:setHungChange(portion.hunger)
    item:setCalories(portion.calories)
    item:setCarbohydrates(portion.carbs)
    item:setProteins(portion.proteins)
    item:setLipids(portion.lipids)
    item:setOffAge(M.PORTION_DAYS[1])
    item:setOffAgeMax(M.PORTION_DAYS[2])
    item:setAge(taken.ageShare * M.PORTION_DAYS[1])
end

-- Turns a portion soft: the days it has left to stale and to rotten count 2/3 (the barrel's SOFT_KEEP), once.
function M.softenKraut(item)
    local itemModData = item:getModData()
    if itemModData[M.KRAUT_SOFT_KEY] then return false end
    itemModData[M.KRAUT_SOFT_KEY] = true
    local age = item:getAge()
    item:setOffAge(age + math.max(item:getOffAge() - age, 0) / M.SOFT_KEEP)
    item:setOffAgeMax(age + math.max(item:getOffAgeMax() - age, 0) / M.SOFT_KEEP)
    return true
end

-- Brings a portion's frost up to now at the place it was seen in last, and counts from where it is now (place, or
-- where the item is); frozen through, it goes soft. Its keeping stays vanilla's. Returns its frost record, or nil for
-- anything else and for cooked or burnt kraut (vanilla's clock, as cooked vegetables).
function M.keepKraut(item, now, place)
    if not M.KRAUT_OF_PRODUCT[item:getFullType()] or item:isCooked() or item:isBurnt() then return nil end
    now = now or getGameTime():getWorldAgeHours()
    local fire, holder
    if not place then place, fire, holder = FluidAgeing.placeOfItem(item) end
    local itemModData = item:getModData()
    local record = itemModData[M.KRAUT_FROST_KEY]
    place = place or (record and record.place) or Weather.DEFAULT_PLACE
    if not record then
        record = Frost.newRecord(M.KRAUT_FROST, now, place)
        itemModData[M.KRAUT_FROST_KEY] = record
    else
        local hours = Frost.catchUp(record, M.KRAUT_FROST, now, place, record)
        if Frost.frozenThrough(record, hours) and M.frostDamage() then M.softenKraut(item) end
    end
    if holder then FluidAgeing.noteFire(record, fire, holder, now) end
    return record
end
