-- Traditional Preservation (Fruits and Vegetables): the hand jobs at a Kraut Barrel. "pack" shreds and packs one head
-- (a cabbage or a turnip; they mix) or one apple or carrot, "unpack" takes everything packed back out before it is salted and compressed,
-- "compress" lays the cloth, the board and the stone on it with the salt (sealing it), "take" takes one portion out of a
-- ready barrel, "empty" empties a spoiled one, and "unseal" lifts the board and stone off (they come back only so). The
-- brine (user, 2026-11-27): "starter" pours 1 L of Kraut Brine from item onto a packing barrel, "draw" draws 1 L off a
-- ready one into item, "drain" fills item from a barrel of brine, "pour" pours item's brine into an empty barrel or
-- one of brine, and "putback" puts a portion (item) back under the brine.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationFruitVegetables"

TPKrautBarrel = ISBaseTimedAction:derive("TPKrautBarrel")

local M = TraditionalPreservationFruitVegetables
local Action = require "TraditionalPreservationCore/Action"
local Uses = require "TraditionalPreservationCore/Uses"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local DURATIONS = { pack = 120, unpack = 150, compress = 250, take = 40, empty = 150, starter = 60, draw = 60, drain = 120,
    pour = 120, putback = 40, unseal = 100 }

-- Brought up to the minute first, so a barrel that has just turned is seen as it is now.
local function barrelNow(self)
    TraditionalPreservationFruitVegetablesWorld.refresh(self.station)
    return M.barrelOf(self.station)
end

local function inInventory(self, item)
    return item ~= nil and self.character:getInventory():containsRecursive(item)
end

-- What the character has in reach for salting and compressing, as M.compressRefusal reads it, and the cloth, board and stone.
function TPKrautBarrel.compressKit(character)
    local inventory = character:getInventory()
    local function first(fullTypes)
        for fullType in pairs(fullTypes) do
            local item = inventory:getFirstTypeRecurse(fullType)
            if item then return item end
        end
    end
    local kit = {
        cloth = first(M.CLOTHS),
        board = inventory:getFirstTypeRecurse(M.BOARD),
        stone = inventory:getFirstTypeRecurse(M.STONE),
    }
    kit.salt = Uses.count(character, ItemTag.SALT)
    return kit
end

-- Why this piece can't be packed, or nil: a kraut head or an extra.
local function packRefusal(barrel, item)
    local kind = M.KRAUT_OF_HEAD[item:getFullType()]
    if kind then return M.packRefusal(barrel) end
    return M.extraRefusal(barrel, M.EXTRA_OF_TYPE[item:getFullType()])
end
TPKrautBarrel.packRefusal = packRefusal

function TPKrautBarrel:isValid()
    if not self.station:getSquare() then return false end
    local barrel = M.barrelOf(self.station)
    local stage = M.barrelStage(barrel)
    if self.mode == "pack" then
        return inInventory(self, self.item) and not self.item:isRotten() and packRefusal(barrel, self.item) == nil
    elseif self.mode == "unpack" then
        return stage == "Packing"
    elseif self.mode == "compress" then
        -- The kit is looked for once, before the action starts, and again as it ends: not on every tick.
        return self.started or M.compressRefusal(barrel, TPKrautBarrel.compressKit(self.character)) == nil
    elseif self.mode == "take" then
        return stage == "Ready" and M.portionsLeft(barrel, self.kind) > 0 and not M.pressed(barrel)
    elseif self.mode == "starter" then
        return inInventory(self, self.item) and M.onlyFluid(self.item, M.KRAUT_BRINE) >= M.STARTER_L - 1e-6
            and M.starterRefusal(barrel) == nil
    elseif self.mode == "draw" then
        return inInventory(self, self.item) and M.roomFor(self.item, M.KRAUT_BRINE) >= M.STARTER_L - 1e-6 and M.drawRefusal(barrel) == nil
    elseif self.mode == "drain" then
        return inInventory(self, self.item) and stage == "Brine" and not M.pressed(barrel)
            and M.roomFor(self.item, barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE) > 0
    elseif self.mode == "pour" then
        return inInventory(self, self.item) and M.onlyFluid(self.item, M.KRAUT_BRINE) > 0 and M.pourRefusal(barrel) == nil
    elseif self.mode == "unseal" then
        return M.unsealRefusal(barrel) == nil
    elseif self.mode == "putback" then
        return inInventory(self, self.item) and M.KRAUT_OF_PRODUCT[self.item:getFullType()] ~= nil
            and M.putBackRefusal(barrel, M.isFreshKraut(self.item)) == nil
    end
    return stage == "Spoiled"
end

function TPKrautBarrel:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPKrautBarrel:start()
    self.started = true
    self:setActionAnim("Loot")
end

-- The board and stone, back when it is unsealed (user, 2026-11-27: Unseal, not the last portion, gives them back).
local function givePress(character)
    Actions.addOrDropItem(character, instanceItem(M.BOARD))
    Actions.addOrDropItem(character, instanceItem(M.STONE))
end

function TPKrautBarrel:complete()
    local barrel = barrelNow(self)
    local character = self.character
    local now = getGameTime():getWorldAgeHours()
    if self.mode == "pack" then
        if inInventory(self, self.item) and packRefusal(barrel, self.item) == nil then
            local kind = M.KRAUT_OF_HEAD[self.item:getFullType()]
            if kind then
                M.pack(barrel, kind, self.item:getAge(), M.foodOf(self.item), now, self.item:getOffAge())
            else
                M.packExtra(barrel, M.EXTRA_OF_TYPE[self.item:getFullType()], self.item:getAge(), M.foodOf(self.item), now)
            end
            Action.removeItem(self.item)
        end
    elseif self.mode == "unpack" then
        for _, piece in ipairs(M.unpack(barrel, now)) do
            if piece.brine then
                -- The starter back into a carried container with room for it; with none, it is poured away.
                local into = TPKrautBarrel.brineContainer(character, piece.brine)
                if into then M.fillWith(into, M.KRAUT_BRINE, piece.brine) end
            else
                local item = instanceItem(piece.fullType)
                item:setAge(piece.age)
                Actions.addOrDropItem(character, item)
            end
        end
    elseif self.mode == "starter" then
        if M.onlyFluid(self.item, M.KRAUT_BRINE) >= M.STARTER_L - 1e-6 and M.addStarter(barrel) then
            M.takeFluid(self.item, M.KRAUT_BRINE, M.STARTER_L)
        end
    elseif self.mode == "draw" then
        if M.roomFor(self.item, M.KRAUT_BRINE) >= M.STARTER_L - 1e-6 then
            M.fillWith(self.item, M.KRAUT_BRINE, M.drawStarter(barrel))
        end
    elseif self.mode == "drain" then
        local fluid = barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE
        local room = M.roomFor(self.item, fluid)
        if room > 0 then
            local litres, drained, fluidAge = M.drainBrine(barrel, room)
            M.fillWith(self.item, drained or fluid, litres, fluidAge)
        end
    elseif self.mode == "pour" then
        local litres = M.onlyFluid(self.item, M.KRAUT_BRINE)
        local fluidAge = FluidAgeing.sourceFluidAge(self.item, now)
        local took = M.pourBrine(barrel, litres, fluidAge)
        if took > 0 then M.takeFluid(self.item, M.KRAUT_BRINE, took) end
    elseif self.mode == "putback" then
        local item = self.item
        local kind = M.KRAUT_OF_PRODUCT[item:getFullType()]
        if kind and M.putBack(barrel, kind, M.foodOf(item), item:getAge(), item:getModData()[M.KRAUT_SOFT_KEY] == true,
            M.getLedger()) then
            Action.removeItem(item)
        end
    elseif self.mode == "compress" then
        local kit = TPKrautBarrel.compressKit(character)
        if M.compressRefusal(barrel, kit) == nil then
            Uses.take(character, ItemTag.SALT, M.saltNeeded(M.headCount(barrel)))
            Action.removeItem(kit.cloth)
            Action.removeItem(kit.board)
            Action.removeItem(kit.stone)
            -- Packing's xp comes here, not as each piece goes in: Unpack gives them back, so packing again would pay again.
            local pieces = M.headCount(barrel) + M.extraCount(barrel, "apple") + M.extraCount(barrel, "carrot")
            M.compress(barrel, M.getLedger(), now)
            character:getXp():AddXP(Perks.Cooking, M.COMPRESS_XP + M.PACK_XP * pieces)
        end
    elseif self.mode == "take" then
        local taken = M.takePortion(barrel, self.kind)
        if taken then
            local item = instanceItem(M.KRAUTS[taken.kind].product)
            M.applyPortion(item, taken)
            Actions.addOrDropItem(character, item)

        end
    elseif self.mode == "unseal" then
        if M.unseal(barrel) then givePress(character) end
    else
        M.emptySpoiled(barrel)
    end
    TraditionalPreservationFruitVegetablesWorld.refresh(self.station)
    return true
end

function TPKrautBarrel:perform()
    ISBaseTimedAction.perform(self)
end

function TPKrautBarrel:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- A carried container with room for litres of Kraut Brine (empty, or holding only it), or nil.
function TPKrautBarrel.brineContainer(character, litres)
    local found
    local items = character:getInventory():getAllEvalRecurse(function(item)
        return M.roomFor(item, M.KRAUT_BRINE) >= litres - 1e-6
    end)
    if items:size() > 0 then found = items:get(0) end
    return found
end

-- item is the head, apple or carrot for "pack", the container for the brine's modes, the portion for "putback"; kind
-- the kraut to take ("cabbage" or "turnip") for "take".
function TPKrautBarrel:new(character, station, mode, item, kind)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.kind = kind
    o.maxTime = o:getDuration()
    return o
end
