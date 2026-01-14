-- local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
-- if not isValid or not targetPid then return end

eventHandler.OnActorCellChange = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local isCellLoaded = LoadedCells[cellDescription] ~= nil

        if not isCellLoaded then
            logicHandler.LoadCell(cellDescription)
        end

        local eventStatus = Deps.customEventHooks.triggerValidators("OnActorCellChange", { pid, cellDescription })
        if eventStatus.validDefaultHandler then
            LoadedCells[cellDescription]:SaveActorCellChanges(pid)
        end
        Deps.customEventHooks.triggerHandlers("OnActorCellChange", eventStatus, { pid, cellDescription })

        if not isCellLoaded then
            logicHandler.UnloadCell(cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnGenericObjectEvent = function(pid, cellDescription, packetType)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedObjectList()
        local packetOrigin = tes3mp.GetObjectListOrigin()
        local clientScript
        tes3mp.LogAppend(enumerations.log.INFO, "- packetOrigin was " ..
            tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))

        if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) then
            tes3mp.Kick(pid)
            tes3mp.SendMessage(pid, logicHandler.GetChatName(pid) .. consoleKickMessage, true)
            return
        elseif logicHandler.IsPacketFromClientScript(packetOrigin) then
            clientScript = tes3mp.GetObjectListClientScript()
            tes3mp.LogAppend(enumerations.log.INFO, "- clientScript was " .. clientScript)
        end

        local isCellLoaded = LoadedCells[cellDescription] ~= nil

        if not isCellLoaded and logicHandler.DoesPacketOriginRequireLoadedCell(packetOrigin) then
            tes3mp.LogMessage(enumerations.log.WARN, "Invalid " .. packetType ..
                logicHandler.GetChatName(pid) .. " used impossible packetOrigin for unloaded " .. cellDescription)
            return
        end

        local packetTables = packetReader.GetObjectPacketTables(packetType)
        local objects = packetTables.objects
        local targetPlayers = packetTables.players

        if not tableHelper.isEmpty(objects) or not tableHelper.isEmpty(targetPlayers) then
            if not isCellLoaded then
                logicHandler.LoadCell(cellDescription)
            end

            local eventStatus = Deps.customEventHooks.triggerValidators("On" .. packetType,
                { pid, cellDescription, objects, targetPlayers })

            if eventStatus.validDefaultHandler then
                local debugMessage = "Accepted " .. packetType .. " from " .. logicHandler.GetChatName(pid) ..
                    " about " .. cellDescription .. " for "

                if not tableHelper.isEmpty(objects) then
                    debugMessage = debugMessage .. "objects: "
                    local includeComma = false

                    for uniqueIndex, object in pairs(objects) do
                        if includeComma then debugMessage = debugMessage .. ", " end
                        debugMessage = debugMessage .. object.refId .. " " .. uniqueIndex
                        includeComma = true
                    end
                end

                if not tableHelper.isEmpty(targetPlayers) then
                    local chatNames = logicHandler.GetChatNames(tableHelper.getArrayFromIndices(targetPlayers))
                    debugMessage = debugMessage .. "players: " .. tableHelper.concatenateArrayValues(chatNames, 1, ", ")
                end

                tes3mp.LogMessage(enumerations.log.INFO, debugMessage)

                LoadedCells[cellDescription]:SaveObjectsByPacketType(packetType, objects)
                LoadedCells[cellDescription]:LoadObjectsByPacketType(packetType, pid, objects,
                    tableHelper.getArrayFromIndices(objects), true)
            end

            Deps.customEventHooks.triggerHandlers("On" .. packetType, eventStatus,
                { pid, cellDescription, objects, targetPlayers })

            if not isCellLoaded then
                logicHandler.UnloadCell(cellDescription)
            end
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectActivate = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectActivate")
end

eventHandler.OnObjectHit = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectHit")
end

eventHandler.OnObjectSound = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectSound")
end

eventHandler.OnObjectPlace = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectPlace")
end

eventHandler.OnObjectSpawn = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectSpawn")
end

eventHandler.OnObjectDelete = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectDelete")
end

eventHandler.OnObjectLock = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectLock")
end

eventHandler.OnObjectDialogueChoice = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectDialogueChoice")
end

eventHandler.OnObjectMiscellaneous = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectMiscellaneous")
end

eventHandler.OnObjectRestock = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectRestock")
end

eventHandler.OnObjectTrap = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectTrap")
end

eventHandler.OnObjectScale = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectScale")
end

eventHandler.OnObjectState = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ObjectState")
end

eventHandler.OnDoorState = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "DoorState")
end

eventHandler.OnClientScriptLocal = function(pid, cellDescription)
    eventHandler.OnGenericObjectEvent(pid, cellDescription, "ClientScriptLocal")
end

eventHandler.OnConsoleCommand = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedObjectList()

        local packetTables = packetReader.GetObjectPacketTables("ConsoleCommand")
        local objects = packetTables.objects
        local targetPlayers = packetTables.players
        local consoleCommand = tes3mp.GetObjectListConsoleCommand()

        local eventStatus = Deps.customEventHooks.triggerValidators("OnConsoleCommand",
            { pid, cellDescription, consoleCommand,
                objects, targetPlayers })

        if eventStatus.validDefaultHandler then
            local debugMessage = "Accepted ConsoleCommand from " .. logicHandler.GetChatName(pid) ..
                " about " .. cellDescription

            debugMessage = debugMessage .. "\n- consoleCommand: " .. consoleCommand

            for uniqueIndex, object in pairs(objects) do
                debugMessage = debugMessage .. "\n- object target: " .. object.refId .. " " .. uniqueIndex
            end

            for targetPid, targetPlayer in pairs(targetPlayers) do
                debugMessage = debugMessage .. "\n- player target: " .. logicHandler.GetChatName(targetPid)
            end

            local isQueuedConsoleCommand = false

            -- Clear this only once from the console commands queued for this player, if found in that table
            for arrayIndex, consoleCommandQueued in pairs(Players[pid].consoleCommandsQueued) do
                if consoleCommandQueued == consoleCommand then
                    Players[pid].consoleCommandsQueued[arrayIndex] = nil
                    isQueuedConsoleCommand = true
                    debugMessage = debugMessage .. "\n- was a console command executed at the server's request"
                    break
                end
            end

            if not isQueuedConsoleCommand then
                debugMessage = debugMessage .. "\n- was a console command executed unilaterally from the client"
            end

            tes3mp.LogMessage(enumerations.log.INFO, debugMessage)
        end

        Deps.customEventHooks.triggerHandlers("OnConsoleCommand", eventStatus, { pid, cellDescription, consoleCommand,
            objects, targetPlayers })
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnContainer = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedObjectList()
        local packetOrigin = tes3mp.GetObjectListOrigin()
        tes3mp.LogAppend(enumerations.log.INFO, "- packetOrigin was " ..
            tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))

        if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) then
            tes3mp.Kick(pid)
            tes3mp.SendMessage(pid, logicHandler.GetChatName(pid) .. consoleKickMessage, true)
            return
        end

        local isCellLoaded = LoadedCells[cellDescription] ~= nil

        if not config.allowOnContainerForUnloadedCells and not isCellLoaded and logicHandler.DoesPacketOriginRequireLoadedCell(packetOrigin) then
            tes3mp.LogMessage(enumerations.log.WARN, "Invalid Container: " .. logicHandler.GetChatName(pid) ..
                " used impossible packetOrigin for unloaded " .. cellDescription)
            return
        end

        -- Iterate through the objects in the Container packet and only sync and save the
        -- ones whose refIds are valid
        --local objects = packetReader.GetObjectPacketTables("container").objects
        --local acceptedObjects, rejectedObjects = {}, {}
        local isAllowed = true
        local rejectedObjects = {}

        -- Don't allow container changes in currently dying actors
        local unusableContainerUniqueIndexes = {}

        if isCellLoaded then
            unusableContainerUniqueIndexes = LoadedCells[cellDescription].unusableContainerUniqueIndexes
        end

        local subAction = tes3mp.GetObjectListContainerSubAction()

        local objects = {}

        for index = 0, tes3mp.GetObjectListSize() - 1 do
            local object = {}
            object.refId = tes3mp.GetObjectRefId(index)
            object.uniqueIndex = tes3mp.GetObjectRefNum(index) .. "-" .. tes3mp.GetObjectMpNum(index)

            if tableHelper.containsValue(unusableContainerUniqueIndexes, object.uniqueIndex) then
                if subAction == enumerations.containerSub.REPLY_TO_REQUEST then
                    tableHelper.removeValue(unusableContainerUniqueIndexes, object.uniqueIndex)
                    tes3mp.LogMessage(enumerations.log.INFO, "Making container " .. object.uniqueIndex ..
                        " usable as a result of request reply")
                    table.insert(objects, object)
                else
                    table.insert(rejectedObjects, object.refId .. " " .. object.uniqueIndex)
                    isAllowed = false

                    Players[pid]:Message("That container is currently unusable for synchronization reasons.\n")
                end
            else
                table.insert(objects, object)
            end
        end

        if isAllowed then
            local eventStatus = Deps.customEventHooks.triggerValidators("OnContainer", { pid, cellDescription, objects })
            if eventStatus.validDefaultHandler then
                local useTemporaryLoad = false

                if not isCellLoaded then
                    logicHandler.LoadCell(cellDescription)
                    useTemporaryLoad = true
                end

                -- Don't sync this packet here; BaseCell():SaveContainers will have to
                -- deal with it
                LoadedCells[cellDescription]:SaveContainers(pid)

                if useTemporaryLoad then
                    logicHandler.UnloadCell(cellDescription)
                end
            end
            Deps.customEventHooks.triggerHandlers("OnContainer", eventStatus, { pid, cellDescription, objects })
        else
            tes3mp.LogMessage(enumerations.log.INFO, "Rejected Container from " .. logicHandler.GetChatName(pid) ..
                " about " .. tableHelper.concatenateArrayValues(rejectedObjects, 1, ", "))
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnVideoPlay = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedObjectList()
        local packetOrigin = tes3mp.GetObjectListOrigin()
        tes3mp.LogAppend(enumerations.log.INFO, "- packetOrigin was " ..
            tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))

        local consoleCommand = tes3mp.GetObjectListConsoleCommand()
        local hasConsoleVideoQueued = tableHelper.containsValue(Players[pid].consoleVideosQueued, consoleCommand)

        if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) and not hasConsoleVideoQueued then
            tes3mp.Kick(pid)
            tes3mp.SendMessage(pid, logicHandler.GetChatName(pid) .. consoleKickMessage, true)
            return
        end

        if hasConsoleVideoQueued then
            Players[pid].consoleVideosQueued = {}
        end

        if config.shareVideos == true then
            tes3mp.LogMessage(enumerations.log.INFO, "Sharing VideoPlay from " .. logicHandler.GetChatName(pid))

            local videos = {}

            for i = 0, tes3mp.GetObjectListSize() - 1 do
                local videoFilename = tes3mp.GetVideoFilename(i)
                table.insert(videos, videoFilename)
                tes3mp.LogAppend(enumerations.log.WARN, "- videoFilename " .. videoFilename)
            end
            local eventStatus = Deps.customEventHooks.triggerValidators("OnVideoPlay", { pid, videos })
            if eventStatus.validDefaultHandler then
                tes3mp.CopyReceivedObjectListToStore()
                -- Send this VideoPlay packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendVideoPlay(true, true)
            end
            Deps.customEventHooks.triggerHandlers("OnVideoPlay", eventStatus, { pid, videos })
        end
    end
end

eventHandler.OnRecordDynamic = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedWorldstate()

        local recordNumericalType = tes3mp.GetRecordType(pid)

        -- Iterate through the records in the RecordDynamic packet and only sync and save them
        -- if all their names are allowed
        local isAllowed = true
        local rejectedRecords = {}

        local recordArray = packetReader.GetRecordDynamicArray(pid)
        local recordTable = {}

        if recordNumericalType ~= enumerations.recordType.ENCHANTMENT then
            for _, record in pairs(recordArray) do
                if not logicHandler.IsNameAllowed(record.name) then
                    isAllowed = false

                    Players[pid]:Message("You are not allowed to create a record called " .. record.name .. "\n")
                end
            end
        end

        if not isAllowed then
            tes3mp.LogMessage(enumerations.log.INFO, "Rejected RecordDynamic from " .. logicHandler.GetChatName(pid) ..
                " about " .. tableHelper.concatenateArrayValues(rejectedRecords, 1, ", "))
            return
        end

        local storeType = string.lower(tableHelper.getIndexByValue(enumerations.recordType, recordNumericalType))
        local recordStore = RecordStores[storeType]
        local isEnchantable

        if recordStore == nil then
            tes3mp.LogMessage(enumerations.log.WARN, "Rejected RecordDynamic for invalid record store of type " ..
                recordNumericalType)
            return
        else
            isEnchantable = tableHelper.containsValue(config.enchantableRecordTypes, storeType)
        end

        local eventStatus = Deps.customEventHooks.triggerValidators("OnRecordDynamic", { pid, recordArray, storeType })

        if eventStatus.validDefaultHandler then
            for _, record in ipairs(recordArray) do
                local recordId

                -- Is there already a record exactly like this one, icon and model aside?
                -- If so, we'll just reuse it the way OpenMW would
                if storeType == "potion" then
                    recordId = recordStore:GetMatchingRecordId(record, recordStore.data.generatedRecords,
                        Players[pid].data.recordLinks[storeType], { "icon", "model", "quantity" }, true, 25)
                end

                if recordId == nil then
                    recordId = recordStore:GenerateRecordId()
                end

                if storeType == "enchantment" then
                    -- We need to store this enchantment's original client-generated id
                    -- on this player so we can match it with its server-generated correct
                    -- id once the player sends the record of the enchanted item they've
                    -- used it on
                    Players[pid].unresolvedEnchantments[record.clientsideEnchantmentId] = recordId
                    record.clientsideEnchantmentId = nil
                end

                recordTable[recordId] = record
            end

            recordStore:SaveGeneratedRecords(recordTable)
            recordStore:LoadGeneratedRecords(pid, recordTable, tableHelper.getArrayFromIndices(recordTable), true)

            for _, player in pairs(Players) do
                for recordId, record in pairs(recordTable) do
                    table.insert(player.generatedRecordsReceived, recordId)
                end
            end

            -- Add the final spell to the player's spellbook
            if storeType == "spell" then
                tes3mp.ClearSpellbookChanges(pid)
                tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.ADD)

                for recordId, record in pairs(recordTable) do
                    table.insert(Players[pid].data.spellbook, recordId)
                    tes3mp.AddSpell(pid, recordId)

                    Players[pid]:AddLinkToRecord(storeType, recordId)
                end

                recordStore:QuicksaveToDrive()
                Players[pid]:QuicksaveToDrive()
                tes3mp.SendSpellbookChanges(pid)

                -- Add the final items to the player's inventory
            elseif storeType == "potion" or isEnchantable then
                local enchantmentStore

                if isEnchantable then enchantmentStore = RecordStores["enchantment"] end

                local itemArray = {}

                for recordId, record in pairs(recordTable) do
                    local item = {
                        refId = recordId,
                        count = record.quantity,
                        charge = -1,
                        enchantmentCharge = -1,
                        soul =
                        ""
                    }
                    inventoryHelper.addItem(Players[pid].data.inventory, item.refId, item.count, item.charge,
                        item.enchantmentCharge, item.soul)
                    table.insert(itemArray, item)

                    Players[pid]:AddLinkToRecord(storeType, recordId)

                    -- If this is an enchantable item record, add a link to it from its associated
                    -- enchantment record
                    if isEnchantable then
                        enchantmentStore:AddLinkToRecord(record.enchantmentId,
                            recordId, storeType)
                    end
                end

                if isEnchantable then enchantmentStore:QuicksaveToDrive() end

                recordStore:QuicksaveToDrive()
                Players[pid]:QuicksaveToDrive()
                Players[pid]:LoadItemChanges(itemArray, enumerations.inventory.ADD)
            end
        end
        Deps.customEventHooks.triggerHandlers("OnRecordDynamic", eventStatus, { pid, recordTable, storeType })
    end
end

eventHandler.OnWorldKillCount = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnWorldKillCount", { pid })
        if eventStatus.validDefaultHandler then
            WorldInstance:SaveKills(pid)
            tes3mp.CopyReceivedWorldstateToStore()

            -- Send this WorldKillCount packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendWorldKillCount(pid, true, true)
        end
        Deps.customEventHooks.triggerHandlers("OnWorldKillCount", eventStatus, { pid })
    end
end

eventHandler.OnWorldMap = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedWorldstate()
        local mapTileArray = packetReader.GetWorldMapTileArray()

        local eventStatus = Deps.customEventHooks.triggerValidators("OnWorldMap", { pid, mapTileArray })
        if eventStatus.validDefaultHandler then
            WorldInstance:SaveMapTiles(mapTileArray)

            if config.shareMapExploration == true then
                tes3mp.CopyReceivedWorldstateToStore()

                -- Send this WorldMap packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendWorldMap(pid, true, true)
            end
        end
        Deps.customEventHooks.triggerHandlers("OnWorldMap", eventStatus, { pid, mapTileArray })
    end
end

eventHandler.OnWorldWeather = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnWorldWeather", { pid })
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
        Deps.customEventHooks.triggerHandlers("OnWorldWeather", eventStatus, { pid })
    end
end

return eventHandler
