function execute(sender, commandName, mode, arg)
    local player = Player(sender)
    if not player then
        return 1, "", "You're not in a ship!"
    end

    if not player.craft then
        return 1, "", "You're not in a ship!"
    end

    if not Server():hasAdminPrivileges(player) then
        return 1, "", "You don't have admin privileges!"
    end
    
    if not mode or mode == "help" then
        player:sendChatMessage("Server"%_t, 0, getHelp())
    else
        player:addScriptOnce("data/scripts/player/npcrespawn.lua", mode, arg or "")
    end

    return 0, "", ""
end

function getDescription()
    return "Allows to configure NPC Respawn."
end

function getHelp()
    return [[Allows to configure NPC Respawn. Usage:
    /npcrespawn type sectortype - Set sector type. Replace 'sectortype' with sector type. Not specifying it resets this setting to default.
    /npcrespawn shiptype 4 - Set ship type desired amount. Replace 'shiptype' with military/defender/carrier/miner and specify amount. Not specifying amount resets this setting to default.
    /npcrespawn station false - Enable(true) or disable(false) station respawn. Not specifying true/false resets this setting to default.]]
end