-- Traditional Preservation (Fruits and Vegetables): commands for the debug Lua console, loaded only in debug mode.
-- Type TPFV.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local M = TraditionalPreservationFruitVegetables
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
local Frost = require "TraditionalPreservationCore/Frost"
TPFV = {}

local function say(text) print("[TPFV] " .. text) end

function TPFV.help()
    say("TPFV.weather()        the temperature by place, and how long a kraut barrel takes there")
    say("TPFV.here()           which place you're standing in (open air, an open roof, indoors or a basement)")
    say("TPFV.barrel()         the nearest kraut barrel: stage, contents, place, progress, hours too warm")
    say("TPFV.age(hours)       give every kraut barrel this many hours of good weather (souring, then keeping)")
    say("TPFV.fast(hours)      test timer: a barrel sours in this many hours at 18 C. TPFV.fast() goes back to the sandbox time")
    say("TPFV.cellar()         days fresh for each vegetable by place, at today's weather")
    say("TPFV.veg()            the kept vegetables on you and within reach: place, rate, age, cured, the storage they lie in (pole, hay or sand crate)")
    say("TPFV.keep(days)       age the vegetables on you and within reach by this many days at their place and storage")
    say("TPFV.cure()           cure the vegetables that cure, on you and within reach, now")
    say("TPFV.frost(hours)     freeze every kept vegetable near you for hours (default 3): 12 h ruins one; 6 h makes kraut soft")
    say("TPFV.clamp()          the nearest clamp (within 5 tiles): earthed or not, its place and temperature, what it holds, sweating")
    say("TPFV.earth(on)        earth the nearest clamp up (true, the default) or take the soil down (false), at once")
    say("TPFV.give(name, n)    spawn n of a vegetable (potato, cabbage...), sauerkraut, sauerTurnip, krautBrine, garlicBraid or onionBraid. TPFV.give() lists them")
    say("TPFV.kit(kind)        the things a test of kind needs; TPFV.kit(\"?\") lists the kinds")
    say("Weather, game speed and the Stone Hearth's commands are TP Core's: TPC.help()")
end

function TPFV.weather()
    local ledger = M.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C. A barrel sours in %.1f days at 18 C.",
        ledger.temperature or 0, ledger.seasonTemperature or 0, M.FERMENT_HOURS / 24))
    for _, place in ipairs(M.PLACES) do
        local celsius = M.placeTemperature(ledger, place)
        local days = M.fermentDays(celsius)
        say(string.format("%-9s %.1f C: %s%s, ready kraut keeps %.0f days", place, celsius,
            days and string.format("sours in %.1f days", days) or "stopped (0 C or below)",
            M.hotRate(celsius) > 0 and ", TOO WARM" or "", M.KEEP_DAYS / math.max(M.keepRate(celsius), 1e-6)))
    end
end

function TPFV.here()
    say("You're in: " .. tostring(M.placeOf(getPlayer())))
end

-- The nearest loaded barrel, brought up to now.
local function nearestBarrel()
    local World = TraditionalPreservationFruitVegetablesWorld
    if not World then return nil end
    local player, best, bestDistance = getPlayer(), nil, math.huge
    for _, station in ipairs(World.barrels()) do
        local square = station:getSquare()
        local distance = IsoUtils.DistanceTo(player:getX(), player:getY(), square:getX(), square:getY())
        if distance < bestDistance then best, bestDistance = station, distance end
    end
    return best
end

function TPFV.barrel()
    local station = nearestBarrel()
    if not station then return say("No kraut barrel loaded.") end
    local barrel = TraditionalPreservationFruitVegetablesWorld.updateBarrel(station)
    local status = M.barrelStatus(barrel, M.getLedger(), barrel.place)
    say(string.format("%s: %d cabbages, %d turnips, apples %d, carrots %d", status.stage, M.headCount(barrel, "cabbage"), M.headCount(barrel, "turnip"),
        barrel.apples or M.extraCount(barrel, "apple"), barrel.carrots or M.extraCount(barrel, "carrot")))
    say(string.format("%s at %.1f C, progress %.0f%%, rate %.2f, %s", tostring(status.place), status.temperature,
        (status.progress or 0) * 100, status.rate or 0,
        status.hoursLeft and string.format("%.0f h to ready", status.hoursLeft)
        or status.daysLeft and string.format("keeps %.0f more days", status.daysLeft) or ""))
    if status.hotHours then say(string.format("%.0f h above %d C (soft at %d, spoiled at %d)", status.hotHours, M.HOT_C, M.HOT_SOFT_HOURS, M.HOT_SPOIL_HOURS)) end
    if barrel.portions then
        say(string.format("%d Sauerkraut and %d Sauer Turnip left, soft: %s", M.portionsLeft(barrel, "cabbage"),
            M.portionsLeft(barrel, "turnip"), tostring(barrel.soft == true)))
    end
end

function TPFV.age(hours)
    hours = hours or 24
    local ledger = M.getLedger()
    for _, place in ipairs(M.PLACES) do
        ledger["ferment" .. place] = (ledger["ferment" .. place] or 0) + hours
        ledger["keep" .. place] = (ledger["keep" .. place] or 0) + hours
    end
    say(string.format("Added %.0f hours of good weather. Barrels update within a few seconds.", hours))
end

function TPFV.fast(hours)
    if not hours then
        M.FERMENT_HOURS = 28 * 24
        M.applySandbox()
        return say(string.format("Back to the sandbox time: %.1f days at 18 C.", M.FERMENT_HOURS / 24))
    end
    M.FERMENT_HOURS = hours
    say(string.format("Test timer on: a barrel sours in %s hours at 18 C.", tostring(hours)))
end

-- Kept vegetables carried and in containers within TP Core's PlaceKeepingUI.REACH tiles.
local function vegetablesNear()
    return PlaceKeepingUI.near(M.CROP_OF_TYPE)
end

function TPFV.cellar()
    local ledger = M.CROPS.potato.keeper.ledger()
    local header = string.format("%-10s", "")
    for _, place in ipairs(M.PLACES) do header = header .. string.format(" %9s", place) end
    say(header .. string.format(" %9s", "Fridge"))
    local function row(label, crop, cured)
        local keeper = cured and crop.curedKeeper or crop.keeper
        local line = string.format("%-10s", label)
        for _, place in ipairs(M.PLACES) do
            line = line .. string.format(" %7.0f d", crop.vanilla / keeper.rate(place, ledger))
        end
        say(line .. string.format(" %7.0f d", crop.vanilla / keeper.rate("Fridge", ledger)))
    end
    for _, name in ipairs(M.CROP_NAMES) do
        local crop = M.CROPS[name]
        row(name, crop)
        if crop.curedKeeper then row("  cured", crop, true) end
    end
    say("Days fresh at today's weather; vanilla's are the warm room's (22 C).")
end

function TPFV.veg()
    local found = vegetablesNear()
    if #found == 0 then return say("No kept vegetables on you or within " .. PlaceKeepingUI.REACH .. " tiles.") end
    for _, item in ipairs(found) do
        M.keepVegetable(item)
        local keeper = M.keeperOf(item)
        local curing = item:getModData()[M.CURING_KEY]
        local state = item:getModData()[M.CURED] and "cured" or curing and string.format("curing %.0f h", curing.age) or "not curing"
        local storage = M.storageOf(item)
        local line = keeper.describe(item) .. ", " .. state
        local frost = item:getModData()[M.FROST_KEY]
        local crop = M.CROP_OF_TYPE[item:getFullType()]
        if frost then
            line = line .. string.format(", frozen %.1f h in all (freezes at %g C%s)", frost.age, crop.freezeC,
                Frost.freezingAt(crop.frost, frost.place) and ", freezing here now" or "")
        end
        if item:getModData()[M.SWEAT_KEY] then line = line .. ", in an earthed clamp (sweats above " .. M.SWEAT_C .. " C)" end
        if storage then
            -- describe is the place's alone: the storage's keeping counts on top of it.
            local crop = M.CROP_OF_TYPE[item:getFullType()]
            local factor = M.storageKeepFactor(crop, storage)
            local clock = item:getModData()[keeper.keepingRules.modDataKey]
            local rate = keeper.rate(clock and clock.fluidAge.place) * keeper.ageing.speed() * factor
            local cures = crop.cure and string.format(", cures x%.1f", M.storageCureFactor(crop, storage)) or ""
            line = line .. string.format(", in the %s (keeping x%.2f%s): %s days fresh with it", M.STORAGE_WORDS[storage], factor, cures,
                rate > 0 and string.format("%.0f", item:getOffAge() / rate) or "never")
        end
        say(line)
    end
end

function TPFV.keep(days)
    days = days or 1
    local found = vegetablesNear()
    for _, item in ipairs(found) do
        M.keepVegetable(item)
        M.keeperOf(item).age(item, days * M.storageKeepFactor(M.CROP_OF_TYPE[item:getFullType()], M.storageOf(item)))
    end
    say(string.format("Aged %d vegetables by %s days at their place.", #found, tostring(days)))
end

-- Hours of frost on every kept vegetable near you, as if they had frozen that long (the sandbox's Vegetables freeze
-- aside).
function TPFV.frost(hours)
    hours = hours or 3
    local found = vegetablesNear()
    for _, item in ipairs(found) do
        local clock = M.keepVegetable(item)
        if clock then M.frostBite(item, clock, hours) end
    end
    -- Kraut out of the barrel: frozen through, it goes soft.
    local krauts = PlaceKeepingUI.near(M.KRAUT_OF_PRODUCT)
    local softened = 0
    for _, item in ipairs(krauts) do
        if hours >= Frost.THROUGH_HOURS and M.softenKraut(item) then softened = softened + 1 end
    end
    say(string.format("Froze %d vegetables for %s hours; %d portions of kraut went soft.", #found, tostring(hours), softened))
end

function TPFV.cure()
    local count = 0
    for _, item in ipairs(vegetablesNear()) do
        local crop = M.CROP_OF_TYPE[item:getFullType()]
        if crop.cure and M.keepVegetable(item) and not item:getModData()[M.CURED] then
            item:getModData()[M.CURING_KEY].age = M.CURES[crop.cure].hours
            M.keepVegetable(item)
            count = count + 1
        end
    end
    say(string.format("Cured %d vegetables.", count))
end

-- The nearest clamp within 5 tiles of you, or nil.
local function nearestClamp()
    local player = getPlayer()
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local best, bestDistance
    for x = px - 5, px + 5 do
        for y = py - 5, py + 5 do
            local square = getCell():getGridSquare(x, y, pz)
            local objects = square and square:getObjects()
            for i = 0, (objects and objects:size() or 0) - 1 do
                local object = objects:get(i)
                local distance = math.abs(x - px) + math.abs(y - py)
                if M.isClamp(object) and (not bestDistance or distance < bestDistance) then best, bestDistance = object, distance end
            end
        end
    end
    return best
end

function TPFV.clamp()
    local clamp = nearestClamp()
    if not clamp then return say("No clamp within 5 tiles.") end
    local Weather = require "TraditionalPreservationCore/Weather"
    local place = M.clampPlace(clamp)
    local celsius = Weather.placeTemperature(Weather.weatherModData(), place)
    local container = clamp:getContainer()
    local items = container and container:getItems()
    say(string.format("%s, %.1f C, %d pieces, accepts by %s%s", M.clampEarthed(clamp) and "Earthed up" or "Under straw", celsius,
        items and items:size() or 0, tostring(container and container:getAcceptItemFunction()),
        (M.clampEarthed(clamp) and celsius > M.SWEAT_C) and string.format(", SWEATING (above %g C)", M.SWEAT_C) or ""))
end

function TPFV.earth(on)
    local clamp = nearestClamp()
    if not clamp then return say("No clamp within 5 tiles.") end
    M.setClampEarthed(clamp, on ~= false)
    if TraditionalPreservationFruitVegetablesWorld then TraditionalPreservationFruitVegetablesWorld.refreshClamp(clamp) end
    TPFV.clamp()
end

local GIVES = { sauerkraut = M.KRAUTS.cabbage.product, sauerTurnip = M.KRAUTS.turnip.product,
    garlicBraid = M.BRAIDS.garlic.braid, onionBraid = M.BRAIDS.onion.braid,
    pasteCrock = M.CROCK, pasteCrockSealed = M.CROCK_SEALED, tomatoPaste = M.PASTE_PORTION }
for name, crop in pairs(M.CROPS) do GIVES[name] = crop.fullType end
local GIVE_NAMES = {}
for name in pairs(GIVES) do table.insert(GIVE_NAMES, name) end
table.insert(GIVE_NAMES, "krautBrine")
table.sort(GIVE_NAMES)

-- A glass jar of a litre of good Kraut Brine: a starter for a new barrel, or to drink.
local function brineJar(inventory)
    local jar = inventory:AddItem("Base.EmptyJar")
    if jar and jar.getFluidContainer and jar:getFluidContainer() then M.fillWith(jar, M.KRAUT_BRINE, M.STARTER_L) end
    return jar
end

function TPFV.give(name, count)
    if name == "krautBrine" then
        for _ = 1, count or 1 do brineJar(getPlayer():getInventory()) end
        return say("Gave " .. (count or 1) .. " jar(s) of kraut brine.")
    end
    local fullType = GIVES[name]
    if not fullType then return say("Things: " .. table.concat(GIVE_NAMES, ", ")) end
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem(fullType) end
    say("Gave " .. (count or 1) .. " " .. name .. ".")
end

local function add(inventory, fullType, count)
    for _ = 1, count or 1 do inventory:AddItem(fullType) end
end

-- One kit per kind of test, the whole group, sorted when listed.
local KITS = {
    barrel = {
        about = "a hammer, a saw, 6 planks, 10 nails and 4 twine to build the Brine Barrel (Woodwork 3); 30 cabbages, "
            .. "6 apples, 6 carrots, 30 turnips, 2 salt shakers, a ripped sheet, a plank and a flat stone to fill, salt and compress it; "
            .. "a jar of kraut brine for its starter, 4 empty jars and a bucket to draw and drain brine into",
        give = function(inventory)
            add(inventory, "Base.Hammer")
            add(inventory, "Base.Saw")
            add(inventory, "Base.Plank", 7)
            add(inventory, "Base.Nails", 10)
            add(inventory, "Base.Twine", 4)
            add(inventory, "Base.Cabbage", 30)
            add(inventory, "Base.Apple", 6)
            add(inventory, "Base.Carrots", 6)
            add(inventory, "Base.Turnip", 30)
            add(inventory, "Base.Salt", 2)
            add(inventory, "Base.RippedSheets")
            add(inventory, M.STONE)
            brineJar(inventory)
            add(inventory, "Base.EmptyJar", 4)
            add(inventory, "Base.BucketEmpty")
        end,
    },
    storage = {
        about = "a hammer, a saw, 9 planks, 12 nails, 2 twine, 4 hay and a sack of sand to build the Drying Pole (Woodwork 2) and "
            .. "the Vegetable Crates (Hay, Sand; 1); 10 potatoes, 4 sweet potatoes, 2 pumpkins, 10 garlic, 10 onions, 6 carrots, 6 sugar beets",
        give = function(inventory)
            add(inventory, "Base.Hammer")
            add(inventory, "Base.Saw")
            add(inventory, "Base.Plank", 9)
            add(inventory, "Base.Nails", 12)
            add(inventory, "Base.Sandbag")
            add(inventory, "Base.Twine", 2)
            add(inventory, "Base.HayTuft", 4)
            add(inventory, "Base.Potato", 10)
            add(inventory, "Base.SweetPotato", 4)
            add(inventory, "Base.Pumpkin", 2)
            add(inventory, "Base.Garlic", 10)
            add(inventory, "Base.Onion", 10)
            add(inventory, "Base.Carrots", 6)
            add(inventory, "Base.SugarBeet", 6)
        end,
    },
    clamp = {
        about = "a shovel and 12 hay to dig two Clamps (one to level); 5 each of potato, turnip, sugar beet, carrots "
            .. "and cabbage to clamp, and a leek and an onion it refuses",
        give = function(inventory)
            add(inventory, "Base.Shovel")
            add(inventory, "Base.HayTuft", 12)
            for _, name in ipairs(M.CLAMP_CROPS) do add(inventory, M.CROPS[name].fullType, 5) end
            add(inventory, "Base.Leek")
            add(inventory, "Base.Onion")
        end,
    },
    paste = {
        about = "20 tomatoes, a cooking pot and a saucepan to cook them down; a Ceramic Jar, a Glazed Ceramic Jar and an "
            .. "Empty Jar to pack into; 2 salt shakers for the crust; a bottle of Vegetable Oil and a block of Lard to cap it",
        give = function(inventory)
            add(inventory, M.TOMATO, 20)
            add(inventory, "Base.Pot")
            add(inventory, "Base.Saucepan")
            add(inventory, "Base.ClayJar")
            add(inventory, "Base.ClayJarGlazed")
            add(inventory, "Base.EmptyJar")
            add(inventory, "Base.Salt", 2)
            add(inventory, "Base.OilVegetable")
            add(inventory, "Base.Lard")
        end,
    },
    cellar = {
        about = "3 of each vegetable the cellar keeps (" .. table.concat(M.CROP_NAMES, ", ") .. ")",
        give = function(inventory)
            for _, name in ipairs(M.CROP_NAMES) do add(inventory, M.CROPS[name].fullType, 3) end
        end,
    },
}

local KIT_NAMES = {}
for name in pairs(KITS) do table.insert(KIT_NAMES, name) end
table.sort(KIT_NAMES)

function TPFV.kit(kind)
    local kit = KITS[kind]
    if not kit then
        for _, name in ipairs(KIT_NAMES) do say(string.format("TPFV.kit(\"%s\"): %s", name, KITS[name].about)) end
        return
    end
    kit.give(getPlayer():getInventory())
    say("Gave " .. kit.about .. ".")
end

say("Debug commands loaded. Type TPFV.help() in the Lua console.")
