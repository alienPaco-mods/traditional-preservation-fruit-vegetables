-- Traditional Preservation (Fruits and Vegetables): Braid Garlic / Braid Onions, plaiting carried bulbs into a braid,
-- and Unbraid. The bulbs and the braid must still be in the inventory as it ends.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPBraid = ISBaseTimedAction:derive("TPBraid")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local TICKS_PER_BULB, UNBRAID_TICKS = 20, 60

local function carried(self)
    local inventory = self.character:getInventory()
    if self.braid then return inventory:contains(self.braid) end
    for _, bulb in ipairs(self.bulbs) do
        if not inventory:contains(bulb) then return false end
    end
    return true
end

function TPBraid:isValid()
    return carried(self)
end

function TPBraid:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TPBraid:complete()
    if not carried(self) then return false end
    if self.braid then
        M.unbraid(self.character:getInventory(), self.braid)
    else
        M.braid(self.character:getInventory(), self.bulbs, self.kind)
    end
    return true
end

function TPBraid:perform()
    ISBaseTimedAction.perform(self)
end

function TPBraid:getDuration()
    return Action.duration(self.character, self.braid and UNBRAID_TICKS or TICKS_PER_BULB * #self.bulbs)
end

-- bulbs and kind to braid, or braid to unbraid.
function TPBraid:new(character, bulbs, kind, braid)
    local o = ISBaseTimedAction.new(self, character)
    o.bulbs = bulbs or {}
    o.kind = kind
    o.braid = braid
    o.maxTime = o:getDuration()
    return o
end
