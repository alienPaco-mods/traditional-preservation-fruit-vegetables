-- Traditional Preservation (Fruits and Vegetables) B42: kraut in TP Core's Brine Barrel (BrineBarrel.lua; the barrel
-- was this mod's Kraut Barrel until 0.0.26: the station, its stages, the press, the starter and the brine tank are
-- Core's now, and this file registers the kraut on it). One batch at a time, of cabbages, turnips or
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
-- Salt and Compress and sours the batch STARTER_BONUS faster (back-slopping). The M.* names of Core's machinery
-- below are kept for this mod's callers and pass on to Core's. Required by TraditionalPreservationFruitVegetables.lua.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Station = require "TraditionalPreservationCore/Station"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Frost = require "TraditionalPreservationCore/Frost"
local BrineBarrel = require "TraditionalPreservationCore/BrineBarrel"

M.BARREL_KEY = BrineBarrel.KEY   -- the barrel's record in its movableData (Core's)
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
M.CLOTHS = BrineBarrel.CLOTHS
M.BOARD = BrineBarrel.BOARD   -- back with the stone once the barrel is unsealed
M.STONE = BrineBarrel.STONE

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

-- Empty, Packing, Fermenting, Ready, Spoiled or Brine.
M.barrelStage = BrineBarrel.stage

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
M.compressRefusal = BrineBarrel.sealRefusal

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
local clear = BrineBarrel.clear

-- Everything packed, at its age now, as Core's Unpack gives it back: the heads, then the apples and carrots.
local function unpacked(barrel, now)
    local back = {}
    for _, head in ipairs(barrel.heads or {}) do
        table.insert(back, { fullType = M.KRAUTS[head.kind].head, age = M.packedAge(head, now) })
    end
    for _, extra in ipairs({ "apple", "carrot" }) do
        for _, piece in ipairs((barrel.extras or {})[extra] or {}) do
            table.insert(back, { fullType = M.EXTRAS[extra], age = M.packedAge(piece, now) })
        end
    end
    return back
end

-- Everything packed comes back out at its age now: { { fullType, age } ... }, and a starter as { brine = litres }, the
-- barrel empty again. Only before it is salted and compressed.
M.unpack = BrineBarrel.unpack

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

-- The kraut's side of sealing a packed barrel (Core's BrineBarrel.seal lays the press on and uses the starter): what
-- was packed becomes its portions, the heads stale now its soft ones, the brine made, a starter in the batch faster.
local function seal(barrel, ledger, now)
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
    barrel.workHours, barrel.hotHours, barrel.soft = 0, 0, nil
    barrel.brine = M.portionsLeft(barrel) * M.BRINE_PER_HEAD
    barrel.speed = barrel.starter and 1 + M.STARTER_BONUS or nil
    barrel.marks = Weather.mark({}, ledger, "ferment")
    barrel.hotMarks = Weather.mark({}, ledger, "hot")
end

-- Seals a packed barrel and starts the ferment (Core's seal, the kraut's fields above).
M.compress = BrineBarrel.seal

-- The kraut's clock at place: the ferment and the hours too warm while it ferments, then its keeping once ready.
local function update(barrel, ledger, place)
    local stage = M.barrelStage(barrel)
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
    end
end

-- Brings a barrel up to now at place: the kraut's clock (above), then its brine on its own once only that is left
-- (Core's).
M.updateBarrel = BrineBarrel.update

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

-- Core's: empty a spoiled barrel, the press and Unseal, the brine (a barrel sealed before it kept brine has its
-- batch's, BRINE_PER_HEAD a head it was sealed with), the starter, draw, drain, pour, and the room to put back.
M.emptySpoiled = BrineBarrel.emptySpoiled
M.pressed = BrineBarrel.pressed
M.unsealRefusal = BrineBarrel.unsealRefusal
M.unseal = BrineBarrel.unseal
M.brineOf = BrineBarrel.brineOf
M.holdBrine = BrineBarrel.holdBrine
M.starterRefusal = BrineBarrel.starterRefusal
M.addStarter = BrineBarrel.addStarter
M.drawRefusal = BrineBarrel.drawRefusal
M.drawStarter = BrineBarrel.drawStarter
M.drainBrine = BrineBarrel.drainBrine
M.pourRefusal = BrineBarrel.pourRefusal
M.pourBrine = BrineBarrel.pourBrine
M.putBackRoom = BrineBarrel.putBackRoom
M.putBackRefusal = BrineBarrel.putBackRefusal

-- The litres a barrel sealed before it kept brine had: BRINE_PER_HEAD a head it was sealed with.
local function sealedBrine(barrel)
    local heads = 0
    for _, n in pairs(barrel.headCounts or {}) do heads = heads + n end
    return heads * M.BRINE_PER_HEAD
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

M.barrelOf = BrineBarrel.of
M.onlyFluid = BrineBarrel.onlyFluid
M.roomFor = BrineBarrel.roomFor
M.takeFluid = BrineBarrel.takeFluid

-- Pours litres of fluid of fluidAge (fresh Kraut Brine when nil) into a container, its age going with it.
function M.fillWith(item, fluid, litres, fluidAge)
    BrineBarrel.fillWith(item, fluid, litres, fluidAge, M.KRAUT_KIND)
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

-- The kraut on TP Core's Brine Barrel. What it packs: heads (cabbage, turnip) and the apples and carrots they allow.
local function packRefusal(barrel, item)
    local kind = M.KRAUT_OF_HEAD[item:getFullType()]
    if kind then return M.packRefusal(barrel) end
    return M.extraRefusal(barrel, M.EXTRA_OF_TYPE[item:getFullType()])
end

local function packed(barrel)
    return M.headCount(barrel) + M.extraCount(barrel, "apple") + M.extraCount(barrel, "carrot")
end

-- The overlay an open barrel shows: the shreds at the rim of what is in it, cabbage, turnip or both mixed (packing,
-- or kraut left once unsealed; user, 2026-11-27); nothing when nothing is in it (empty, or brine only). Core draws the
-- cloth, board and stone while the press is on.
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
local function shredsOf(cabbages, turnips)
    if cabbages > 0 and turnips > 0 then return Tiles.OVERLAYS.mixed end
    if cabbages + turnips == 0 then return nil end
    return Tiles.OVERLAYS[turnips > 0 and "turnip" or "cabbage"]
end

local function look(barrel, face)
    local stage = M.barrelStage(barrel)
    local overlay
    if stage == "Packing" or stage == "Spoiled" then
        overlay = shredsOf(M.headCount(barrel, "cabbage"), M.headCount(barrel, "turnip"))
    elseif stage == "Ready" then
        overlay = shredsOf(M.portionsLeft(barrel, "cabbage"), M.portionsLeft(barrel, "turnip"))
    end
    return overlay and Tiles.PREFIX .. (overlay + face) or nil
end

M.KRAUT_KIND = BrineBarrel.kind({
    id = "kraut",
    getLedger = function() return M.getLedger() end,
    capacity = M.BARREL_MAX,
    least = M.BARREL_MIN,
    perSalt = M.HEADS_PER_SALT,
    brine = { fluid = M.KRAUT_BRINE, rotten = M.ROTTEN_BRINE, ageing = M.BRINE_KIND, perPiece = M.BRINE_PER_HEAD,
        max = M.BRINE_MAX, starter = M.STARTER_L },
    takes = function(item) return M.KRAUT_OF_HEAD[item:getFullType()] ~= nil or M.EXTRA_OF_TYPE[item:getFullType()] ~= nil end,
    starterBonus = function() return M.STARTER_BONUS end,
    packRefusal = packRefusal,
    pack = function(barrel, item, now)
        local kind = M.KRAUT_OF_HEAD[item:getFullType()]
        if kind then
            M.pack(barrel, kind, item:getAge(), M.foodOf(item), now, item:getOffAge())
        else
            M.packExtra(barrel, M.EXTRA_OF_TYPE[item:getFullType()], item:getAge(), M.foodOf(item), now)
        end
    end,
    count = function(barrel) return M.headCount(barrel) end,
    packed = packed,
    unpacked = unpacked,
    -- Packing's xp comes at the seal, not as each piece goes in: Unpack gives them back, so packing again would pay again.
    sealXp = function(barrel) return M.COMPRESS_XP + M.PACK_XP * packed(barrel) end,
    seal = seal,
    update = update,
    status = function(barrel, ledger, place) return M.barrelStatus(barrel, ledger, place) end,
    portionsLeft = function(barrel, which) return M.portionsLeft(barrel, which) end,
    take = function(barrel, which) return M.takePortion(barrel, which) end,
    output = function(taken)
        local item = instanceItem(M.KRAUTS[taken.kind].product)
        M.applyPortion(item, taken)
        return item
    end,
    isPortion = function(item) return M.KRAUT_OF_PRODUCT[item:getFullType()] end,
    isFresh = function(item) return M.isFreshKraut(item) end,
    putBack = function(barrel, item, ledger)
        local kind = M.KRAUT_OF_PRODUCT[item:getFullType()]
        return kind ~= nil and M.putBack(barrel, kind, M.foodOf(item), item:getAge(), item:getModData()[M.KRAUT_SOFT_KEY] == true, ledger)
    end,
    sealedBrine = sealedBrine,
    look = look,
})
