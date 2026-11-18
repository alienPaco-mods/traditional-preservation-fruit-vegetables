-- Checks the Kraut Barrel's right-click menu and its hand jobs (TPKrautBarrel) with stand-ins for the engine: pack,
-- salt and compress, take kraut out. Run from the mod folder: luajit tests/test_menu.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules, TP Core's and the mod's action load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local ui = H.installMenus()
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return 18 end, getHumidity = function() return 50 end }
end
ItemTag.SALT = "base:salt"
Perks = { Cooking = "Cooking" }
local square = { getX = function() return 5 end, getY = function() return 4 end, getZ = function() return 0 end, getObjects = function() return H.list({}) end,
    isOutside = function() return false end, isInARoom = function() return true end }
function getCell()
    return { getGridSquare = function(_, x, y, z) if x == 5 and y == 4 and (z or 0) == 0 then return square end end }
end

-- What the player carries, as the inventory and the reach both see it.
local xp = {}
local function remove(item)
    for i, carried in ipairs(ui.carried) do
        if carried == item then return table.remove(ui.carried, i) end
    end
end
local inventory = { Remove = function(_, item) remove(item) end }
function inventory:containsRecursive(item)
    for _, carried in ipairs(ui.carried) do if carried == item then return true end end
    return false
end
function inventory:getFirstTypeRecurse(fullType)
    for _, carried in ipairs(ui.carried) do if carried:getFullType() == fullType then return carried end end
end
function inventory:getAllTagRecurse(tag, list)
    for _, carried in ipairs(ui.carried) do if carried.tag == tag then list:add(carried) end end
    return list
end
local given = {}
local playerObj = {
    getInventory = function() return inventory end,
    getXp = function() return { AddXP = function(_, perk, amount) xp[perk] = (xp[perk] or 0) + amount end } end,
    isTimedActionInstant = function() return false end,
    getSquare = function() return square end,
}
function getSpecificPlayer() return playerObj end
ArrayList = { new = function()
    local list = { items = {} }
    function list:add(x) table.insert(self.items, x) end
    function list:size() return #self.items end
    function list:get(i) return self.items[i + 1] end
    function list:isEmpty() return #self.items == 0 end
    return list
end }
Actions = { addOrDropItem = function(_, item) table.insert(given, item) end }
function instanceItem(fullType)
    local item = { fullType = fullType, modData = {} }
    for _, name in ipairs({ "BaseHunger", "HungChange", "Calories", "Carbohydrates", "Proteins", "Lipids", "UnhappyChange",
        "BoredomChange", "OffAge", "OffAgeMax", "Age" }) do
        item["set" .. name] = function(self, x) self[name] = x end
    end
    function item:getFullType() return self.fullType end
    return item
end

local function food(fullType, age, hunger, calories)
    local item = { fullType = fullType, age = age or 0 }
    function item:getFullType() return self.fullType end
    function item:getAge() return self.age end
    function item:isRotten() return self.rotten == true end
    function item:getHungChange() return hunger end
    function item:getCalories() return calories end
    function item:getCarbohydrates() return 1 end
    function item:getProteins() return 1 end
    function item:getLipids() return 0 end
    function item:getContainer() return inventory end
    function item:getCurrentUses() return self.uses or 0 end
    function item:setCurrentUses(x) self.uses = x end
    function item:getWorldItem() return nil end
    function item:isFavorite() return false end
    return item
end

require "TraditionalPreservationFruitVegetables"
local M = TraditionalPreservationFruitVegetables
require "TimedActions/TPKrautBarrel"
require "TimedActions/TPBraid"
CharacterActionAnims = { Craft = "Craft" }
function isClient() return false end
MapObjects = { OnLoadWithSprite = function() end }
dofile("42/media/lua/server/TraditionalPreservationFruitVegetablesWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationFruitVegetablesUI.lua")
local handlers = H.handlers.OnFillWorldObjectContextMenu
local onFillMenu = handlers[#handlers]

local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
local modData = {}
local barrelObject = {
    getSprite = function() return { getName = function() return Tiles.STATIONS[1] end } end,
    getModData = function() return modData end,
    getSquare = function() return square end,
    isOutside = function() return false end,
    clearAttachedAnimSprite = function() end,
    addAttachedAnimSpriteByName = function() end,
}

local function menuFor()
    local context = H.menu()
    onFillMenu(0, context, { barrelObject }, false)
    return context.options[1].subOption
end

local function named(menu, prefix)
    for _, option in ipairs(menu.options) do
        if option.name:sub(1, #prefix) == prefix then return option end
    end
end

local function runQueued()
    local queued = ui.queued
    ui.queued = {}
    for _, action in ipairs(queued) do
        action.setActionAnim = function() end
        if action:isValid() then
            action:start()
            action:complete()
        end
    end
end

check("a probe for the controller's prompt finds the barrel", (function()
    local before = ui.probes
    onFillMenu(0, H.menu(), { barrelObject }, true)
    return ui.probes == before + 1
end)())

-- An empty barrel with 35 cabbages and 3 apples carried
for i = 1, 35 do table.insert(ui.carried, food("Base.Cabbage", i / 10, -0.24, 180)) end
for _ = 1, 3 do table.insert(ui.carried, food("Base.Apple", 1, -0.16, 95)) end
local menu = menuFor()
local pack = named(menu, "Pack Cabbage")
check("Pack Cabbage: All (35 held), then One", pack and pack.name == "Pack Cabbage"
    and pack.subOption.options[1].name == "All (35)" and pack.subOption.options[2].name == "One")
check("Pack Turnip says none in reach", named(menu, "Pack Turnip").notAvailable == true)
check("an apple needs heads first", named(menu, "Add Apple").notAvailable == true)
check("no Salt and Compress on an empty barrel", named(menu, "Salt and Compress") == nil)

-- Pack 30
pack.subOption.options[1].onSelect(pack.subOption.options[1].target, unpack(pack.subOption.options[1].args))
check("All queues one action a head, oldest first", #ui.queued == 35 and ui.queued[1].item.age == 3.5)
for i = 31, 35 do ui.queued[i] = nil end
runQueued()
local barrel = M.barrelOf(barrelObject)
check("30 heads packed, 5 left carried with the apples, no xp yet", M.headCount(barrel) == 30 and #ui.carried == 8 and xp.Cooking == nil
    and barrel.heads[1].food.calories == 180 and near(barrel.heads[1].age, 3.5))

menu = menuFor()
check("the status row says packing, with its contents", menu.options[1].name:find("Packing", 1, true) ~= nil
    and menu.options[1].name:find("30 cabbages", 1, true) ~= nil)
local compress = named(menu, "Salt and Compress")
check("Salt and Compress asks 6 salt, refused without salt", compress.name:find("6 salt", 1, true) ~= nil and compress.notAvailable == true
    and compress.toolTip.description:find("6 uses of salt", 1, true) ~= nil)
check("Unpack is offered while packing", named(menu, "Unpack the Barrel") ~= nil)
local apple = named(menu, "Add Apple")
apple.subOption.options[2].onSelect(apple.subOption.options[2].target, unpack(apple.subOption.options[2].args))
runQueued()
check("an apple goes in", M.extraCount(barrel, "apple") == 1)

-- The salting and compressing kit
local salt = food("Base.Salt", 0, -0.1, 0)
salt.tag, salt.uses = "base:salt", 10
local sheet, plank, stone = food("Base.RippedSheets"), food("Base.Plank"), food("Base.FlatStone")
for _, item in ipairs({ salt, sheet, plank, stone }) do table.insert(ui.carried, item) end
menu = menuFor()
compress = named(menu, "Salt and Compress")
check("with salt, a cloth, a plank and a stone it can be salted and compressed", not compress.notAvailable)
compress.onSelect(compress.target, unpack(compress.args))
check("the cloth, plank and stone are carried first", #ui.moved >= 3)
runQueued()
check("salted and compressed: fermenting, 6 salt and the kit taken, 10 xp and 1 a piece packed", M.barrelStage(barrel) == "Fermenting" and salt.uses == 4
    and not inventory:containsRecursive(sheet) and not inventory:containsRecursive(plank) and not inventory:containsRecursive(stone)
    and xp.Cooking == 30 + 1 + 10)
menu = menuFor()
check("sealed: no packing rows, no unpack", named(menu, "Pack Cabbage") == nil and named(menu, "Unpack the Barrel") == nil
    and named(menu, "Add Apple") == nil)

-- Ready: take kraut out
barrel.workHours = M.FERMENT_HOURS
M.updateBarrel(barrel, M.getLedger(), "Sheltered")
menu = menuFor()
local take = named(menu, "Take Sauerkraut")
check("ready: Take Sauerkraut (30 left)", take ~= nil and take.name:find("30 left", 1, true) ~= nil)
take.subOption.options[2].onSelect(take.subOption.options[2].target, unpack(take.subOption.options[2].args))
runQueued()
check("one portion out, with the batch's food and no mood", #given == 1
    and given[1].fullType == "TraditionalPreservationFruitVegetables.Sauerkraut" and near(given[1].Calories, 180 + 95 / 30)
    and given[1].UnhappyChange == nil and given[1].BoredomChange == nil and M.portionsLeft(barrel) == 29)
take = named(menuFor(), "Take Sauerkraut")
take.subOption.options[1].onSelect(take.subOption.options[1].target, unpack(take.subOption.options[1].args))
runQueued()
check("All takes the other 29 and the plank and stone come back", #given == 32 and given[31].fullType == "Base.Plank"
    and given[32].fullType == "Base.FlatStone"
    and M.barrelStage(barrel) == "Empty")

-- Braid Garlic on 12 selected bulbs (vanilla's stacked entry), Unbraid on a braid
local inventoryHandlers = H.handlers.OnFillInventoryObjectContextMenu
local onInventoryMenu = inventoryHandlers[#inventoryHandlers]
local garlic = {}
for i = 1, 12 do
    garlic[i] = food("Base.Garlic", 0, -0.05, 14)
    garlic[i].isCooked = function() return false end
    garlic[i].isBurnt = function() return false end
end
local context = H.menu()
onInventoryMenu(0, context, { { items = garlic } })
local braid = context:getOptionFromName("Braid Garlic (10)")
check("Braid Garlic offers 10 of 12 selected", braid ~= nil)
ui.queued = {}
braid.onSelect(braid.target, unpack(braid.args))
check("one braiding action, taking 10 bulbs", #ui.queued == 1 and #ui.queued[1].bulbs == 10 and ui.queued[1].kind == "garlic")
context = H.menu()
onInventoryMenu(0, context, { garlic[1] })
check("one bulb alone is too few to braid", context:getOptionFromName("Braid Garlic (1)") == nil)
local braidItem = { getFullType = function() return "TraditionalPreservationFruitVegetables.GarlicBraid" end }
context = H.menu()
onInventoryMenu(0, context, { braidItem })
check("a braid offers Unbraid", context:getOptionFromName("Unbraid") ~= nil)

H.done()
