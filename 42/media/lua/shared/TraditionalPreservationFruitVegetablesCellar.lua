-- Traditional Preservation (Fruits and Vegetables) B42: the root cellar. Vanilla vegetables keep by place on TP Core's
-- PlaceKeeping, as butter and Potted Meat do: every Potato, Turnip, Sugar Beet, Carrot, Cabbage, Leek, Garlic, Onion,
-- Sweet Potato and Pumpkin, found or grown. Each crop has its days fresh at four temperatures (a warm room 22 C, a cool
-- room 15 C, a basement about 8 C, a fridge's 4 C); vanilla's own days are the warm room's (a cabbage's 7, not
-- vanilla's 2), and no place keeps worse than vanilla does (a powered fridge never worse than vanilla's fridge at its
-- default 0.2). A day counts as vanilla's days fresh over the place's days fresh, joined by straight lines between the
-- four; colder than 4 C counts as 4 C, warmer than 22 C as 22 C. Rotten follows at vanilla's own ratio. Cooked or
-- burnt vegetables go by vanilla's clock.
-- Frost (M.FROST): each crop freezes at its own point (TP Core's Frost, by place); every hour at or below it costs
-- 1/FROST_RUIN_HOURS of its life up to rotten, so half a day of frost ruins it. A basement never freezes, nor a place
-- by a lit fire or banked embers; a powered fridge or freezer keeps vanilla's rules; a Vegetable Crate (Hay) halves
-- the hours.
-- Curing is the first part of keeping, not a recipe (M.CURES): a potato cures in 7 days at 10 to 20 C, a sweet potato
-- in 7 and a pumpkin in 10 at 20 to 32 C (counted on a ledger, so unloaded time counts); a cured one keeps longer
-- everywhere after (its curedShare). Garlic and onion cure in 14 days in moving air from 20 C, slower when cooler,
-- in the open or in a closed room, never in a basement, a fridge or a freezer (M.CURES.dry); they keep by their cured days while they cure
-- somewhere dry, and once cured keep them in a damp place too. The Drying Pole and the Vegetable Crates (STORAGE_BONUS, below) speed curing or slow keeping on top
-- of the place. Places by a fire count as TP Core's (by a fire 28 C, banked embers 24 C): a sweet potato or pumpkin
-- by the stove cures in autumn, as real growers did. Required by TraditionalPreservationFruitVegetables.lua, whose M it adds to.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Frost = require "TraditionalPreservationCore/Frost"

M.CELLAR_TEMPERATURES = { 4, 8, 15, 22 }
-- Vanilla's fridge, at the sandbox's default Fridge Effectiveness: a day counts as 0.2.
M.VANILLA_FRIDGE_RATE = 0.2

-- Days fresh at 4, 8, 15 and 22 C; vanilla is its script's DaysFresh (22 C uses it). cured: the cured crop's days.
-- Never rename a crop's key once the mod is out: its ledger and the item's clock are named after it.
M.CROPS = {
    potato = { fullType = "Base.Potato", vanilla = 28, days = { 140, 150, 60, 28 }, cure = "warm",
        curedShare = 150 / 210, freezeC = -1 },
    turnip = { fullType = "Base.Turnip", vanilla = 28, days = { 140, 120, 28, 28 }, freezeC = -1.5 },
    sugarBeet = { fullType = "Base.SugarBeet", vanilla = 4, days = { 120, 120, 14, 4 }, freezeC = -1.5 },
    carrots = { fullType = "Base.Carrots", vanilla = 6, days = { 120, 120, 14, 6 }, freezeC = -1.5 },
    cabbage = { fullType = "Base.Cabbage", vanilla = 2, days = { 90, 90, 14, 7 }, freezeC = -3 },
    -- A leek stands in the field all winter.
    leek = { fullType = "Base.Leek", vanilla = 5, days = { 60, 60, 10, 5 }, freezeC = -10 },
    -- Cured garlic sprouts at 4 to 10 C and moulds in a fridge's damp (vanilla's fridge floor, 70), but near 0 C and
    -- dry, a winter attic, it keeps longest (curedAtZero: days at 0 C, a point below the 4 C one).
    garlic = { fullType = "Base.Garlic", vanilla = 14, days = { 70, 30, 28, 14 }, cure = "dry",
        cured = { 70, 60, 180, 90 }, curedAtZero = 210, freezeC = -3.5 },
    onion = { fullType = "Base.Onion", vanilla = 14, days = { 70, 30, 28, 14 }, cure = "dry",
        cured = { 180, 60, 180, 90 }, freezeC = -3.5 },
    -- Hot cured (user, 2026-11-18: "pumpkins and sweet potatoes too"); my picks: chilled below 10 C, a sweet potato
    -- keeps best at 13 to 15 C, a pumpkin rots in a damp cellar; cured, both keep twice as long.
    -- A sweet potato is chilled below 10 C (a hard, rotting core within weeks): a cold basement is the wrong place
    -- even cured. A cured pumpkin keeps 2 months in a warm room (user, 2026-11-18).
    sweetPotato = { fullType = "Base.SweetPotato", vanilla = 28, days = { 140, 30, 120, 28 }, cure = "hot",
        cureHours = 7 * 24, cured = { 140, 45, 240, 56 }, freezeC = -1 },
    pumpkin = { fullType = "Base.Pumpkin", vanilla = 14, days = { 70, 30, 45, 30 }, cure = "hot",
        cureHours = 10 * 24, curedShare = 0.5, freezeC = -1 },
}
M.CROP_NAMES = {}
for name in pairs(M.CROPS) do table.insert(M.CROP_NAMES, name) end
table.sort(M.CROP_NAMES)

-- How each kind cures: hours of good keeping it needs. warm: hours at 10 to 20 C (a ledger process, so it counts
-- while unloaded); dry: hours anywhere but a basement, fridge or freezer.
M.CURES = {
    warm = { hours = 7 * 24, curve = { { 9, 0 }, { 10, 1 }, { 20, 1 }, { 21, 0 } } },
    -- Warm and close: the real ideal is 27 to 30 C, but a Kentucky room at harvest is 20 to 22 (my pick).
    hot = { hours = 10 * 24, curve = { { 19, 0 }, { 20, 1 }, { 32, 1 }, { 33, 0 } } },
    -- Dried by moving air (user, 2026-11-18: a shut room has none): how much an hour counts by place. A porch or open
    -- shed (Covered) and a room with a window open (AiredRoom, often upstairs) are the classic spots; the open air sets
    -- it back with sun and rain; a shut room, a basement, a fridge or a freezer, too still, damp or cold, not at all.
    -- And by the warmth, as Fish & Meat's dry cure (user): full from 20 C (the real ideal is 24 to 30), a straight line
    -- down to a fifth at 4 C and below (frozen bulbs still dry, slowly). Counted on the ledger, by place, times places.
    -- By a lit fire indoors as a porch (user, 2026-11-18: the fire draws air through the room); banked embers draw
    -- next to none, so there, and by any fire under a roof or in the open, it is the air of the place under it.
    dry = { hours = 14 * 24, curve = { { 4, 0.2 }, { 20, 1 } },
        places = { Covered = 1, AiredRoom = 1, Open = 0.75, Sheltered = 0, Basement = 0,
        [FluidAgeing.FRIDGE] = 0, [FluidAgeing.FREEZER] = 0, [Fire.PLACE] = 1 } },
}
-- Item modData keys, kept: the crop's clock (one per crop and state), the cure's progress, and cured.
M.CELLAR_KEY = "tpfvKeep"
M.CURED_KEY = "tpfvKeepCured"
M.CURING_KEY = "tpfvCuring"
M.CURED = "tpfvCured"
M.CELLAR_LEDGER_KEY = "TraditionalPreservationFruitVegetablesCellar"
-- Item modData: the crop's frost record (TP Core's Frost), kept.
M.FROST_KEY = "tpfvFrost"
-- Hours at or below its freezing point that take a crop from where it is to rotten (user, session 76).
M.FROST_RUIN_HOURS = 12

-- The sandbox's "Vegetables keep by place"; off, vegetables keep as vanilla's.
function M.cellarByPlace()
    local options = SandboxVars and SandboxVars.TraditionalPreservationFruitVegetables
    return not options or options.CellarByPlace ~= false
end

-- The sandbox's "Vegetables freeze"; off, frost does them no harm. It works through the keeping by place.
function M.frostDamage()
    local options = SandboxVars and SandboxVars.TraditionalPreservationFruitVegetables
    return not options or options.FrostDamage ~= false
end

-- A curve of days of vanilla age a day counts as, from days fresh at M.CELLAR_TEMPERATURES. Never faster than
-- vanilla, nor than vanilla's fridge at 4 C.
function M.cellarCurve(vanilla, days)
    local curve = {}
    for index, celsius in ipairs(M.CELLAR_TEMPERATURES) do
        local rate = math.min(vanilla / days[index], 1)
        if index == 1 then rate = math.min(rate, M.VANILLA_FRIDGE_RATE) end
        table.insert(curve, { celsius, rate })
    end
    return curve
end

local function newKeeper(name, suffix, curve, modDataKey)
    return PlaceKeeping.new({
        process = name .. suffix, curve = curve, ledgerKey = M.CELLAR_LEDGER_KEY .. name .. suffix,
        modDataKey = modDataKey, enabled = M.cellarByPlace,
    })
end

-- Each crop's keepers: keeper, and curedKeeper for a crop that cures.
for name, crop in pairs(M.CROPS) do
    crop.name = name
    crop.frost = Frost.point(crop.freezeC)
    crop.keeper = newKeeper(name, "", M.cellarCurve(crop.vanilla, crop.days), M.CELLAR_KEY)
    if crop.curedShare then
        local curve = {}
        for _, point in ipairs(crop.keeper.keepingRules.curve) do table.insert(curve, { point[1], point[2] * crop.curedShare }) end
        crop.curedKeeper = newKeeper(name, "Cured", curve, M.CURED_KEY)
    elseif crop.cured then
        local curve = M.cellarCurve(crop.vanilla, crop.cured)
        if crop.curedAtZero then table.insert(curve, 1, { 0, crop.vanilla / crop.curedAtZero }) end
        crop.curedKeeper = newKeeper(name, "Cured", curve, M.CURED_KEY)
    end
end

-- How much an hour of the dry cure counts at a place (unknown places as a room). By a fire with none of its own,
-- the place under it: the fire place's own (Covered, Open), else placeWithoutFire (Fire.noteFire's).
function M.dryCurePlace(place, placeWithoutFire)
    local air = M.CURES.dry.places[place]
    if air then return air end
    local fire = Weather.FIRE_PLACES[place]
    if fire then return M.dryCurePlace(fire.placeWithoutFire or placeWithoutFire or Fire.DEFAULT_PLACE_WITHOUT_FIRE) end
    return M.CURES.dry.places.Sheltered
end

-- The dry cure's air over a stretch from hour to now at a place: by a fire, the fire's air while its noted fuel lasted
-- (fireUntil), the place under it after, shared by time (as Fire.catchUp shares the work).
local function dryCureAir(place, note, hour, now)
    local air = M.dryCurePlace(place, note.placeWithoutFire)
    if not Weather.FIRE_PLACES[place] or not note.fireUntil or not hour or now <= hour then return air end
    local byFire = math.min(math.max(note.fireUntil - hour, 0), now - hour) / (now - hour)
    return air * byFire + M.dryCurePlace(note.placeWithoutFire or Fire.DEFAULT_PLACE_WITHOUT_FIRE) * (1 - byFire)
end

-- The cures' hours, counted by place on a ledger of their own (process "<kind>Cure").
local cureProcesses = {}
for kind, rule in pairs(M.CURES) do
    if rule.curve then
        rule.ageing = { process = kind .. "Cure", rate = function(celsius) return Weather.curve(rule.curve, celsius) end }
        cureProcesses[rule.ageing.process] = rule.ageing.rate
    end
end
function M.cureLedger()
    return Weather.getLedger(M.CELLAR_LEDGER_KEY .. "Cure", function(now) return Weather.newLedger(now, cureProcesses) end)
end

M.CROP_OF_TYPE = {}
for _, crop in pairs(M.CROPS) do M.CROP_OF_TYPE[crop.fullType] = crop end

-- Adds a stretch of weather to every cellar ledger (every ten minutes, from a Weather.onReading).
function M.recordCellarWeather(now, temperature)
    for _, name in ipairs(M.CROP_NAMES) do
        local crop = M.CROPS[name]
        crop.keeper.recordWeather(now, temperature)
        if crop.curedKeeper then crop.curedKeeper.recordWeather(now, temperature) end
    end
    Weather.advance(M.cureLedger(), now, temperature, cureProcesses)
end

-- The storages (tiles with a container, as Fish & Meat's Stockfish Pallet): what lies in one, loose or in a braid
-- inside it, cures or keeps faster or slower than its place alone gives, the place still deciding. cure: how much a
-- stretch of curing counts by the cure's kind; keep: how much a stretch of keeping counts by crop (all: every crop).
-- A Drying Pole (bunches hung on a T-pole, airy) speeds garlic's and onions' dry cure and keeps them longer hanging
-- after; a Vegetable Crate (Hay) speeds the other cures (potatoes, sweet potatoes, pumpkins) and keeps them, turnips and
-- cabbages longer; a Vegetable Crate (Sand) keeps carrots, beets, leeks and turnips longer, packed in damp sand (user,
-- 2026-11-18).
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
M.STORAGE_BONUS = {
    pole = { cure = { dry = 1.5 }, keep = { garlic = 0.75, onion = 0.75 } },
    -- Carrots, beets and leeks were kept in damp sand, not dry hay: no bonus for them in hay; the sand crate is theirs,
    -- and turnips' too (they were kept either way) (user, 2026-11-18).
    -- Packed in hay, a short frost doesn't get through: half its hours count (user, session 76).
    hayCrate = { cure = { warm = 1.5, hot = 1.5 }, keep = { all = 0.75, garlic = 1, onion = 1, carrots = 1, sugarBeet = 1, leek = 1 },
        frost = 0.5 },
    sandCrate = { keep = { carrots = 0.75, sugarBeet = 0.75, leek = 0.75, turnip = 0.75 } },
}
M.STORAGE_OF_CONTAINER = {}
for key, storage in pairs(Tiles.STORAGES) do M.STORAGE_OF_CONTAINER[storage.container] = key end
-- Item modData: the storage a vegetable lay in when last looked at (nil: none); it counts for the time since.
-- STORAGE_WORDS: how the console names each.
M.STORED_KEY = "tpfvIn"
M.STORAGE_WORDS = { pole = "onion and garlic pole", hayCrate = "hay crate", sandCrate = "sand crate" }

-- The storage an item lies in, loose or inside a braid or a bag there: "pole", "hayCrate", "sandCrate", or nil.
function M.storageOf(item)
    local container = item:getContainer()
    while container do
        local storage = M.STORAGE_OF_CONTAINER[container:getType()]
        if storage then return storage end
        local holder = container:getContainingItem()
        container = holder and holder:getContainer()
    end
    return nil
end

-- How much a stretch of keeping counts for a crop in a storage (1: as its place alone).
function M.storageKeepFactor(crop, storage)
    local keep = storage and M.STORAGE_BONUS[storage].keep
    return keep and (keep[crop.name] or keep.all) or 1
end

-- How much a stretch of curing counts for a crop in a storage.
function M.storageCureFactor(crop, storage)
    local cure = storage and M.STORAGE_BONUS[storage].cure
    return cure and cure[crop.cure] or 1
end

-- How much a stretch of frost counts for a vegetable in a storage (1: as its place alone).
function M.storageFrostFactor(storage)
    return storage and M.STORAGE_BONUS[storage].frost or 1
end

-- The fire a vegetable's clock noted at this look (Fire.noteFire), copied onto another of its records.
local function copyFire(from, to)
    to.fireUntil, to.placeWithoutFire = from.fireUntil, from.placeWithoutFire
end

-- Brings a cure up to now at the place the vegetable was seen in last, and counts from place (seen: the keeping
-- clock's fluidAge, with the fire noted now); factor is how much the stretch counts (its storage). Returns true once cured.
local function cure(crop, item, now, place, factor, seen)
    local itemModData = item:getModData()
    local rule = M.CURES[crop.cure]
    local curing = itemModData[M.CURING_KEY]
    local hours = crop.cureHours or rule.hours
    if rule.ageing then
        local ledger = M.cureLedger()
        if not curing then
            curing = FluidAgeing.newFluidAge(rule.ageing, ledger, now, place)
            copyFire(seen, curing)
            itemModData[M.CURING_KEY] = curing
            return false
        end
        -- The stretch since the last look, at the place it was in then (and the dry cure's air there).
        local before, was, hour = curing.age, curing.place, curing.hour
        local air = rule.places and dryCureAir(was, curing, hour, now) or 1
        FluidAgeing.advance(curing, rule.ageing, ledger, now, place)
        copyFire(seen, curing)
        curing.age = before + (curing.age - before) * factor * air
        return curing.age >= hours
    end
end

-- Brings a vegetable's frost up to now at the place it was seen in last (TP Core's Frost.see; clock: its keeping
-- clock, just brought up to now), and moves it that much nearer rotten. Returns the hours it was frozen since the last
-- look (after its storage's factor).
local function frost(crop, item, now, clock, factor)
    local hours = Frost.see(item:getModData(), M.FROST_KEY, crop.frost, now, clock.fluidAge) * factor
    if hours <= 0 or not M.frostDamage() then return 0 end
    M.frostBite(item, clock, hours)
    return hours
end

-- Moves a kept vegetable hours of frost nearer rotten (never past it): its clock's base, so the keeping goes on from
-- there. Also the console's TPFV.frost.
function M.frostBite(item, clock, hours)
    Frost.bite(item, hours, M.FROST_RUIN_HOURS, clock)
end

-- The keeper a vegetable ages by now: a cured one's cured keeper; garlic or onion curing in a dry place the cured
-- one too (curing is drying, so it doesn't spend its days); otherwise its crop's.
local function keeperFor(crop, cured, place, placeWithoutFire)
    if cured or (crop.cure == "dry" and M.dryCurePlace(place, placeWithoutFire) > 0) then return crop.curedKeeper end
    return crop.keeper
end

-- The keeper looking after a vegetable now: the one whose clock it carries. Nil for one the cellar doesn't keep.
function M.keeperOf(item)
    local crop = M.CROP_OF_TYPE[item:getFullType()]
    if not crop then return nil end
    return item:getModData()[M.CURED_KEY] and crop.curedKeeper or crop.keeper
end

-- Brings a vegetable's age up to now at the place it was seen in last, and counts from where it is now (place, or
-- where the item is). It changes keeper, from the age it has, when it is cured or (garlic and onion) moves between a
-- dry place and a damp one. Returns its clock, or nil when it isn't kept (the sandbox off, not a kept crop, cooked
-- or burnt).
function M.keepVegetable(item, now, place)
    local crop = M.CROP_OF_TYPE[item:getFullType()]
    if not crop or not M.cellarByPlace() or item:isCooked() or item:isBurnt() then return nil end
    now = now or getGameTime():getWorldAgeHours()
    local itemModData = item:getModData()
    local keeper = M.keeperOf(item)
    -- The storage it lay in since the last look counts for that stretch, as its place does.
    local storedIn = itemModData[M.STORED_KEY]
    itemModData[M.STORED_KEY] = M.storageOf(item)
    local held = itemModData[keeper.keepingRules.modDataKey]
    local ageBefore = held and held.fluidAge.age
    local clock = keeper.keep(item, now, place)
    local keepFactor = M.storageKeepFactor(crop, storedIn)
    if ageBefore and keepFactor ~= 1 then
        clock.fluidAge.age = ageBefore + (clock.fluidAge.age - ageBefore) * keepFactor
        item:setAge(clock.base + clock.fluidAge.age / 24)
    end
    frost(crop, item, now, clock, M.storageFrostFactor(storedIn))
    if not crop.cure then return clock end
    local seen = clock.fluidAge
    place = seen.place
    if not itemModData[M.CURED] and cure(crop, item, now, place, M.storageCureFactor(crop, storedIn), seen) then
        itemModData[M.CURED] = true
        itemModData[M.CURING_KEY] = nil
    end
    local wanted = keeperFor(crop, itemModData[M.CURED], place, seen.placeWithoutFire)
    if wanted == keeper then return clock end
    itemModData[keeper.keepingRules.modDataKey] = nil
    local wantedClock = wanted.keep(item, now, place)
    if wantedClock then copyFire(seen, wantedClock.fluidAge) end
    return wantedClock
end

-- Days fresh a crop keeps at a temperature, cured or not (the console's and the report's).
function M.daysFresh(crop, celsius, cured)
    local keeper = cured and crop.curedKeeper or crop.keeper
    local rate = keeper.ageRate(celsius)
    return rate > 0 and crop.vanilla / rate or math.huge
end
