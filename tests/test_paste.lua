-- Checks tomato paste (TraditionalPreservationFruitVegetablesPaste.lua): the pot route's rules, a packing's portions
-- and salt, a cap of oil or fat and its food, a crock's keeping by place, spooning out, a glass jar's name and
-- another mod's fat only when it is on. Run from the mod folder: luajit tests/test_paste.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()

local known = { ["TraditionalPreservationDairy.ClarifiedButter"] = true }
getScriptManager = function() return { FindItem = function(_, fullType) return known[fullType] and {} or nil end } end
ScriptManager = { instance = { getItem = function(_, fullType)
    return { getActualWeight = function() return fullType == "Base.EmptyJar" and 0.2 or 0.5 end }
end } }
local NAMES = {}
getItemNameFromFullType = function(fullType) return NAMES[fullType] or fullType end
getText = function(key) return key end
ItemTag = { SALT = "base:salt" }
Fluid = { Get = function(name) return { name = name } end }

dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables
local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local Uses = require "TraditionalPreservationCore/Uses"

-- Food with the setters Portions and PlaceKeeping use.
local function food(fullType, o)
    o = o or {}
    local self = { fullType = fullType, modData = {}, hunger = o.hunger or -0.24, calories = o.calories or 28,
        carbohydrates = o.carbohydrates or 7, lipids = o.lipids or 0.4, proteins = o.proteins or 2.6, uses = o.uses,
        age = o.age or 0, offAge = o.offAge or 180, offAgeMax = o.offAgeMax or 240, model = 0 }
    function self:getFullType() return self.fullType end
    function self:getModData() return self.modData end
    function self:getHungChange() return self.hunger end
    function self:setHungChange(x) self.hunger = x end
    function self:setBaseHunger(x) self.base = x end
    function self:getCalories() return self.calories end
    function self:setCalories(x) self.calories = x end
    function self:getCarbohydrates() return self.carbohydrates end
    function self:setCarbohydrates(x) self.carbohydrates = x end
    function self:getLipids() return self.lipids end
    function self:setLipids(x) self.lipids = x end
    function self:getProteins() return self.proteins end
    function self:setProteins(x) self.proteins = x end
    function self:getCurrentUses() return self.uses end
    function self:setModelIndex(x) self.model = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:isRotten() return self.age >= self.offAgeMax end
    function self:setName(x) self.name = x end
    function self:setCustomName(x) self.customName = x end
    function self:setActualWeight(x) self.weight = x end
    function self:setCustomWeight(x) self.customWeight = x end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getContainer() return self.container end
    function self:getDisplayName() return self.fullType end
    function self:multiplyFoodValues(k)
        for _, key in ipairs({ "hunger", "calories", "carbohydrates", "lipids", "proteins" }) do self[key] = self[key] * k end
    end
    return self
end

-- An inventory that hands out food items and remembers them.
local function inventory()
    local self = { items = {} }
    function self:AddItem(fullType)
        local item = food(fullType, { offAge = M.PASTE_DAYS[fullType] and M.PASTE_DAYS[fullType][1] or 7,
            offAgeMax = M.PASTE_DAYS[fullType] and M.PASTE_DAYS[fullType][2] or 14 })
        item.container = self
        table.insert(self.items, item)
        return item
    end
    function self:contains(item) for _, it in ipairs(self.items) do if it == item then return true end end return false end
    function self:Remove(item) for i, it in ipairs(self.items) do if it == item then table.remove(self.items, i) end end end
    return self
end

-- The pot route
check("a tomato is 0.15 L of pulp: a 1.5 L pot takes 10, a 0.6 L saucepan 4",
    ItemFluid.pieceRoom(1.5, 0, false, M.PASTE_PIECE_ML) == 10 and ItemFluid.pieceRoom(0.6, 0, false, M.PASTE_PIECE_ML) == 4)
local pot = {}
ItemFluid.putPieces(pot, { 100 }, 0)
local fluid, burnt = M.TOMATO_PULP, false
for minute = 0, 180 do fluid, burnt = ItemFluid.advance(pot, fluid, minute / 60, true, "Base.Pot") end
check("3 hours steaming: paste, its clock on FluidAgeing, not the pot", fluid == M.TOMATO_PASTE_FLUID and pot.offAt == nil)
check("cooked down to a fifth: 10 tomatoes make 0.3 L, two portions", near(1.5 * M.PASTE_SHRINK, 0.3) and M.packPlan(0.3).portions == 2)
for minute = 181, 300 do fluid, burnt = ItemFluid.advance(pot, fluid, minute / 60, true, "Base.Pot"); if burnt then break end end
check("2 hours more and it scorches the pot", burnt and ItemFluid.burntItem(M.TOMATO_PASTE_FLUID, "Base.Pot") == M.SCORCHED_PASTE["Base.Pot"])
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
check("unpacked paste ages as a fluid: a week at 20 C, about a month at 4 C, frozen not at all, rotten pulp after",
    FluidAgeing.fluidKindOf(M.TOMATO_PASTE_FLUID) == M.PASTE_FLUID_KIND and M.PASTE_FLUID_KIND.spoilHours == 168
    and near(M.pasteRate(20), 1) and near(168 / M.pasteRate(4) / 24, 35) and M.pasteRate(-2) == 0
    and FluidAgeing.stage({ age = 168 }, M.PASTE_FLUID_KIND) == "Spoiled")

-- A packing's plan
local plan = M.packPlan(0.75)
check("0.75 L (25 tomatoes): 5 portions, 1 salt", plan.portions == 5 and near(plan.litres, 0.75) and plan.salt == 1)
plan = M.packPlan(5)
check("a crock takes 10 portions at most (1.5 L, 50 tomatoes), 2 salt (a part litre counts)", plan.portions == 10
    and near(plan.litres, 1.5) and plan.salt == 2)
check("under a portion packs nothing", M.packPlan(0.1).portions == 0)
plan = M.packPlan(0.21)
check("7 tomatoes (0.21 L): all of it, 1.4 portions, no scrap left", near(plan.litres, 0.21) and near(plan.portions, 1.4)
    and M.portionsText(plan.portions) == "1.4" and M.portionsText(2) == "2")
check("past the crock only more than a scrap stays", near(M.packPlan(1.505).litres, 1.505) and near(M.packPlan(1.8).litres, 1.5))

-- A cap of oil: its food shared over the portions
local oil = food("Base.OilVegetable", { calories = 2120, carbohydrates = 0, lipids = 240, proteins = 0, uses = 30 })
local sealFood = M.sealFood(oil)
check("3 of 30 uses of oil: a tenth of its food", near(sealFood.calories, 212) and near(sealFood.lipids, 24))
local portion = M.crockPortion(10, sealFood)
check("each of 10 portions five tomatoes' food, light on hunger, plus a tenth of the cap", near(portion.calories, 70 + 21.2)
    and near(portion.hunger, -0.10))

-- Packing with stand-ins for the player's reach
local taken = {}
Uses.take = function(_, tag, owed) taken[tag] = (taken[tag] or 0) + owed end
local lard = food("Base.Lard", { calories = 4095, lipids = 454, uses = 24 })
Uses.carried = function(_, fullType)
    return fullType == "Base.OilVegetable" and { oil } or fullType == "Base.Lard" and { lard } or {}
end
local bag = inventory()
local character = { getInventory = function() return bag end, getXp = function() return { AddXP = function() end } end }
local Action = require "TraditionalPreservationCore/Action"
Action.addXp = function() end
Action.removeItem = function(item) if item.container then item.container:Remove(item) end end
local container = { amount = 0.75 }
function container:getAmount() return self.amount end
function container:adjustSpecificFluidAmount(_, amount) self.amount = amount end
ItemFluid.oneFluid = function(c) return M.TOMATO_PASTE_FLUID, c.amount end
local source = { getFluidContainer = function() return container end }
local jar = bag:AddItem("Base.ClayJarGlazed")
local seals = M.sealsInReach(character)
check("a seal of each type in reach, oil first, then Lard", #seals == 2 and seals[1] == oil and seals[2] == lard)
local crock = M.packPaste(character, source, jar, oil)
check("packed under oil: a sealed crock of 5 portions in the glazed jar", crock.fullType == M.CROCK_SEALED
    and near(M.crockPortions(crock), 5) and crock.model == 1 and crock.modData.tpfvVessel == "Base.ClayJarGlazed")
check("the salt crust and the cap taken, the paste out of the pot", taken[ItemTag.SALT] == 1 and taken["Base.OilVegetable"] == 3
    and near(container.amount, 0))
check("its keeping: the sealed crock's year in a cellar", crock.offAge == 365 and crock.offAgeMax == 480)

-- A glass jar takes it too, named for the jar
container.amount = 0.3
local glass = bag:AddItem("Base.EmptyJar")
local inJar = M.packPaste(character, source, glass, nil)
check("in a glass jar: model 2, a salt crust only, called a jar", inJar.fullType == M.CROCK and inJar.model == 2
    and inJar.name == "IGUI_TraditionalPreservationFruitVegetables_PasteJar" and near(M.crockPortions(inJar), 2))

-- Adding to a crock: all the paste up to its room, one salt and one seal use, the age averaged
taken = {}
local started = bag:AddItem(M.CROCK_SEALED)
M.fillCrock(started, 5, "Base.ClayJar", M.sealFood(oil))
started.age = 30
M.keepCrock(started)
container.amount = 0.36
local added = M.addToCrock(character, source, started, lard)
check("a saucepan's worth and more: all of it in (2.4 portions), the pot empty", near(added, 2.4) and near(container.amount, 0)
    and near(M.crockPortions(started), 7.4))
check("one salt and one Lard use, however much it added", taken[ItemTag.SALT] == 1 and taken["Base.Lard"] == 1)
check("the age the portions' average: 30 days over 5 of 7.4", near(started.age, 30 * 5 / 7.4))
container.amount = 1.5
added = M.addToCrock(character, source, started, lard)
check("into the room only: 2.6 portions, the rest stays", near(added, 2.6) and near(container.amount, 1.5 - 0.39)
    and near(M.crockPortions(started), 10))
check("a full crock takes no more", M.topUpPlan(1, started).portions == 0 and M.addToCrock(character, source, started, lard) == 0)
local plain = bag:AddItem(M.CROCK)
M.fillCrock(plain, 2, "Base.ClayJar", nil)
M.keepCrock(plain)
taken = {}
container.amount = 0.12
check("a salt-crust crock: a 4-tomato saucepan in, salt only", near(M.addToCrock(character, source, plain, nil), 0.8)
    and taken[ItemTag.SALT] == 1 and taken["Base.Lard"] == nil and plain.fullType == M.CROCK)

local potA, potB = { amount = 0.3 }, { amount = 0.12 }
for _, c in ipairs({ potA, potB }) do
    c.getAmount, c.adjustSpecificFluidAmount = container.getAmount, container.adjustSpecificFluidAmount
end
local pots = { { getFluidContainer = function() return potA end }, { getFluidContainer = function() return potB end } }
local together = bag:AddItem(M.CROCK)
M.fillCrock(together, 1, "Base.ClayJar", nil)
M.keepCrock(together)
taken = {}
check("All Pots: a pot and a saucepan in one addition, one salt", near(M.addToCrock(character, pots, together, nil), 2.8)
    and near(potA.amount, 0) and near(potB.amount, 0) and taken[ItemTag.SALT] == 1 and near(M.crockPortions(together), 3.8))

-- A salt-crust crock capped on an addition: a whole cap, sealed from then on, its share of keeping carried
instanceItem = function(fullType) local made = food(fullType) made.container = nil return made end
Action.replaceItem = function(old, new) local inv = old.container inv:Remove(old) table.insert(inv.items, new) new.container = inv return new end
local salted = bag:AddItem(M.CROCK)
M.fillCrock(salted, 4, "Base.ClayJarGlazed", nil)
salted.age = 90
M.keepCrock(salted)
taken = {}
container.amount = 0.3
local addedNow, nowSealed = M.addToCrock(character, source, salted, lard)
check("capped on an addition: 3 Lard uses and 1 salt, a sealed crock in its place, the glazed model kept", near(addedNow, 2)
    and taken["Base.Lard"] == 3 and taken[ItemTag.SALT] == 1 and nowSealed.fullType == M.CROCK_SEALED and nowSealed.model == 1
    and not bag:contains(salted) and bag:contains(nowSealed) and near(M.crockPortions(nowSealed), 6))
check("its keeping share carried: 60 of 180 days (averaged) is 1/3, so 1/3 of 365", near(nowSealed.age, 60 * 365 / 180)
    and nowSealed.offAge == 365)
check("then it needs a cap: no seal, nothing added", M.addToCrock(character, source, nowSealed, nil) == 0)

local gone = bag:AddItem(M.CROCK)
M.fillCrock(gone, 1, "Base.ClayJar", nil)
gone.age = 250
M.keepCrock(gone)
container.amount = 0.3
check("a rotten crock takes no paste", gone:isRotten() and M.addToCrock(character, source, gone, nil) == 0 and near(container.amount, 0.3))
local back = M.emptyCrock(gone)
check("Empty the Crock: the paste thrown out, the clay jar back", not bag:contains(gone) and back ~= nil)

local capped = bag:AddItem(M.CROCK_SEALED)
M.fillCrock(capped, 2, "Base.ClayJar", M.sealFood(oil))
M.keepCrock(capped)
for _ = 1, 4 do container.amount = 0.3; M.addToCrock(character, source, capped, oil) end
check("four refreshes on a packed crock: still one cap's food (212 kcal) over its 10 portions", near(M.crockPortions(capped), 10)
    and near(capped.modData.tpfvPortion.calories, 70 + 212 / 10))

local potC, potD = { amount = 0.3 }, { amount = 0.3 }
for _, c in ipairs({ potC, potD }) do
    c.getAmount, c.adjustSpecificFluidAmount = container.getAmount, container.adjustSpecificFluidAmount
end
local fromTwo = M.packPaste(character, { { getFluidContainer = function() return potC end },
    { getFluidContainer = function() return potD end } }, bag:AddItem("Base.ClayJar"), nil)
check("packing from All Pots: two pots' 4 portions in one crock, both emptied", near(M.crockPortions(fromTwo), 4)
    and near(potC.amount, 0) and near(potD.amount, 0))

-- Spooning out
local spoon = M.spoonOut(character, inJar)
check("a spoonful: a portion of Tomato Paste, one fewer in the jar", spoon.fullType == M.PASTE_PORTION
    and near(spoon.hunger, -0.10) and near(spoon.calories, 70) and near(M.crockPortions(inJar), 1))
M.spoonOut(character, inJar)
local emptied = false
for _, item in ipairs(bag.items) do if item.fullType == "Base.EmptyJar" then emptied = true end end
check("the last spoonful gives the jar back", emptied)
local rotten = bag:AddItem(M.CROCK)
M.fillCrock(rotten, 2, "Base.ClayJar", nil)
rotten.age = 300
local bad = M.spoonOut(character, rotten)
check("a rotten crock spoons out rotten paste", bad.age >= bad.offAgeMax)

-- Keeping by place
local keeper = M.PASTE_KEEPER
check("a cellar day a day, a fridge half, 22 C two, frozen nothing", keeper.ageRate(15) == 1 and near(keeper.ageRate(4), 0.5)
    and near(keeper.ageRate(22), 2) and keeper.ageRate(-5) == 0)
check("salt crust: 180 days in a cellar, 90 in a warm room, a year in a fridge",
    near(180 / keeper.ageRate(22), 90) and near(180 / keeper.ageRate(4), 360))

-- Another mod's fat only when it is on
local types = {}
for _, fullType in ipairs(M.sealTypes()) do types[fullType] = true end
check("Dairy's Clarified Butter with Dairy on, Fish & Meat's Tallow not without it",
    types["TraditionalPreservationDairy.ClarifiedButter"] and not types["TraditionalPreservationFishMeat.Tallow"]
    and types["Base.Lard"] and types["Base.OilOlive"])

H.done()
