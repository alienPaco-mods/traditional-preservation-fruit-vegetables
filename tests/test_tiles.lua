-- Checks the generated Tiles.lua against the entity scripts. Run from the mod folder: luajit tests/test_tiles.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
local Tiles = require "TraditionalPreservationFruitVegetables/Tiles"
H.checkTiles(Tiles)

-- The storages aren't stations (Tiles.STATIONS), so each script is checked against its own tile here: a renumbered
-- builder must move the script's row with it.
local SCRIPTS = { pole = "entity_Drying_Pole.txt", hayCrate = "entity_Hay_Crate.txt", sandCrate = "entity_Sand_Crate.txt" }
for key, file in pairs(SCRIPTS) do
    local text = io.open("42/media/scripts/entities/" .. file):read("*a")
    local rows = {}
    for row in text:gmatch("row = ([%w_]+)") do table.insert(rows, row) end
    check(file .. " shows the " .. key .. "'s tile, and only it", #rows == 1 and rows[1] == Tiles.STORAGES[key].tile)
end
check("no build script for the clamp: it is dug from the right-click menu",
    io.open("42/media/scripts/entities/entity_Clamp.txt") == nil)
check("the clamp has its own depth texture, so neighbouring floors don't cut into its trenches (B42 depth)",
    io.open("common/media/depthmaps/DEPTH_" .. Tiles.PREFIX:sub(1, -2) .. ".png") ~= nil)
check("the clamp's overlays are its own tiles", Tiles.CLAMP.earthed ~= Tiles.CLAMP.tile and Tiles.CLAMP.wet ~= Tiles.CLAMP.wetEarthed)
H.done()
