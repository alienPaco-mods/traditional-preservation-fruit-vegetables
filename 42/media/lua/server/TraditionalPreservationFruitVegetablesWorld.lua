-- Traditional Preservation (Fruits and Vegetables) B42: keeps track of every Kraut Barrel and storage, records the
-- weather (the barrel's ledger and the cellar's), brings each barrel's batch up to now at the place it was seen in
-- last and layers the sprite for its stage, and each storage's for how full it is. The batch sits in the barrel's movableData, so it goes with a barrel picked up.
if isClient() then return end

TraditionalPreservationFruitVegetablesWorld = TraditionalPreservationFruitVegetablesWorld or {}
local World = TraditionalPreservationFruitVegetablesWorld
local M = TraditionalPreservationFruitVegetables
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
local log = require "TraditionalPreservationCore/Log"

local function squareKey(station)
    local square = station:getSquare()
    return square and (square:getX() .. "," .. square:getY() .. "," .. square:getZ())
end

-- Brings a barrel's batch up to now: the time since the last look counts at the place it was seen in then (by a
-- fire while the fuel it had then lasts; a barrel moved since, where it stands now). Then notes where it is and its
-- fire. Returns the barrel's record.
function World.updateBarrel(station)
    local barrel = M.barrelOf(station)
    local now = getGameTime():getWorldAgeHours()
    local place, fire = Fire.placeOf(station)
    local here = squareKey(station)
    local before = M.barrelStage(barrel)
    M.updateBarrel(barrel, M.getLedger(), barrel.at == here and barrel.place or place)
    barrel.place, barrel.at = place, here
    Fire.noteFire(barrel, station, fire, now)
    local after = M.barrelStage(barrel)
    if after ~= before then log("TPFV", "barrel %s -> %s, %s", before, after, place) end
    return barrel
end

-- The overlay a stage shows: the shreds at the rim (cabbage, turnip, or both mixed), then the cloth, board and stone.
local function overlayOf(barrel)
    local stage = M.barrelStage(barrel)
    if stage == "Packing" then
        local cabbages, turnips = M.headCount(barrel, "cabbage"), M.headCount(barrel, "turnip")
        if cabbages > 0 and turnips > 0 then return Tiles.OVERLAYS.mixed end
        return Tiles.OVERLAYS[turnips > 0 and "turnip" or "cabbage"]
    end
    if stage ~= "Empty" then return Tiles.OVERLAYS.weighted end
end

local function refresh(station, sessionState)
    local overlay = overlayOf(World.updateBarrel(station))
    local names = {}
    if overlay then table.insert(names, Tiles.PREFIX .. (overlay + sessionState.faceIndex)) end
    Station.showSprites(station, sessionState, tostring(overlay), names)
end

local function newSessionState(station)
    local name = station:getSprite() and station:getSprite():getName()
    for index, sprite in ipairs(Tiles.STATIONS) do
        if sprite == name then return { faceIndex = index - 1 } end
    end
end

-- A barrel just built or put down isn't known to the map loader, so the tracker looks for new ones round each player.
local tracker = Station.tracker({ sprites = Tiles.STATIONS, newSessionState = newSessionState, refresh = refresh, scan = true })

World.track = tracker.track

-- Redraws a tracked barrel now, without waiting for the next tick, e.g. after packing.
function World.refresh(station)
    local sessionState = tracker.track(station)
    if sessionState then refresh(station, sessionState) end
end

-- Every tracked barrel that is loaded, for the dev console.
function World.barrels()
    local barrels = {}
    for station in pairs(tracker.tracked) do
        if Station.isLoaded(station) then table.insert(barrels, station) end
    end
    return barrels
end

-- The storages (Drying Pole, Vegetable Crates): each shows what it holds in Tiles.LEVELS steps by the
-- weight inside against its capacity, nothing when empty. What lies in one cures or keeps by the cellar's rules,
-- looked at like any vegetable (TP Core's PlaceKeepingUI); the World only draws it.
local STORAGE_OF_TILE = {}
local storageTiles = {}
for _, storage in pairs(Tiles.STORAGES) do
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
        local level = World.storageLevel(container:getContentsWeight(), storage.capacity, Tiles.LEVELS)
        Station.showSprites(station, sessionState, tostring(level), level and { Tiles.PREFIX .. (storage.overlay + level - 1) } or {})
    end,
    scan = true,
})

Weather.onReading(function(now, climate)
    M.advance(M.getLedger(), now, climate:getTemperature())
    M.recordCellarWeather(now, climate:getTemperature())
end)

tracker.start()
storageTracker.start()
