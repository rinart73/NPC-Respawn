if onClient() then return end

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
        sector:invokeFunction("data/scripts/sector/npcrespawn.lua", "reloadSettings")
        Player():sendChatMessage("Server"%_t, 0, "Changed sector settings."%_t, arg)
    end
    terminate()
end