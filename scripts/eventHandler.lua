-- local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
-- if not isValid or not targetPid then return end

eventHandler.OnWorldKillCount = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = CustomEventHooks.triggerValidators('OnWorldKillCount', { pid })
        if eventStatus.validDefaultHandler then
            WorldInstance:SaveKills(pid)
            tes3mp.CopyReceivedWorldstateToStore()

            -- Send this WorldKillCount packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendWorldKillCount(pid, true, true)
        end
        CustomEventHooks.triggerHandlers('OnWorldKillCount', eventStatus, { pid })
    end
end

eventHandler.OnWorldMap = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedWorldstate()
        local mapTileArray = packetReader.GetWorldMapTileArray()

        local eventStatus = CustomEventHooks.triggerValidators('OnWorldMap', { pid, mapTileArray })
        if eventStatus.validDefaultHandler then
            WorldInstance:SaveMapTiles(mapTileArray)

            if config.shareMapExploration == true then
                tes3mp.CopyReceivedWorldstateToStore()

                -- Send this WorldMap packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendWorldMap(pid, true, true)
            end
        end
        CustomEventHooks.triggerHandlers('OnWorldMap', eventStatus, { pid, mapTileArray })
    end
end

eventHandler.OnWorldWeather = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = CustomEventHooks.triggerValidators('OnWorldWeather', { pid })
        if eventStatus.validDefaultHandler then
            tes3mp.ReadReceivedWorldstate()

            local regionName = string.lower(tes3mp.GetWeatherRegion())

            -- Track current weather in each region
            if WorldInstance.storedRegions[regionName] ~= nil then
                WorldInstance:SaveRegionWeather(regionName)
            end

            -- Go through the other players on the server and send them this weather update
            for _, otherPlayer in pairs(Players) do
                local otherPid = otherPlayer.pid

                -- Ignore the player we got the weather from
                if otherPid ~= pid then
                    -- If this player has been marked as requiring a force weather update for
                    -- this region, provide them with one
                    if WorldInstance:IsForcedWeatherUpdatePid(otherPid, regionName) then
                        WorldInstance:LoadRegionWeather(regionName, otherPid, false, true)
                        WorldInstance:RemoveForcedWeatherUpdatePid(otherPid, regionName)
                    else
                        WorldInstance:LoadRegionWeather(regionName, otherPid, false, false)
                    end
                end
            end
        end
        CustomEventHooks.triggerHandlers('OnWorldWeather', eventStatus, { pid })
    end
end

return eventHandler
