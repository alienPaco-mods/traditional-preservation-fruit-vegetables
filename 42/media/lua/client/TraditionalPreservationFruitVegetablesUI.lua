-- Traditional Preservation (Fruits and Vegetables) B42: the Kraut Barrel's right-click menu (pack, unpack, salt and compress,
-- take kraut out, empty a spoiled one) and its Info window (TP Core's InfoWindow), opened from the menu or by clicking
-- the barrel; Braid and Unbraid on garlic and onions; the door rule for the barrel and the storages; and the cellar's
-- look at vegetables (TP Core's PlaceKeepingUI).
local UI = require "TraditionalPreservationCore/UI"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"

local M = TraditionalPreservationFruitVegetables
local say = UI.say
local tooltipFor, refuse, findItems = UI.tooltip, UI.refuse, UI.findItems
local BARREL_ICON = "media/textures/Item_KrautBarrel.png"
local ICONS = { cabbage = "Item_Cabbage", turnip = "Item_Turnip", apple = "Item_Apple", carrot = "Item_Carrots",
    Sauerkraut = "media/textures/Item_Sauerkraut.png", SauerTurnip = "media/textures/Item_SauerTurnip.png" }
local KrautWindow -- the info window, below the menu

local REFUSALS = {
    Sealed = "IGUI_TraditionalPreservationFruitVegetables_Sealed",
    Full = "IGUI_TraditionalPreservationFruitVegetables_Full",
    NoHeads = "IGUI_TraditionalPreservationFruitVegetables_NoHeads",
    TooMany = "IGUI_TraditionalPreservationFruitVegetables_TooMany",
    TooFew = "IGUI_TraditionalPreservationFruitVegetables_TooFew",
    NoSalt = "IGUI_TraditionalPreservationFruitVegetables_NoSalt",
    NoCloth = "IGUI_TraditionalPreservationFruitVegetables_NoCloth",
    NoBoard = "IGUI_TraditionalPreservationFruitVegetables_NoBoard",
    NoStone = "IGUI_TraditionalPreservationFruitVegetables_NoStone",
    NoneCarried = "IGUI_TraditionalPreservationFruitVegetables_NoneCarried",
}

local STATIONS = {}
for _, name in ipairs(Tiles.STATIONS) do STATIONS[name] = true end

local function isBarrel(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and STATIONS[sprite:getName()] == true
end

local function refusalText(refusal, barrel)
    return say(REFUSALS[refusal], M.BARREL_MIN, M.saltNeeded(M.headCount(barrel)), M.HEADS_PER_EXTRA)
end

local function barrelNow(station)
    if TraditionalPreservationFruitVegetablesWorld then return TraditionalPreservationFruitVegetablesWorld.updateBarrel(station) end
    return M.barrelOf(station)
end

-- One action a piece (false: an action with none); carry is brought into the inventory first (the cloth, plank and
-- stone for Salt and Compress); kind is the kraut a "take" takes.
local function queue(playerObj, station, mode, items, carry, kind)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(carry or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    for _, item in ipairs(items or { false }) do
        if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
        ISTimedActionQueue.add(TPKrautBarrel:new(playerObj, station, mode, item or nil, kind))
    end
end

-- Pieces of fullType in reach that aren't rotten, oldest first.
local function piecesOf(playerObj, fullType)
    local found = findItems(playerObj, function(item) return item:getFullType() == fullType and not item:isRotten() end)
    table.sort(found, function(a, b) return a:getAge() > b:getAge() end)
    return found
end

local function firstOf(list, n)
    local picked = {}
    for i = 1, math.min(n, #list) do picked[i] = list[i] end
    return picked
end

-- One row a kind of piece: All (as many as are held, up to what the barrel takes) and One, or in red with the reason.
local function addPackRow(menu, playerObj, station, barrel, label, fullType, icon, refusal, room)
    local pieces = piecesOf(playerObj, fullType)
    local option = menu:addOption(getText(label))
    option.iconTexture = getTexture(icon)
    if refusal then return refuse(option, refusalText(refusal, barrel)) end
    if #pieces == 0 then return refuse(option, refusalText("NoneCarried", barrel)) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    local all = math.min(#pieces, room)
    if all > 1 then
        sub:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_All", all), playerObj, queue, station, "pack", firstOf(pieces, all))
    end
    sub:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_One"), playerObj, queue, station, "pack", { pieces[1] })
end

local function addPackMenu(menu, playerObj, station, barrel)
    local heads = M.headCount(barrel)
    for _, kind in ipairs(M.KRAUT_KINDS) do
        addPackRow(menu, playerObj, station, barrel, "ContextMenu_TraditionalPreservationFruitVegetables_Pack_" .. kind,
            M.KRAUTS[kind].head, ICONS[kind], M.packRefusal(barrel), M.BARREL_MAX - heads)
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        addPackRow(menu, playerObj, station, barrel, "ContextMenu_TraditionalPreservationFruitVegetables_Add_" .. extra,
            M.EXTRAS[extra], ICONS[extra], M.extraRefusal(barrel, extra), M.extraRoom(heads) - M.extraCount(barrel, extra))
    end
end

-- The cloth, board and stone in reach, and the salt's uses.
local function compressKit(playerObj)
    local function first(test)
        return findItems(playerObj, test)[1]
    end
    return {
        cloth = first(function(item) return M.CLOTHS[item:getFullType()] == true end),
        board = first(function(item) return item:getFullType() == M.BOARD end),
        stone = first(function(item) return item:getFullType() == M.STONE end),
        salt = require("TraditionalPreservationCore/Uses").count(playerObj, ItemTag.SALT),
    }
end

local function onCompress(playerObj, station, kit)
    queue(playerObj, station, "compress", nil, { kit.cloth, kit.board, kit.stone })
end

local function addCompressMenu(menu, playerObj, station, barrel)
    local kit = compressKit(playerObj)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_Compress", M.saltNeeded(M.headCount(barrel))),
        playerObj, onCompress, station, kit)
    option.iconTexture = getTexture("Item_FlatRock")
    local refusal = M.compressRefusal(barrel, kit)
    if refusal then
        refuse(option, refusalText(refusal, barrel))
    else
        tooltipFor(option, getText("IGUI_TraditionalPreservationFruitVegetables_CompressHelp"))
    end
end

-- One row a kraut still in the barrel: All (what is left) and One.
local function addTakeMenu(menu, playerObj, station, barrel)
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local left = M.portionsLeft(barrel, kind)
        if left > 0 then
            local product = M.KRAUTS[kind].product
            local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_Take", getItemNameFromFullType(product), left))
            option.iconTexture = getTexture(ICONS[product:match("%.(.+)$")])
            local sub = menu:getNew(menu)
            menu:addSubMenu(option, sub)
            if left > 1 then
                local all = {}
                for i = 1, left do all[i] = false end
                sub:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_All", left), playerObj, queue, station, "take", all, false, kind)
            end
            sub:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_One"), playerObj, queue, station, "take", { false }, false, kind)
        end
    end
end

local function stageText(barrel)
    local stage = M.barrelStage(barrel)
    if stage == "Ready" and barrel.soft then return getText("IGUI_TraditionalPreservationFruitVegetables_StageSoft") end
    return getText("IGUI_TraditionalPreservationFruitVegetables_Stage" .. stage)
end

local function contentsText(barrel)
    if M.barrelStage(barrel) == "Empty" then return getText("IGUI_TraditionalPreservationFruitVegetables_Nothing") end
    local apples = barrel.apples or M.extraCount(barrel, "apple")
    local carrots = barrel.carrots or M.extraCount(barrel, "carrot")
    return say("IGUI_TraditionalPreservationFruitVegetables_Contents", M.headCount(barrel, "cabbage"), M.headCount(barrel, "turnip"),
        apples, carrots)
end

-- What happens next and when, for the menu's hover and the window.
local function nextText(status)
    if status.stage == "Fermenting" then
        if not status.hoursLeft then return getText("IGUI_TraditionalPreservationFruitVegetables_Stalled") end
        return say("IGUI_TraditionalPreservationFruitVegetables_ReadyIn", UI.hoursText(status.hoursLeft))
    elseif status.stage == "Ready" then
        if not status.daysLeft then return getText("IGUI_TraditionalPreservationFruitVegetables_KeepsForever") end
        return say("IGUI_TraditionalPreservationFruitVegetables_KeepsFor", string.format("%.0f", status.daysLeft))
    end
    return getText("IGUI_TraditionalPreservationFruitVegetables_Help" .. status.stage)
end

local function statusOf(station, barrel)
    return M.barrelStatus(barrel, M.getLedger(), barrel.place or M.placeOf(station))
end

local function addBarrelMenu(context, playerObj, station)
    local barrel = barrelNow(station)
    local stage = M.barrelStage(barrel)
    local option = context:addOption(getText("IGUI_CraftingWindow_KrautBarrel"))
    option.iconTexture = getTexture(BARREL_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = statusOf(station, barrel)
    local statusOption = menu:addOption(stageText(barrel) .. ": " .. contentsText(barrel))
    statusOption.isDisabled = true
    tooltipFor(statusOption, UI.placeText(status.place, status.temperature) .. " <LINE> " .. nextText(status))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Info"), playerObj, KrautWindow.open, station)
    info.iconTexture = getTexture(BARREL_ICON)

    if stage == "Empty" or stage == "Packing" then
        addPackMenu(menu, playerObj, station, barrel)
        if stage == "Packing" then
            addCompressMenu(menu, playerObj, station, barrel)
            local unpack = menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Unpack"), playerObj, queue, station, "unpack", nil)
            tooltipFor(unpack, getText("IGUI_TraditionalPreservationFruitVegetables_UnpackHelp"))
        end
    elseif stage == "Ready" then
        addTakeMenu(menu, playerObj, station, barrel)
    elseif stage == "Spoiled" then
        menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Empty"), playerObj, queue, station, "empty", nil)
    end
end

-- Barrel Info: the stage, what is in it, the place and its heat, the ferment or the keeping, kept up to date while open.
local BAR_COLOURS = { ferment = { 0.62, 0.66, 0.38 }, keep = { 0.6, 0.57, 0.46 } }

KrautWindow = InfoWindow:derive("TraditionalPreservationFruitVegetablesKrautWindow")

function KrautWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_CraftingWindow_KrautBarrel")
    return o
end

function KrautWindow.open(playerObj, station)
    InfoWindow.open(KrautWindow, playerObj, station)
end

function KrautWindow:refresh()
    local barrel = barrelNow(self.station)
    self.barrelView = { barrel = barrel, status = statusOf(self.station, barrel) }
end

function KrautWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.barrelView then return end
    local barrel, status = self.barrelView.barrel, self.barrelView.status
    local y = self:top()
    y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoStage", stageText(barrel))
    y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoContents", contentsText(barrel))
    y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoPlace", UI.placeText(status.place, status.temperature))
    if status.stage == "Fermenting" then
        y = self:bar(y, "IGUI_TraditionalPreservationFruitVegetables_InfoFerment", status.progress, BAR_COLOURS.ferment, UI.percent(status.progress))
        y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoSpeed", UI.percent(status.rate))
        y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoTooWarm", UI.say("IGUI_TraditionalPreservationFruitVegetables_InfoTooWarmValue",
            string.format("%.0f", status.hotHours), M.HOT_SOFT_HOURS, M.HOT_SPOIL_HOURS))
    elseif status.stage == "Ready" then
        y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoPortions", say("IGUI_TraditionalPreservationFruitVegetables_InfoPortionsValue",
            M.portionsLeft(barrel, "cabbage"), M.portionsLeft(barrel, "turnip")))
        y = self:bar(y, "IGUI_TraditionalPreservationFruitVegetables_InfoKept", status.progress, BAR_COLOURS.keep, UI.percent(status.progress))
    end
    y = self:row(y, "IGUI_TraditionalPreservationFruitVegetables_InfoNext", nextText(status))
    local notes = { getText("IGUI_TraditionalPreservationFruitVegetables_Note" .. status.stage) }
    if status.stage == "Fermenting" or status.stage == "Ready" then table.insert(notes, getText("IGUI_TraditionalPreservationFruitVegetables_InfoAssumes")) end
    self:drawNotes(y, notes)
end

-- Clicking a barrel opens Barrel Info, as clicking a door opens it.
InfoWindow.clickOpens(isBarrel, function(playerObj, station)
    if TraditionalPreservationFruitVegetablesWorld then TraditionalPreservationFruitVegetablesWorld.track(station) end
    KrautWindow.open(playerObj, station)
end)

-- A barrel with anything in it stays where it is: packing, fermenting or kraut waiting, its time goes by its place
-- (user, 2026-11-19: no station is moved mid-process). Empty, it picks up as any moveable.
local barrelTiles = {}
for _, sprite in ipairs(Tiles.STATIONS) do barrelTiles[sprite] = true end
UI.keepInPlace(function(isoObject)
    local sprite = isoObject:getSprite()
    if not (sprite and barrelTiles[sprite:getName()]) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local barrel = movableData and movableData[M.BARREL_KEY]
    return (barrel ~= nil and M.barrelStage(barrel) ~= "Empty") or nil
end)
-- No barrel or storage is put down in front of a door (TP Core's Doors).
UI.keepDoorsFree(Tiles.STATIONS)
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

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local seen = {}
    for _, isoObject in ipairs(worldobjects) do
        if isBarrel(isoObject) and not seen[isoObject] then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            -- A barrel built or placed this session isn't tracked until its area reloads, so its menu starts it.
            if TraditionalPreservationFruitVegetablesWorld then TraditionalPreservationFruitVegetablesWorld.track(isoObject) end
            addBarrelMenu(context, getSpecificPlayer(playerNum), isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Vegetables catch up on their keeping whenever they are looked at or moved (TP Core's PlaceKeepingUI).
PlaceKeepingUI.watch({ keep = M.keepVegetable }, M.CROP_OF_TYPE)
