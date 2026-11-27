-- Traditional Preservation (Fruits and Vegetables): tomato paste (ROADMAP §8 phase 4; user, 2026-11-27). The
-- Sicilian 'strattu, Turkish and Balkan salca and the autumn ajvar's way, cooked down at the fire all year round:
-- tomatoes go into a pot or saucepan (TP Core's ItemFluid) or the Stone Hearth's cauldron (CauldronFluid) as Tomato
-- Pulp, a tomato's PASTE_PIECE_ML each; kept steaming PASTE_COOK_HOURS they cook down to Tomato Paste, a fifth of it. In a pot, PASTE_SCORCH_HOURS
-- more steaming scorches it (the vessel swapped for its scorched item); the cauldron never scorches. Pulp left raw
-- goes off when its oldest tomato would have; cooked paste not packed keeps about a week at 20 C, by place, wherever
-- it is poured (FluidAgeing), so the crock is what keeps it. Pack Tomato Paste puts it into an empty clay
-- jar or pot, or a glass jar (no lid needed), under a salt
-- crust (PASTE_SALT_PER_L uses a litre), optionally capped with oil or fat (PASTE_SEAL_USES of it, its food into the
-- crock): a Crock of Tomato Paste, a portion per PASTE_PORTION_L, keeping by place (TP Core's PlaceKeeping) on the
-- cellar's days, a capped one twice as long. Spoon Out Tomato Paste takes a portion for a dish; the crock can also
-- be eaten from as Fish & Meat's Crock of Potted Meat. Required by TraditionalPreservationFruitVegetables.lua.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"
local Portions = require "TraditionalPreservationCore/Portions"
local Uses = require "TraditionalPreservationCore/Uses"
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"

M.TOMATO = "Base.Tomato"
M.TOMATOES = { [M.TOMATO] = true }
-- Fluids: never rename them once the mod is out, saves hold the names.
M.TOMATO_PULP = "TomatoPulp"
M.TOMATO_PASTE_FLUID = "TomatoPaste"
M.ROTTEN_PULP = "RottenTomatoPulp"
M.PASTE_PIECE_ML = 150          -- a tomato's pulp
M.PASTE_COOK_HOURS = 3          -- steaming until it is paste
M.PASTE_SCORCH_HOURS = 2        -- more steaming in a pot scorches it
M.PASTE_SHRINK = 0.2            -- cooked down to a fifth of the pulp: 10 tomatoes (1.5 L) to 0.3 L
M.PASTE_PORTION_L = 0.15        -- five tomatoes' paste: a portion in the crock
M.PASTE_CROCK_L = 1.5           -- a full crock: 10 portions, 50 tomatoes (user, 2026-11-27: "50 tomatoes to a crock, for gameplay sake")
M.PASTE_PORTION_WEIGHT = 0.15   -- a portion's weight in the crock
M.PASTE_SALT_PER_L = 1          -- the salt crust's uses a litre (any part counts)
M.PASTE_SEAL_USES = 3           -- a thin cap of oil or fat: 3 of a bottle's 30 uses
-- Adding paste to a crock already packed (Add to the Crock; user, 2026-11-27): any number of portions up to its room
-- at a time, each addition a fresh salt crust and, on a sealed crock, a fresh cap, whatever it adds. A salt-crust
-- crock may be capped on an addition: a whole new cap (PASTE_SEAL_USES), and it is a sealed crock from then on.
M.TOPUP_SALT = 1
M.TOPUP_SEAL_USES = 1
M.PASTE_CROCK_PORTIONS = 10     -- M.PASTE_CROCK_L / M.PASTE_PORTION_L
M.PASTE_SKILL = 1               -- Cooking, to put tomatoes in and to pack
M.PASTE_XP = 2                  -- Cooking, a portion packed

M.CROCK = "TraditionalPreservationFruitVegetables.CrockOfTomatoPaste"
M.CROCK_SEALED = "TraditionalPreservationFruitVegetables.CrockOfTomatoPasteSealed"
M.CROCKS = { [M.CROCK] = true, [M.CROCK_SEALED] = true }
M.PASTE_PORTION = "TraditionalPreservationFruitVegetables.TomatoPaste"
-- The vessels a crock goes into, with the model index (icon and world model) each gives it: 0 unglazed, 1 glazed,
-- 2 a glass jar (user, 2026-11-27: no lid needed, the same seals). A Ceramic Pot shares vanilla's unglazed jar icon.
M.PASTE_VESSELS = { ["Base.ClayJar"] = 0, ["Base.ClayJarGlazed"] = 1, ["Base.ClayPot"] = 0,
    ["Base.EmptyJar"] = 2, ["Base.JarCrafted"] = 2 }
M.GLASS_INDEX = 2
-- What caps a crock: oil (the tradition: it flows back as paste is spooned out) or a solid fat (pure fat, airtight,
-- as confit). Fat from another TP mod counts only when that mod is on (M.sealTypes).
M.PASTE_SEALS = { "Base.OilOlive", "Base.OilVegetable", "Base.Lard",
    "TraditionalPreservationDairy.ClarifiedButter", "TraditionalPreservationFishMeat.Tallow" }
-- Pots and saucepans, and what each becomes scorched.
M.SCORCHED_PASTE = {
    ["Base.Pot"] = "TraditionalPreservationFruitVegetables.PotOfScorchedTomatoPaste",
    ["Base.PotForged"] = "TraditionalPreservationFruitVegetables.PotForgedScorchedTomatoPaste",
    ["Base.Saucepan"] = "TraditionalPreservationFruitVegetables.SaucepanScorchedTomatoPaste",
    ["Base.SaucepanCopper"] = "TraditionalPreservationFruitVegetables.SaucepanCopperScorchedTomatoPaste",
}
M.PASTE_POTS = {}
for vessel in pairs(M.SCORCHED_PASTE) do M.PASTE_POTS[vessel] = true end
-- Under this many portions a crock counts as eaten out (the engine keeps hunger as a 32-bit float).
M.PASTE_EMPTY = 0.05

ItemFluid.turnsHot(M.TOMATO_PULP, M.TOMATO_PASTE_FLUID, M.PASTE_COOK_HOURS, nil, M.PASTE_SHRINK)
ItemFluid.goesOff(M.TOMATO_PULP, M.ROTTEN_PULP)
ItemFluid.burns(M.TOMATO_PASTE_FLUID, M.PASTE_SCORCH_HOURS, M.SCORCHED_PASTE)
ItemFluid.staysIn(M.TOMATO_PULP)
CauldronFluid.turnsHot(M.TOMATO_PULP, M.TOMATO_PASTE_FLUID, M.PASTE_COOK_HOURS, nil, M.PASTE_SHRINK)
CauldronFluid.goesOff(M.TOMATO_PULP, M.ROTTEN_PULP)

-- Cooked paste not yet packed ages as milk and wort do, on TP Core's FluidAgeing (side agent's catch, 2026-11-27):
-- its age goes with it when it is poured, ladled into or out of the cauldron, so moving it never makes it fresh. A
-- week at 20 C, slower in the cold (a month or so at 4 C), stopped frozen; cooking it again (a pot topped up) starts
-- it afresh, as reboiling does. One stage: rotten pulp is both its turned and its spoiled fluid.
M.PASTE_PROCESS = "tomatoPaste"
M.PASTE_SPOIL_HOURS = 7 * 24
M.PASTE_FLUID_CURVE = { { 0, 0 }, { 4, 0.2 }, { 10, 0.4 }, { 20, 1 }, { 30, 2 } }
function M.pasteRate(celsius)
    return Weather.curve(M.PASTE_FLUID_CURVE, celsius)
end
M.PROCESSES[M.PASTE_PROCESS] = M.pasteRate
M.PASTE_FLUID_KIND = FluidAgeing.register({
    process = M.PASTE_PROCESS,
    rate = M.pasteRate,
    turnHours = M.PASTE_SPOIL_HOURS,
    spoilHours = M.PASTE_SPOIL_HOURS,
    fresh = { [M.TOMATO_PASTE_FLUID] = M.ROTTEN_PULP },
    spoiled = { [M.TOMATO_PASTE_FLUID] = M.ROTTEN_PULP },
    getLedger = function() return M.getLedger() end,
    speed = FluidAgeing.foodRotSpeed,
})

-- A save from before the paste has no ledger totals for it: filled once as the save loads.
Events.OnInitGlobalModData.Add(function() Weather.fillLedger(M.getLedger(), M.PROCESSES) end)
CauldronFluid.staysIn(M.TOMATO_PULP)
CauldronFluid.staysIn(M.ROTTEN_PULP)

-- Hours until a tomato is rotten (the pulp goes off when its oldest tomato would have).
function M.tomatoHoursLeft(item)
    return math.max(item:getOffAgeMax() - item:getAge(), 0) * 24
end

-- The seal types in game: another mod's fat only when its item exists.
function M.sealTypes()
    local found = {}
    for _, fullType in ipairs(M.PASTE_SEALS) do
        if fullType:sub(1, 5) == "Base." or getScriptManager():FindItem(fullType) then table.insert(found, fullType) end
    end
    return found
end

-- One seal of each type in reach with uses enough for a cap (uses: how many it must have, a full cap's by default), in M.PASTE_SEALS order (user, 2026-11-27: a row each,
-- so Lard can be picked over oil).
function M.sealsInReach(character, uses)
    uses = uses or M.PASTE_SEAL_USES
    local found = {}
    for _, fullType in ipairs(M.sealTypes()) do
        for _, item in ipairs(Uses.carried(character, fullType, true)) do
            if item:getCurrentUses() >= uses then
                table.insert(found, item)
                break
            end
        end
    end
    return found
end

-- Litres of paste in a container (only paste in it), or 0.
function M.pasteLitres(container)
    local fluid, litres = ItemFluid.oneFluid(container)
    if fluid ~= M.TOMATO_PASTE_FLUID then return 0 end
    return litres or 0
end

-- What one packing takes from litres of paste: { litres, portions, salt }. A part portion stays in the pot.
-- The litres of paste that go in, of litres in the pot, with roomL left in the crock: all of it, a part portion too, so
-- no scrap stays in the pot (user, 2026-11-27: "will there be an annoying tiny leftover?"); past the room only what
-- is more than a scrap (PASTE_EMPTY of a portion) stays.
local function intoCrock(litres, roomL)
    if litres - roomL < M.PASTE_EMPTY * M.PASTE_PORTION_L then return litres end
    return math.max(0, roomL)
end

-- A packing of litres of paste: { litres, portions (a part one in it too), salt }. A portion at least, or 0 portions.
function M.packPlan(litres)
    if litres < M.PASTE_PORTION_L - 1e-6 then return { litres = 0, portions = 0, salt = 0 } end
    local used = intoCrock(litres, M.PASTE_CROCK_L)
    return { litres = used, portions = used / M.PASTE_PORTION_L, salt = math.ceil(used / 1 - 1e-6) * M.PASTE_SALT_PER_L }
end

-- A count of portions as the menus show it: whole, or to a tenth.
function M.portionsText(portions)
    if math.abs(portions - math.floor(portions + 0.5)) < 0.05 then return string.format("%d", math.floor(portions + 0.5)) end
    return string.format("%.1f", portions)
end

-- A portion's food: five tomatoes' (vanilla Tomato's values), but light on hunger (-10, as the engine keeps it
-- -0.10): paste is a seasoning, concentrated, not bulk.
M.PASTE_PORTION_FOOD = { hunger = -0.10, calories = 70, carbohydrates = 17.5, lipids = 1.0, proteins = 6.5 }

-- The food a seal adds over a crock's portions: its share of the seal item's food for taken uses (a full cap's by
-- default).
function M.sealFood(seal, taken)
    local uses = seal:getCurrentUses()
    if uses <= 0 then return { calories = 0, carbohydrates = 0, lipids = 0, proteins = 0 } end
    local share = (taken or M.PASTE_SEAL_USES) / uses
    return { calories = seal:getCalories() * share, carbohydrates = seal:getCarbohydrates() * share,
        lipids = seal:getLipids() * share, proteins = seal:getProteins() * share }
end

-- One portion of a crock: the paste's, plus the seal's food shared over the portions (no hunger: a thin cap).
function M.crockPortion(portions, sealFood)
    local portion = {}
    for key, amount in pairs(M.PASTE_PORTION_FOOD) do portion[key] = amount end
    if sealFood and portions > 0 then
        for key, amount in pairs(sealFood) do portion[key] = (portion[key] or 0) + amount / portions end
    end
    return portion
end

-- The portions left in a crock.
function M.crockPortions(crock)
    local portion = crock:getModData().tpfvPortion
    if not portion or portion.hunger == 0 then return 0 end
    return crock:getHungChange() / portion.hunger
end

-- The crock's plain name ("Jar of Tomato Paste" in a glass jar), and the weight of the vessel and what is left in it.
function M.labelCrock(crock)
    local crockModData = crock:getModData()
    if M.PASTE_VESSELS[crockModData.tpfvVessel or ""] == M.GLASS_INDEX then
        crock:setName(getText(crock:getFullType() == M.CROCK_SEALED and "IGUI_TraditionalPreservationFruitVegetables_PasteJarSealed"
            or "IGUI_TraditionalPreservationFruitVegetables_PasteJar"))
        crock:setCustomName(true)
    else
        crock:setName(getItemNameFromFullType(crock:getFullType()))
        crock:setCustomName(false)
    end
    Portions.weigh(crock, M.crockPortions(crock), crockModData.tpfvVessel or "Base.ClayJar", crockModData.tpfvPortionWeight or 0)
end

-- A new crock: portions of paste in the vessel (a full type), its seal's food shared in.
function M.fillCrock(crock, portions, vessel, sealFood)
    local crockModData = crock:getModData()
    crockModData.tpfvVessel = vessel
    crockModData.tpfvPortion = M.crockPortion(portions, sealFood)
    crockModData.tpfvPortionWeight = M.PASTE_PORTION_WEIGHT
    crock:setModelIndex(M.PASTE_VESSELS[vessel] or 0)
    Portions.set(crock, crockModData.tpfvPortion, portions, portions)
    crock:setAge(0)
    M.labelCrock(crock)
end

-- A crock with no packing of its own (the debug Item List, loot): what its script gives, one portion in a plain jar.
function M.adoptCrock(crock)
    local crockModData = crock:getModData()
    if crockModData.tpfvPortion then return end
    crockModData.tpfvVessel = crockModData.tpfvVessel or "Base.ClayJar"
    crockModData.tpfvPortion = M.crockPortion(1, nil)
    crockModData.tpfvPortion.hunger = crock:getHungChange()
    crockModData.tpfvPortionWeight = M.PASTE_PORTION_WEIGHT
end

-- After any eat or spoonful: an emptied crock goes back to its container as its vessel; one with paste left is
-- weighed again. Returns the empty vessel, if any.
function M.afterCrockUse(crock, container)
    return Portions.used(crock, container, function() return M.crockPortions(crock) >= M.PASTE_EMPTY end,
        crock:getModData().tpfvVessel or "Base.ClayJar", M.labelCrock)
end

-- The paste in sources (a pot or a list of pots), in litres.
local function sourceList(sources)
    if sources.getFluidContainer then return { sources } end
    return sources
end
function M.sourcesLitres(sources)
    local litres = 0
    for _, source in ipairs(sourceList(sources)) do litres = litres + M.pasteLitres(source:getFluidContainer()) end
    return litres
end

-- Takes litres of paste out of sources, the pots in turn.
local function drawPaste(sources, litres)
    for _, source in ipairs(sourceList(sources)) do
        local container = source:getFluidContainer()
        local take = math.min(litres, M.pasteLitres(container))
        if take > 0 then
            container:adjustSpecificFluidAmount(Fluid.Get(M.TOMATO_PASTE_FLUID), container:getAmount() - take)
            litres = litres - take
        end
    end
end

-- Packs a crock (character's work): paste out of sources (a pot holding only paste, or a list of them, in turn) into the vessel (an empty clay
-- jar or pot), the salt crust taken from what is in reach and, with seal (an item with PASTE_SEAL_USES uses or
-- more), its cap. Returns the crock, or nil when there is too little paste.
function M.packPaste(character, sources, vessel, seal)
    local plan = M.packPlan(M.sourcesLitres(sources))
    if plan.portions < 1 then return nil end
    local sealFood = seal and M.sealFood(seal)
    if seal then Uses.take(character, seal:getFullType(), M.PASTE_SEAL_USES, true) end
    Uses.take(character, ItemTag.SALT, plan.salt)
    drawPaste(sources, plan.litres)
    local vesselType = vessel:getFullType()
    local inventory = character:getInventory()
    Action.removeItem(vessel)
    local crock = inventory:AddItem(seal and M.CROCK_SEALED or M.CROCK)
    M.fillCrock(crock, plan.portions, vesselType, sealFood)
    M.keepCrock(crock)
    Action.addXp(character, { "Cooking", M.PASTE_XP * plan.portions })
    return crock
end

-- The portions a crock has room for.
function M.crockRoom(crock)
    return math.max(0, M.PASTE_CROCK_PORTIONS - M.crockPortions(crock))
end

-- What one addition takes from litres of paste into a crock: { litres, portions }, all of it up to the crock's room,
-- a part portion too (portions under PASTE_EMPTY: nothing to add).
function M.topUpPlan(litres, crock)
    local used = intoCrock(litres, M.crockRoom(crock) * M.PASTE_PORTION_L)
    if used / M.PASTE_PORTION_L < M.PASTE_EMPTY then return { litres = 0, portions = 0 } end
    return { litres = used, portions = used / M.PASTE_PORTION_L }
end


local CAP_KEYS = { "calories", "carbohydrates", "lipids", "proteins" }

-- The seal uses an addition takes: a fresh cap on a sealed crock, a whole cap sealing a salt-crust one, none without.
function M.addSealUses(crock, seal)
    if not seal then return 0 end
    return crock:getFullType() == M.CROCK_SEALED and M.TOPUP_SEAL_USES or M.PASTE_SEAL_USES
end

-- A salt-crust crock capped: put back as a sealed crock, its paste, food and vessel kept and its share of keeping
-- used carried over (half through the salt crust's days, half through the sealed crock's; user, 2026-11-27).
-- Returns the sealed crock.
function M.sealCrock(crock)
    local crockModData = crock:getModData()
    local count = M.crockPortions(crock)
    local sealed = instanceItem(M.CROCK_SEALED)
    local sealedModData = sealed:getModData()
    for _, key in ipairs({ "tpfvVessel", "tpfvPortion", "tpfvPortionWeight" }) do sealedModData[key] = crockModData[key] end
    sealed:setModelIndex(M.PASTE_VESSELS[sealedModData.tpfvVessel] or 0)
    Portions.set(sealed, sealedModData.tpfvPortion, count, count)
    local was, now = M.PASTE_DAYS[M.CROCK], M.PASTE_DAYS[M.CROCK_SEALED]
    sealed:setOffAge(now[1])
    sealed:setOffAgeMax(now[2])
    sealed:setAge(crock:getAge() * now[1] / was[1])
    Action.replaceItem(crock, sealed)
    M.keepCrock(sealed)
    M.labelCrock(sealed)
    return sealed
end

-- Adds paste to a crock (character's work) from sources (a pot, or a list of pots: All Pots on the crock's menu,
-- one addition): all the paste the crock's room allows, taken from the pots in turn, under a fresh salt crust and,
-- with seal, a cap (addSealUses of it, its food in, the crock holding one cap's food at most): a fresh one on a sealed crock, which needs it, or a whole one
-- sealing a salt-crust crock. The crock's age is the portions' average: fresh paste in an old crock makes it
-- younger by its share (user, 2026-11-27). A rotten crock takes none (side agent's catch: fresh paste would average
-- it back to fresh; user: "no adding to rotten"). Returns the portions added (or 0) and the crock (a new one if sealed).
function M.addToCrock(character, sources, crock, seal)
    M.adoptCrock(crock)
    M.keepCrock(crock)
    local plan = M.topUpPlan(M.sourcesLitres(sources), crock)
    if plan.portions <= 0 or crock:isRotten() then return 0, crock end
    if crock:getFullType() == M.CROCK_SEALED and not seal then return 0, crock end
    local sealUses = M.addSealUses(crock, seal)
    local crockModData = crock:getModData()
    local left = M.crockPortions(crock)
    -- The cap's food in the crock now: what its portions hold over the paste's own.
    local cap = {}
    for _, key in ipairs(CAP_KEYS) do
        cap[key] = math.max(0, ((crockModData.tpfvPortion[key] or 0) - M.PASTE_PORTION_FOOD[key]) * left)
    end
    if seal then
        for key, amount in pairs(M.sealFood(seal, sealUses)) do cap[key] = cap[key] + amount end
        -- One cap's worth at most (user, 2026-11-27): a refresh's fat beyond it is lost on the rim and the spoon.
        local most = M.sealFood(seal, M.PASTE_SEAL_USES).calories
        if cap.calories > most and cap.calories > 0 then
            local k = most / cap.calories
            for _, key in ipairs(CAP_KEYS) do cap[key] = cap[key] * k end
        end
        Uses.take(character, seal:getFullType(), sealUses, true)
    end
    Uses.take(character, ItemTag.SALT, M.TOPUP_SALT)
    drawPaste(sources, plan.litres)
    local count = left + plan.portions
    local portion = M.crockPortion(count, cap)
    crockModData.tpfvPortion = portion
    Portions.set(crock, portion, count, count)
    M.PASTE_KEEPER.setAge(crock, crock:getAge() * left / count)
    M.labelCrock(crock)
    if seal and crock:getFullType() == M.CROCK then crock = M.sealCrock(crock) end
    Action.addXp(character, { "Cooking", M.PASTE_XP * plan.portions })
    return plan.portions, crock
end

-- A spoonful out of a crock (character's work): a Tomato Paste portion, as stale or rotten as the crock is.
function M.spoonOut(character, crock)
    M.adoptCrock(crock)
    M.keepCrock(crock)
    local left = M.crockPortions(crock)
    if left < M.PASTE_EMPTY then return nil end
    local take = math.min(left, 1)
    local portion = character:getInventory():AddItem(M.PASTE_PORTION)
    local food = crock:getModData().tpfvPortion
    Portions.set(portion, food, take, 1)
    if crock:isRotten() then
        portion:setAge(portion:getOffAgeMax())
    elseif crock:getAge() >= crock:getOffAge() then
        portion:setAge(portion:getOffAge())
    end
    crock:multiplyFoodValues((left - take) / left)
    M.afterCrockUse(crock, crock:getContainer())
    return portion
end

-- Empties a crock (Empty the Crock: rotten, or done with): its paste thrown out, the vessel given back. Returns the
-- vessel.
function M.emptyCrock(crock)
    M.adoptCrock(crock)
    crock:multiplyFoodValues(0)
    return M.afterCrockUse(crock, crock:getContainer())
end

-- Keeping by place, on TP Core's PlaceKeeping: the crocks' script days (salt crust 180 / 240, capped 365 / 480) are
-- a 15 C cellar's; a fridge's 4 C counts half a day (about a year / two), a 22 C room two (90 / 120 days with a salt
-- crust), 30 C and up three, frozen nothing. Real salted paste kept in a cool larder lasts the year, under oil longer.
M.PASTE_AGE_CURVE = { { -2, 0 }, { 4, 0.5 }, { 15, 1 }, { 22, 2 }, { 30, 3 } }
M.PASTE_DAYS = { [M.CROCK] = { 180, 240 }, [M.CROCK_SEALED] = { 365, 480 } }
M.PASTE_LEDGER_KEY = "TraditionalPreservationFruitVegetablesPaste"

M.PASTE_KEEPER = PlaceKeeping.new({
    process = "paste", curve = M.PASTE_AGE_CURVE, ledgerKey = M.PASTE_LEDGER_KEY, modDataKey = "tpfvPasteKeep",
    days = M.PASTE_DAYS,
})

function M.keepCrock(crock, now, place, ledger)
    return M.PASTE_KEEPER.keep(crock, now, place, ledger)
end

-- Eaten from through vanilla's eat action (TP Core's Portions): kept up to now first, weighed or emptied after.
for crockType in pairs(M.CROCKS) do
    Portions.onEat(crockType, function(crock)
        M.adoptCrock(crock)
        M.keepCrock(crock)
    end, function(crock, container)
        M.afterCrockUse(crock, container)
    end)
end
