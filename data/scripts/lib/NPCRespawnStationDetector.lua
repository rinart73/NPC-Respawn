package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth, config, Log = unpack(include("npcrespawninit"))
if anynils(Azimuth, config, Log) then return end


local StationDetector = {}

--[[ Can return 2 values:
1. "respawnFunction" from 'SectorGenerator' or nil/false if station didn't pass checks.
2. Additional data, that will be passed to respawn function (such as factory good).
]]
function StationDetector.isFactory(entity)
    local scripts = {
      "data/scripts/entity/merchants/basefactory.lua",
      "data/scripts/entity/merchants/factory.lua",
      "data/scripts/entity/merchants/highfactory.lua",
      "data/scripts/entity/merchants/lowfactory.lua",
      "data/scripts/entity/merchants/midfactory.lua"
    }
    local script
    for _, path in pairs(entity:getScripts()) do
        path = path:gsub("\\","/")
        for i = 1, #scripts do
            if scripts[i] == path then
                script = scripts[i]
                break
            end
        end
        if script then break end
    end
    if not script then return end
    -- save factory good
    local status, data = entity:invokeFunction(script, "secure")
    if status ~= 0 then
        Log.Error("Can't get factory production data")
        return "createFactory", { script = script }
    end
    return "createFactory", { script = script, production = data.production, maxNumProductions = data.maxNumProductions }
end

function StationDetector.isPlanetaryTradingPost(entity)
    for _, path in pairs(entity:getScripts()) do
        path = path:gsub("\\","/")
        if path == "data/scripts/entity/merchants/planetarytradingpost.lua" then -- it's just not the first one
            return "createPlanetaryTradingPost", true
        end
    end
end

return StationDetector