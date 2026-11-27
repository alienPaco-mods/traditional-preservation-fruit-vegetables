-- Traditional Preservation (Fruits and Vegetables) B42: the kraut barrel. One batch at a time, of cabbages, turnips or
-- any mix of the two (one ferment, as a real barrel). Heads are packed in (Pack), with apples and carrots if wanted, up
-- to one of each per five heads; until it is salted and compressed everything can come back out (Unpack). Salt and
-- Compress needs at least BARREL_MIN heads, a use of salt per five heads, a cloth, a board and a flat stone: it seals
-- the barrel and the ferment starts, and nothing more goes in. The ferment runs by the temperature where the barrel stands (Core's
-- places, by a fire too): FERMENT_HOURS at 18 C, slower when cool down to a stop at 0 C, faster when warm. Too warm
-- spoils it: HOT_SOFT_HOURS above HOT_C before it is ready leave it soft (it keeps 2/3 as long), HOT_SPOIL_HOURS
-- spoil it. The kraut carries no mood of its own: it is a way of keeping cabbage, not a treat (user, 2026-11-18).
-- Ready kraut stays in the barrel and keeps by place (KEEP_DAYS in an 8 C cellar) and is taken out a portion at a
-- time, one a head (a cabbage's as Sauerkraut, a turnip's as Sauer Turnip), each with its own kind's food and the
-- apples and carrots shared out over all the heads. The last
-- portion, or emptying a spoiled barrel, gives the board and stone back (the cloth is used up). Out of the barrel a
-- portion keeps by vanilla's clock; frozen through (TP Core's Frost, KRAUT_FREEZE_C) it goes soft: the days it has
-- left count 2/3 (user, session 76). A head already stale when the barrel is sealed makes a soft portion (user,
-- 2026-11-22: wilted cabbage gives a poor brine): in the barrel it keeps as a soft batch would, and the soft portions
-- of a kind are taken first. The brine (user, 2026-11-27, art/kraut_brine_mock.png): BRINE_PER_HEAD a head packed,
-- made at Salt and Compress. Draw Starter takes STARTER_L at most off a ready barrel with kraut in it; once the last
-- portion is out the brine stays (stage Brine) and ages as Kraut Brine (FluidAgeing), and Drain Brine takes it all,
-- after which the barrel is empty and can be moved. Pour In Brine on an empty barrel, then fresh Sauerkraut or Sauer
-- Turnip put back, BRINE_PER_HEAD of brine a portion, each keeping its own age: the barrel keeps them by place again,
-- each on its own clock (barrel.pieces). A starter of STARTER_L of good Kraut Brine, put in while packing, is used at
-- Salt and Compress and sours the batch STARTER_BONUS faster (back-slopping). Required by
-- TraditionalPreservationFruitVegetables.lua.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Station = require "TraditionalPreservationCore/Station"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Frost = require "TraditionalPreservationCore/Frost"

M.BARREL_KEY = "tpfvBarrel"   -- the barrel's record in its movableData; never rename once the mod is out
M.BARREL_MIN, M.BARREL_MAX = 20, 60   -- 20 (user, 2026-11-18: the long seal makes bigger barrels pay anyway)
M.HEADS_PER_SALT = 5
M.HEADS_PER_EXTRA = 5         -- one apple and one carrot at most per five heads
M.FERMENT_HOURS = 28 * 24     -- at 18 C; the sandbox's Ferment days
M.HOT_C = 27
M.HOT_SOFT_HOURS = 48
M.HOT_SPOIL_HOURS = 5 * 24
M.KEEP_DAYS = 180             -- ready kraut in an 8 C cellar
M.PORTION_DAYS = { 14, 28 }   -- a portion out of the barrel, fresh and rotten; it comes out as far into its fresh
                              -- days as the barrel is into KEEP_DAYS
M.SOFT_KEEP = 1.5             -- a soft batch's keeping counts half again: it keeps 2/3 as long (user, 2026-11-18)
-- A portion out of the barrel: salt and acid keep it liquid below water's 0 C. Item modData: its frost record, and soft.
M.KRAUT_FREEZE_C = -3
M.KRAUT_FROST_KEY = "tpfvKrautFrost"
M.KRAUT_SOFT_KEY = "tpfvKrautSoft"
M.PACK_XP = 1                 -- Cooking, a piece packed, paid when the barrel is salted and compressed
M.COMPRESS_XP = 10            -- Cooking, salting and compressing a barrel
M.BRINE_PER_HEAD = 0.15       -- litres of brine a head makes, and a portion put back needs
M.BRINE_MAX = M.BARREL_MAX * M.BRINE_PER_HEAD
M.STARTER_L = 1               -- a starter of old brine, and the most drawn off a barrel with kraut in it
M.STARTER_BONUS = 0.25        -- how much faster a batch with a starter sours (sandbox Kraut starter bonus)
M.KRAUT_BRINE = "KrautBrine"
M.ROTTEN_BRINE = "RottenKrautBrine"
M.BRINE_PROCESS = "krautBrine"
M.BRINE_SPOIL_HOURS = 21 * 24 -- at 20 C: about 3 weeks; about 2 months at 8 C, never frozen

M.KRAUT_KINDS = { "cabbage", "turnip" }
M.KRAUTS = {
    cabbage = { head = "Base.Cabbage", product = "TraditionalPreservationFruitVegetables.Sauerkraut" },
    turnip = { head = "Base.Turnip", product = "TraditionalPreservationFruitVegetables.SauerTurnip" },
}
M.EXTRAS = { apple = "Base.Apple", carrot = "Base.Carrots" }
M.KRAUT_OF_HEAD = {}
for kind, kraut in pairs(M.KRAUTS) do M.KRAUT_OF_HEAD[kraut.head] = kind end
M.KRAUT_OF_PRODUCT = {}
for kind, kraut in pairs(M.KRAUTS) do M.KRAUT_OF_PRODUCT[kraut.product] = kind end
M.KRAUT_FROST = Frost.point(M.KRAUT_FREEZE_C)
M.EXTRA_OF_TYPE = {}
for extra, fullType in pairs(M.EXTRAS) do M.EXTRA_OF_TYPE[fullType] = extra end
M.CLOTHS = { ["Base.RippedSheets"] = true, ["Base.BurlapPiece"] = true, ["Base.CheeseCloth"] = true }
M.BOARD = "Base.Plank"      -- back with the stone once the barrel is empty
M.STONE = "Base.FlatStone"

-- Rates. The ferment: days at 4, 8, 13, 18, 21 and 24 C are 120, 60, 40, 28, 21 and 16; slower still towards 0 C,
-- where it stops (user, 2026-11-18: winter kraut sours slowly in the cold); warmer than 24 C as 24 C. A share of
-- FERMENT_HOURS an hour.
local FERMENT_CURVE = { { 0, 0 }, { 4, 28 / 120 }, { 8, 28 / 60 }, { 13, 28 / 40 }, { 18, 1 }, { 21, 28 / 21 }, { 24, 28 / 16 } }
-- Too warm: an hour above HOT_C counts one.
local HOT_CURVE = { { M.HOT_C, 0 }, { M.HOT_C + 0.5, 1 } }
-- Keeping, days of age a day: a cellar's 8 C one, a fridge's 4 C 0.75 (about 8 months), a cool room 2 (3 months), a
-- warm room 6 (a month), frozen nothing.
local KEEP_CURVE = { { -2, 0 }, { 4, 0.75 }, { 8, 1 }, { 15, 2 }, { 22, 6 }, { 28, 9 } }

function M.fermentRate(celsius)
    if M.SENSITIVITY == 0 then return 1 end
    return math.max(Weather.scaled(Weather.curve(FERMENT_CURVE, celsius), M.SENSITIVITY, 0), 0)
end

-- Off: never too warm.
function M.hotRate(celsius)
    if M.SENSITIVITY == 0 then return 0 end
    return Weather.curve(HOT_CURVE, celsius)
end

function M.keepRate(celsius)
    if M.SENSITIVITY == 0 then return 1 end
    return Weather.curve(KEEP_CURVE, celsius)
end

M.PROCESSES.ferment = function(celsius) return M.fermentRate(celsius) end
M.PROCESSES.hot = function(celsius) return M.hotRate(celsius) end
M.PROCESSES.keep = function(celsius) return M.keepRate(celsius) end

-- Kraut Brine on its own ages as milk and wort do (TP Core's FluidAgeing): one stage, mouldy at the end.
local BRINE_CURVE = { { 0, 0 }, { 4, 0.2 }, { 8, 0.35 }, { 15, 0.6 }, { 20, 1 }, { 30, 2 } }
function M.brineRate(celsius)
    return Weather.curve(BRINE_CURVE, celsius)
end
M.PROCESSES[M.BRINE_PROCESS] = M.brineRate
M.BRINE_KIND = FluidAgeing.register({
    process = M.BRINE_PROCESS,
    rate = M.brineRate,
    turnHours = M.BRINE_SPOIL_HOURS,
    spoilHours = M.BRINE_SPOIL_HOURS,
    fresh = { [M.KRAUT_BRINE] = M.ROTTEN_BRINE },
    spoiled = { [M.KRAUT_BRINE] = M.ROTTEN_BRINE },
    getLedger = function() return M.getLedger() end,
    speed = FluidAgeing.foodRotSpeed,
})

-- Days a batch takes to be ready at a temperature (nil: it doesn't work there).
function M.fermentDays(celsius)
    local rate = M.fermentRate(celsius)
    return rate > 0 and M.FERMENT_HOURS / rate / 24 or nil
end

-- Empty, Packing, Fermenting, Ready or Spoiled.
function M.barrelStage(barrel)
    return barrel.stage or "Empty"
end

-- Heads in a packing barrel, of one kind or (kind nil) all; a compressed one's portions are counted by M.portionsLeft.
function M.headCount(barrel, kind)
    local count = 0
    for _, head in ipairs(barrel.heads or {}) do
        if not kind or head.kind == kind then count = count + 1 end
    end
    if not barrel.heads and barrel.headCounts then
        for headKind, n in pairs(barrel.headCounts) do
            if not kind or headKind == kind then count = count + n end
        end
    end
    return count
end

-- Portions still in a ready barrel, of one kind or (kind nil) all.
function M.portionsLeft(barrel, kind)
    local count = 0
    for portionKind, n in pairs(barrel.portions or {}) do
        if not kind or portionKind == kind then count = count + n end
    end
    return count
end

function M.extraCount(barrel, extra)
    local list = barrel.extras and barrel.extras[extra]
    return list and #list or 0
end

function M.saltNeeded(heads)
    return math.ceil(heads / M.HEADS_PER_SALT)
end

-- How many of an extra the heads allow.
function M.extraRoom(heads)
    return math.floor(heads / M.HEADS_PER_EXTRA)
end

-- Why a head can't go in ("Sealed", "Pressed", "Full"), or nil. Cabbages and turnips mix.
function M.packRefusal(barrel)
    local stage = M.barrelStage(barrel)
    if stage ~= "Empty" and stage ~= "Packing" then return "Sealed" end
    if M.pressed(barrel) then return "Pressed" end
    if M.headCount(barrel) >= M.BARREL_MAX then return "Full" end
end

-- Why an apple or a carrot can't go in ("Sealed", "NoHeads", "TooMany"), or nil.
function M.extraRefusal(barrel, extra)
    if M.barrelStage(barrel) ~= "Packing" then return M.barrelStage(barrel) == "Empty" and "NoHeads" or "Sealed" end
    if M.extraCount(barrel, extra) >= M.extraRoom(M.headCount(barrel)) then return "TooMany" end
end

-- Why it can't be salted and compressed ("Sealed", "TooFew", "NoSalt", "NoCloth", "NoBoard", "NoStone"), or nil. have: what
-- the player has in reach { salt = uses, cloth, board, stone = true/false }.
function M.compressRefusal(barrel, have)
    local stage = M.barrelStage(barrel)
    if stage ~= "Packing" and stage ~= "Empty" then return "Sealed" end
    local heads = M.headCount(barrel)
    if heads < M.BARREL_MIN then return "TooFew" end
    if (have.salt or 0) < M.saltNeeded(heads) then return "NoSalt" end
    if not have.cloth then return "NoCloth" end
    if not have.board then return "NoBoard" end
    if not have.stone then return "NoStone" end
end

-- A packed piece as kept: its age, the hour it went in, its food and (a head) the age it goes stale at. food:
-- { hunger, calories, carbs, proteins, lipids }. Until the barrel is salted and compressed a piece ages as it would
-- lying out (vanilla's pace, Food Spoilage included), so an unsealed barrel is no cold store: Unpack gives it back
-- that much older.
function M.pack(barrel, kind, age, food, hour, offAge)
    barrel.stage = "Packing"
    barrel.heads = barrel.heads or {}
    table.insert(barrel.heads, { kind = kind, age = age, hour = hour, food = food, offAge = offAge })
end

function M.packExtra(barrel, extra, age, food, hour)
    barrel.extras = barrel.extras or {}
    barrel.extras[extra] = barrel.extras[extra] or {}
    table.insert(barrel.extras[extra], { age = age, hour = hour, food = food })
end

-- A packed piece's age now: what it had, plus the days since it went in at vanilla's pace.
function M.packedAge(piece, now)
    if not piece.hour or not now then return piece.age end
    return piece.age + math.max(now - piece.hour, 0) / 24 * FluidAgeing.foodRotSpeed()
end

-- Whether a packed head is stale now (one packed before heads kept their stale age never is).
function M.isStaleHead(head, now)
    return head.offAge ~= nil and M.packedAge(head, now) > head.offAge
end

-- Stale heads in a packing barrel now, of one kind or (kind nil) all.
function M.staleHeads(barrel, now, kind)
    local count = 0
    for _, head in ipairs(barrel.heads or {}) do
        if (not kind or head.kind == kind) and M.isStaleHead(head, now) then count = count + 1 end
    end
    return count
end

-- Soft portions still in a sealed barrel from heads that were stale, of one kind or (kind nil) all.
function M.softLeft(barrel, kind)
    local count = 0
    for softKind, n in pairs(barrel.softHeads or {}) do
        if not kind or softKind == kind then count = count + n end
    end
    return count
end

local limitPieces

-- Empties the barrel's record, keeping where it stands (the World's place and square) and whether its plank and stone
-- are on it.
local function clear(barrel)
    local place, at, press = barrel.place, barrel.at, M.pressed(barrel)
    for key in pairs(barrel) do barrel[key] = nil end
    -- false kept as false: no record reads as a barrel sealed before Unseal, pressed once it holds kraut again.
    barrel.place, barrel.at, barrel.press = place, at, press
end

-- Everything packed comes back out at its age now: { { fullType, age } ... }, and a starter as { brine = litres }, the
-- barrel empty again. Only before it is salted and compressed.
function M.unpack(barrel, now)
    if M.barrelStage(barrel) ~= "Packing" and not barrel.starter then return {} end
    local back = {}
    for _, head in ipairs(barrel.heads or {}) do
        table.insert(back, { fullType = M.KRAUTS[head.kind].head, age = M.packedAge(head, now) })
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        for _, piece in ipairs((barrel.extras or {})[extra] or {}) do
            table.insert(back, { fullType = M.EXTRAS[extra], age = M.packedAge(piece, now) })
        end
    end
    if barrel.starter then table.insert(back, { brine = M.STARTER_L }) end
    clear(barrel)
    return back
end

local FOOD_FIELDS = { "hunger", "calories", "carbs", "proteins", "lipids" }

-- One portion's food for a kind: its own heads' food a head, plus the apples and carrots shared out over every head.
-- Nil for a kind not packed.
function M.portionOf(barrel, kind)
    local heads, ofKind = M.headCount(barrel), M.headCount(barrel, kind)
    if ofKind == 0 then return nil end
    local portion = {}
    for _, field in ipairs(FOOD_FIELDS) do portion[field] = 0 end
    local function add(piece, share)
        for _, field in ipairs(FOOD_FIELDS) do portion[field] = portion[field] + (piece.food[field] or 0) * share end
    end
    for _, head in ipairs(barrel.heads or {}) do
        if head.kind == kind then add(head, 1 / ofKind) end
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        for _, piece in ipairs((barrel.extras or {})[extra] or {}) do add(piece, 1 / heads) end
    end
    return portion
end

-- Seals a packed barrel and starts the ferment: what was packed becomes its portions, the heads stale now its soft ones,
-- the brine made, a starter used (the batch faster by it).
function M.compress(barrel, ledger, now)
    barrel.portion, barrel.portions, barrel.headCounts, barrel.softHeads = {}, {}, {}, nil
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local count = M.headCount(barrel, kind)
        if count > 0 then
            barrel.portion[kind] = M.portionOf(barrel, kind)
            barrel.portions[kind] = count
            barrel.headCounts[kind] = count
            local stale = M.staleHeads(barrel, now, kind)
            if stale > 0 then
                barrel.softHeads = barrel.softHeads or {}
                barrel.softHeads[kind] = stale
            end
        end
    end
    barrel.apples = M.extraCount(barrel, "apple")
    barrel.carrots = M.extraCount(barrel, "carrot")
    barrel.heads, barrel.extras = nil, nil
    barrel.stage = "Fermenting"
    barrel.workHours, barrel.hotHours, barrel.soft = 0, 0, nil
    barrel.brine = M.portionsLeft(barrel) * M.BRINE_PER_HEAD
    barrel.press = true
    barrel.speed = barrel.starter and 1 + M.STARTER_BONUS or nil
    barrel.starterUsed, barrel.starter = barrel.starter, nil
    barrel.marks = Weather.mark({}, ledger, "ferment")
    barrel.hotMarks = Weather.mark({}, ledger, "hot")
end

-- Brings a barrel up to now at place: the ferment and the hours too warm while it ferments, then its keeping once ready.
function M.updateBarrel(barrel, ledger, place)
    local stage = M.barrelStage(barrel)
    M.brineOf(barrel, true)
    if stage == "Fermenting" then
        barrel.workHours = barrel.workHours
            + Fire.catchUp(barrel, barrel.marks, ledger, "ferment", place, M.fermentRate) * (barrel.speed or 1)
        barrel.hotHours = barrel.hotHours + Fire.catchUp(barrel, barrel.hotMarks, ledger, "hot", place, M.hotRate)
        if barrel.hotHours >= M.HOT_SPOIL_HOURS then
            barrel.stage = "Spoiled"
        elseif barrel.workHours >= M.FERMENT_HOURS then
            barrel.stage = "Ready"
            barrel.soft = barrel.hotHours >= M.HOT_SOFT_HOURS or nil
            barrel.keepDays = 0
            barrel.keepMarks = Weather.mark({}, ledger, "keep")
        end
    elseif stage == "Ready" then
        local days = Fire.catchUp(barrel, barrel.keepMarks, ledger, "keep", place, M.keepRate) / 24
        if barrel.pieces then
            for _, piece in ipairs(barrel.pieces) do piece.keep = piece.keep + days * piece.rate end
            limitPieces(barrel)
        else
            barrel.keepDays = barrel.keepDays + days * M.keepFactor(barrel)
        end
        if barrel.keepDays >= M.KEEP_DAYS then barrel.stage = "Spoiled" end
    elseif stage == "Brine" then
        local fluidAge = barrel[FluidAgeing.KEY]
        if fluidAge and FluidAgeing.stage(fluidAge, M.BRINE_KIND) ~= "Spoiled" then
            FluidAgeing.advance(fluidAge, M.BRINE_KIND, ledger, getGameTime():getWorldAgeHours(), place)
            if FluidAgeing.stage(fluidAge, M.BRINE_KIND) == "Spoiled" then barrel.brineSpoiled = true end
        end
    end
end

-- How much faster than by KEEP_DAYS a ready barrel's keeping runs: SOFT_KEEP when soft; with kraut put back, its
-- nearest piece to spoiling's.
function M.keepFactor(barrel)
    if barrel.pieces then return barrel.limitRate or 1 end
    return barrel.soft and M.SOFT_KEEP or 1
end

-- How the barrel is doing at place: progress (of the ferment, or of its keeping), the rate there, hours left to
-- ready (nil when stalled), days left to keep, the hours it has been too warm.
function M.barrelStatus(barrel, ledger, place)
    local temperature = M.placeTemperatureAt(ledger, place)
    local stage = M.barrelStage(barrel)
    local status = { place = place, temperature = temperature, stage = stage }
    if stage == "Fermenting" then
        status.rate = M.fermentRate(temperature) * (barrel.speed or 1)
        status.progress = math.min(barrel.workHours / M.FERMENT_HOURS, 1)
        status.hoursLeft = status.rate > 0 and (M.FERMENT_HOURS - barrel.workHours) / status.rate or nil
        status.hotHours = barrel.hotHours
    elseif stage == "Ready" then
        status.rate = M.keepRate(temperature) * M.keepFactor(barrel)
        status.progress = math.min(barrel.keepDays / M.KEEP_DAYS, 1)
        status.daysLeft = status.rate > 0 and (M.KEEP_DAYS - barrel.keepDays) / status.rate or nil
    elseif stage == "Brine" and barrel[FluidAgeing.KEY] then
        status.rate = M.brineRate(temperature)
        local left = FluidAgeing.hoursLeft(barrel[FluidAgeing.KEY], M.BRINE_KIND)
        status.hoursLeft = status.rate > 0 and left and left / status.rate or nil
    end
    status.brine = M.brineOf(barrel)
    return status
end

-- A place's temperature, a fire's places included.
function M.placeTemperatureAt(ledger, place)
    if Fire.isFirePlace(place) then return Fire.fireC(place, ledger) end
    return Weather.placeTemperature(ledger, place)
end

-- Takes one portion of a kind out of a ready barrel: { portion, kind, ageShare (of its fresh days), soft, last }, or
-- nil. The last one of all empties the barrel. A kind's soft portions (stale heads) come first: they have kept as a
-- soft batch would, SOFT_KEEP faster, so they come out further on, past fresh once the barrel is two thirds through
-- its keeping. A soft batch's portions are all soft already.
function M.takePortion(barrel, kind)
    if M.barrelStage(barrel) ~= "Ready" or M.portionsLeft(barrel, kind) <= 0 or M.pressed(barrel) then return nil end
    local taken
    if barrel.pieces then
        -- Soft ones of the kind first, then the oldest.
        local best
        for index, piece in ipairs(barrel.pieces) do
            if piece.kind == kind then
                local other = best and barrel.pieces[best]
                if not other or (piece.soft and not other.soft)
                    or (piece.soft == other.soft and piece.keep / piece.cap > other.keep / other.cap) then best = index end
            end
        end
        local piece = table.remove(barrel.pieces, best)
        taken = { portion = piece.food, kind = kind, soft = piece.soft == true,
            ageShare = math.min(piece.keep / M.KEEP_DAYS, piece.cap) }
        limitPieces(barrel)
    else
        taken = { portion = barrel.portion[kind], kind = kind, soft = barrel.soft == true,
            ageShare = math.min(barrel.keepDays / M.KEEP_DAYS, 1) }
    end
    if not barrel.pieces and not barrel.soft and M.softLeft(barrel, kind) > 0 then
        barrel.softHeads[kind] = barrel.softHeads[kind] - 1
        taken.soft = true
        taken.ageShare = math.min(barrel.keepDays * M.SOFT_KEEP / M.KEEP_DAYS, M.PORTION_DAYS[2] / M.PORTION_DAYS[1])
    end
    barrel.portions[kind] = barrel.portions[kind] - 1
    if M.portionsLeft(barrel) <= 0 then
        taken.last = true
        local brine = M.brineOf(barrel)
        clear(barrel)
        if brine > 0 then M.holdBrine(barrel, brine) end
    end
    return taken
end

-- Empties a spoiled barrel (its plank and stone stay on it until it is unsealed). Returns true if it was spoiled.
function M.emptySpoiled(barrel)
    if M.barrelStage(barrel) ~= "Spoiled" then return false end
    clear(barrel)
    return true
end

-- The press (user, 2026-11-27): Salt and Compress lays the plank and stone on; they stay until Unseal lifts them off,
-- once the batch is ready (lifting them mid-ferment lets the kraut float out of its brine). Nothing else gives them
-- back. Pressed, the barrel is shut: nothing comes out (kraut, a starter, the brine) or goes in, and it stays where it
-- is. A barrel sealed before this has them on.
function M.pressed(barrel)
    if barrel.press ~= nil then return barrel.press end
    local stage = M.barrelStage(barrel)
    return stage == "Fermenting" or stage == "Ready" or stage == "Spoiled"
end

-- Why it can't be unsealed ("NotPressed", "Fermenting"), or nil.
function M.unsealRefusal(barrel)
    if not M.pressed(barrel) then return "NotPressed" end
    if M.barrelStage(barrel) == "Fermenting" then return "Fermenting" end
end

-- Lifts the plank and stone off. Returns true if they came off.
function M.unseal(barrel)
    if M.unsealRefusal(barrel) then return false end
    barrel.press = false
    return true
end

-- Brine

-- Litres of brine in the barrel. A barrel sealed before it kept brine has its batch's (BRINE_PER_HEAD a head it was
-- sealed with); save writes that down.
function M.brineOf(barrel, save)
    if barrel.brine then return barrel.brine end
    local stage = M.barrelStage(barrel)
    if stage ~= "Fermenting" and stage ~= "Ready" then return 0 end
    local heads = 0
    for _, n in pairs(barrel.headCounts or {}) do heads = heads + n end
    local brine = heads * M.BRINE_PER_HEAD
    if save then barrel.brine = brine end
    return brine
end

-- The barrel holding only brine (stage Brine): litres of it, aging from now as Kraut Brine (fluidAge, or a fresh one).
function M.holdBrine(barrel, litres, fluidAge)
    barrel.stage, barrel.brine = "Brine", litres
    barrel[FluidAgeing.KEY] = fluidAge and FluidAgeing.copy(fluidAge)
        or FluidAgeing.newFluidAge(M.BRINE_KIND, M.getLedger(), getGameTime():getWorldAgeHours(), barrel.place or Weather.DEFAULT_PLACE)
    barrel.brineSpoiled = FluidAgeing.stage(barrel[FluidAgeing.KEY], M.BRINE_KIND) == "Spoiled" or nil
end

-- Why a starter can't go in ("Sealed", "HasStarter"), or nil: only while it is empty or packing.
function M.starterRefusal(barrel)
    local stage = M.barrelStage(barrel)
    if stage ~= "Empty" and stage ~= "Packing" then return "Sealed" end
    if M.pressed(barrel) then return "Pressed" end
    if barrel.starter then return "HasStarter" end
end

-- A starter of STARTER_L of Kraut Brine goes in.
function M.addStarter(barrel)
    if M.starterRefusal(barrel) then return false end
    barrel.stage = "Packing"
    barrel.starter = true
    return true
end

-- Why a starter can't be drawn ("NotReady", "Drawn", "NoBrine"), or nil: a ready barrel with kraut in it, once.
function M.drawRefusal(barrel)
    if M.barrelStage(barrel) ~= "Ready" then return "NotReady" end
    if M.pressed(barrel) then return "Pressed" end
    if barrel.starterDrawn then return "Drawn" end
    if M.brineOf(barrel) < M.STARTER_L then return "NoBrine" end
end

-- Draws STARTER_L of brine off a ready barrel. Returns the litres, or 0.
function M.drawStarter(barrel)
    if M.drawRefusal(barrel) then return 0 end
    barrel.brine = M.brineOf(barrel) - M.STARTER_L
    barrel.starterDrawn = true
    return M.STARTER_L
end

-- Drains up to litres (all when nil) of a barrel holding only brine: returns the litres, their fluid (good or
-- mouldy) and their fluidAge. Emptied, the barrel is empty again.
function M.drainBrine(barrel, litres)
    if M.barrelStage(barrel) ~= "Brine" or M.pressed(barrel) then return 0 end
    local took = math.min(litres or barrel.brine, barrel.brine)
    local fluid = barrel.brineSpoiled and M.ROTTEN_BRINE or M.KRAUT_BRINE
    local fluidAge = barrel[FluidAgeing.KEY] and FluidAgeing.copy(barrel[FluidAgeing.KEY])
    barrel.brine = barrel.brine - took
    if barrel.brine <= 1e-6 then clear(barrel) end
    return took, fluid, fluidAge
end

-- Why brine can't be poured in ("Sealed", "Mouldy", "Full"), or nil: an empty barrel or one of brine.
function M.pourRefusal(barrel)
    local stage = M.barrelStage(barrel)
    if stage ~= "Empty" and stage ~= "Brine" then return "Sealed" end
    if barrel.brineSpoiled then return "Mouldy" end
    if M.brineOf(barrel) >= M.BRINE_MAX - 1e-6 then return "Full" end
end

-- Pours up to litres of good Kraut Brine of fluidAge in. Returns the litres taken.
function M.pourBrine(barrel, litres, fluidAge)
    if M.pourRefusal(barrel) then return 0 end
    local had = M.brineOf(barrel)
    local took = math.min(litres, M.BRINE_MAX - had)
    if M.barrelStage(barrel) == "Empty" then
        M.holdBrine(barrel, took, fluidAge)
    else
        barrel.brine = had + took
        if fluidAge then FluidAgeing.receive(barrel, fluidAge, true, barrel.place) end
    end
    return took
end

-- Portions that can be put back: what the brine covers, BARREL_MAX at most, less what is in (0 where none go).
function M.putBackRoom(barrel)
    local stage = M.barrelStage(barrel)
    if (stage ~= "Brine" and stage ~= "Ready") or barrel.brineSpoiled then return 0 end
    local covered = math.min(math.floor(M.brineOf(barrel) / M.BRINE_PER_HEAD + 1e-6), M.BARREL_MAX)
    return math.max(covered - M.portionsLeft(barrel), 0)
end

-- Why a portion can't be put back ("NoBrine", "Mouldy", "Covered", "Stale"), or nil. fresh: it hasn't gone stale.
function M.putBackRefusal(barrel, fresh)
    local stage = M.barrelStage(barrel)
    if stage ~= "Brine" and stage ~= "Ready" then return "NoBrine" end
    if M.pressed(barrel) then return "Pressed" end
    if barrel.brineSpoiled then return "Mouldy" end
    if M.putBackRoom(barrel) <= 0 then return "Covered" end
    if not fresh then return "Stale" end
end

-- The nearest piece to spoiling sets the barrel's keepDays and keepFactor (keep / cap: a soft piece may go twice as
-- far into its fresh days before it is past).
limitPieces = function(barrel)
    local worst
    for _, piece in ipairs(barrel.pieces) do
        if not worst or piece.keep / piece.cap > worst.keep / worst.cap then worst = piece end
    end
    barrel.keepDays = worst and worst.keep / worst.cap or 0
    barrel.limitRate = worst and worst.rate / worst.cap or 1
end

-- A ready barrel's portions, one by one, as pieces each with its own clock (keep, rate, cap), before any is put back.
local function toPieces(barrel)
    if barrel.pieces then return end
    barrel.pieces = {}
    for _, kind in ipairs(M.KRAUT_KINDS) do
        local soft = barrel.soft and (barrel.portions[kind] or 0) or M.softLeft(barrel, kind)
        for i = 1, barrel.portions[kind] or 0 do
            local piece = { kind = kind, food = barrel.portion[kind], keep = barrel.keepDays, rate = M.keepFactor(barrel), cap = 1 }
            if i <= soft then
                piece.soft = true
                if not barrel.soft then piece.keep, piece.rate, piece.cap = barrel.keepDays * M.SOFT_KEEP, M.SOFT_KEEP, 2 end
            end
            table.insert(barrel.pieces, piece)
        end
    end
    barrel.softHeads, barrel.soft = nil, nil
end

-- Puts a portion back: its food, its age (days, out of the barrel's PORTION_DAYS) and whether it is soft. It keeps
-- by place again from its own age. Returns true if it went in.
function M.putBack(barrel, kind, food, age, soft, ledger)
    if M.putBackRefusal(barrel, true) then return false end
    if M.barrelStage(barrel) == "Brine" then
        local brine = barrel.brine
        clear(barrel)
        barrel.stage, barrel.brine, barrel.portions, barrel.pieces = "Ready", brine, {}, {}
        barrel.keepDays = 0
        barrel.keepMarks = Weather.mark({}, ledger, "keep")
    end
    toPieces(barrel)
    table.insert(barrel.pieces, { kind = kind, food = food, keep = age / M.PORTION_DAYS[1] * M.KEEP_DAYS,
        rate = soft and M.SOFT_KEEP or 1, cap = soft and 2 or 1, soft = soft or nil })
    barrel.portions[kind] = (barrel.portions[kind] or 0) + 1
    limitPieces(barrel)
    return true
end

-- Engine side

function M.barrelOf(station)
    local modData = Station.movableData(station)
    modData[M.BARREL_KEY] = modData[M.BARREL_KEY] or {}
    return modData[M.BARREL_KEY]
end

-- Litres of fluid in a container holding only that fluid (0 for anything else, or none).
function M.onlyFluid(item, fluid)
    local container = item and item.getFluidContainer and item:getFluidContainer()
    if not container or container:isEmpty() then return 0 end
    local name, litres = require("TraditionalPreservationCore/ItemFluid").oneFluid(container)
    return name == fluid and litres or 0
end

-- Room for fluid in a container: empty, or holding only that fluid (0 otherwise).
function M.roomFor(item, fluid)
    local container = item and item.getFluidContainer and item:getFluidContainer()
    if not container then return 0 end
    if not container:isEmpty() and M.onlyFluid(item, fluid) <= 0 then return 0 end
    return math.max(container:getCapacity() - container:getAmount(), 0)
end

-- Pours litres of fluid of fluidAge (a fresh one when nil) into a container, its age going with it (TP Core's
-- FluidAgeing: the age is the fluid's, and travels on with it when it is poured on).
function M.fillWith(item, fluid, litres, fluidAge)
    if litres <= 0 then return end
    local container = item:getFluidContainer()
    local hadSome = not container:isEmpty()
    container:addFluid(fluid, litres)
    local now = getGameTime():getWorldAgeHours()
    local place = FluidAgeing.placeOfItem(item)
    fluidAge = fluidAge or FluidAgeing.newFluidAge(M.BRINE_KIND, M.getLedger(), now, place or Weather.DEFAULT_PLACE)
    FluidAgeing.receive(item:getModData(), fluidAge, hadSome, place)
end

-- Takes litres out of a container of one fluid.
function M.takeFluid(item, fluid, litres)
    local container = item:getFluidContainer()
    container:adjustSpecificFluidAmount(Fluid.Get(fluid), math.max(container:getAmount() - litres, 0))
end

-- A food's own values, as the barrel keeps them.
function M.foodOf(item)
    return { hunger = item:getHungChange(), calories = item:getCalories(), carbs = item:getCarbohydrates(),
        proteins = item:getProteins(), lipids = item:getLipids() }
end

-- A portion that may go back under brine: not cooked or burnt, not stale or rotten.
function M.isFreshKraut(item)
    return not item:isCooked() and not item:isBurnt() and not item:isRotten() and item:getAge() < item:getOffAge()
end

-- Sets a taken portion's food and age on a new Sauerkraut or Sauer Turnip.
function M.applyPortion(item, taken)
    local portion = taken.portion
    item:setBaseHunger(portion.hunger)
    item:setHungChange(portion.hunger)
    item:setCalories(portion.calories)
    item:setCarbohydrates(portion.carbs)
    item:setProteins(portion.proteins)
    item:setLipids(portion.lipids)
    item:setOffAge(M.PORTION_DAYS[1])
    item:setOffAgeMax(M.PORTION_DAYS[2])
    item:setAge(taken.ageShare * M.PORTION_DAYS[1])
end

-- Turns a portion soft: the days it has left to stale and to rotten count 2/3 (the barrel's SOFT_KEEP), once.
function M.softenKraut(item)
    local itemModData = item:getModData()
    if itemModData[M.KRAUT_SOFT_KEY] then return false end
    itemModData[M.KRAUT_SOFT_KEY] = true
    local age = item:getAge()
    item:setOffAge(age + math.max(item:getOffAge() - age, 0) / M.SOFT_KEEP)
    item:setOffAgeMax(age + math.max(item:getOffAgeMax() - age, 0) / M.SOFT_KEEP)
    return true
end

-- Brings a portion's frost up to now at the place it was seen in last, and counts from where it is now (place, or
-- where the item is); frozen through, it goes soft. Its keeping stays vanilla's. Returns its frost record, or nil for
-- anything else and for cooked or burnt kraut (vanilla's clock, as cooked vegetables).
function M.keepKraut(item, now, place)
    if not M.KRAUT_OF_PRODUCT[item:getFullType()] or item:isCooked() or item:isBurnt() then return nil end
    now = now or getGameTime():getWorldAgeHours()
    local fire, holder
    if not place then place, fire, holder = FluidAgeing.placeOfItem(item) end
    local itemModData = item:getModData()
    local record = itemModData[M.KRAUT_FROST_KEY]
    place = place or (record and record.place) or Weather.DEFAULT_PLACE
    if not record then
        record = Frost.newRecord(M.KRAUT_FROST, now, place)
        itemModData[M.KRAUT_FROST_KEY] = record
    else
        local hours = Frost.catchUp(record, M.KRAUT_FROST, now, place, record)
        if Frost.frozenThrough(record, hours) and M.frostDamage() then M.softenKraut(item) end
    end
    if holder then FluidAgeing.noteFire(record, fire, holder, now) end
    return record
end
