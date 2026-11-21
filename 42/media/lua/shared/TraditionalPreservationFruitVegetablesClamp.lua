-- Traditional Preservation (Fruits and Vegetables) B42: the clamp (ROADMAP section 8 phase 3, user session 77). Roots
-- heaped on bare ground under straw, drainage trenches dug either side, then earthed over once hard frost comes: a
-- storage (a container from its tile, as the Vegetable Crates), open the whole time, as a real clamp was opened at one
-- end, some taken and closed again. What lies in it is at TP Core's StrawClamp place, earthed over its EarthedClamp place
-- (Weather: halfway from the air to the basement), so it keeps by the cellar's curves and freezes by its own points
-- there. Earthed over while still warm it sweats: above SWEAT_C its crops age SWEAT_RATE times as fast. Only the roots
-- and heads that were clamped go in (CLAMP_CROPS); no rain rule (user: the spring warmth ends its season). The World
-- draws the soil and the rainwater in the trenches. Dug from a right-click on bare dirt with a shovel, as vanilla's
-- furrow (no build menu, not movable); the menu earths it up, takes the soil down and levels it.
local M = TraditionalPreservationFruitVegetables
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"

-- What goes in (user: no leek, it stays in the ground; onions and garlic want dry air, sweet potatoes chill).
M.CLAMP_CROPS = { "potato", "turnip", "sugarBeet", "carrots", "cabbage" }
M.CLAMP_TAKES = {}
for _, name in ipairs(M.CLAMP_CROPS) do M.CLAMP_TAKES[M.CROPS[name].fullType] = true end

-- Earthed over above this, the crops sweat (user, session 77): their keeping counts SWEAT_RATE times.
M.SWEAT_C = 8
M.SWEAT_RATE = 1.5
-- Save key of a vegetable's sweating record (a FluidAgeing age on its keeper's ledger). Never rename it.
M.SWEAT_KEY = "tpfvSweat"
-- Vanilla's puddles (IsoPuddles, 0 to 0.7) from which the trenches show water.
M.CLAMP_WET_PUDDLES = 0.1
-- Minutes of work, on the game clock: digging one, earthing up, taking the soil down, levelling an empty one (user,
-- session 77: 20 to 30 minutes).
M.CLAMP_MINUTES = { dig = 30, earth = 30, unearth = 20, level = 20 }
-- The straw a clamp is heaped under, used up as it is dug.
M.CLAMP_HAY = { fullType = "Base.HayTuft", count = 6 }

function M.isClamp(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and sprite:getName() == Tiles.CLAMP.tile
end

-- Earthed up or not is the clamp's container type (Tiles.CLAMP.container under straw, .earthedContainer earthed up),
-- saved with the object: the place of what lies in it and the loot window's title and icon all follow it.
function M.clampEarthed(isoObject)
    local container = isoObject:getContainer()
    return container ~= nil and container:getType() == Tiles.CLAMP.earthedContainer
end

function M.setClampEarthed(isoObject, earthed)
    local container = isoObject:getContainer()
    if not container then return end
    container:setType(earthed and Tiles.CLAMP.earthedContainer or Tiles.CLAMP.container)
    -- An open loot window redraws its buttons (the icon) and title.
    if triggerEvent then triggerEvent("OnContainerUpdate") end
end

-- The place of what lies in a clamp: StrawClamp under straw, EarthedClamp earthed over.
function M.clampPlace(isoObject)
    return isoObject and M.clampEarthed(isoObject) and "EarthedClamp" or "StrawClamp"
end

FluidAgeing.CONTAINER_PLACES[Tiles.CLAMP.container] = function() return "StrawClamp" end
FluidAgeing.CONTAINER_PLACES[Tiles.CLAMP.earthedContainer] = function() return "EarthedClamp" end

-- The clamp's AcceptItemFunction (set by the World on each clamp it sees): only the clamped crops, raw.
function M.acceptClamp(_, item)
    return M.CLAMP_TAKES[item:getFullType()] == true and not item:isCooked() and not item:isBurnt()
end
M.CLAMP_ACCEPT = "TraditionalPreservationFruitVegetables.acceptClamp"

-- Why a clamp can't be dug here now, or nil. diggable: TP Core's Ground.diggable (vanilla's furrow rule, the grass
-- removed, under the sky); grass: grass still on it; hay: hay in reach.
function M.digRefusal(diggable, hay, hasShovel, grass)
    if not hasShovel then return "NoShovel" end
    if grass then return "Grass" end
    if not diggable then return "NoGround" end
    if hay < M.CLAMP_HAY.count then return "NoHay" end
    return nil
end

-- Makes a clamp on square, under straw: the tile's object with its container (as vanilla puts furniture down).
function M.makeClamp(square)
    local clamp = IsoObject.new(getCell(), square, getSprite(Tiles.CLAMP.tile))
    clamp:createContainersFromSpriteProperties()
    for i = 0, clamp:getContainerCount() - 1 do clamp:getContainerByIndex(i):setExplored(true) end
    square:AddTileObject(clamp)
    return clamp
end

-- Why a clamp can't be earthed up, taken down or levelled now, or nil. hasShovel: a shovel in reach.
function M.clampRefusal(mode, earthed, itemCount, hasShovel)
    if mode == "earth" and earthed then return "Earthed" end
    if mode == "unearth" and not earthed then return "NotEarthed" end
    if mode == "level" and itemCount > 0 then return "NotEmpty" end
    if not hasShovel then return "NoShovel" end
    return nil
end

-- Each keeper's sweating, a second ageing on its ledger: the keeper's own rate times SWEAT_RATE - 1 above SWEAT_C,
-- none at or below it.
local function sweatCurve(keeper)
    local extra = M.SWEAT_RATE - 1
    local above = M.SWEAT_C + 0.001
    local curve = { { M.SWEAT_C, 0 }, { above, keeper.ageRate(above) * extra } }
    for _, point in ipairs(keeper.keepingRules.curve) do
        if point[1] > above then table.insert(curve, { point[1], point[2] * extra }) end
    end
    return curve
end
for _, name in ipairs(M.CLAMP_CROPS) do
    local crop = M.CROPS[name]
    for _, keeper in ipairs({ crop.keeper, crop.curedKeeper }) do
        keeper.sweat = keeper.addAgeing(keeper.keepingRules.process .. "Sweat", sweatCurve(keeper))
    end
end

-- Adds the sweating since the last look to a vegetable's keeping (clock: its keeper's, just brought up to now): the
-- stretch counts only if it lay in an earthed clamp. A record starts in an earthed clamp and ends once out of one.
-- Returns the hours of keeping added.
function M.sweat(item, now, keeper, clock)
    if not keeper.sweat then return 0 end
    local itemModData = item:getModData()
    local record = itemModData[M.SWEAT_KEY]
    local place = clock.fluidAge.place
    local hours = 0
    if record and record.process == keeper.sweat.process then
        local was, before = record.place, record.age
        FluidAgeing.advance(record, keeper.sweat, keeper.ledger(), now, place)
        if was == "EarthedClamp" then hours = record.age - before end
    else
        record = nil
    end
    if place == "EarthedClamp" then
        itemModData[M.SWEAT_KEY] = record or FluidAgeing.newFluidAge(keeper.sweat, keeper.ledger(), now, place)
    else
        itemModData[M.SWEAT_KEY] = nil
    end
    if hours > 0 then
        clock.fluidAge.age = clock.fluidAge.age + hours
        item:setAge(clock.base + clock.fluidAge.age / 24)
    end
    return hours
end
