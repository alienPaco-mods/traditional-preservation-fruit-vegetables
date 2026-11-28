-- Traditional Preservation (Fruits and Vegetables) B42: keeps track of every storage and clamp, records the weather
-- (the kraut's ledger and the cellar's) and layers each storage's sprite for how full it is. The kraut's Brine Barrel
-- is TP Core's (BrineBarrelWorld).
if isClient() then return end

TraditionalPreservationFruitVegetablesWorld = TraditionalPreservationFruitVegetablesWorld or {}
local World = TraditionalPreservationFruitVegetablesWorld
local M = TraditionalPreservationFruitVegetables
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"

-- The barrel is TP Core's Brine Barrel (BrineBarrelWorld: its tracking, its catch-up by place and fire, its looks);
-- these pass on to it for this mod's console and callers.
function World.updateBarrel(station)
    return TraditionalPreservationCoreBrineBarrel.updateBarrel(station)
end

function World.refresh(station)
    return TraditionalPreservationCoreBrineBarrel.refresh(station)
end

function World.barrels()
    return TraditionalPreservationCoreBrineBarrel.barrels()
end

-- The storages (Drying Pole, Vegetable Crates): each shows what it holds in Tiles.LEVELS steps by the
-- weight inside against its capacity, nothing when empty. What lies in one cures or keeps by the cellar's rules,
-- looked at like any vegetable (TP Core's PlaceKeepingUI); the World only draws it.
local STORAGE_OF_TILE = {}
local storageTiles = {}
for key, storage in pairs(Tiles.STORAGES) do
    storage.key = key
    STORAGE_OF_TILE[storage.tile] = storage
    table.insert(storageTiles, storage.tile)
end

-- The fill step of a storage's container: 1 to levels by weight, nil when empty.
function World.storageLevel(contentsWeight, capacity, levels)
    if contentsWeight <= 0 then return nil end
    return math.max(1, math.min(levels, math.ceil(contentsWeight / capacity * levels - 0.0001)))
end

local storageTracker = Station.tracker({
    sprites = storageTiles,
    newSessionState = function(isoObject)
        local sprite = isoObject:getSprite()
        local storage = sprite and STORAGE_OF_TILE[sprite:getName()]
        return storage and { storage = storage } or nil
    end,
    refresh = function(station, sessionState)
        local container = station:getContainer()
        if not container then return end
        local storage = sessionState.storage
        -- What it takes (an accept function isn't saved, so set on every storage seen).
        local accept = M.STORAGE_ACCEPTS[storage.key]
        if container:getAcceptItemFunction() ~= accept then container:setAcceptItemFunction(accept) end
        local level = World.storageLevel(container:getContentsWeight(), storage.capacity, Tiles.LEVELS)
        Station.showSprites(station, sessionState, tostring(level), level and { Tiles.PREFIX .. (storage.overlay + level - 1) } or {})
    end,
    scan = true,
})

-- The clamp: its container only takes the clamped crops (an accept function isn't saved, so set on every clamp seen),
-- the soil dome over it once earthed up, and rainwater in its trenches while vanilla's puddles are up.
local function clampWet()
    local puddles = IsoPuddles and IsoPuddles.getInstance and IsoPuddles.getInstance()
    return puddles ~= nil and puddles:getPuddlesSize() >= M.CLAMP_WET_PUDDLES
end

-- The overlays a clamp shows: the soil earthed up, then the water left in sight.
function World.clampSprites(earthed, wet)
    local names = {}
    if earthed then table.insert(names, Tiles.CLAMP.earthed) end
    if wet then table.insert(names, earthed and Tiles.CLAMP.wetEarthed or Tiles.CLAMP.wet) end
    return names
end

local function refreshClamp(station, sessionState)
    local container = station:getContainer()
    if container and container:getAcceptItemFunction() ~= M.CLAMP_ACCEPT then container:setAcceptItemFunction(M.CLAMP_ACCEPT) end
    local earthed, wet = M.clampEarthed(station), clampWet()
    Station.showSprites(station, sessionState, tostring(earthed) .. tostring(wet), World.clampSprites(earthed, wet))
end

local clampTracker = Station.tracker({
    sprites = { Tiles.CLAMP.tile },
    newSessionState = function(isoObject)
        return M.isClamp(isoObject) and {} or nil
    end,
    refresh = refreshClamp,
    scan = true,
})

-- Redraws a clamp now (a clamp just built, earthed up or taken down), and starts tracking it.
function World.refreshClamp(station)
    local sessionState = clampTracker.track(station)
    if sessionState then refreshClamp(station, sessionState) end
end

-- Stops tracking a clamp levelled away.
World.forgetClamp = clampTracker.forget

Weather.onReading(function(now, climate)
    M.advance(M.getLedger(), now, climate:getTemperature())
    M.recordCellarWeather(now, climate:getTemperature())
    M.PASTE_KEEPER.recordWeather(now, climate:getTemperature())
end)

storageTracker.start()
clampTracker.start()
