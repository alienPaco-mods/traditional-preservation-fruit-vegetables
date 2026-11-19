-- Shows how a kraut barrel does through the year by place, from forecasts read from the real game: salted and compressed on the
-- first of each month, the days until it is ready (soft or spoiled if it was too warm), then the days it keeps in the
-- barrel. It runs the mod's own barrel code (the ten-minute weather record, a daily look), so it doubles as a check
-- that a change to that code keeps every number. Run from the mod folder: luajit tools/kraut_report.lua [climate.csv]
-- Each line of the file: world month offset tempMin tempMean tempMax humMin humMean humMax rainy snowy
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
H.installClock(0)
H.installModData()
Events = { OnInitGlobalModData = { Add = function() end } }
dofile("42/media/lua/shared/TraditionalPreservationFruitVegetables.lua")
local M = TraditionalPreservationFruitVegetables
local Weather = require "TraditionalPreservationCore/Weather"

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local PLACES = { "Sheltered", "AiredRoom", "Basement", "Covered", "Open" }
local STEPS_PER_HOUR = 6

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for column in line:gmatch("%S+") do table.insert(f, column) end
        -- Each month's forecast also holds the 10 days before it (offset below 0): skipped, so a month is 30 days.
        if #f >= 6 and tonumber(f[3]) >= 0 then
            table.insert(days, { world = tonumber(f[1]), offset = tonumber(f[3]), month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) })
        end
    end
    return days
end

-- The day's weather, coldest before dawn and warmest mid-afternoon.
local function temperatureAt(day, hour)
    local swing = math.cos((hour - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

-- The first sampled world's calendar year, twice over, so a barrel salted and compressed late in the year keeps into the next.
local all = readDays(arg[1] or "tools/climate_year.csv")
local year = {}
for _, day in ipairs(all) do
    if day.world == all[1].world then table.insert(year, day) end
end
local days = {}
for _ = 1, 2 do
    for _, day in ipairs(year) do table.insert(days, day) end
end

-- The ledger starts as a long-running save's would on 1 January.
local ledger = M.getLedger()
ledger.seasonTemperature, ledger.groundTemperature = Weather.settledMeans(year)(year[1].month, year[1].offset)

local FOOD = { hunger = -0.24, calories = 180, carbs = 41, proteins = 9, lipids = 0.7 }
local barrels = {}
local function compressBarrels(month)
    for _, place in ipairs(PLACES) do
        local barrel = {}
        for _ = 1, M.BARREL_MIN do M.pack(barrel, "cabbage", 0, FOOD) end
        M.compress(barrel, ledger)
        table.insert(barrels, { barrel = barrel, key = month .. place, place = place, start = H.hours })
    end
end

local ready, ended, endedAs = {}, {}, {}
for index, day in ipairs(days) do
    if index <= #year and (index == 1 or day.month ~= days[index - 1].month) then compressBarrels(day.month) end
    for hour = 0, 23 do
        for step = 1, STEPS_PER_HOUR do
            H.setHours(H.hours + 1 / STEPS_PER_HOUR)
            M.advance(ledger, H.hours, temperatureAt(day, hour + step / STEPS_PER_HOUR))
        end
    end
    for _, kept in ipairs(barrels) do
        if not ended[kept.key] then
            local before = M.barrelStage(kept.barrel)
            M.updateBarrel(kept.barrel, ledger, kept.place)
            local stage = M.barrelStage(kept.barrel)
            if stage == "Ready" and before == "Fermenting" then
                ready[kept.key] = { days = (H.hours - kept.start) / 24, soft = kept.barrel.soft, at = H.hours }
            elseif stage == "Spoiled" then
                ended[kept.key] = (H.hours - (ready[kept.key] and ready[kept.key].at or kept.start)) / 24
                endedAs[kept.key] = ready[kept.key] and "kept" or "spoiled"
            end
        end
    end
end

local function cell(key)
    local made = ready[key]
    if not made then
        if endedAs[key] == "spoiled" then return string.format("spoiled on day %.0f", ended[key]) end
        return "not ready"
    end
    local text = string.format("%.0f%s", made.days, made.soft and " soft" or "")
    return text .. (ended[key] and string.format(", keeps %.0f", ended[key]) or ", keeps 365+")
end

print(string.format("A kraut barrel salted and compressed on the first of the month: days to ready (%d at 18 C), then days it keeps", M.FERMENT_HOURS / 24))
print("| Month | Shut room | Aired room | Basement | Under a roof | Open air |")
print("|---|---|---|---|---|---|")
for month = 1, 12 do
    local row = { MONTHS[month] }
    for _, place in ipairs(PLACES) do table.insert(row, cell(month .. place)) end
    print("| " .. table.concat(row, " | ") .. " |")
end
