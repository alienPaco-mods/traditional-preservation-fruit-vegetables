-- Shows how long each vegetable stays fresh through the year by place, from forecasts read from the real game. It
-- runs the mod's own cellar code (the ten-minute weather record, a daily look, curing), so it doubles as a check that
-- a change to that code keeps every number. Run from the mod folder: luajit tools/cellar_report.lua [climate.csv]
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
local PLACES = { "Sheltered", "AiredRoom", "Basement", "Covered" }
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

-- The first sampled world's calendar year, twice over, so a vegetable put away in December keeps into the next year.
local all = readDays(arg[1] or "tools/climate_year.csv")
local year = {}
for _, day in ipairs(all) do
    if day.world == all[1].world then table.insert(year, day) end
end
local days = {}
for _ = 1, 2 do
    for _, day in ipairs(year) do table.insert(days, day) end
end

-- Every ledger starts as a long-running save's would on 1 January.
local season, ground = Weather.settledMeans(year)(year[1].month, year[1].offset)
local function settleLedger(ledger) ledger.seasonTemperature, ledger.groundTemperature = season, ground end
for _, name in ipairs(M.CROP_NAMES) do
    local crop = M.CROPS[name]
    settleLedger(crop.keeper.ledger())
    if crop.curedKeeper then settleLedger(crop.curedKeeper.ledger()) end
end
settleLedger(M.cureLedger())

local function vegetable(crop)
    local self = { fullType = crop.fullType, offAge = crop.vanilla, age = 0, modData = {} }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getContainer() return self.container end
    function self:isCooked() return false end
    function self:isBurnt() return false end
    return self
end

-- One of each crop per place, put away on the first of each month of the first year, looked at once a day.
local stored, results, cured = {}, {}, {}
local function putAway(month)
    for _, name in ipairs(M.CROP_NAMES) do
        for _, place in ipairs(PLACES) do
            local item = vegetable(M.CROPS[name])
            M.keepVegetable(item, H.hours, place)
            table.insert(stored, { item = item, key = name .. month .. place, place = place, start = H.hours })
        end
    end
end

for index, day in ipairs(days) do
    if index <= #year and (index == 1 or day.month ~= days[index - 1].month) then putAway(day.month) end
    for hour = 0, 23 do
        for step = 1, STEPS_PER_HOUR do
            H.setHours(H.hours + 1 / STEPS_PER_HOUR)
            M.recordCellarWeather(H.hours, temperatureAt(day, hour + step / STEPS_PER_HOUR))
        end
    end
    for _, kept in ipairs(stored) do
        if not results[kept.key] then
            M.keepVegetable(kept.item, H.hours, kept.place)
            if kept.item.modData[M.CURED] and not cured[kept.key] then cured[kept.key] = (H.hours - kept.start) / 24 end
            if kept.item.age >= kept.item.offAge then results[kept.key] = (H.hours - kept.start) / 24 end
        end
    end
end

local function cell(key)
    local text = results[key] and string.format("%.0f", results[key]) or "365+"
    if cured[key] then text = text .. string.format(" (c %.0f)", cured[key]) end
    return text
end

print("Days fresh for a vegetable put away on the first of the month (c: cured on that day)")
for _, name in ipairs(M.CROP_NAMES) do
    print("")
    print(string.format("%s (vanilla %d days)", name, M.CROPS[name].vanilla))
    print("| Month | Shut room | Aired room | Basement | Under a roof |")
    print("|---|---|---|---|---|")
    for month = 1, 12 do
        local row = { MONTHS[month] }
        for _, place in ipairs(PLACES) do table.insert(row, cell(name .. month .. place)) end
        print("| " .. table.concat(row, " | ") .. " |")
    end
end
