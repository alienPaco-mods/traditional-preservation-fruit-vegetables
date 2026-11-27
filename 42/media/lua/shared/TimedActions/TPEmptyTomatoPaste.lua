-- Traditional Preservation (Fruits and Vegetables): empties a crock or jar of tomato paste, rotten or not, and gives
-- the vessel back (M.emptyCrock).
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPEmptyTomatoPaste = ISBaseTimedAction:derive("TPEmptyTomatoPaste")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 60

function TPEmptyTomatoPaste:isValid()
    return self.character:getInventory():containsRecursive(self.crock)
end

function TPEmptyTomatoPaste:start()
    self:setActionAnim("Loot")
end

function TPEmptyTomatoPaste:complete()
    M.emptyCrock(self.crock)
    return true
end

function TPEmptyTomatoPaste:perform()
    ISBaseTimedAction.perform(self)
end

function TPEmptyTomatoPaste:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPEmptyTomatoPaste:new(character, crock)
    local o = ISBaseTimedAction.new(self, character)
    o.crock = crock
    o.maxTime = o:getDuration()
    return o
end
