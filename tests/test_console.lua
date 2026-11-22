-- Checks the debug console (TPFV) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

-- Engine stand-ins
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return 20 end, getHumidity = function() return 50 end }
end
SandboxVars = { TraditionalPreservationFruitVegetables = { FermentDays = 20 } }
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player({ z = -1 })
function getPlayer() return player end

dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables
H.fire("OnInitGlobalModData")
local TPFV, run = H.checkConsole("42/media/lua/client/TraditionalPreservationFruitVegetablesDev.lua", "TPFV")

check("weather names every place and the souring", (function()
    local text = run("weather")
    for _, place in ipairs(M.PLACES) do
        if not text:find(place, 1, true) then return false end
    end
    return text:find("sours in", 1, true) ~= nil
end)())
check("here says where the player stands", run("here"):find("Basement", 1, true) ~= nil)
check("barrel says when none is loaded", run("barrel"):find("No kraut barrel", 1, true) ~= nil)

local before = M.getLedger()["ferment" .. M.PLACES[1]] or 0
run("age", 12)
check("age adds its hours of souring and keeping to every place", M.getLedger()["ferment" .. M.PLACES[1]] == before + 12
    and (M.getLedger()["keep" .. M.PLACES[1]] or 0) >= 12)

run("fast", 2)
check("fast sets the test timer", M.FERMENT_HOURS == 2)
run("fast")
check("fast with no number goes back to the sandbox time", M.FERMENT_HOURS == 20 * 24)

player.given = {}
run("give", "sauerkraut", 2)
check("give spawns kraut", #player.given == 2 and player.given[1] == "TraditionalPreservationFruitVegetables.Sauerkraut")
player.given = {}
run("kit", "barrel")
check("the barrel's kit: its build, two batches' heads, apples, carrots, salt and salting and compressing", #player.given == 1 + 1 + 7 + 10 + 4 + 30 + 6 + 6 + 30 + 2 + 1 + 1
    and player.given[1] == "Base.Hammer")
check("kit lists the kinds", run("kit", "?"):find("barrel", 1, true) ~= nil and run("kit"):find("cellar", 1, true) ~= nil
    and run("kit"):find("storage", 1, true) ~= nil)
player.given = {}
run("kit", "storage")
check("the storages' kit: three builds and what to put on them", #player.given == 1 + 1 + 9 + 12 + 1 + 2 + 4 + 10 + 4 + 2 + 10 + 10 + 6 + 6)

-- The cellar: a potato and a cabbage carried
player.given = {}
run("give", "potato", 2)
check("give spawns vegetables by crop name", #player.given == 2 and player.given[1] == "Base.Potato")
check("give with no name lists the vegetables and kraut", run("give"):find("potato", 1, true) ~= nil and run("give"):find("sauerTurnip", 1, true) ~= nil)
player.given = {}
run("kit", "cellar")
check("the cellar's kit: three of each kept vegetable", #player.given == 3 * #M.CROP_NAMES)

local function vegetable(fullType, offAge, offAgeMax)
    local self = { fullType = fullType, offAge = offAge, offAgeMax = offAgeMax, age = 0, modData = {} }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getContainer() return self.container end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getDisplayName() return self.fullType end
    function self:isCooked() return false end
    function self:isBurnt() return false end
    return self
end
local carried = { vegetable("Base.Potato", 28, 280), vegetable("Base.Cabbage", 2, 4) }
local inventory = player:getInventory()
function inventory:getAllEvalRecurse(wanted)
    local found = {}
    for _, item in ipairs(carried) do
        if wanted(item) then table.insert(found, item) end
    end
    return H.list(found)
end
check("cellar lists every crop by place", run("cellar"):find("cabbage", 1, true) ~= nil and run("cellar"):find("Basement", 1, true) ~= nil)
check("veg describes each vegetable carried", select(2, run("veg"):gsub("Base%.", "")) == 2)
carried[2].getContainer = function() return { getType = function() return "haycrate" end, getContainingItem = function() return nil end } end
check("veg shows a storage's keeping on top of the place", run("veg"):find("in the hay crate (keeping x0.75): 10 days fresh with it", 1, true) ~= nil)
carried[2].getContainer = function() return nil end
run("keep", 3)
check("keep ages them by their place, the cabbage further into its days", carried[1].age > 0
    and carried[2].age / carried[2].offAge > carried[1].age / carried[1].offAge)
check("cure cures the potato, not the cabbage", run("cure"):find("Cured 1 ", 1, true) ~= nil
    and carried[1].modData[M.CURED] == true and carried[2].modData[M.CURED] == nil)
carried = {}
check("veg says so when you carry none", run("veg"):find("No kept vegetables", 1, true) ~= nil)

H.done()
