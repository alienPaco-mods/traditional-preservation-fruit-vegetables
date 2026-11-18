-- Checks garlic and onion braids (TraditionalPreservationFruitVegetablesBraid.lua): what goes in, braiding and
-- unbraiding. Run from the mod folder: luajit tests/test_braid.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables

local function inventory()
    local self = { items = {} }
    function self:AddItem(item)
        if type(item) == "string" then
            local fullType = item
            item = { fullType = fullType, getFullType = function() return fullType end }
            local inside = inventory()
            item.getInventory = function() return inside end
        end
        table.insert(self.items, item)
        return item
    end
    function self:Remove(item)
        for i, held in ipairs(self.items) do if held == item then return table.remove(self.items, i) end end
    end
    function self:getItems() return H.list(self.items) end
    return self
end
local function bulb(fullType, rotten)
    return { getFullType = function() return fullType end, isRotten = function() return rotten == true end,
        isCooked = function() return false end, isBurnt = function() return false end }
end

check("a garlic braid takes garlic only, up to 10", (function()
    local inside = inventory()
    if not M.acceptGarlicBraid(inside, bulb("Base.Garlic")) or M.acceptGarlicBraid(inside, bulb("Base.Onion")) then return false end
    for _ = 1, 10 do inside:AddItem(bulb("Base.Garlic")) end
    return not M.acceptGarlicBraid(inside, bulb("Base.Garlic")) and M.acceptOnionBraid(inventory(), bulb("Base.Onion"))
end)())
check("a rotten bulb can't be braided", not M.braidable(bulb("Base.Garlic", true), "garlic") and M.braidable(bulb("Base.Onion"), "onion"))

local bag = inventory()
local bulbs = {}
for i = 1, 12 do bulbs[i] = bag:AddItem(bulb("Base.Garlic")) end
local braid = M.braid(bag, bulbs, "garlic")
check("braiding: 10 go into the braid, 2 stay loose", #braid:getInventory().items == 10 and #bag.items == 3
    and braid:getFullType() == "TraditionalPreservationFruitVegetables.GarlicBraid")
M.unbraid(bag, braid)
check("unbraiding: all 12 loose again, the braid gone", #bag.items == 12)

-- The storages show a third, two thirds or full by weight
function isClient() return false end
MapObjects = { OnLoadWithSprite = function() end }
function getCell() return { getGridSquare = function() return nil end } end
dofile("42/media/lua/server/TraditionalPreservationFruitVegetablesWorld.lua")
local World = TraditionalPreservationFruitVegetablesWorld
check("empty shows nothing, a little a third, half two thirds, full full", World.storageLevel(0, 30, 3) == nil
    and World.storageLevel(0.2, 30, 3) == 1 and World.storageLevel(15, 30, 3) == 2 and World.storageLevel(30, 30, 3) == 3
    and World.storageLevel(31, 30, 3) == 3)

H.done()
