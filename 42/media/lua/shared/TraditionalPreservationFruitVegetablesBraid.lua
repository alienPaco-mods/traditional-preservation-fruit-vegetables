-- Traditional Preservation (Fruits and Vegetables) B42: garlic and onion braids. Bulbs plaited by their own dry stalks,
-- up to BRAID_MAX in one: only lighter to carry (the braid's WeightReduction); they keep and cure inside as loose ones
-- do, and on a Drying Pole count as hung there (the cellar looks through containers). Braid and Unbraid are a hand job
-- from the right-click menu (TPBraid). Required by TraditionalPreservationFruitVegetables.lua, whose M it adds to.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables

M.BRAID_MAX = 10
M.BRAID_MIN = 2
M.BRAIDS = {
    garlic = { bulb = "Base.Garlic", braid = "TraditionalPreservationFruitVegetables.GarlicBraid" },
    onion = { bulb = "Base.Onion", braid = "TraditionalPreservationFruitVegetables.OnionBraid" },
}
M.BRAID_OF_BULB, M.BRAID_KIND = {}, {}
for kind, braid in pairs(M.BRAIDS) do
    M.BRAID_OF_BULB[braid.bulb] = kind
    M.BRAID_KIND[braid.braid] = kind
end

-- A bulb that can be braided: its kind, not rotten, cooked or burnt.
function M.braidable(item, kind)
    return item:getFullType() == M.BRAIDS[kind].bulb and not item:isRotten() and not item:isCooked() and not item:isBurnt()
end

-- The braids' AcceptItemFunction: only their own bulbs go in, up to BRAID_MAX.
local function accepts(kind)
    return function(container, item)
        return item:getFullType() == M.BRAIDS[kind].bulb and container:getItems():size() < M.BRAID_MAX
    end
end
M.acceptGarlicBraid = accepts("garlic")
M.acceptOnionBraid = accepts("onion")

-- Plaits bulbs (a list, up to BRAID_MAX, all of kind) from inventory into a new braid there. Returns the braid.
function M.braid(inventory, bulbs, kind)
    local braid = inventory:AddItem(M.BRAIDS[kind].braid)
    local inside = braid:getInventory()
    for i = 1, math.min(#bulbs, M.BRAID_MAX) do
        inventory:Remove(bulbs[i])
        inside:AddItem(bulbs[i])
    end
    return braid
end

-- Unplaits a braid in inventory: its bulbs back there, the braid gone.
function M.unbraid(inventory, braid)
    local inside = braid:getInventory()
    local items = inside:getItems()
    for i = items:size() - 1, 0, -1 do
        local bulb = items:get(i)
        inside:Remove(bulb)
        inventory:AddItem(bulb)
    end
    inventory:Remove(braid)
end
