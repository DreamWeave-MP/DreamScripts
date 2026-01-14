-- local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
-- if not isValid or not targetPid then return end

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

                    Players[pid]:Message('You are not allowed to create a record called ' .. record.name .. '\n')
                end
            end
        end

        if not isAllowed then
            tes3mp.LogMessage(enumerations.log.INFO, 'Rejected RecordDynamic from ' .. logicHandler.GetChatName(pid) ..
                ' about ' .. tableHelper.concatenateArrayValues(rejectedRecords, 1, ', '))
            return
        end

        local storeType = string.lower(tableHelper.getIndexByValue(enumerations.recordType, recordNumericalType))
        local recordStore = RecordStores[storeType]
        local isEnchantable

        if recordStore == nil then
            tes3mp.LogMessage(enumerations.log.WARN, 'Rejected RecordDynamic for invalid record store of type ' ..
                recordNumericalType)
            return
        else
            isEnchantable = tableHelper.containsValue(config.enchantableRecordTypes, storeType)
        end

        local eventStatus = CustomEventHooks.triggerValidators('OnRecordDynamic', { pid, recordArray, storeType })

        if eventStatus.validDefaultHandler then
            for _, record in ipairs(recordArray) do
                local recordId

                -- Is there already a record exactly like this one, icon and model aside?
                -- If so, we'll just reuse it the way OpenMW would
                if storeType == 'potion' then
                    recordId = recordStore:GetMatchingRecordId(record, recordStore.data.generatedRecords,
                        Players[pid].data.recordLinks[storeType], { 'icon', 'model', 'quantity' }, true, 25)
                end

                if recordId == nil then
                    recordId = recordStore:GenerateRecordId()
                end

                if storeType == 'enchantment' then
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
            if storeType == 'spell' then
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
            elseif storeType == 'potion' or isEnchantable then
                local enchantmentStore

                if isEnchantable then enchantmentStore = RecordStores['enchantment'] end

                local itemArray = {}

                for recordId, record in pairs(recordTable) do
                    local item = {
                        refId = recordId,
                        count = record.quantity,
                        charge = -1,
                        enchantmentCharge = -1,
                        soul =
                        ''
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
        CustomEventHooks.triggerHandlers('OnRecordDynamic', eventStatus, { pid, recordTable, storeType })
    end
end

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
