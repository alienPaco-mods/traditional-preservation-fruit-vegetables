-- Traditional Preservation (Fruits and Vegetables): packs tomato paste from a pot or saucepan (only paste in it), or
-- several (sources, a list), into
-- an empty clay jar or pot or a glass jar, under a salt crust and, with a seal, a cap of oil or fat
-- (TraditionalPreservationFruitVegetablesPaste.lua, M.packPaste).
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPPackTomatoPaste = ISBaseTimedAction:derive("TPPackTomatoPaste")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local Uses = require "TraditionalPreservationCore/Uses"
local DURATION = 120

function TPPackTomatoPaste:isValid()
    local inventory = self.character:getInventory()
    if not inventory:containsRecursive(self.vessel) then return false end
    for _, source in ipairs(self.sources) do
        if not inventory:containsRecursive(source) then return false end
    end
    local plan = M.packPlan(M.sourcesLitres(self.sources))
    if plan.portions < 1 or Uses.count(self.character, ItemTag.SALT) < plan.salt then return false end
    return not self.seal or self.seal:getCurrentUses() >= M.PASTE_SEAL_USES
end

function TPPackTomatoPaste:start()
    self:setActionAnim("Loot")
end

function TPPackTomatoPaste:complete()
    M.packPaste(self.character, self.sources, self.vessel, self.seal)
    return true
end

function TPPackTomatoPaste:perform()
    ISBaseTimedAction.perform(self)
end

function TPPackTomatoPaste:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPPackTomatoPaste:new(character, sources, vessel, seal)
    local o = ISBaseTimedAction.new(self, character)
    o.sources = sources
    o.vessel = vessel
    o.seal = seal
    o.maxTime = o:getDuration()
    return o
end
