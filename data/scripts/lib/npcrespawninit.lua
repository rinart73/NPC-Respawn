local Azimuth = include("azimuthlib-basic")

-- load config
local configOptions = {
  _version = { default = "0.3.2", comment = "Config version. Don't touch." },
  LogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
  RespawnShips = { default = true, comment = "If false, disable ship respawn in all sectors." },
  RespawnStations = { default = true, comment = "If false, ddisable station respawn in all sectors." },
  ShipRespawnInterval = { default = 120, min = 10, comment = "Interval in seconds between ship respawns." },
  ShipRespawnAmount = { default = 1, min = 1, format = "floor", comment = "How many ships should be respawned every x seconds (maximum)." },
  RespawnSectors = {
    default = {
      asteroidfieldminer = { miner = { min = 1, max = 2 }, station = true },
      colony = { defender = { min = 4, max = 6 }, station = true },
      basefactories = { defender = { min = 4, max = 6 }, station = true },
      factoryfield = { defender = { min = 4, max = 6 }, station = true },
      highfactories = { defender = { min = 4, max = 6 }, station = true },
      loneconsumer = { defender = { min = 0, max = 2 }, station = true },
      lonescrapyard = { defender = { min = 1, max = 3 }, station = true },
      loneshipyard = { defender = { min = 1, max = 2 }, station = true },
      lonetrader = { defender = { min = 0, max = 2 }, station = true },
      lonetradingpost = { defender = { min = 0, max = 2 }, station = true },
      lowfactories = { defender = { min = 4, max = 6 }, station = true },
      midfactories = { defender = { min = 4, max = 6 }, station = true },
      miningfield = { defender = { min = 4, max = 6 }, miner = { min = 1, max = 2 }, station = true },
      neutralzone = { defender = { min = 4, max = 6 }, station = true },
      resistancecell = { defender = { min = 4, max = 6 }, station = true },
      smugglerhideout = { defender = { min = 0, max = 2 }, station = true },
      startsector = { defender = { min = 5, max = 5 }, station = true }
    },
    comment = "Format: sectorType = { shipType = { min = minAmount, max = maxAmount} }. 'shipType' can be: miner, military, defender or carrier. You can also use 'station = false' to disable station respawn in a sector type."
  },
  StationRespawnDelay = { default = 600, min = 10, comment = "Stations will be respawned after x seconds." },
  StationScripts = {
    default = {
      -- ["data/scripts/entity/merchants/biotope.lua"] -- has no special parameters
      -- ["data/scripts/entity/merchants/casino.lua"]
      ["data/scripts/entity/merchants/equipmentdock.lua"] = "createEquipmentDock",
      ["data/scripts/entity/merchants/fighterfactory.lua"] = "createFighterFactory",
      -- ["data/scripts/entity/merchants/habitat.lua"]
      ["data/scripts/entity/merchants/headquarters.lua"] = "createHeadquarters", -- modded function
      ["data/scripts/entity/merchants/militaryoutpost.lua"] = "createMilitaryBase",
      --["data/scripts/entity/merchants/planetarytradingpost.lua"] = "createPlanetaryTradingPost", -- modded, removed in 0.3.2 because it's not the first script
      ["data/scripts/entity/merchants/repairdock.lua"] = "createRepairDock",
      ["data/scripts/entity/merchants/researchstation.lua"] = "createResearchStation",
      ["data/scripts/entity/merchants/resistanceoutpost.lua"] = "createResistanceOutpost", -- modded
      -- ["data/scripts/entity/merchants/resourcetrader.lua"]
      -- ["data/scripts/entity/merchants/scrapyard.lua"]
      ["data/scripts/entity/merchants/shipyard.lua"] = "createShipyard",
      ["data/scripts/entity/merchants/smugglersmarket.lua"] = "createSmugglerHideout", -- modded
      -- ["data/scripts/entity/merchants/tradingpost.lua"]
      ["data/scripts/entity/merchants/turretfactory.lua"] = "createTurretFactory"
    },
    comment = 'You can add custom stations from other mods. Format: ["path/to/first/station/script"] = "functionFromSectorGenerator". You can also disable station respawn: "path/to/first/station/script" = false'
  },
  StationScriptCustom = {
    default = {
      "isFactory",
      "isPlanetaryTradingPost" -- added in 0.3.2
    },
    comment = "Here you can specify custom functions from 'NPCRespawnStationDetector' that perform checks in order to determine which 'SectorGenerator' function should be used to respawn station."
  },
  ExtraSettings = {
    default = {
      ChanceToRespawnRandomFactory = 0
    },
    comment = "Here you can specify additional settings for integrated mods."
  },
  UpdateInterval = { default = 20, min = 5, comment = "Used to calculate ship/station respawn. Smaller value = more precise timing and more performance hit." }
}
local config, isModified = Azimuth.loadConfig("NPCRespawn", configOptions)

-- Check 'RespawnSectors' for errors
local defaults = configOptions.RespawnSectors.default
local value
for k, v in pairs(config.RespawnSectors) do
    if type(v) ~= "table" then
        if defaults[k] then -- reset
            config.RespawnSectors[k] = defaults[k]
        else -- remove
            config.RespawnSectors[k] = nil
        end
        isModified = true
    else -- check each miner/defender
        for k2, v2 in pairs(v) do
            if k2 == "station" then
                if type(v2) ~= "boolean" then
                    config.RespawnSectors[k][k2] = v2 and true or false
                    isModified = true
                end
            elseif k2 ~= "miner" and k2 ~= "defender" and k2 ~= "carrier" and k2 ~= "military" then -- remove
                config.RespawnSectors[k][k2] = nil
                isModified = true
            elseif type(v2) ~= "table" then
                if defaults[k][k2] then -- reset
                    config.RespawnSectors[k][k2] = defaults[k][k2]
                else -- remove
                    config.RespawnSectors[k][k2] = nil
                end
                isModified = true
            else -- check min/max values
                if tonumber(v2.min) == nil then
                    if defaults[k][k2] then -- reset
                        config.RespawnSectors[k][k2].min = defaults[k][k2].min
                    else -- reset
                        config.RespawnSectors[k][k2].min = 0
                    end
                    isModified = true
                end
                value = math.max(0, math.floor(v2.min))
                isModified = isModified or (v2.min ~= value)
                config.RespawnSectors[k][k2].min = value
                if tonumber(v2.max) == nil then
                    if defaults[k][k2] then -- reset
                        config.RespawnSectors[k][k2].max = defaults[k][k2].max
                    else -- reset
                        config.RespawnSectors[k][k2].max = 0
                    end
                    isModified = true
                end
                value = math.max(0, math.floor(v2.max))
                isModified = isModified or (v2.max ~= value)
                config.RespawnSectors[k][k2].max = value
            end
        end
    end
end
-- Check 'StationScripts'
local t
for k, v in pairs(config.StationScripts) do
    t = type(v)
    if t == "boolean" then
        if v then -- no need to have `'path' = true`
            config.StationScripts[k] = nil
            isModified = true
        end
    elseif t ~= "string" then -- incorrect type
        config.StationScripts[k] = nil
        isModified = true
    end
end
-- Check 'StationScriptCustom'
for k, v in pairs(config.StationScriptCustom) do
    if type(v) ~= "string" then
        config.StationScriptCustom[k] = nil
        isModified = true
    end
end

-- Update config
if config._version == "0.2" then
    t = config.StationScripts["data/scripts/entity/merchants/smugglersmarket"]
    if t ~= nil then
        config.StationScripts["data/scripts/entity/merchants/smugglersmarket"] = nil
        config.StationScripts["data/scripts/entity/merchants/smugglersmarket.lua"] = t
    end
    config._version = "0.2.1"
    isModified = true
end
if config._version == "0.2.1" then
    config._version = "0.3"
    isModified = true
end
if config._version == "0.3" then
    config.StationScripts["data/scripts/entity/merchants/planetarytradingpost.lua"] = nil
    config.StationScriptCustom[#config.StationScriptCustom+1] = "isPlanetaryTradingPost"
    config._version = "0.3.2"
    isModified = true
end

local Log = Azimuth.logs("NPCRespawn", config.LogLevel)

if isModified then
    Log.Debug("Config was modified, need to resave it")
    Azimuth.saveConfig("NPCRespawn", config, configOptions) -- resave config file with comments/updates
end

return { Azimuth, config, Log }