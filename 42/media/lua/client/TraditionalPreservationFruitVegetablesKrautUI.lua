-- Traditional Preservation (Fruits and Vegetables): the kraut on TP Core's Brine Barrel, its menu rows and its Info
-- window's pieces (the barrel's menu and window are Core's BrineBarrelUI since Core 0.1.83; they were this mod's main UI
-- file's, as the Kraut Barrel's). The barrel's texts stay this mod's own: the heads, the kraut, the brine and every
-- refusal, as they always read; only the station's name is Core's (Brine Barrel).
local BrineBarrelUI = require "TraditionalPreservationCore/BrineBarrelUI"
local UI = require "TraditionalPreservationCore/UI"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local M = TraditionalPreservationFruitVegetables
local say = UI.say
local ICONS = { cabbage = "Item_Cabbage", turnip = "Item_Turnip", apple = "Item_Apple", carrot = "Item_Carrots",
    Sauerkraut = "media/textures/Item_Sauerkraut.png", SauerTurnip = "media/textures/Item_SauerTurnip.png" }
TraditionalPreservationFruitVegetablesKrautUI = {}
local KrautUI = TraditionalPreservationFruitVegetablesKrautUI

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
    NotBrine = "IGUI_TraditionalPreservationFruitVegetables_NotBrine",
    Pressed = "IGUI_TraditionalPreservationFruitVegetables_Pressed",
    NotPressed = "IGUI_TraditionalPreservationFruitVegetables_NotPressed",
    Fermenting = "IGUI_TraditionalPreservationFruitVegetables_UnsealFermenting",
}

local function refusalText(refusal, barrel)
    return say(REFUSALS[refusal], M.BARREL_MIN, M.saltNeeded(M.headCount(barrel)), M.HEADS_PER_EXTRA)
end

local function litresText(litres)
    return string.format("%.1f", litres)
end

local KEY = "IGUI_TraditionalPreservationFruitVegetables_"
local MENU = "ContextMenu_TraditionalPreservationFruitVegetables_"
BrineBarrelUI.words({
    one = MENU .. "One", all = MENU .. "All", unpack = MENU .. "Unpack", take = MENU .. "Take", empty = MENU .. "Empty",
    compress = MENU .. "Compress", addStarter = MENU .. "AddStarter", drawStarter = MENU .. "DrawStarter",
    drainBrine = MENU .. "DrainBrine", pourBrine = MENU .. "PourBrine", pourFrom = MENU .. "PourFrom", putBack = MENU .. "PutBack",
    unseal = MENU .. "Unseal",
    stage = KEY .. "Stage", help = KEY .. "Help", note = KEY .. "Note", nothing = KEY .. "Nothing", brineOnly = KEY .. "BrineOnly",
    readyIn = KEY .. "ReadyIn", stalled = KEY .. "Stalled", keepsFor = KEY .. "KeepsFor", keepsForever = KEY .. "KeepsForever",
    brineKeeps = KEY .. "BrineKeeps", unpackHelp = KEY .. "UnpackHelp", compressHelp = KEY .. "CompressHelp",
    starterHelp = KEY .. "StarterHelp", drawHelp = KEY .. "DrawHelp", drainHelp = KEY .. "DrainHelp", pourHelp = KEY .. "PourHelp",
    putBackHelp = KEY .. "PutBackHelp", unsealHelp = KEY .. "UnsealHelp", infoBrine = KEY .. "InfoBrine",
    brineAmount = KEY .. "BrineAmount", brineAtCompress = KEY .. "BrineAtCompress", brineOverHeads = KEY .. "BrineOverHeads",
    brineCovers = KEY .. "BrineCovers", brineMouldy = KEY .. "BrineMouldy", brineRoomFor = KEY .. "BrineRoomFor",
    slotStarter = KEY .. "SlotStarter", slotLitres = KEY .. "SlotLitres", slotAddStarter = KEY .. "SlotAddStarter",
    slotUsed = KEY .. "SlotUsed", dropStarter = KEY .. "DropStarter", dropBrine = KEY .. "DropBrine", buttonUnpack = KEY .. "ButtonUnpack",
    buttonTake = KEY .. "ButtonTake", noteDrag = KEY .. "NoteDrag", infoAssumes = KEY .. "InfoAssumes", lore = KEY .. "Lore",
    infoContents = KEY .. "InfoContents", infoWork = KEY .. "InfoFerment", barText = KEY .. "BarText",
    refusal = refusalText,
})

-- The pack rows, in menu order: Pack Cabbage, Pack Turnip, then Add Apple and Add Carrot as the heads allow.
local function packs(barrel)
    local heads = M.headCount(barrel)
    local rows = {}
    for _, kind in ipairs(M.KRAUT_KINDS) do
        table.insert(rows, { label = MENU .. "Pack_" .. kind, fullType = M.KRAUTS[kind].head, icon = ICONS[kind],
            refusal = M.packRefusal(barrel), room = M.BARREL_MAX - heads })
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        table.insert(rows, { label = MENU .. "Add_" .. extra, fullType = M.EXTRAS[extra], icon = ICONS[extra],
            refusal = M.extraRefusal(barrel, extra), room = M.extraRoom(heads) - M.extraCount(barrel, extra) })
    end
    return rows
end

-- What comes out and goes back: Sauerkraut, then Sauer Turnip.
local PRODUCTS = {}
for _, kind in ipairs(M.KRAUT_KINDS) do
    local product = M.KRAUTS[kind].product
    table.insert(PRODUCTS, { which = kind, fullType = product, icon = ICONS[product:match("%.(.+)$")] })
end

local function stageText(barrel)
    if M.barrelStage(barrel) == "Ready" and barrel.soft then return getText(KEY .. "StageSoft") end
end

local function contentsText(barrel)
    local apples = barrel.apples or M.extraCount(barrel, "apple")
    local carrots = barrel.carrots or M.extraCount(barrel, "carrot")
    return say(KEY .. "Contents", M.headCount(barrel, "cabbage"), M.headCount(barrel, "turnip"), apples, carrots)
end

-- Kraut Barrel Info's pieces (art/kraut_info_mock.png), drawn in Core's Brine Barrel window.
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
        -- The status's litres, worked out with its stage: Drain Brine clears the record in place, and the window keeps
        -- its status until the next refresh.
        if barrel.brineSpoiled then
            return getText(KEY .. "StageBrine"), say(KEY .. "BandBrineMouldy", litresText(status.brine)), InfoWindow.BAND_AT_RISK
        end
        return getText(KEY .. "StageBrine"), say(KEY .. "BandBrineText", litresText(status.brine)), InfoWindow.BAND_WAITING
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

-- The Working bar while it sours: its speed, the starter's share when one went in; slow when too warm or stalled.
local function bar(barrel, status)
    local text = barrel.speed and say(KEY .. "BarTextStarter", UI.percent(status.progress), UI.percent(status.rate), UI.percent(barrel.speed - 1))
        or say(KEY .. "BarText", UI.percent(status.progress), UI.percent(status.rate))
    return KEY .. "InfoFerment", text, status.temperature > M.HOT_C or not status.hoursLeft
end

-- Core's pieces of the barrel's window, under this mod's old names for the tests and the console.
KrautUI.brineHolding = BrineBarrelUI.brineHolding
KrautUI.starterSlot = BrineBarrelUI.starterSlot
KrautUI.judgeStarter = BrineBarrelUI.judgeStarter
KrautUI.buttons = BrineBarrelUI.buttons
KrautUI.brineHolders = BrineBarrelUI.brineHolders

BrineBarrelUI.kind(M.KRAUT_KIND.id, {
    packs = packs,
    products = function() return PRODUCTS end,
    stageText = stageText,
    contents = contentsText,
    band = KrautUI.band,
    rows = KrautUI.rows,
    holding = KrautUI.holding,
    judgeDrop = KrautUI.judgeDrop,
    judgePutBack = KrautUI.judgePutBack,
    bar = bar,
    -- Kraut Brine's DarkSeaGreen and its mould's DarkOliveGreen (the fluids' colours).
    brineColour = { 0.561, 0.737, 0.545 },
    mouldyColour = { 0.33, 0.42, 0.18 },
})
