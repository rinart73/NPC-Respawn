package.path = package.path .. ";data/scripts/entity/?.lua"

local NamePool = include("namepool")
local SectorSpecifics = include("sectorspecifics")

function SectorGenerator:createHeadquarters(faction)
    local station = self:createStation(faction, "merchants/headquarters.lua")
    ShipUtility.addArmedTurretsToCraft(station)

    return station
end

function SectorGenerator:createPlanetaryTradingPost(faction, respawn)
    local x, y = Sector():getCoordinates()
    local specs = SectorSpecifics(x, y, Server().seed)
    local planets = {specs:generatePlanets()}
    local rand = Random(specs.generationSeed)
    local value = respawn and 1 or rand:getInt(1, 4)

    local station
    if #planets > 0 and value == 1 and planets[1].type ~= PlanetType.BlackHole then
        -- create a planetary trading post
        station = self:createStation(faction)
        station:addScript("merchants/planetarytradingpost.lua", planets[1])
    else
        -- create a trading post
        station = self:createStation(faction, "merchants/tradingpost.lua")
    end

    return station
end

function SectorGenerator:createResistanceOutpost(faction)
    local rand0 = Random(getSectorSeed(Sector():getCoordinates()))
    local rand = Random(rand0:createSeed())
    
    local station = self:createStation(faction, "merchants/resistanceoutpost.lua")
    local possible =
    {
        "merchants/equipmentdock.lua",
        "merchants/factory.lua", -- make factory slightly more likely
        "merchants/factory.lua",
        "merchants/factory.lua",
        "merchants/turretfactory.lua",
        "merchants/shipyard.lua",
        "merchants/repairdock.lua",
        "merchants/resourcetrader.lua",
        "merchants/tradingpost.lua",
        "merchants/turretmerchant.lua",
        "merchants/casino.lua",
        "merchants/researchstation.lua",
        "merchants/biotope.lua",
        "merchants/militaryoutpost.lua",
    }
    station:addScript(possible[rand:getInt(1, #possible)])

    return station
end

function SectorGenerator:createSmugglerHideout(faction)
    local station = self:createStation(faction, "merchants/smugglersmarket")
    station.title = "Smuggler Hideout"%_t
    station:addScript("merchants/tradingpost")
    NamePool.setStationName(station)
    
    return station
end

--[[
Function arguments:
* faction - NPC faction.
* args - Additional arguments, that were received from function in 'NPCRespawnStationDetector'.
* settings - 'ExtraSettings' table from config file.
]]
function SectorGenerator:createFactory(faction, args, settings)
    -- chance to spawn random factory
    local spawnRandomFactory = false
    if settings then
        local chance = tonumber(settings.ChanceToRespawnRandomFactory)
        if chance ~= nil then
            local rand = Random(Seed(appTimeMs()))
            spawnRandomFactory = rand:getFloat() <= chance
        end
    end

    local station
    if not args.production or spawnRandomFactory then -- no production, spawn random factory
        station = self:createStation(faction, args.script)
    else -- set production
        station = self:createStation(faction)
        station:addScript(args.script, "nothing")
        station:invokeFunction(args.script, "setProduction", args.production, args.maxNumProductions - 1)
        station:invokeFunction(args.script, "updateTitle")
    end

    return station
end