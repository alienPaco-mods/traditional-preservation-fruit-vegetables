-- Traditional Preservation (Fruits and Vegetables) B42: Braid and Unbraid on garlic and onions, the door rule for the
-- storages, and the cellar's look at vegetables (TP Core's PlaceKeepingUI). The kraut's rows and pieces on TP Core's
-- Brine Barrel are ...KrautUI.lua; the barrel's menu and window are Core's.
local UI = require "TraditionalPreservationCore/UI"
local KeepingTooltip = require "TraditionalPreservationCore/KeepingTooltip"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
require "TraditionalPreservationFruitVegetablesKrautUI"

local M = TraditionalPreservationFruitVegetables
local say = UI.say
local KEY = "IGUI_TraditionalPreservationFruitVegetables_"

-- No storage is put down in front of a door (TP Core's Doors).
local storageTiles = {}
for _, storage in pairs(Tiles.STORAGES) do table.insert(storageTiles, storage.tile) end
table.sort(storageTiles)
UI.keepDoorsFree(storageTiles)

-- Braid Garlic / Braid Onions on selected bulbs (up to BRAID_MAX), and Unbraid on braids. What is selected but not
-- carried is brought into the inventory first.
local function onBraid(playerObj, bulbs, kind)
    for _, bulb in ipairs(bulbs) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bulb) end
    ISTimedActionQueue.add(TPBraid:new(playerObj, bulbs, kind))
end

local function onUnbraid(playerObj, braids)
    for _, braid in ipairs(braids) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, braid)
        ISTimedActionQueue.add(TPBraid:new(playerObj, nil, nil, braid))
    end
end

local function onFillInventoryMenu(playerNum, context, items)
    local bulbs, braids = { garlic = {}, onion = {} }, {}
    for _, entry in ipairs(items) do
        for _, item in ipairs(entry.items or { entry }) do
            local kind = M.BRAID_OF_BULB[item:getFullType()]
            if kind and M.braidable(item, kind) and #bulbs[kind] < M.BRAID_MAX then
                local seen = false
                for _, bulb in ipairs(bulbs[kind]) do if bulb == item then seen = true end end
                if not seen then table.insert(bulbs[kind], item) end
            elseif M.BRAID_KIND[item:getFullType()] then
                table.insert(braids, item)
            end
        end
    end
    local playerObj = getSpecificPlayer(playerNum)
    for _, kind in ipairs({ "garlic", "onion" }) do
        if #bulbs[kind] >= M.BRAID_MIN then
            local option = context:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_Braid_" .. kind, #bulbs[kind]),
                playerObj, onBraid, bulbs[kind], kind)
            option.iconTexture = getTexture("media/textures/Item_" .. (kind == "garlic" and "GarlicBraid" or "OnionBraid") .. ".png")
        end
    end
    if #braids > 0 then
        context:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Unbraid"), playerObj, onUnbraid, braids)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)

-- The storages' own icons in the loot window (vanilla shows the shelves for a container type it doesn't know).
local CONTAINER_ICONS = { pole = "DryingPole", hayCrate = "HayCrate", sandCrate = "SandCrate" }
for key, name in pairs(CONTAINER_ICONS) do
    UI.containerIcon(Tiles.STORAGES[key].container, "media/textures/Container_" .. name .. ".png")
end

-- Vegetables catch up on their keeping whenever they are looked at or moved (TP Core's PlaceKeepingUI).
PlaceKeepingUI.watch({ keep = M.keepVegetable }, M.CROP_OF_TYPE)
-- Kraut out of the barrel catches up on its frost the same way.
PlaceKeepingUI.watch({ keep = M.keepKraut }, M.KRAUT_OF_PRODUCT)

-- A vegetable's tooltip (TP Core's KeepingTooltip): how long it keeps where it is, then the storage it lies in (its
-- ageing and curing factors) and its cure's progress.
local function factorText(factor)
    return (string.format("%.2f", factor):gsub("0+$", ""):gsub("%.$", ""))
end

local function vegetableLines(item)
    local forecast = M.forecast(item)
    local lines = forecast and KeepingTooltip.forecastLines(forecast)
    if not lines then return nil end
    local crop = M.CROP_OF_TYPE[item:getFullType()]
    if forecast.storage then
        local name = getText("IGUI_ContainerTitle_" .. Tiles.STORAGES[forecast.storage].container)
        local keep = factorText(M.storageKeepFactor(crop, forecast.storage))
        if crop.cure and not (forecast.cure and forecast.cure.cured) then
            table.insert(lines, say(KEY .. "KeepInCure", name, keep, factorText(M.storageCureFactor(crop, forecast.storage))))
        else
            table.insert(lines, say(KEY .. "KeepIn", name, keep))
        end
    end
    local cure = forecast.cure
    if cure then
        local kind = getText(KEY .. "CureKind_" .. cure.kind)
        if cure.cured then
            table.insert(lines, say(KEY .. "Cured", kind))
        elseif cure.hoursLeft then
            table.insert(lines, say(KEY .. "Curing", kind, UI.percent(cure.share), UI.durationText(cure.hoursLeft)))
        else
            table.insert(lines, say(KEY .. "CuringWaits", kind, UI.percent(cure.share)))
        end
    end
    return lines
end

KeepingTooltip.add(M.CROP_OF_TYPE, vegetableLines)
