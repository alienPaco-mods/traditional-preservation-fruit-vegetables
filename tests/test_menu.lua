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
local square = H.shutRoom({ getX = function() return 5 end, getY = function() return 4 end, getZ = function() return 0 end, getObjects = function() return H.list({}) end,
    isOutside = function() return false end, isInARoom = function() return true end })
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
    function item:getOffAge() return self.offAge or 7 end
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
    hasModData = function() return true end,
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
local function canPickUp() return ISMoveableSpriteProps.canPickUpMoveable({}, playerObj, square, barrelObject) end
check("a fermenting barrel can't be picked up (user, 2026-11-19: no station is moved mid-process)", canPickUp() == false)
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
check("emptied, it picks up again", canPickUp() == true)

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

-- Kraut Barrel Info's pieces (art/kraut_info_mock.png): the band, the Station rows, the drag onto the cells, the cells
-- and the buttons by stage.
local KrautUI = TraditionalPreservationFruitVegetablesKrautUI
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local function heads(n, kind, extras)
    local b = { stage = n > 0 and "Packing" or nil, heads = {} }
    for _ = 1, n do table.insert(b.heads, { kind = kind or "cabbage", age = 0, food = {} }) end
    for extra, count in pairs(extras or {}) do
        for _ = 1, count do M.packExtra(b, extra, 0, {}, nil) end
    end
    return b
end
local word, text, look = KrautUI.band({}, { stage = "Empty" })
check("empty: a grey band asking for 20 to 60 heads", word == "Empty" and text == "pack 20 to 60 heads" and look == InfoWindow.BAND_IDLE)
word, text, look = KrautUI.band(heads(12), { stage = "Packing" })
check("packing under 20: amber, how many it needs", text == "12 heads, 20 to seal" and look == InfoWindow.BAND_WAITING)
word, text = KrautUI.band(heads(40), { stage = "Packing" })
check("packing 40: the salt it seals with", text == "40 heads, seals with 8 salt")
local sealed = { stage = "Fermenting", hotHours = 30, portions = { cabbage = 30, turnip = 10 }, headCounts = { cabbage = 30, turnip = 10 },
    apples = 2, carrots = 1 }
word, text, look = KrautUI.band(sealed, { stage = "Fermenting", temperature = 12, hoursLeft = 34 * 24, hotHours = 30, rate = 0.65, progress = 0.2 })
check("fermenting: green, ready in about 34 days", word == "Fermenting" and text == "ready in about 34 days" and look == InfoWindow.BAND_WORKING)
word, text, look = KrautUI.band(sealed, { stage = "Fermenting", temperature = 28, hoursLeft = 100, hotHours = 30 })
check("too warm now: red, the hours and when it goes soft", word == "Too warm" and text == "30 h above 27°C, soft at 48"
    and look == InfoWindow.BAND_AT_RISK)
sealed.hotHours = 60
word, text = KrautUI.band(sealed, { stage = "Fermenting", temperature = 28, hoursLeft = 100, hotHours = 60 })
check("already soft: when it spoils", text == "60 h above 27°C, spoils at 120")
word, text, look = KrautUI.band(sealed, { stage = "Fermenting", temperature = 0, hotHours = 0 })
check("stalled in the cold: amber", text == "stopped: too cold to sour" and look == InfoWindow.BAND_WAITING)
word, text, look = KrautUI.band({ soft = true }, { stage = "Ready", daysLeft = 170.4 })
check("ready but soft: amber, how long it keeps", word == "Soft" and text == "keeps about 170 d here" and look == InfoWindow.BAND_WAITING)
check("Speed and Too warm rows only while it ferments", #KrautUI.rows({ stage = "Fermenting", rate = 0.65, hotHours = 0 }) == 2
    and #KrautUI.rows({ stage = "Ready" }) == 0)

local function piece(fullType, rotten, age)
    return { getFullType = function() return fullType end, isRotten = function() return rotten == true end,
        getAge = function() return age or 0 end, getOffAge = function() return 7 end }
end
local judged = KrautUI.judgeDrop(heads(4), { piece("Base.Apple"), piece("Base.Turnip"), piece("Base.Cabbage"), piece("Base.Steak") })
check("a drag packs heads first, so their room lets an apple in; a steak is refused", #judged.take == 3
    and judged.take[3]:getFullType() == "Base.Apple" and judged.lines[1] == "Pack 3 in the barrel"
    and judged.refused == "Only cabbages, turnips, apples and carrots go in.")
judged = KrautUI.judgeDrop(heads(4), { piece("Base.Cabbage", false, 9), piece("Base.Cabbage", false, 9), piece("Base.Cabbage") })
check("stale heads in a drag say their kraut will be soft", #judged.take == 3 and judged.lines[2] == "2 stale: their kraut will be soft")
local packing = heads(20)
packing.heads[1].offAge, packing.heads[1].age = 7, 8
check("a packing barrel shows its stale heads under the cells", KrautUI.holding(packing, nil, 100).under == "1 stale: soft kraut")
check("a sealed barrel its soft portions left", KrautUI.holding({ stage = "Ready", portions = { cabbage = 20 }, headCounts = { cabbage = 20 },
    softHeads = { cabbage = 3 } }).under == "3 soft, taken first")
judged = KrautUI.judgeDrop(heads(4), { piece("Base.Turnip"), piece("Base.Turnip") })
check("turnips dragged show in the turnip pattern", judged.pattern:find("TPCell_Turnip", 1, true) ~= nil)
judged = KrautUI.judgeDrop(heads(60), { piece("Base.Cabbage") })
check("a full barrel refuses, nothing taken", #judged.take == 0 and judged.refused ~= nil and judged.lines[1] == judged.refused)
judged = KrautUI.judgeDrop(sealed, { piece("Base.Cabbage") })
check("a sealed barrel takes no drag", #judged.take == 0 and judged.refused ~= nil)
judged = KrautUI.judgeDrop({}, { piece("Base.Carrots") })
check("a carrot alone in an empty barrel needs heads", #judged.take == 0 and judged.refused ~= nil)
judged = KrautUI.judgeDrop(heads(4), { piece("Base.Cabbage", true) })
check("a rotten head is refused", #judged.take == 0 and judged.refused == "Rotten: it won't keep.")

local packing = heads(30, "cabbage", { apple = 2, carrot = 1 })
for _ = 1, 10 do table.insert(packing.heads, { kind = "turnip", age = 0, food = {} }) end
local held = KrautUI.holding(packing, {})
check("packing: 40 of 60, the mix, the extras under it, a drag target", held.amount == "40 / 60 heads"
    and held.state == "30 cabbages, 10 turnips" and held.under == nil and #held.counts == 2 and held.counts[1][1] == "Item_Apple" and held.counts[1][2] == 2
    and held.counts[2][1] == "Item_Carrots" and held.counts[2][2] == 1 and near(held.share, 40 / 60)
    and held.drop ~= nil and held.parts[1].weight == 30 and held.parts[2].weight == 10)
held = KrautUI.holding(sealed, {})
check("sealed: no drag, the heads", held.drop == nil and held.amount == "40 heads")
check("a kind at none is left out", KrautUI.holding(heads(20, "turnip"), {}).state == "20 turnips"
    and #KrautUI.holding(heads(20, "turnip"), {}).counts == 0)
local ready = { stage = "Ready", portions = { cabbage = 22, turnip = 10 }, headCounts = { cabbage = 30, turnip = 10 } }
held = KrautUI.holding(ready, {})
check("ready: the portions left", held.amount == "32 portions" and held.state == "22 Sauerkraut, 10 Sauer Turnip" and held.under == nil)
ready.apples, ready.carrots = 2, 0
check("ready: still shows what it was spiked with, a kind at none left out", #KrautUI.holding(ready, {}).counts == 1
    and KrautUI.holding(ready, {}).counts[1][2] == 2)

local asked
local buttons = KrautUI.buttons(packing, { salt = 0 }, function(mode) asked = mode end)
check("packing: Salt and Compress greyed with the reason, then Unpack (43)", #buttons == 2
    and buttons[1].title == "Salt and Compress (8 salt)" and buttons[1].enabled == false and buttons[1].tooltip ~= nil
    and buttons[2].title == "Unpack (43)")
buttons[2].onClick()
check("Unpack asks to unpack", asked == "unpack")
buttons = KrautUI.buttons(ready, {}, function(mode, pieces, kind) asked = { mode = mode, pieces = pieces, kind = kind } end)
check("ready: one menu button a kraut, One and All (n)", #buttons == 2 and buttons[1].title == "Take Sauerkraut (22)"
    and buttons[2].title == "Take SauerTurnip (10)" and #buttons[1].menu == 2 and buttons[1].menu[1].title == "One"
    and buttons[1].menu[2].title == "All (22)")
buttons[2].menu[2].onClick()
check("All takes every portion of its kind", asked.mode == "take" and #asked.pieces == 10 and asked.kind == "turnip")
buttons = KrautUI.buttons({ stage = "Ready", portions = { cabbage = 1, turnip = 0 } }, {}, function() end)
check("one portion left: one button, One alone", #buttons == 1 and #buttons[1].menu == 1)
buttons = KrautUI.buttons({ stage = "Spoiled" }, {}, function(mode) asked = mode end)
buttons[1].onClick()
check("spoiled: Empty", #buttons == 1 and asked == "empty")
check("no buttons while it ferments", #KrautUI.buttons(sealed, {}, function() end) == 0)

H.done()
