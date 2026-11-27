-- Traditional Preservation (Fruits and Vegetables): adds tomato paste from a pot or saucepan, or several (sources,
-- a list), to a crock or jar already packed, under a fresh salt crust and, on a sealed crock, a fresh cap
-- (M.addToCrock); a salt-crust crock capped is sealed from then on.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPAddTomatoPaste = ISBaseTimedAction:derive("TPAddTomatoPaste")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local Uses = require "TraditionalPreservationCore/Uses"
local DURATION = 90

function TPAddTomatoPaste:isValid()
    local inventory = self.character:getInventory()
    if not inventory:containsRecursive(self.crock) or self.crock:isRotten() then return false end
    for _, source in ipairs(self.sources) do
        if not inventory:containsRecursive(source) then return false end
    end
    if M.topUpPlan(M.sourcesLitres(self.sources), self.crock).portions <= 0 then return false end
    if Uses.count(self.character, ItemTag.SALT) < M.TOPUP_SALT then return false end
    if self.crock:getFullType() == M.CROCK_SEALED and not self.seal then return false end
    return not self.seal or self.seal:getCurrentUses() >= M.addSealUses(self.crock, self.seal)
end

function TPAddTomatoPaste:start()
    self:setActionAnim("Loot")
end

function TPAddTomatoPaste:complete()
    M.addToCrock(self.character, self.sources, self.crock, self.seal)
    return true
end

function TPAddTomatoPaste:perform()
    ISBaseTimedAction.perform(self)
end

function TPAddTomatoPaste:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPAddTomatoPaste:new(character, sources, crock, seal)
    local o = ISBaseTimedAction.new(self, character)
    o.sources = sources
    o.crock = crock
    o.seal = seal
    o.maxTime = o:getDuration()
    return o
end
