-- Traditional Preservation (Fruits and Vegetables) B42: the clamp's right-click menus. Dig a Clamp on bare dirt, as
-- vanilla's Dig Furrow (no build menu). A storage, so no Info window (user, session 77): its loot window is vanilla's.
-- Its menu says where its crops are and how warm, and does the shovel work: Earth Up, Take Down Soil and, once empty,
-- Level the Clamp.
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"

local M = TraditionalPreservationFruitVegetables
local say = UI.say
local KEY = "IGUI_TraditionalPreservationFruitVegetables_"
local MENU = "ContextMenu_TraditionalPreservationFruitVegetables_"
local CLAMP_ICON = "media/textures/Item_Clamp.png"
local ROW_ICONS = { earth = "Item_Shovel", unearth = "Item_Shovel", level = "Item_Shovel" }
local ROWS = { earth = MENU .. "EarthUp", unearth = MENU .. "TakeDownSoil", level = MENU .. "LevelClamp" }
local HELPS = { earth = KEY .. "EarthUpHelp", unearth = KEY .. "TakeDownSoilHelp", level = KEY .. "LevelClampHelp" }
local REFUSALS = { Earthed = KEY .. "ClampEarthed", NotEarthed = KEY .. "ClampNotEarthed", NotEmpty = KEY .. "ClampNotEmpty",
    NoShovel = KEY .. "NoShovel", NoGround = KEY .. "ClampNoGround", Grass = KEY .. "ClampGrass", NoHay = KEY .. "ClampNoHay" }

local function isShovel(item)
    return not item:isBroken() and item:hasTag(ItemTag.TAKE_DIRT)
end

local function itemCount(station)
    local container = station:getContainer()
    return container and container:getItems():size() or 0
end

local function onWork(playerObj, station, mode, shovel)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, shovel)
    ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), shovel, true, true)
    ISTimedActionQueue.add(TPClamp:new(playerObj, station, mode, shovel))
end

local function addWorkRow(menu, playerObj, station, mode, shovel)
    local option = menu:addOption(getText(ROWS[mode]), playerObj, onWork, station, mode, shovel)
    option.iconTexture = getTexture(ROW_ICONS[mode])
    local refusal = M.clampRefusal(mode, M.clampEarthed(station), itemCount(station), shovel ~= nil)
    if refusal then
        UI.refuse(option, getText(REFUSALS[refusal]))
    else
        UI.tooltip(option, say(HELPS[mode], M.SWEAT_C))
    end
end

local function addClampMenu(context, playerObj, station)
    -- A clamp built this session isn't tracked until its area reloads, so its menu starts it.
    if TraditionalPreservationFruitVegetablesWorld then TraditionalPreservationFruitVegetablesWorld.refreshClamp(station) end
    local option = context:addOption(getText("IGUI_ContainerTitle_clamp"))
    option.iconTexture = getTexture(CLAMP_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local earthed = M.clampEarthed(station)
    local place = M.clampPlace(station)
    local celsius = Weather.placeTemperature(Weather.weatherModData(), place)
    local status = menu:addOption(UI.placeText(place, celsius))
    status.isDisabled = true
    status.iconTexture = getTexture(CLAMP_ICON)
    local note = say(KEY .. "ClampHolds", itemCount(station))
    if earthed and celsius > M.SWEAT_C then note = note .. " <LINE> " .. say(KEY .. "ClampSweating", M.SWEAT_C) end
    UI.tooltip(status, note)

    local shovel = UI.findItems(playerObj, isShovel, true)[1]
    addWorkRow(menu, playerObj, station, earthed and "unearth" or "earth", shovel)
    if itemCount(station) == 0 then addWorkRow(menu, playerObj, station, "level", shovel) end
end

local function onDig(playerObj, square, shovel)
    if not luautils.walkAdj(playerObj, square) then return end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, shovel)
    local inventory = playerObj:getInventory()
    local hay = inventory:getItemsFromFullType(M.CLAMP_HAY.fullType, true)
    for i = 0, math.min(hay:size(), M.CLAMP_HAY.count) - 1 do ISWorldObjectContextMenu.transferIfNeeded(playerObj, hay:get(i)) end
    ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), shovel, true, true)
    ISTimedActionQueue.add(TPClamp:new(playerObj, square, "dig", shovel))
end

-- Dig a Clamp, as vanilla's Dig Furrow: offered with a shovel in reach on a square outdoors at ground level with no
-- clamp yet, greyed with the reason where the ground or the hay won't do. Returns true if it added the row.
local function addDigRow(context, playerObj, square, test)
    if not square or square:getZ() ~= 0 or not square:isOutside() or TPClamp.clampOn(square) then return false end
    local shovel = UI.findItems(playerObj, isShovel, true)[1]
    if not shovel then return false end
    if test then ISWorldObjectContextMenu.setTest() return true end
    local option = context:addOption(getText(MENU .. "DigClamp"), playerObj, onDig, square, shovel)
    option.iconTexture = getTexture("Item_Shovel")
    local refusal = TPClamp.digRefusal(playerObj, square, shovel)
    if refusal then
        UI.refuse(option, say(REFUSALS[refusal], M.CLAMP_HAY.count))
    else
        UI.tooltip(option, say(KEY .. "DigClampHelp", M.CLAMP_HAY.count))
    end
    return true
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    local clicked = worldobjects[1] and worldobjects[1]:getSquare()
    if addDigRow(context, playerObj, clicked, test) and test then return true end
    local seen = {}
    for _, isoObject in ipairs(worldobjects) do
        if M.isClamp(isoObject) and not seen[isoObject] then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            addClampMenu(context, playerObj, isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Its own icon in the loot window, not vanilla's shelves: the straw heap, or the soil dome once earthed up.
local CLAMP = require("TraditionalPreservationFruitVegetables/Tiles").CLAMP
UI.containerIcon(CLAMP.container, "media/textures/Container_Clamp.png")
UI.containerIcon(CLAMP.earthedContainer, "media/textures/Container_ClampEarthed.png")
