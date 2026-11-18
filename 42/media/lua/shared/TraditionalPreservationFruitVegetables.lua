-- Traditional Preservation (Fruits and Vegetables) B42: the public table, the places, the weather ledger and the
-- sandbox. The root cellar is in ...Cellar.lua, the kraut barrel in ...Barrel.lua.
TraditionalPreservationFruitVegetables = TraditionalPreservationFruitVegetables or {}
local M = TraditionalPreservationFruitVegetables
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"

-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "TraditionalPreservationFruitVegetables"

-- Places and their temperatures are shared with the other Traditional Preservation mods; these are the mod's public
-- names for them, used by the Dev console and the tests. A barrel within reach of a lit fire is by a fire (TP Core's
-- Fire); PLACES are the weather's, which the ledger keeps totals for.
M.PLACES = Weather.PLACES
M.placeTemperature = Weather.placeTemperature
M.placeOf = Fire.placeOf

M.SENSITIVITY = 1

-- The ledger's processes, filled in by ...Barrel.lua: { [process] = rate at a temperature }. Totals are
-- "<process><place>", e.g. "fermentBasement".
M.PROCESSES = {}

function M.newLedger(now)
    return Weather.newLedger(now, M.PROCESSES)
end

-- Adds one stretch of weather to the totals.
function M.advance(ledger, now, temperature)
    Weather.advance(ledger, now, temperature, M.PROCESSES)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

function M.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationFruitVegetables
    if not options then return end
    if options.FermentDays then M.FERMENT_HOURS = options.FermentDays * 24 end
    if options.TemperatureSensitivity then M.SENSITIVITY = Weather.sensitivity(options.TemperatureSensitivity) end
end

Events.OnInitGlobalModData.Add(M.applySandbox)

require "TraditionalPreservationFruitVegetablesCellar"
require "TraditionalPreservationFruitVegetablesBarrel"
require "TraditionalPreservationFruitVegetablesBraid"
