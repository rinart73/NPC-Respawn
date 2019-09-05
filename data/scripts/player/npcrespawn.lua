if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth, config, Log = unpack(include("npcrespawninit"))

-- namespace NPCRespawn
NPCRespawn = {}

function NPCRespawn.initialize(mode, arg)
    local sector = Sector()
    if mode == "type" then
        sector:setValue("generator_script", arg)
        sector:setValue("npc_respawn_type_changed", true)
        sector:removeScript("data/scripts/sector/npcrespawn.lua")
        sector:addScriptOnce("data/scripts/sector/npcrespawn.lua")
        Player():sendChatMessage("Server"%_t, 0, "Changed sector type to '%s'."%_t, arg)
    else
        sector:setValue("npc_respawn_"..mode, arg)
        local status = sector:invokeFunction("npcrespawn.lua", "reloadSettings")
        if status ~= 0 then
            Log.Error("player file - failed to reload settings, status %i", status)
            return
        end
        Player():sendChatMessage("Server"%_t, 0, "Changed sector settings."%_t, arg)
    end
    terminate()
end