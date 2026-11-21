-- Traditional Preservation (Fruits and Vegetables): the shovel work at a clamp, on the game clock (M.CLAMP_MINUTES).
-- "dig" digs a new one on a square (trenches either side, the hay heaped as straw), "earth" throws the soil from the
-- trenches over the straw (Earth Up), "unearth" takes it back down in spring, "level" digs an empty clamp back into the
-- ground, its straw lost.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"
local Action = require "TraditionalPreservationCore/Action"
local Ground = require "TraditionalPreservationCore/Ground"

TPClamp = ISBaseTimedAction:derive("TPClamp")

local M = TraditionalPreservationFruitVegetables

local function itemCount(station)
    local container = station:getContainer()
    return container and container:getItems():size() or 0
end

-- A clamp already standing on the square.
function TPClamp.clampOn(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        if M.isClamp(objects:get(i)) then return objects:get(i) end
    end
    return nil
end

-- Why a clamp can't be dug on square by character now, or nil.
function TPClamp.digRefusal(character, square, shovel)
    local hay = character:getInventory():getCountTypeRecurse(M.CLAMP_HAY.fullType)
    local diggable = Ground.diggable(square) and TPClamp.clampOn(square) == nil
    return M.digRefusal(diggable, hay, shovel ~= nil and not shovel:isBroken(), Ground.hasGrass(square))
end

function TPClamp:isValid()
    local inventory = self.character:getInventory()
    if not inventory:containsRecursive(self.shovel) then return false end
    if self.mode == "dig" then
        -- Looked at once before it starts: the hay and the ground don't change while digging.
        return self.started or TPClamp.digRefusal(self.character, self.square, self.shovel) == nil
    end
    if not self.station:getSquare() then return false end
    return M.clampRefusal(self.mode, M.clampEarthed(self.station), itemCount(self.station), not self.shovel:isBroken()) == nil
end

function TPClamp:face()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function TPClamp:waitToStart()
    self:face()
    return self.character:shouldBeTurning()
end

function TPClamp:start()
    self.started = true
    Action.startClock(self)
    self:setActionAnim(BuildingHelper.getShovelAnim(self.character:getPrimaryHandItem()))
    self.sound = getSoundManager():PlayWorldSound("Shoveling", self.square, 0, 10, 1, true)
end

-- Runs on the game clock, so it takes the same in-game time at any Day Length.
function TPClamp:update()
    self:face()
    Action.clockProgress(self, self.shovel, M.CLAMP_MINUTES[self.mode])
end

function TPClamp:stopSound()
    if self.sound and self.sound:isPlaying() then self.sound:stop() end
end

function TPClamp:stop()
    self:stopSound()
    self.shovel:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end

function TPClamp:perform()
    self:stopSound()
    self.shovel:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function TPClamp:complete()
    local World = TraditionalPreservationFruitVegetablesWorld
    if self.mode == "dig" then
        if TPClamp.digRefusal(self.character, self.square, self.shovel) ~= nil then return false end
        local inventory = self.character:getInventory()
        for _ = 1, M.CLAMP_HAY.count do
            local hay = inventory:getFirstTypeRecurse(M.CLAMP_HAY.fullType)
            Action.removeItem(hay)
        end
        local clamp = M.makeClamp(self.square)
        if World then World.refreshClamp(clamp) end
        return true
    end
    if self.mode == "level" then
        if World then World.forgetClamp(self.station) end
        self.square:transmitRemoveItemFromSquare(self.station)
        return true
    end
    -- What lies in it catches up at the place it was in before the soil went on or came off, then is seen again so it
    -- counts from the new place on.
    local container = self.station:getContainer()
    local function lookAtAll()
        if not container then return end
        local items = container:getItems()
        for i = 0, items:size() - 1 do M.keepVegetable(items:get(i)) end
    end
    lookAtAll()
    M.setClampEarthed(self.station, self.mode == "earth")
    lookAtAll()
    if World then World.refreshClamp(self.station) end
    return true
end

function TPClamp:getDuration()
    return -1
end

-- mode: "dig" (target: the square), or "earth", "unearth", "level" (target: the clamp); shovel: the tool
-- (base:takedirt) in the character's inventory.
function TPClamp:new(character, target, mode, shovel)
    local o = ISBaseTimedAction.new(self, character)
    o.mode = mode
    if mode == "dig" then
        o.square = target
    else
        o.station = target
        o.square = target:getSquare()
    end
    o.shovel = shovel
    o.maxTime = o:getDuration()
    o.caloriesModifier = 8
    return o
end
