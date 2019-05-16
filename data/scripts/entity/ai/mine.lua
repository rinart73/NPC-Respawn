-- this function will be executed every frame on the server only
function AIMine.updateServer(timeStep)
    local ship = Entity()

    if miningMaterial == nil then
        AIMine.checkIfAbleToMine()

        if miningMaterial == nil then
            ShipAI():setPassive()
            terminate()
            return
        end
    end

    -- making sure that AI miners can do this without captain
    if not Faction(ship.factionIndex).isAIFaction and (ship.hasPilot or ship:getCrewMembers(CrewProfessionType.Captain) == 0) then
--        print("no captain")
        ShipAI():setPassive()
        terminate()
        return
    end

    -- find an asteroid that can be harvested
    AIMine.updateMining(timeStep)
end

function AIMine.updateMining(timeStep)
    local ship = Entity()

    if hasRawLasers == true then
        if Entity().freeCargoSpace < 1 then
            if noCargoSpace == false then
                local faction = Faction(ship.factionIndex)
                local x, y = Sector():getCoordinates()
                local coords = tostring(x) .. ":" .. tostring(y)
                if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Error, "Your ship's cargo bay in sector %s is full."%_T, coords) end

                ShipAI():setPassive()

                local ores, totalOres = getOreAmountsOnShip(ship)
                local scraps, totalScraps = getScrapAmountsOnShip(ship)
                if totalOres + totalScraps == 0 then
                    ShipAI():setStatus("Mining - No Cargo Space"%_T, {})
                    if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, "Sir, we can't mine in \\s(%s), we have no space in our cargo bay!"%_T, coords) end
                    noCargoSpace = true
                else
                    if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, "Sir, we can't continue mining in \\s(%s), we have no more space left in our cargo bay!"%_T, coords) end
                    -- If this is NPC miner, make it jump away to be replaced with another one
                    if faction.isAIFaction then
                        Sector():deleteEntityJumped(ship)
                    else
                        terminate()
                    end
                end
            end

            return
        else
            noCargoSpace = false
        end
    end

    -- highest priority is collecting the resources
    if not valid(minedAsteroid) and not valid(minedLoot) then

        -- first, check if there is loot to collect
        AIMine.findMinedLoot()

        -- then, if there's no loot, check if there is an asteroid to mine
        if not valid(minedLoot) then
            AIMine.findMinedAsteroid()
        end

    end

    local ai = ShipAI()

    if valid(minedLoot) then
        ai:setStatus("Collecting Mined Loot /* ship AI status*/"%_T, {})

        -- there is loot to collect, fly there
        collectCounter = collectCounter + timeStep
        if collectCounter > 3 then
            collectCounter = collectCounter - 3

            if ai.isStuck then
                stuckLoot[minedLoot.index.string] = true
                AIMine.findMinedLoot()
                collectCounter = collectCounter + 2
            end

            if valid(minedLoot) then                
                ai:setFly(minedLoot.translationf, 0)
            end
        end

    elseif valid(minedAsteroid) then
        ai:setStatus("Mining /* ship AI status*/"%_T, {})

        -- if there is an asteroid to collect, harvest it
        if ship.selectedObject == nil
            or ship.selectedObject.index ~= minedAsteroid.index
            or ai.state ~= AIState.Harvest then

            ai:setHarvest(minedAsteroid)
            stuckLoot = {}
        end
    else
--        print("no asteroids")
        ai:setStatus("Mining - No Asteroids Left /* ship AI status*/"%_T, {})
    end

end