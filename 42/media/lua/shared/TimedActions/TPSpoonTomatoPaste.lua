-- Traditional Preservation (Fruits and Vegetables): spoons a portion of Tomato Paste out of a crock or jar, as
-- stale or rotten as the crock is; the last spoonful gives the vessel back (M.spoonOut).
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPSpoonTomatoPaste = ISBaseTimedAction:derive("TPSpoonTomatoPaste")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 30

function TPSpoonTomatoPaste:isValid()
    return self.character:getInventory():containsRecursive(self.crock) and M.crockPortions(self.crock) >= M.PASTE_EMPTY
end

function TPSpoonTomatoPaste:start()
    self:setActionAnim("Loot")
end

function TPSpoonTomatoPaste:complete()
    M.spoonOut(self.character, self.crock)
    return true
end

function TPSpoonTomatoPaste:perform()
    ISBaseTimedAction.perform(self)
end

function TPSpoonTomatoPaste:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPSpoonTomatoPaste:new(character, crock)
    local o = ISBaseTimedAction.new(self, character)
    o.crock = crock
    o.maxTime = o:getDuration()
    return o
end
