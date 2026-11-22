-- Checks the clamp (TraditionalPreservationFruitVegetablesClamp.lua): what it takes, the place it gives what lies in
-- it, its refusals and the sweating of an earthed clamp while warm. Run from the mod folder: luajit tests/test_clamp.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"

local function clamp(earthed)
    local object = {}
    local container = { object = object, type = earthed and Tiles.CLAMP.earthedContainer or Tiles.CLAMP.container }
    function object:getContainer() return container end
    function container:getType() return self.type end
    function container:setType(type) self.type = type end
    function container:isPowered() return false end
    function container:getParent() return self.object end
    function container:getContainingItem() return nil end
    return container, object
end

local function vegetable(fullType, container)
    local self = { fullType = fullType, age = 0, modData = {}, container = container, offAge = 6, offAgeMax = 8 }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getContainer() return self.container end
    function self:getOutermostContainer() return self.container end
    function self:getWorldItem() return nil end
    function self:isCooked() return self.cooked == true end
    function self:isBurnt() return false end
    return self
end

-- What goes in (user, session 77: potato, turnip, sugar beet, carrots, cabbage; no leek)
check("the clamped roots and heads go in", M.acceptClamp(nil, vegetable("Base.Potato")) and M.acceptClamp(nil, vegetable("Base.Carrots"))
    and M.acceptClamp(nil, vegetable("Base.Cabbage")) and M.acceptClamp(nil, vegetable("Base.SugarBeet")) and M.acceptClamp(nil, vegetable("Base.Turnip")))
check("no leek, onion, garlic or sweet potato", not M.acceptClamp(nil, vegetable("Base.Leek")) and not M.acceptClamp(nil, vegetable("Base.Onion"))
    and not M.acceptClamp(nil, vegetable("Base.Garlic")) and not M.acceptClamp(nil, vegetable("Base.SweetPotato")))
local cooked = vegetable("Base.Potato")
cooked.cooked = true
check("nothing cooked", not M.acceptClamp(nil, cooked))
check("the accept function is named as the World sets it", M.CLAMP_ACCEPT == "TraditionalPreservationFruitVegetables.acceptClamp")

-- The place: Core's StrawClamp under straw, EarthedClamp earthed over (Weather.placeTemperature)
local thatchedBox, thatched = clamp(false)
local earthedBox = clamp(true)
check("what lies in a thatched clamp is in a clamp", FluidAgeing.placeOfItem(vegetable("Base.Potato", thatchedBox)) == "StrawClamp")
check("in an earthed one, in an earthed clamp", FluidAgeing.placeOfItem(vegetable("Base.Potato", earthedBox)) == "EarthedClamp")
M.setClampEarthed(thatched, true)
check("earthing up moves what is in it to the earthed clamp", FluidAgeing.placeOfItem(vegetable("Base.Potato", thatchedBox)) == "EarthedClamp")
M.setClampEarthed(thatched, false)
check("earthing up is the container's type, which the loot window's title and icon follow", thatchedBox:getType() == "clamp"
    and (function() M.setClampEarthed(thatched, true); local t = thatchedBox:getType(); M.setClampEarthed(thatched, false); return t end)() == "earthedclamp")
check("taking the soil down moves it back", M.clampPlace(thatched) == "StrawClamp" and not M.clampEarthed(thatched))

-- Digging one (as vanilla's Dig Furrow: bare dirt under the sky, a shovel, 6 hay)
check("dig: grass still on it is refused, before the ground's other reasons", M.digRefusal(false, 6, true, true) == "Grass")
check("dig: a shovel first, then the ground, then the hay", M.digRefusal(true, 6, false) == "NoShovel"
    and M.digRefusal(false, 6, true) == "NoGround" and M.digRefusal(true, 5, true) == "NoHay" and M.digRefusal(true, 6, true) == nil)
check("it takes 6 hay, and 30 minutes", M.CLAMP_HAY.count == 6 and M.CLAMP_HAY.fullType == "Base.HayTuft" and M.CLAMP_MINUTES.dig == 30)

-- Refusals
check("earth up: refused once earthed, or without a shovel", M.clampRefusal("earth", true, 0, true) == "Earthed"
    and M.clampRefusal("earth", false, 5, false) == "NoShovel" and M.clampRefusal("earth", false, 5, true) == nil)
check("take the soil down: only when earthed", M.clampRefusal("unearth", false, 0, true) == "NotEarthed" and M.clampRefusal("unearth", true, 9, true) == nil)
check("level: only an empty clamp", M.clampRefusal("level", false, 1, true) == "NotEmpty" and M.clampRefusal("level", true, 0, true) == nil)

-- Sweating (user, session 77): earthed over above 8 C, its crops age half as fast again
local keeper = M.CROPS.carrots.keeper
check("each clamped crop's keeper has its sweating, none for a leek", keeper.sweat ~= nil and M.CROPS.potato.curedKeeper.sweat ~= nil
    and M.CROPS.leek.keeper.sweat == nil)
check("the sweating is half the keeping above 8 C, none at or below it",
    keeper.sweat.rate(8) == 0 and near(keeper.sweat.rate(13.5), keeper.ageRate(13.5) * 0.5) and near(keeper.sweat.rate(20), keeper.ageRate(20) * 0.5))

local function settle(celsius)
    for _, field in ipairs({ "temperature", "seasonTemperature", "threeDayTemperature", "dayTemperature", "groundTemperature" }) do
        keeper.ledger()[field] = celsius
    end
end
local function run(hours, celsius, from)
    for step = 1, hours do keeper.recordWeather(from + step, celsius) end
    return from + hours
end

settle(15)
local inEarthed, inThatched = vegetable("Base.Carrots", (clamp(true))), vegetable("Base.Carrots", (clamp(false)))
M.keepVegetable(inEarthed, 0)
M.keepVegetable(inThatched, 0)
local now = run(240, 15, 0)
M.keepVegetable(inEarthed, now)
M.keepVegetable(inThatched, now)
check("warm (13.5 C in both clamps), the earthed clamp's carrots age half as fast again",
    near(inEarthed.age, inThatched.age * 1.5, 1e-6) and inThatched.age > 0)
check("an earthed clamp's crop carries its sweating record, a thatched one's none",
    inEarthed.modData[M.SWEAT_KEY] ~= nil and inThatched.modData[M.SWEAT_KEY] == nil)

settle(0)
local earthedBefore, thatchedBefore = inEarthed.age, inThatched.age
now = run(240, 0, now)
M.keepVegetable(inEarthed, now)
M.keepVegetable(inThatched, now)
check("cold, no sweating: both age alike", near(inEarthed.age - earthedBefore, inThatched.age - thatchedBefore, 1e-6))

-- Taken out: the record ends, and the stretch since counts as where it went
inEarthed.container = nil
settle(15)
M.keepVegetable(inEarthed, now, "Sheltered")
check("taken out of the clamp, its sweating record ends", inEarthed.modData[M.SWEAT_KEY] == nil)

H.done()
