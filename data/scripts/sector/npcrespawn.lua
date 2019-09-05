if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

include("galaxy")
include("randomext")
include("utility")
local AsyncShipGenerator = include("asyncshipgenerator")
local Placer = include("placer")
local SectorGenerator = include("SectorGenerator")
local SectorSpecifics = include("data/scripts/sectorspecifics")
local StationDetector = include("NPCRespawnStationDetector")
local Azimuth, config, Log = unpack(include("npcrespawninit"))

-- namespace NPCRespawn
NPCRespawn = {}

local sector, x, y, generatorScript
local isGenerating = true -- don't respawn anything while sector is being generated
local data = {
  shipTimer = 0,
  stationTimer = 0,
  stations = {}
}
local generatorArmed = AsyncShipGenerator(NPCRespawn, NPCRespawn.resolveIntersections)
local stationGenerator

local function lateInitialization()
    -- get sector generator script
    generatorScript = sector:getValue("generator_script")
    if not generatorScript then
        generatorScript = SectorSpecifics(x, y, Server().seed):getScript()
        generatorScript = string.gsub(generatorScript, "^[^/]+/", "")
    end
    if not config.RespawnSectors[generatorScript] then
        Log.Debug("(%i:%i) - generatorScript: %s, script terminated", x, y, generatorScript)
        terminate()
        return
    else
        Log.Debug("(%i:%i) - generatorScript: %s", x, y, generatorScript)
    end
    -- init other vars
    stationGenerator = SectorGenerator(x, y)

    return true
end

local function finishedGenerating()
    isGenerating = false
    sector:unregisterCallback("onPlayerEntered", "onPlayerEntered")
    sector:unregisterCallback("onEntityJump", "onEntityJump")
end

local function checkSavedValuesAgainstConfig() -- check if saved ship respawn values match with config settings
    local settings = config.RespawnSectors[generatorScript]
    local newSettings = {}
    local sectorVar

    -- station
    sectorVar = sector:getValue("npc_respawn_station")
    if sectorVar ~= nil then
        newSettings["station"] = tostring(sectorVar) == "true"
        Log.Debug("(%i:%i) - override 'station' setting: %s", x, y, tostring(newSettings["station"]))
    else
        newSettings["station"] = settings["station"]
    end
    -- ships
    local keys = {"military", "defender", "carrier", "miner"}
    local v
    for _, k in pairs(keys) do
        v = settings[k]
        sectorVar = sector:getValue("npc_respawn_"..k)
        if v then
            if not data.settings[k] then -- randomize
                newSettings[k] = math.random(v.min, v.max)
                Log.Debug("(%i:%i) - added respawn value for '%s' = %i", x, y, k, newSettings[k])
            else -- check
                newSettings[k] = math.min(v.max, math.max(v.min, data.settings[k]))
                Log.Debug("(%i:%i) - checked value for '%s' = [%i <= %i <= %i]", x, y, k, v.min, data.settings[k], v.max)
            end
        end
        -- override with sector vars
        sectorVar = tonumber(sectorVar)
        if sectorVar ~= nil and sectorVar >= 0 then
            newSettings[k] = sectorVar
            Log.Debug("(%i:%i) - override '%s' setting: %i", x, y, k, sectorVar)
        end
    end
    data.settings = newSettings

    if config.RespawnStations and data.settings["station"] then
        sector:registerCallback("onDestroyed", "onDestroyed")
    else
        sector:unregisterCallback("onDestroyed", "onDestroyed")
    end
end

local function getCurrentShipAmounts(saveValues)
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction then
        if saveValues then
            Log.Debug("(%i:%i) - nobody controls this sector, randomize values", x, y)
            data.settings = {}
            checkSavedValuesAgainstConfig()
        end
        return
    end

    -- count all ship types
    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    local minerAmount = 0
    local militaryAmount = 0
    local defenderAmount = 0
    local carrierAmount = 0
    local status, icon, hasAIPatrol
    local shipScripts
    for _, ship in pairs(ships) do
        if ship.factionIndex == faction.index then
            shipScripts = {}
            for _, path in pairs(ship:getScripts()) do
                path = path:gsub("\\","/")
                shipScripts[path] = true
            end

            --Log.Debug("(%i:%i) - ship title = %s, scripts: %s", x, y, ship.title, Log.isDebug and Azimuth.serialize(ship:getScripts()) or "")
            if shipScripts["data/scripts/entity/ai/mine.lua"] then
                minerAmount = minerAmount + 1
            elseif ship:getValue("is_armed")
              and not shipScripts["data/scripts/entity/blocker.lua"]
              and not shipScripts["data/scripts/entity/dialogs/encounters/persecutor.lua"]
              and not shipScripts["data/scripts/entity/story/adventurer1.lua"] then
                status, icon = ship:invokeFunction("icon.lua", "secure")
                if status ~= 0 then
                    Log.Error("sector - failed to retrieve an icon, status %i", status)
                end
                if icon and icon.icon then
                    --Log.Debug("(%i:%i) - ship title = %s, icon = %s", x, y, ship.title, icon.icon)
                    hasAIPatrol = shipScripts["data/scripts/entity/ai/patrol.lua"]
                    if icon.icon == "data/textures/icons/pixel/carrier.png" and hasAIPatrol then
                        carrierAmount = carrierAmount + 1
                    --elseif icon.icon == "data/textures/icons/pixel/defender.png" and hasAIPatrol and ship:hasScript("data/scripts/entity/antismuggle.lua") then
                    elseif icon.icon == "data/textures/icons/pixel/defender.png" and hasAIPatrol then
                        defenderAmount = defenderAmount + 1
                    elseif icon.icon == "data/textures/icons/pixel/military-ship.png" then
                        militaryAmount = militaryAmount + 1
                    end
                end
            end
        end
    end
    Log.Debug("(%i:%i) - miner %i, military %i, defender %i, carrier %i", x, y, minerAmount, militaryAmount, defenderAmount, carrierAmount)
    
    if saveValues then -- save values, but first check them in case config overrides them
        data.settings = {
          carrier = carrierAmount,
          defender = defenderAmount,
          military = militaryAmount,
          miner = minerAmount
        }
        checkSavedValuesAgainstConfig()
    end
    
    return carrierAmount, defenderAmount, militaryAmount, minerAmount
end

function NPCRespawn.initialize()
    sector = Sector()
    x, y = sector:getCoordinates()

    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("onEntityJump", "onEntityJump")
    
    local typeChanged = sector:getValue("npc_respawn_type_changed")
    if typeChanged then -- type was changed, override sector settings
        sector:setValue("npc_respawn_type_changed", nil)
        Log.Debug("(%i:%i) - type was changed, randomize settings", x, y)
        if not lateInitialization() then return end
        data.settings = {}
        checkSavedValuesAgainstConfig()
        finishedGenerating()
    end
end

function NPCRespawn.secure()
    return data
end

function NPCRespawn.restore(_data)
    if not lateInitialization() then return end
    Log.Debug("(%i:%i) - restore: %s", x, y, Log.isDebug and Azimuth.serialize(_data) or "")

    if _data then -- sector was already generated and then saved to disk
        data = _data
        -- sector was generated but nobody entered it, which means that current ship amounts weren't saved
        if not data.settings then
            Log.Debug("(%i:%i) - save current ship amounts", x, y)
            getCurrentShipAmounts(true)
        else -- check if saved ship respawn values match with config settings
            Log.Debug("(%i:%i) - data.settings is present, just check settings", x, y)
            checkSavedValuesAgainstConfig()
        end
    else -- no data but restore was called, which means that script was never executed in this sector before, but sector was generated
        -- save randomized respawn values
        Log.Debug("(%i:%i) - randomize settings", x, y)
        data.settings = {}
        checkSavedValuesAgainstConfig()
    end
    finishedGenerating()
end

function NPCRespawn.getUpdateInterval()
    return config.UpdateInterval
end

function NPCRespawn.update(timePassed)
    if isGenerating then return end

    --Log.Debug("(%i:%i): DATA %s", x, y, Azimuth.serialize(data))
    if config.RespawnStations and data.settings["station"] and #data.stations > 0 then
        data.stationTimer = data.stationTimer + timePassed
        if data.stationTimer >= config.StationRespawnDelay then -- time to respawn stations
            data.stationTimer = 0
            -- respawn station
            local stationData = table.remove(data.stations, 1)
            if stationData.func then -- use respawn function from sector generator
                Log.Debug("(%i:%i) - Trying to respawn station: faction %i, function '%s'", x, y, stationData.faction, tostring(stationData.func))
                stationGenerator[stationData.func](stationGenerator, Faction(stationData.faction), stationData.data, config.ExtraSettings)
            else -- simple respawn
                Log.Debug("(%i:%i) - Trying to respawn station: faction %i, script '%s'", x, y, stationData.faction, tostring(stationData.script))
                stationGenerator:createStation(Faction(stationData.faction), stationData.script)
            end
        end
    end
    
    if config.RespawnShips then
        data.shipTimer = data.shipTimer + timePassed
        if data.shipTimer >= config.ShipRespawnInterval then -- time to check and respawn ships
            data.shipTimer = 0
        
            local faction = Galaxy():getControllingFaction(x, y)
            if not faction or not faction.isAIFaction then
                Log.Debug("(%i:%i) - faction is nil or not AI: %s", x, y, faction and faction.name or "nil")
                return
            end
        
            local carrierAmount, defenderAmount, militaryAmount, minerAmount = getCurrentShipAmounts()
            local maxRespawnAmount = config.ShipRespawnAmount
            local ship, amountDifference, dir, pos, up, look
            
            generatorArmed:startBatch()
            -- military
            if data.settings["military"] then
                amountDifference = data.settings["military"] - militaryAmount
                if amountDifference > 0 then
                    for i = 1, math.min(amountDifference, maxRespawnAmount) do
                        dir = random():getDirection()
                        pos = dir * math.random(500, 5000)
                        up = vec3(0, 1, 0)
                        look = -dir
                        Log.Debug("(%i:%i) - trying to spawn military", x, y)
                        ship = generatorArmed:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos))
                        maxRespawnAmount = maxRespawnAmount - 1
                    end
                end
            end
            -- defenders
            if data.settings["defender"] and maxRespawnAmount > 0 then
                amountDifference = data.settings["defender"] - defenderAmount
                if amountDifference > 0 then
                    for i = 1, math.min(amountDifference, maxRespawnAmount) do
                        dir = random():getDirection()
                        pos = dir * math.random(500, 5000)
                        up = vec3(0, 1, 0)
                        look = -dir
                        Log.Debug("(%i:%i) - trying to spawn defender", x, y)
                        ship = generatorArmed:createDefender(faction, MatrixLookUpPosition(look, up, pos))
                        maxRespawnAmount = maxRespawnAmount - 1
                    end
                end
            end
            -- carriers
            if data.settings["carrier"] and maxRespawnAmount > 0 then
                amountDifference = data.settings["carrier"] - carrierAmount
                if amountDifference > 0 then
                    for i = 1, math.min(amountDifference, maxRespawnAmount) do
                        dir = random():getDirection()
                        pos = dir * math.random(500, 5000)
                        up = vec3(0, 1, 0)
                        look = -dir
                        Log.Debug("(%i:%i) - trying to spawn carrier", x, y)
                        ship = generatorArmed:createCarrier(faction, MatrixLookUpPosition(look, up, pos))
                        maxRespawnAmount = maxRespawnAmount - 1
                    end
                end
            end
            generatorArmed:endBatch()
            -- miners
            if data.settings["miner"] and maxRespawnAmount > 0 then
                amountDifference = data.settings["miner"] - minerAmount
                if amountDifference > 0 then
                    local generator = AsyncShipGenerator(NPCRespawn, NPCRespawn.finalizeMiners)
                    generator:startBatch()
                    for i = 1, math.min(amountDifference, maxRespawnAmount) do
                        dir = random():getDirection()
                        pos = dir * math.random(1500, 7500)
                        up = vec3(0, 1, 0)
                        look = -dir
                        Log.Debug("(%i:%i) - trying to spawn miner", x, y)
                        ship = generator:createMiningShip(faction, MatrixLookUpPosition(look, up, pos))
                        maxRespawnAmount = maxRespawnAmount - 1
                    end
                    generator:endBatch()
                end
            end
        end
    end
end

function NPCRespawn.onPlayerEntered()
    Log.Debug("(%i:%i) - player entered, generating: %s", x, y, tostring(isGenerating))
    if not isGenerating then return end
    -- sector finished generating and player jumped in. Time to save current ship amounts
    if not lateInitialization() then return end
    getCurrentShipAmounts(true)
    finishedGenerating()
end

function NPCRespawn.onEntityJump(shipIndex, x, y) -- this should solve starting sector problem
    if not isGenerating then return end
    if not lateInitialization() then return end
    getCurrentShipAmounts(true)
    finishedGenerating()
end

function NPCRespawn.onDestroyed(entityIndex)
    local entity = Entity(entityIndex)
    if not entity.isStation or not entity.aiOwned then return end

    -- check entity with custom detectors first
    local func, respawnData, detector
    for k, v in pairs(config.StationScriptCustom) do
        detector = StationDetector[v]
        if not detector then
            --config.StationScriptCustom[k] = nil
            Log.Error("(%i:%i) - Couldn't find station detector function: %s", x, y, v)
        else
            func, respawnData = detector(entity)
            if func then break end
        end
    end
    if func then
        if not stationGenerator[func] then
            Log.Error("(%i:%i) - Respawn function doesn't exist: %s", x, y, func)
            return
        end
        Log.Debug("(%i:%i) - station was destroyed: %s", x, y, func)
        data.stations[#data.stations+1] = {
          faction = entity.factionIndex,
          func = func,
          data = respawnData
        }
        return
    end
    
    -- get first script
    local scripts = entity:getScripts()
    Log.Debug("(%i:%i) - station was destroyed: %s", x, y, Log.isDebug and Azimuth.serialize(scripts) or "")
    if not scripts[0] then
        Log.Error("(%i:%i) - station had no scripts", x, y)
        return
    end
    func = config.StationScripts[scripts[0]]
    if func then
        if not stationGenerator[func] then
            Log.Error("(%i:%i) - Respawn function doesn't exist: %s (%s)", x, y, func, scripts[0])
            return
        end
        data.stations[#data.stations+1] = {
          faction = entity.factionIndex,
          func = func
        }
    else -- it's a simple respawn
        data.stations[#data.stations+1] = {
          faction = entity.factionIndex,
          script = scripts[0]
        }
    end
end

function NPCRespawn.reloadSettings()
    checkSavedValuesAgainstConfig()
end

function NPCRespawn.resolveIntersections(ships)
    Placer.resolveIntersections(ships)
end

function NPCRespawn.finalizeMiners(ships)
    Placer.resolveIntersections(ships)
    for i = 1, #ships do
        ships[i]:addScript("data/scripts/entity/ai/mine.lua")
    end
end