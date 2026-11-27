-- Traditional Preservation (Fruits and Vegetables) B42: the Kraut Barrel's right-click menu (pack, unpack, salt and compress,
-- take kraut out, empty a spoiled one) and its Info window (TP Core's InfoWindow), opened from the menu; Braid and Unbraid on garlic and onions; the door rule for the barrel and the storages; and the cellar's
-- look at vegetables (TP Core's PlaceKeepingUI).
local UI = require "TraditionalPreservationCore/UI"
local KeepingTooltip = require "TraditionalPreservationCore/KeepingTooltip"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local StationReport = require "TraditionalPreservationCore/StationReport"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"

local M = TraditionalPreservationFruitVegetables
local say = UI.say
local tooltipFor, refuse, findItems = UI.tooltip, UI.refuse, UI.findItems
local BARREL_ICON = "media/textures/Item_KrautBarrel.png"
local ICONS = { cabbage = "Item_Cabbage", turnip = "Item_Turnip", apple = "Item_Apple", carrot = "Item_Carrots",
    Sauerkraut = "media/textures/Item_Sauerkraut.png", SauerTurnip = "media/textures/Item_SauerTurnip.png" }
local KrautWindow -- the info window, below the menu
TraditionalPreservationFruitVegetablesKrautUI = {}

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
    HasStarter = "IGUI_TraditionalPreservationFruitVegetables_HasStarter",
    NotReady = "IGUI_TraditionalPreservationFruitVegetables_NotReady",
    Drawn = "IGUI_TraditionalPreservationFruitVegetables_Drawn",
    NoBrine = "IGUI_TraditionalPreservationFruitVegetables_NoBrine",
    Mouldy = "IGUI_TraditionalPreservationFruitVegetables_Mouldy",
    Covered = "IGUI_TraditionalPreservationFruitVegetables_Covered",
    Stale = "IGUI_TraditionalPreservationFruitVegetables_StaleBack",
    NoContainer = "IGUI_TraditionalPreservationFruitVegetables_NoContainer",
    NoStarterBrine = "IGUI_TraditionalPreservationFruitVegetables_NoStarterBrine",
    Pressed = "IGUI_TraditionalPreservationFruitVegetables_Pressed",
    NotPressed = "IGUI_TraditionalPreservationFruitVegetables_NotPressed",
    Fermenting = "IGUI_TraditionalPreservationFruitVegetables_UnsealFermenting",
}
local BRINE_ICON = "Item_GlassJar"

local STATIONS = {}
for _, name in ipairs(Tiles.STATIONS) do STATIONS[name] = true end

local function isBarrel(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and STATIONS[sprite:getName()] == true
end

local function refusalText(refusal, barrel)
    return say(REFUSALS[refusal], M.BARREL_MIN, M.saltNeeded(M.headCount(barrel)), M.HEADS_PER_EXTRA)
end

local function litresText(litres)
    return string.format("%.1f", litres)
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

-- One row a kraut still in the barrel: All (what is left) and One; in red while the plank and stone are on.
local function addTakeMenu(menu, playerObj, station, barrel)
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local left = M.portionsLeft(barrel, kind)
        if left > 0 then
            local product = M.KRAUTS[kind].product
            local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_Take", getItemNameFromFullType(product), left))
            option.iconTexture = getTexture(ICONS[product:match("%.(.+)$")])
            if M.pressed(barrel) then return refuse(option, refusalText("Pressed", barrel)) end
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

-- The brine (user, 2026-11-27, art/kraut_brine_mock.png). Containers in reach holding at least litres of Kraut Brine, and
-- ones with room for litres of fluid (empty, or holding only it).
local function brineHolders(playerObj, litres)
    return findItems(playerObj, function(item) return M.onlyFluid(item, M.KRAUT_BRINE) >= litres - 1e-6 end)
end
local function roomHolders(playerObj, fluid, litres)
    return findItems(playerObj, function(item) return M.roomFor(item, fluid) >= litres - 1e-6 end)
end
TraditionalPreservationFruitVegetablesKrautUI.brineHolders = brineHolders

-- Add Starter while packing: 1 L of Kraut Brine from a container in reach.
local function addStarterMenu(menu, playerObj, station, barrel)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_AddStarter", M.STARTER_L))
    option.iconTexture = getTexture(BRINE_ICON)
    local refusal = M.starterRefusal(barrel)
    local holders = brineHolders(playerObj, M.STARTER_L)
    if not refusal and #holders == 0 then refusal = "NoStarterBrine" end
    if refusal then return refuse(option, refusalText(refusal, barrel)) end
    option.target, option.onSelect, option.param1, option.param2, option.param3 = playerObj, queue, station, "starter", { holders[1] }
    tooltipFor(option, say("IGUI_TraditionalPreservationFruitVegetables_StarterHelp", UI.percent(1 + M.STARTER_BONUS)))
end

-- Draw Starter off a ready barrel: 1 L into a container with room.
local function addDrawMenu(menu, playerObj, station, barrel)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_DrawStarter", M.STARTER_L))
    option.iconTexture = getTexture(BRINE_ICON)
    local refusal = M.drawRefusal(barrel)
    local holders = roomHolders(playerObj, M.KRAUT_BRINE, M.STARTER_L)
    if not refusal and #holders == 0 then refusal = "NoContainer" end
    if refusal then return refuse(option, refusalText(refusal, barrel)) end
    option.target, option.onSelect, option.param1, option.param2, option.param3 = playerObj, queue, station, "draw", { holders[1] }
    tooltipFor(option, getText("IGUI_TraditionalPreservationFruitVegetables_DrawHelp"))
end

-- Drain Brine off a barrel of brine: into containers in reach one after another, until it is all out.
local function addDrainMenu(menu, playerObj, station, barrel)
    local fluid = barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_DrainBrine", litresText(barrel.brine)))
    option.iconTexture = getTexture(BRINE_ICON)
    if M.pressed(barrel) then return refuse(option, refusalText("Pressed", barrel)) end
    local holders, room, take = roomHolders(playerObj, fluid, 0.01), 0, {}
    for _, item in ipairs(holders) do
        if room >= barrel.brine then break end
        table.insert(take, item)
        room = room + M.roomFor(item, fluid)
    end
    if #take == 0 then return refuse(option, refusalText("NoContainer", barrel)) end
    option.target, option.onSelect, option.param1, option.param2, option.param3 = playerObj, queue, station, "drain", take
    tooltipFor(option, getText("IGUI_TraditionalPreservationFruitVegetables_DrainHelp"))
end

-- Pour In Brine on an empty barrel or one of brine: a row per container of Kraut Brine in reach.
local function addPourMenu(menu, playerObj, station, barrel)
    local holders = brineHolders(playerObj, 0.01)
    if #holders == 0 then return end
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_PourBrine"))
    option.iconTexture = getTexture(BRINE_ICON)
    local refusal = M.pourRefusal(barrel)
    if refusal then return refuse(option, refusalText(refusal, barrel)) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(holders) do
        local row = sub:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_PourFrom", item:getDisplayName(),
            litresText(M.onlyFluid(item, M.KRAUT_BRINE))), playerObj, queue, station, "pour", { item })
        row.itemForTexture = item
    end
    tooltipFor(option, getText("IGUI_TraditionalPreservationFruitVegetables_PourHelp"))
end

-- Fresh portions of a kraut in reach, oldest first.
local function freshKraut(playerObj, product)
    local found = findItems(playerObj, function(item) return item:getFullType() == product and M.isFreshKraut(item) end)
    table.sort(found, function(a, b) return a:getAge() > b:getAge() end)
    return found
end

-- Put Back, a row a kraut carried: All (as many as the brine covers) and One, or in red with the reason.
local function addPutBackMenu(menu, playerObj, station, barrel)
    local room = M.putBackRoom(barrel)
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local product = M.KRAUTS[kind].product
        local pieces = freshKraut(playerObj, product)
        local any = #findItems(playerObj, function(item) return item:getFullType() == product end) > 0
        if any then
            local option = menu:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_PutBack", getItemNameFromFullType(product)))
            option.iconTexture = getTexture(ICONS[product:match("%.(.+)$")])
            local refusal = M.putBackRefusal(barrel, #pieces > 0)
            if refusal then
                refuse(option, refusalText(refusal, barrel))
            else
                local sub = menu:getNew(menu)
                menu:addSubMenu(option, sub)
                local all = math.min(#pieces, room)
                if all > 1 then
                    sub:addOption(say("ContextMenu_TraditionalPreservationFruitVegetables_All", all), playerObj, queue, station, "putback", firstOf(pieces, all))
                end
                sub:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_One"), playerObj, queue, station, "putback", { pieces[1] })
                tooltipFor(option, say("IGUI_TraditionalPreservationFruitVegetables_PutBackHelp", room, M.BRINE_PER_HEAD))
            end
        end
    end
end

-- Unseal: the plank and stone off, once it is ready (or spoiled, or down to brine, or empty with them still on).
local function addUnsealMenu(menu, playerObj, station, barrel)
    if not M.pressed(barrel) then return end
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Unseal"), playerObj, queue, station, "unseal", nil)
    option.iconTexture = getTexture("Item_FlatRock")
    local refusal = M.unsealRefusal(barrel)
    if refusal then return refuse(option, refusalText(refusal, barrel)) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationFruitVegetables_UnsealHelp"))
end

local function stageText(barrel)
    local stage = M.barrelStage(barrel)
    if stage == "Ready" and barrel.soft then return getText("IGUI_TraditionalPreservationFruitVegetables_StageSoft") end
    return getText("IGUI_TraditionalPreservationFruitVegetables_Stage" .. stage)
end

local function contentsText(barrel)
    if M.barrelStage(barrel) == "Empty" then return getText("IGUI_TraditionalPreservationFruitVegetables_Nothing") end
    if M.barrelStage(barrel) == "Brine" then
        return say("IGUI_TraditionalPreservationFruitVegetables_BrineOnly", litresText(barrel.brine))
    end
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
    elseif status.stage == "Brine" and status.hoursLeft then
        return say("IGUI_TraditionalPreservationFruitVegetables_BrineKeeps", UI.durationText(status.hoursLeft))
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
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationFruitVegetables_Info"), getTexture(BARREL_ICON), playerObj, KrautWindow.open, station)

    if stage == "Empty" or stage == "Packing" then
        addPackMenu(menu, playerObj, station, barrel)
        addStarterMenu(menu, playerObj, station, barrel)
        if stage == "Packing" then
            addCompressMenu(menu, playerObj, station, barrel)
            local unpack = menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Unpack"), playerObj, queue, station, "unpack", nil)
            tooltipFor(unpack, getText("IGUI_TraditionalPreservationFruitVegetables_UnpackHelp"))
        else
            addPourMenu(menu, playerObj, station, barrel)
        end
    elseif stage == "Ready" then
        addTakeMenu(menu, playerObj, station, barrel)
        addPutBackMenu(menu, playerObj, station, barrel)
        addDrawMenu(menu, playerObj, station, barrel)
    elseif stage == "Brine" then
        addPutBackMenu(menu, playerObj, station, barrel)
        addPourMenu(menu, playerObj, station, barrel)
        addDrainMenu(menu, playerObj, station, barrel)
    elseif stage == "Spoiled" then
        menu:addOption(getText("ContextMenu_TraditionalPreservationFruitVegetables_Empty"), playerObj, queue, station, "empty", nil)
    end
    addUnsealMenu(menu, playerObj, station, barrel)
end

-- Kraut Barrel Info (art/kraut_info_mock.png, on the Salting Tub's window; the starter slot and brine tank
-- art/kraut_brine_mock.png): a band with the barrel's state, the place,
-- what it holds as cells with a line of history beside them (what is dragged onto them packs while it is packing),
-- the buttons by stage, the ferment's bar while it sours, then notes. Kept up to date while open.
local KrautUI = TraditionalPreservationFruitVegetablesKrautUI
local KEY = "IGUI_TraditionalPreservationFruitVegetables_"
local MENU = "ContextMenu_TraditionalPreservationFruitVegetables_"
local STATION_ICON = "media/textures/TPStation_KrautBarrel.png"   -- the Station block (TP Core tools/station_icons.py)
local RETURNED_ICON = "media/ui/Entity/Icon_Returned_48x48.png"
local FERMENT_COLOUR, SLOW_COLOUR = { 0.35, 0.6, 0.3 }, { 0.75, 0.55, 0.2 }
local LOAD_COLOUR, SPOILED_COLOUR = { 0.59, 0.51, 0.39 }, { 0.35, 0.31, 0.24 }
-- The cells' pattern by kind (tools/cell_patterns.py in TP Core).
local PATTERNS = { cabbage = "media/textures/TPCell_Cabbage.png", turnip = "media/textures/TPCell_Turnip.png" }

-- Heads of each kind in the barrel now: packed, or once sealed the portions left (all of them until it is ready).
local function headsOf(barrel, kind)
    if barrel.portions then return M.portionsLeft(barrel, kind) end
    return M.headCount(barrel, kind)
end

-- The band: empty, packing, too warm, stalled, fermenting, ready (soft) or spoiled; the worst first. Returns the word,
-- the finished text and the colours.
function KrautUI.band(barrel, status)
    local stage = status.stage
    if stage == "Empty" then
        return getText(KEY .. "StageEmpty"), say(KEY .. "BandEmptyText", M.BARREL_MIN, M.BARREL_MAX), InfoWindow.BAND_IDLE
    elseif stage == "Packing" then
        local heads = M.headCount(barrel)
        local text = heads >= M.BARREL_MIN and say(KEY .. "BandPackingText", heads, M.saltNeeded(heads))
            or say(KEY .. "BandPackingFewText", heads, M.BARREL_MIN)
        if barrel.starter then text = text .. say(KEY .. "BandStarterIn", UI.percent(M.STARTER_BONUS)) end
        return getText(KEY .. "StagePacking"), text, InfoWindow.BAND_WAITING
    elseif stage == "Spoiled" then
        return getText(KEY .. "StageSpoiled"), getText(KEY .. "BandSpoiledText"), InfoWindow.BAND_AT_RISK
    elseif stage == "Brine" then
        if barrel.brineSpoiled then
            return getText(KEY .. "StageBrine"), say(KEY .. "BandBrineMouldy", litresText(barrel.brine)), InfoWindow.BAND_AT_RISK
        end
        return getText(KEY .. "StageBrine"), say(KEY .. "BandBrineText", litresText(barrel.brine)), InfoWindow.BAND_WAITING
    elseif stage == "Ready" then
        local text = status.daysLeft and say(KEY .. "BandReadyText", string.format("%.0f", status.daysLeft))
            or getText(KEY .. "KeepsForever")
        if barrel.soft then return getText(KEY .. "BandSoft"), text, InfoWindow.BAND_WAITING end
        return getText(KEY .. "StageReady"), text, InfoWindow.BAND_WORKING
    end
    if status.temperature > M.HOT_C then
        local after = barrel.hotHours >= M.HOT_SOFT_HOURS and say(KEY .. "BandTooWarmSpoils", M.HOT_SPOIL_HOURS)
            or say(KEY .. "BandTooWarmSoft", M.HOT_SOFT_HOURS)
        return getText(KEY .. "BandTooWarm"), say(KEY .. "BandTooWarmText", string.format("%.0f", status.hotHours), M.HOT_C, after),
            InfoWindow.BAND_AT_RISK
    end
    if not status.hoursLeft then
        return getText(KEY .. "StageFermenting"), getText(KEY .. "BandStalledText"), InfoWindow.BAND_WAITING
    end
    return getText(KEY .. "StageFermenting"), say(KEY .. "BandFermentingText", UI.durationText(status.hoursLeft)), InfoWindow.BAND_WORKING
end

-- The Station block's rows past the place: while it ferments, its speed and the hours it has been too warm.
function KrautUI.rows(status)
    if status.stage ~= "Fermenting" then return {} end
    return {
        { KEY .. "InfoSpeed", UI.percent(status.rate) },
        { KEY .. "InfoTooWarm", say(KEY .. "InfoTooWarmValue", string.format("%.0f", status.hotHours), M.HOT_SOFT_HOURS, M.HOT_SPOIL_HOURS) },
    }
end

-- "30 cabbages, 1 turnip": each kind there, one or many, joined; nil when none.
local function countsText(counts)
    local parts = {}
    for _, entry in ipairs(counts) do
        local n, kind = entry[1], entry[2]
        if n > 0 then table.insert(parts, say(KEY .. "Count_" .. kind .. (n == 1 and "_one" or ""), n)) end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function cellsShare(heads)
    return math.min(heads / M.BARREL_MAX, 1)
end

-- What is dragged onto the barrel's cells: the heads it takes, then the apples and carrots the heads (with those) allow,
-- as Pack would, with the first reason a piece is left out. Returns DropZone's { take, lines, refused } and cells, the
-- cells the heads would fill, in the pattern of the kind most of them are.
function KrautUI.judgeDrop(barrel, items)
    local judged = { take = {}, lines = {} }
    local stage = M.barrelStage(barrel)
    local heads = M.headCount(barrel)
    local extras = { apple = M.extraCount(barrel, "apple"), carrot = M.extraCount(barrel, "carrot") }
    local added, refusal, laterExtras = {}, nil, {}
    local sealed = stage ~= "Empty" and stage ~= "Packing"
    for _, item in ipairs(items) do
        local kind, extra = M.KRAUT_OF_HEAD[item:getFullType()], M.EXTRA_OF_TYPE[item:getFullType()]
        local why
        if not kind and not extra then why = "NotKraut"
        elseif sealed then why = "Sealed"
        elseif item:isRotten() then why = "Rotten" end
        if why then
            refusal = refusal or why
        elseif kind then
            if heads >= M.BARREL_MAX then
                refusal = refusal or "Full"
            else
                table.insert(judged.take, item)
                heads = heads + 1
                added[kind] = (added[kind] or 0) + 1
            end
        else
            table.insert(laterExtras, { item = item, extra = extra })
        end
    end
    -- Apples and carrots after the heads, so the heads in this drag make room for them.
    for _, entry in ipairs(laterExtras) do
        if heads == 0 then
            refusal = refusal or "NoHeads"
        elseif extras[entry.extra] >= M.extraRoom(heads) then
            refusal = refusal or "TooMany"
        else
            table.insert(judged.take, entry.item)
            extras[entry.extra] = extras[entry.extra] + 1
        end
    end
    local Holds = require "TraditionalPreservationCore/Holds"
    judged.cells = Holds.filledCells({ share = cellsShare(heads) }) - Holds.filledCells({ share = cellsShare(M.headCount(barrel)) })
    if #judged.take > 0 then
        table.insert(judged.lines, say(KEY .. "DropPack", #judged.take))
        local stale = 0
        for _, item in ipairs(judged.take) do
            if M.KRAUT_OF_HEAD[item:getFullType()] and item:getAge() > item:getOffAge() then stale = stale + 1 end
        end
        if stale > 0 then table.insert(judged.lines, say(KEY .. "DropStale", stale)) end
        judged.pattern = PATTERNS[(added.turnip or 0) > (added.cabbage or 0) and "turnip" or "cabbage"]
    end
    if refusal then
        judged.refused = refusal == "NotKraut" and getText(KEY .. "DropNotKraut") or refusal == "Rotten" and getText(KEY .. "DropRotten")
            or refusalText(refusal, barrel)
        if #judged.take == 0 then judged.lines = { judged.refused } end
    end
    return judged
end

-- Kraut dragged onto a ready barrel or one of brine: fresh portions back under the brine, as many as it covers.
function KrautUI.judgePutBack(barrel, items)
    local judged = { take = {}, lines = {} }
    local room, refusal = M.putBackRoom(barrel), nil
    local portions = {}
    for _, item in ipairs(items) do
        if not M.KRAUT_OF_PRODUCT[item:getFullType()] then
            refusal = refusal or "NotKraut"
        elseif not M.isFreshKraut(item) then
            refusal = refusal or "Stale"
        else
            table.insert(portions, item)
        end
    end
    table.sort(portions, function(a, b) return a:getAge() > b:getAge() end)
    for _, item in ipairs(portions) do
        if #judged.take >= room then refusal = refusal or "Covered" break end
        table.insert(judged.take, item)
    end
    if barrel.brineSpoiled then judged.take, refusal = {}, "Mouldy" end
    if #judged.take > 0 then table.insert(judged.lines, say(KEY .. "DropPutBack", #judged.take, room)) end
    if refusal then
        judged.refused = refusal == "NotKraut" and getText(KEY .. "DropNotPortion") or refusalText(refusal, barrel)
        if #judged.take == 0 then judged.lines = { judged.refused } end
    end
    return judged
end

-- The cells: the heads' share of a full barrel, cabbage and turnip split by share; what is dragged on packs while
-- packing. Under them the stale heads (their kraut will be soft), then once sealed the soft portions left. now: the
-- hour (the game's when nil).
function KrautUI.holding(barrel, drop, now)
    local stage = M.barrelStage(barrel)
    local cabbages, turnips = headsOf(barrel, "cabbage"), headsOf(barrel, "turnip")
    local heads = cabbages + turnips
    local holding = { kind = "cells", name = getText(KEY .. "InfoContents"), share = cellsShare(heads), colour = LOAD_COLOUR,
        parts = { { pattern = PATTERNS.cabbage, weight = cabbages }, { pattern = PATTERNS.turnip, weight = turnips } },
        drop = (stage == "Empty" or stage == "Packing" or stage == "Ready" or stage == "Brine") and drop or nil }
    if stage == "Brine" then holding.amount, holding.state = getText(KEY .. "Nothing"), getText(KEY .. "HoldsBrineOnly") return holding end
    if stage == "Empty" or stage == "Packing" then
        holding.amount = say(KEY .. "HoldsHeadsOf", heads, M.BARREL_MAX)
    elseif stage == "Ready" then
        holding.amount = say(KEY .. "HoldsPortions", heads)
    else
        holding.amount = say(KEY .. "HoldsHeads", heads)
    end
    if stage == "Ready" then
        holding.state = say(KEY .. "InfoPortionsValue", cabbages, turnips)
    elseif stage == "Spoiled" then
        holding.state, holding.stateColour = getText(KEY .. "HoldsSpoiled"), { 0.85, 0.4, 0.35 }
        holding.parts, holding.colour = nil, SPOILED_COLOUR
    else
        holding.state = countsText({ { cabbages, "cabbage" }, { turnips, "turnip" } })
    end
    if stage == "Packing" then
        local stale = M.staleHeads(barrel, now or getGameTime():getWorldAgeHours())
        if stale > 0 then holding.under = say(KEY .. "HoldsStale", stale) end
    elseif (stage == "Fermenting" or stage == "Ready") and not barrel.soft and M.softLeft(barrel) > 0 then
        holding.under = say(KEY .. "HoldsSoft", M.softLeft(barrel))
    end
    local apples = barrel.apples or M.extraCount(barrel, "apple")
    local carrots = barrel.carrots or M.extraCount(barrel, "carrot")
    -- What it was spiked with, as icons with their counts (art/kraut_spiked_mock.png B): every portion carries its
    -- share of them, so they show until the last one is taken.
    if stage ~= "Spoiled" then
        holding.counts = {}
        if apples > 0 then table.insert(holding.counts, { ICONS.apple, apples }) end
        if carrots > 0 then table.insert(holding.counts, { ICONS.carrot, carrots }) end
    end
    return holding
end

-- The brine tank right of the heads (art/kraut_brine_mock.png): up to BRINE_MAX, its line what it covers.
local BRINE_COLOUR, MOULDY_COLOUR = { 0.84, 0.81, 0.59 }, { 0.33, 0.42, 0.18 }
function KrautUI.brineHolding(barrel)
    local stage = M.barrelStage(barrel)
    local brine = M.brineOf(barrel)
    local holding = { kind = "tank", name = getText(KEY .. "InfoBrine"), share = math.min(brine / M.BRINE_MAX, 1),
        colour = barrel.brineSpoiled and MOULDY_COLOUR or BRINE_COLOUR,
        amount = say(KEY .. "BrineAmount", litresText(brine), litresText(M.BRINE_MAX)) }
    if stage == "Empty" or stage == "Packing" then
        holding.state = getText(KEY .. "BrineAtCompress")
    elseif stage == "Fermenting" then
        holding.state = getText(KEY .. "BrineOverHeads")
    elseif stage == "Ready" then
        holding.state = say(KEY .. "BrineCovers", M.portionsLeft(barrel))
    elseif stage == "Brine" then
        holding.state = barrel.brineSpoiled and getText(KEY .. "BrineMouldy")
            or say(KEY .. "BrineRoomFor", math.min(math.floor(brine / M.BRINE_PER_HEAD + 1e-6), M.BARREL_MAX))
    end
    return holding
end

-- The starter's slot left of the heads (DEVGUIDE, starters): Add Starter while it can take one, the jar bright once in,
-- "used" once the batch has taken it. actions = { drop, click, menu } (the window's) while it takes one.
function KrautUI.starterSlot(barrel, actions)
    local stage = M.barrelStage(barrel)
    local slot = { kind = "slot", arrow = "", icons = { BRINE_ICON } }
    if barrel.starter then
        slot.look, slot.name, slot.count = "in", getText(KEY .. "SlotStarter"), say(KEY .. "SlotLitres", M.STARTER_L)
    elseif stage == "Empty" or stage == "Packing" then
        slot.look, slot.name, slot.nameColour = "empty", getText(KEY .. "SlotAddStarter"), InfoWindow.NOTE_COLOUR
        if actions then slot.drop, slot.click, slot.menu = actions.drop, actions.click, actions.menu end
    else
        slot.look, slot.name, slot.nameColour = "pending", getText(KEY .. "SlotUsed"), InfoWindow.NOTE_COLOUR
    end
    return slot
end

-- Kraut Brine dragged onto the slot: the first container holding a starter's worth.
function KrautUI.judgeStarter(barrel, items)
    local refusal = M.starterRefusal(barrel)
    if refusal then return { take = {}, lines = { refusalText(refusal, barrel) } } end
    for _, item in ipairs(items) do
        if M.onlyFluid(item, M.KRAUT_BRINE) >= M.STARTER_L - 1e-6 then
            return { take = { item }, lines = { say(KEY .. "DropStarter", M.STARTER_L) } }
        end
    end
    return { take = {}, lines = { refusalText("NoStarterBrine", barrel) } }
end

-- The window's buttons (kraut_info_mock): while packing Salt and Compress (greyed with the reason, as the menu's) and
-- Unpack (n); once ready one button a kraut left, opening One and All (n) (user, session 72); spoiled, Empty.
-- act(mode, pieces, kind) does it; kit is compressKit's while packing, else { drawRoom, drainRoom }: whether a
-- container in reach has room for a starter or for the brine (false greys the button, as the menu's red row).
function KrautUI.buttons(barrel, kit, act)
    local stage = M.barrelStage(barrel)
    local buttons = {}
    if stage == "Packing" then
        local refusal = M.compressRefusal(barrel, kit)
        table.insert(buttons, { title = say(MENU .. "Compress", M.saltNeeded(M.headCount(barrel))), icon = "Item_FlatRock",
            enabled = refusal == nil, tooltip = refusal and refusalText(refusal, barrel) or getText(KEY .. "CompressHelp"),
            onClick = function() act("compress") end })
        local pieces = M.headCount(barrel) + M.extraCount(barrel, "apple") + M.extraCount(barrel, "carrot")
        table.insert(buttons, { title = say(KEY .. "ButtonUnpack", pieces), icon = RETURNED_ICON, enabled = true,
            tooltip = getText(KEY .. "UnpackHelp"), onClick = function() act("unpack") end })
    elseif stage == "Ready" then
        for _, kind in ipairs(M.KRAUT_KINDS) do
            local left = M.portionsLeft(barrel, kind)
            if left > 0 then
                local product = M.KRAUTS[kind].product
                local icon = ICONS[product:match("%.(.+)$")]
                local all = {}
                for i = 1, left do all[i] = false end
                local rows = { { title = getText(MENU .. "One"), icon = icon, enabled = true, onClick = function() act("take", { false }, kind) end } }
                if left > 1 then
                    table.insert(rows, { title = say(MENU .. "All", left), icon = icon, enabled = true, onClick = function() act("take", all, kind) end })
                end
                local shut = M.pressed(barrel)
                table.insert(buttons, { title = say(KEY .. "ButtonTake", getItemNameFromFullType(product), left), icon = icon,
                    enabled = not shut, tooltip = shut and refusalText("Pressed", barrel) or nil, menu = not shut and rows or nil })
            end
        end
        local refusal = M.drawRefusal(barrel) or (kit.drawRoom == false and "NoContainer") or nil
        table.insert(buttons, { title = say(MENU .. "DrawStarter", M.STARTER_L), icon = BRINE_ICON, enabled = refusal == nil,
            tooltip = refusal and refusalText(refusal, barrel) or getText(KEY .. "DrawHelp"), onClick = function() act("draw") end })
    elseif stage == "Brine" then
        local refusal = M.pressed(barrel) and "Pressed" or (kit.drainRoom == false and "NoContainer") or nil
        table.insert(buttons, { title = say(MENU .. "DrainBrine", litresText(barrel.brine)), icon = BRINE_ICON, enabled = refusal == nil,
            tooltip = refusal and refusalText(refusal, barrel) or getText(KEY .. "DrainHelp"), onClick = function() act("drain") end })
    elseif stage == "Spoiled" then
        table.insert(buttons, { title = getText(MENU .. "Empty"), icon = RETURNED_ICON, enabled = true,
            onClick = function() act("empty") end })
    end
    if M.pressed(barrel) and stage ~= "Fermenting" then
        table.insert(buttons, { title = getText(MENU .. "Unseal"), icon = "Item_FlatRock", enabled = true,
            tooltip = getText(KEY .. "UnsealHelp"), onClick = function() act("unseal") end })
    end
    return buttons
end

KrautWindow = InfoWindow:derive("TraditionalPreservationFruitVegetablesKrautWindow")

function KrautWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_CraftingWindow_KrautBarrel")
    return o
end

function KrautWindow.open(playerObj, station)
    InfoWindow.open(KrautWindow, playerObj, station)
end
StationReport.add(KrautWindow, function(isoObject) return isBarrel(isoObject) and isoObject or nil end)

local function barrelDrop(window)
    local function judge(items)
        local barrel = barrelNow(window.station)
        local stage = M.barrelStage(barrel)
        if stage == "Ready" or stage == "Brine" then return KrautUI.judgePutBack(barrel, items) end
        return KrautUI.judgeDrop(barrel, items)
    end
    local function drop(take)
        local stage = M.barrelStage(barrelNow(window.station))
        queue(window.playerObj, window.station, (stage == "Ready" or stage == "Brine") and "putback" or "pack", take)
    end
    return { judge = judge, drop = drop }
end

local function starterActions(window)
    local function judge(items) return KrautUI.judgeStarter(barrelNow(window.station), items) end
    local function drop(take) queue(window.playerObj, window.station, "starter", take) end
    local function click()
        local holders = brineHolders(window.playerObj, M.STARTER_L)
        if holders[1] then queue(window.playerObj, window.station, "starter", { holders[1] }) end
    end
    return { drop = { judge = judge, drop = drop }, click = click }
end

function KrautWindow:refresh()
    local barrel = barrelNow(self.station)
    local stage = M.barrelStage(barrel)
    local kit = {}
    if stage == "Packing" then
        kit = compressKit(self.playerObj)
    elseif stage == "Ready" then
        kit.drawRoom = roomHolders(self.playerObj, M.KRAUT_BRINE, M.STARTER_L)[1] ~= nil
    elseif stage == "Brine" then
        kit.drainRoom = roomHolders(self.playerObj, barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE, 0.01)[1] ~= nil
    end
    self.barrelView = { barrel = barrel, status = statusOf(self.station, barrel), kit = kit }
    self.drop = self.drop or barrelDrop(self)
    self.starter = self.starter or starterActions(self)
end

function KrautWindow:barrelButtons(y)
    local playerObj, station = self.playerObj, self.station
    local buttons = KrautUI.buttons(self.barrelView.barrel, self.barrelView.kit, function(mode, pieces, kind)
        if mode == "compress" then return onCompress(playerObj, station, compressKit(playerObj)) end
        if mode == "draw" then
            local holders = roomHolders(playerObj, M.KRAUT_BRINE, M.STARTER_L)
            if holders[1] then queue(playerObj, station, "draw", { holders[1] }) end
            return
        end
        if mode == "drain" then
            local barrel = self.barrelView.barrel
            local fluid = barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE
            local take, room = {}, 0
            for _, item in ipairs(roomHolders(playerObj, fluid, 0.01)) do
                if room >= barrel.brine then break end
                table.insert(take, item)
                room = room + M.roomFor(item, fluid)
            end
            if #take > 0 then queue(playerObj, station, "drain", take) end
            return
        end
        queue(playerObj, station, mode, pieces, false, kind)
    end)
    return self:buttonRow(y, buttons)
end

function KrautWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.barrelView then return end
    local barrel, status = self.barrelView.barrel, self.barrelView.status
    local word, text, look = KrautUI.band(barrel, status)
    local y = self:band(word, text, look[1], look[2])
    y = self:stationBlock(y, STATION_ICON, status.place, status.temperature, KrautUI.rows(status))
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    y = self:holds(y, { KrautUI.starterSlot(barrel, self.starter), KrautUI.holding(barrel, self.drop), KrautUI.brineHolding(barrel) },
        getText(KEY .. "Lore"))
    y = self:barrelButtons(y)
    local notes = {}
    if status.stage == "Fermenting" then
        local slow = status.temperature > M.HOT_C or not status.hoursLeft
        y = self:section(y, "IGUI_TraditionalPreservationCore_SectionWorking")
        y = self:bar(y, KEY .. "InfoFerment", status.progress, slow and SLOW_COLOUR or FERMENT_COLOUR,
            barrel.speed and say(KEY .. "BarTextStarter", UI.percent(status.progress), UI.percent(status.rate), UI.percent(barrel.speed - 1))
            or say(KEY .. "BarText", UI.percent(status.progress), UI.percent(status.rate)))
    end
    if status.stage == "Empty" or status.stage == "Packing" then table.insert(notes, getText(KEY .. "NoteDrag")) end
    table.insert(notes, getText(KEY .. "Note" .. status.stage))
    if status.stage == "Fermenting" then table.insert(notes, getText(KEY .. "InfoAssumes")) end
    self:drawNotes(y, notes)
end

-- A barrel with anything in it stays where it is: packing, fermenting or kraut waiting, its time goes by its place
-- (user, 2026-11-19: no station is moved mid-process), and so does one with its plank and stone on (Unseal first).
-- Empty, it picks up as any moveable.
local barrelTiles = {}
for _, sprite in ipairs(Tiles.STATIONS) do barrelTiles[sprite] = true end
UI.keepInPlace(function(isoObject)
    local sprite = isoObject:getSprite()
    if not (sprite and barrelTiles[sprite:getName()]) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local barrel = movableData and movableData[M.BARREL_KEY]
    return (barrel ~= nil and (M.barrelStage(barrel) ~= "Empty" or M.pressed(barrel))) or nil
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
