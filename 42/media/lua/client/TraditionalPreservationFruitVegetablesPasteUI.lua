-- Traditional Preservation (Fruits and Vegetables): tomato paste on the player's side
-- (TraditionalPreservationFruitVegetablesPaste.lua). Put Tomatoes in a Pot on a tomato's right-click menu and Put
-- Tomatoes in the Cauldron on the Stone Hearth's (TP Core's ItemFluidUI and CauldronUI, as Dairy's butter), the
-- cauldron's notes in Stone Hearth Info; Pack Tomato Paste on a pot or saucepan of paste, a row a vessel in reach,
-- salt crust or capped with each oil or fat carried; Add to the Crock on it too, a row per crock already started,
-- and Add Tomato Paste on a crock, a row per pot of paste and All Pots (never into a rotten one); Empty the Crock;
-- Spoon Out Tomato Paste on a crock. The crocks keep by place
-- (TP Core's PlaceKeepingUI) with their keeping line in the tooltip.
require "TimedActions/TPPackTomatoPaste"
require "TimedActions/TPSpoonTomatoPaste"
require "TimedActions/TPAddTomatoPaste"
require "TimedActions/TPEmptyTomatoPaste"
require "TraditionalPreservationFruitVegetables"
local M = TraditionalPreservationFruitVegetables
local UI = require "TraditionalPreservationCore/UI"
local Uses = require "TraditionalPreservationCore/Uses"
local ItemFluidUI = require "TraditionalPreservationCore/ItemFluidUI"
local CauldronUI = require "TraditionalPreservationCore/CauldronUI"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local Fire = require "TraditionalPreservationCore/Fire"
local KeepingTooltip = require "TraditionalPreservationCore/KeepingTooltip"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"

local P = "TraditionalPreservationFruitVegetables"
local say = UI.say

local function pasteRefusal(playerObj)
    if playerObj:getPerkLevel(Perks.Cooking) < M.PASTE_SKILL then return getText("IGUI_" .. P .. "_PasteSkill") end
end

ItemFluidUI.addPieces({
    title = getText("ContextMenu_" .. P .. "_TomatoesInPot"),
    icon = "Item_Tomato",
    vesselTitle = function(count) return say("ContextMenu_" .. P .. "_PulpTomatoes", tostring(count)) end,
    vesselIcon = "Item_Tomato",
    items = M.TOMATOES,
    fluid = M.TOMATO_PULP,
    pieceMl = M.PASTE_PIECE_ML,
    hoursLeft = M.tomatoHoursLeft,
    vessels = M.PASTE_POTS,
    label = function(pot, count)
        return say("ContextMenu_" .. P .. "_TomatoPotRow", pot:getDisplayName(), tostring(count))
    end,
    help = getText("IGUI_" .. P .. "_TomatoPotHelp"),
    noRoom = getText("IGUI_" .. P .. "_TomatoPotNoRoom"),
    noVessel = getText("IGUI_" .. P .. "_TomatoNoPot"),
    refusal = pasteRefusal,
})

CauldronUI.addPieces({
    title = getText("ContextMenu_" .. P .. "_TomatoesInCauldron"),
    icon = "Item_Tomato",
    pieceMl = M.PASTE_PIECE_ML,
    hoursLeft = M.tomatoHoursLeft,
    fluidRows = { { fluid = M.TOMATO_PULP, items = M.TOMATOES, label = function(count)
        return say("ContextMenu_" .. P .. "_TomatoPieces", tostring(count))
    end } },
    help = getText("IGUI_" .. P .. "_TomatoCauldronHelp"),
    noRoom = getText("IGUI_" .. P .. "_TomatoCauldronNoRoom"),
    refusal = pasteRefusal,
})

CauldronUI.addNotes(function(fireView, notes)
    local cauldron = fireView.part
    if (cauldron.ml or 0) <= 0 then return end
    local now = getGameTime():getWorldAgeHours()
    local left = UI.hoursText(math.max((cauldron.offAt or now) - now, 0))
    if cauldron.fluid == M.TOMATO_PULP then
        table.insert(notes, say("IGUI_" .. P .. "_PulpCooking", UI.hoursText(CauldronFluid.hoursToTurn(cauldron) or 0), left))
    elseif cauldron.fluid == M.TOMATO_PASTE_FLUID then
        table.insert(notes, say("IGUI_" .. P .. "_PasteCooked", left))
    elseif cauldron.fluid == M.ROTTEN_PULP then
        table.insert(notes, getText("IGUI_" .. P .. "_PulpRotten"))
    end
end)

-- An empty vessel a crock can go into (a clay jar or pot holds no fluid; a glass jar holds none).
local function emptyVessel(item)
    if M.PASTE_VESSELS[item:getFullType()] == nil then return false end
    local container = item:getFluidContainer()
    return not container or container:isEmpty()
end

local PACK_ICON = "media/textures/Item_TomatoPaste_Clay.png"

-- Brings the items to hand, walks to the cauldron if a source is one, then queues each action (make(): a new one).
local function queueWith(playerObj, sources, items, makes)
    local fire
    for _, source in ipairs(sources) do
        if source.tpfvFire then fire = source.tpfvFire else ISInventoryPaneContextMenu.transferIfNeeded(playerObj, source) end
    end
    for _, item in ipairs(items) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if fire and not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    for _, make in ipairs(makes) do ISTimedActionQueue.add(make()) end
end

-- Packs vessels in turn from sources, each with its own salt crust and seal's cap (each checks the paste is still
-- there, so All Jars stops when it runs out).
local function onPack(playerObj, sources, vessels, seal)
    local makes = {}
    for _, vessel in ipairs(vessels) do
        table.insert(makes, function() return TPPackTomatoPaste:new(playerObj, sources, vessel, seal) end)
    end
    local items = { unpack(vessels) }
    if seal then table.insert(items, seal) end
    queueWith(playerObj, sources, items, makes)
end

local function onAdd(playerObj, sources, crock, seal)
    queueWith(playerObj, sources, seal and { crock, seal } or { crock },
        { function() return TPAddTomatoPaste:new(playerObj, sources, crock, seal) end })
end

-- Why adding to any crock can't happen now, or nil.
local function addRefusal(playerObj)
    local refusal = pasteRefusal(playerObj)
    if not refusal and Uses.count(playerObj, ItemTag.SALT) < M.TOPUP_SALT then
        refusal = say("IGUI_" .. P .. "_PackNoSalt", tostring(M.TOPUP_SALT))
    end
    return refusal
end

-- A pot or saucepan holding paste.
local function holdsPaste(item)
    return item:getFluidContainer() ~= nil and M.pasteLitres(item:getFluidContainer()) > 0
end

-- The sources of paste in reach: pots and saucepans holding it, then a fitted cauldron near by holding it.
local function sourcesNear(playerObj)
    local sources = UI.findItems(playerObj, holdsPaste)
    local square = playerObj:getCurrentSquare()
    if square then
        for _, fire in ipairs(Fire.fittedNear(square, Cauldron.ID)) do
            if M.cauldronPaste(fire) > 0 then table.insert(sources, M.cauldronSource(fire)) end
        end
    end
    return sources
end

local cauldronIcon
local function sourceRow(menu, label, source)
    local option = menu:addOption(label)
    if source.tpfvFire then
        cauldronIcon = cauldronIcon or instanceItem(Cauldron.ITEM)
        option.itemForTexture = cauldronIcon
    else
        option.itemForTexture = source
    end
    return option
end

local function sourceName(source)
    if source.tpfvFire then return getItemNameFromFullType(Cauldron.ITEM) end
    return source:getDisplayName()
end

-- A row per source and, with two or more pots, All Pots: row(name, sources).
local function eachSource(sources, row)
    local pots = {}
    for _, source in ipairs(sources) do
        row(sourceName(source), { source })
        if not source.tpfvFire then table.insert(pots, source) end
    end
    if #pots > 1 then row(getText("ContextMenu_" .. P .. "_AllPots"), pots) end
end

-- Under option: Salt crust, then a cap per oil or fat carried, each packing vessels from sources.
local function packChoices(menu, option, playerObj, sources, vessels)
    local choices = menu:getNew(menu)
    menu:addSubMenu(option, choices)
    local plain = choices:addOption(getText("ContextMenu_" .. P .. "_AddSaltOnly"), playerObj, onPack, sources, vessels, nil)
    plain.itemForTexture = vessels[1]
    UI.tooltip(plain, getText("IGUI_" .. P .. "_PackHelp"))
    for _, seal in ipairs(M.sealsInReach(playerObj)) do
        local capped = choices:addOption(say("ContextMenu_" .. P .. "_AddCap", seal:getDisplayName()), playerObj, onPack,
            sources, vessels, seal)
        capped.itemForTexture = seal
        UI.tooltip(capped, getText("IGUI_" .. P .. "_PackHelp"))
    end
end

-- An addition's choices under option: on a sealed crock a row per oil or fat (a fresh cap, which it needs); on a
-- salt-crust one salt crust alone, then a row per oil or fat sealing it (a whole cap). add(seal) queues it.
local function addChoices(menu, option, crock, playerObj, add)
    local choices = menu:getNew(menu)
    menu:addSubMenu(option, choices)
    local sealed = crock:getFullType() == M.CROCK_SEALED
    if not sealed then
        local plain = choices:addOption(getText("ContextMenu_" .. P .. "_AddSaltOnly"), nil, function() add(nil) end)
        plain.itemForTexture = crock
        UI.tooltip(plain, getText("IGUI_" .. P .. "_AddHelp"))
    end
    local seals = M.sealsInReach(playerObj, sealed and M.TOPUP_SEAL_USES or M.PASTE_SEAL_USES)
    for _, seal in ipairs(seals) do
        local capped = choices:addOption(say(sealed and "ContextMenu_" .. P .. "_AddCap" or "ContextMenu_" .. P .. "_AddSeals",
            seal:getDisplayName(), tostring(M.PASTE_SEAL_USES)), nil, function() add(seal) end)
        capped.itemForTexture = seal
        UI.tooltip(capped, getText("IGUI_" .. P .. "_AddHelp"))
    end
    if sealed and #seals == 0 then UI.disable(option, getText("IGUI_" .. P .. "_AddNoSeal")) end
end

-- Pack Tomato Paste from sources (a pot, or the cauldron): a row per kind of empty vessel in reach, and with two or
-- more vessels All Jars (as many as the paste fills, 10 portions each, packed in turn), each opening its choices.
local function packFromMenu(context, playerObj, sources)
    local option = context:addOption(getText("ContextMenu_" .. P .. "_PackPaste"))
    option.iconTexture = getTexture(PACK_ICON)
    local litres = M.sourcesLitres(sources)
    local plan = M.packPlan(litres)
    local refusal = pasteRefusal(playerObj)
    if not refusal and plan.portions < 1 then refusal = getText("IGUI_" .. P .. "_PackTooLittle") end
    if not refusal and Uses.count(playerObj, ItemTag.SALT) < plan.salt then
        refusal = say("IGUI_" .. P .. "_PackNoSalt", tostring(plan.salt))
    end
    if refusal then return UI.disable(option, refusal) end
    local vessels = UI.findItems(playerObj, emptyVessel)
    if #vessels == 0 then return UI.disable(option, getText("IGUI_" .. P .. "_PackNoVessel")) end
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)
    local seen = {}
    for _, vessel in ipairs(vessels) do
        if not seen[vessel:getFullType()] then
            seen[vessel:getFullType()] = true
            local row = sub:addOption(say("ContextMenu_" .. P .. "_PackFrom", vessel:getDisplayName(), M.portionsText(plan.portions)))
            row.itemForTexture = vessel
            packChoices(sub, row, playerObj, sources, { vessel })
        end
    end
    local fills = math.min(#vessels, math.ceil(litres / M.PASTE_CROCK_L - 1e-6))
    if #vessels > 1 and fills > 1 then
        local all = {}
        for i = 1, fills do all[i] = vessels[i] end
        local row = sub:addOption(say("ContextMenu_" .. P .. "_AllJars", tostring(fills)))
        row.itemForTexture = vessels[1]
        packChoices(sub, row, playerObj, sources, all)
    end
end

-- Add to the Crock from sources: a row per started crock or jar in reach, greyed with why it can't, else its choices.
local function addToCrockMenu(context, playerObj, sources)
    local crocks = UI.findItems(playerObj, function(item) return M.CROCKS[item:getFullType()] ~= nil end)
    if #crocks == 0 then return end
    local option = context:addOption(getText("ContextMenu_" .. P .. "_AddToCrock"))
    option.itemForTexture = crocks[1]
    local refusal = addRefusal(playerObj)
    if refusal then return UI.disable(option, refusal) end
    local litres = M.sourcesLitres(sources)
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)
    for _, crock in ipairs(crocks) do
        local plan = M.topUpPlan(litres, crock)
        local row = sub:addOption(say("ContextMenu_" .. P .. "_AddRow", crock:getDisplayName(),
            M.portionsText(M.crockPortions(crock)), M.portionsText(plan.portions)))
        row.itemForTexture = crock
        if crock:isRotten() then
            UI.disable(row, getText("IGUI_" .. P .. "_AddRotten"))
        elseif plan.portions <= 0 then
            UI.disable(row, getText("IGUI_" .. P .. "_AddFull"))
        else
            addChoices(sub, row, crock, playerObj, function(seal) onAdd(playerObj, sources, crock, seal) end)
        end
    end
end

-- Add Tomato Paste on a crock's menu: a row per source in reach (pots, a cauldron) and All Pots (one addition, one
-- salt and one seal use), each opening its choices (addChoices).
local function addFromSourcesMenu(context, playerObj, crock)
    local sources = sourcesNear(playerObj)
    if #sources == 0 then return end
    local option = context:addOption(getText("ContextMenu_" .. P .. "_AddPaste"))
    option.itemForTexture = crock
    local refusal = addRefusal(playerObj)
    if not refusal and crock:isRotten() then refusal = getText("IGUI_" .. P .. "_AddRotten") end
    if not refusal and M.crockRoom(crock) < M.PASTE_EMPTY then refusal = getText("IGUI_" .. P .. "_AddFull") end
    if refusal then return UI.disable(option, refusal) end
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)
    eachSource(sources, function(name, from)
        local adds = M.portionsText(M.topUpPlan(M.sourcesLitres(from), crock).portions)
        local row = sourceRow(sub, say("ContextMenu_" .. P .. "_AddFrom", name, adds), from[1])
        addChoices(sub, row, crock, playerObj, function(seal) onAdd(playerObj, from, crock, seal) end)
    end)
end

local function onSpoon(playerObj, crock)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, crock)
    ISTimedActionQueue.add(TPSpoonTomatoPaste:new(playerObj, crock))
end

-- Pack Tomato Paste on an empty vessel's own menu: a row per source in reach (pots, a cauldron) and All Pots, each
-- opening salt crust alone or capped with each oil or fat carried.
local function packIntoMenu(context, playerObj, vessel)
    local sources = sourcesNear(playerObj)
    if #sources == 0 then return end
    local option = context:addOption(getText("ContextMenu_" .. P .. "_PackPaste"))
    option.iconTexture = getTexture(PACK_ICON)
    local refusal = pasteRefusal(playerObj)
    if refusal then return UI.disable(option, refusal) end
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)
    eachSource(sources, function(name, from)
        local plan = M.packPlan(M.sourcesLitres(from))
        local row = sourceRow(sub, say("ContextMenu_" .. P .. "_PackFrom", name, M.portionsText(plan.portions)), from[1])
        if plan.portions < 1 then return UI.disable(row, getText("IGUI_" .. P .. "_PackTooLittle")) end
        if Uses.count(playerObj, ItemTag.SALT) < plan.salt then
            return UI.disable(row, say("IGUI_" .. P .. "_PackNoSalt", tostring(plan.salt)))
        end
        packChoices(sub, row, playerObj, from, { vessel })
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local vessel = UI.firstSelected(items, emptyVessel)
    if vessel then packIntoMenu(context, playerObj, vessel) end
    local crock = UI.firstSelected(items, function(item) return M.CROCKS[item:getFullType()] end)
    if crock and M.crockPortions(crock) >= M.PASTE_EMPTY then
        local option = context:addOption(getText("ContextMenu_" .. P .. "_SpoonOut"), playerObj, onSpoon, crock)
        option.iconTexture = getTexture("Item_TomatoPaste")
    end
    if crock then
        addFromSourcesMenu(context, playerObj, crock)
        local empty = context:addOption(getText("ContextMenu_" .. P .. "_EmptyCrock"), playerObj, function()
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, crock)
            ISTimedActionQueue.add(TPEmptyTomatoPaste:new(playerObj, crock))
        end)
        empty.itemForTexture = crock
        UI.tooltip(empty, getText("IGUI_" .. P .. "_EmptyCrockHelp"))
    end
    local source = UI.firstSelected(items, holdsPaste)
    if not source then return end
    addToCrockMenu(context, playerObj, { source })
    packFromMenu(context, playerObj, { source })
end)

-- The Stone Hearth's cauldron holding paste: Pack Tomato Paste and Add to the Crock straight from it.
CauldronUI.addMenu(function(menu, playerObj, fire, cauldron)
    if cauldron.fluid ~= M.TOMATO_PASTE_FLUID or (cauldron.ml or 0) <= 0 then return end
    local sources = { M.cauldronSource(fire) }
    packFromMenu(menu, playerObj, sources)
    addToCrockMenu(menu, playerObj, sources)
end)

PlaceKeepingUI.watch(M.PASTE_KEEPER, M.PASTE_DAYS)
KeepingTooltip.add(M.PASTE_DAYS, function(item) return KeepingTooltip.keeperLines(M.PASTE_KEEPER, item) end)
