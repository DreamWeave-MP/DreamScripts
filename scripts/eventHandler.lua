local clientVariableScopes = require 'tes3mp.clientVariableScopes'
local color = require 'color'
local config = require 'tes3mp.config'
local enumerations = require 'tes3mp.enumerations'
local inventoryHelper = require 'tes3mp.util.inventory'
local logicHandler = require 'tes3mp.logicHandler'
local packetReader = require 'tes3mp.packet.reader'
local tableHelper = require 'tes3mp.util.table'

---@class EventHandler
local eventHandler = {}

local consoleKickMessage = " has been kicked for using the console despite not having the permission to do so.\n"

eventHandler.OnPlayerDisconnect = function(pid)
    local message = logicHandler.GetChatName(pid) .. " has left the server.\n"
    tes3mp.SendMessage(pid, message, true)

    -- If this player has disconnected before properly logging in, remove their pid
    -- from the table tracking IP addresses
    if tes3mp.GetIP(pid) == "UNASSIGNED_SYSTEM_ADDRESS" then
        for _, pids in pairs(pidsByIpAddress) do
            if tableHelper.containsValue(pids, pid) then
                tableHelper.removeValue(pids, pid)
            end
        end
    end

    if Players[pid] ~= nil then
        if Players[pid]:IsLoggedIn() then
            local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerDisconnect", { pid })

            if eventStatus.validDefaultHandler then
                local ipAddress = Players[pid].ipAddress

                if pidsByIpAddress[ipAddress] ~= nil and tableHelper.containsValue(pidsByIpAddress[ipAddress], pid) then
                    tableHelper.removeValue(pidsByIpAddress[ipAddress], pid)
                end

                Players[pid].data.timestamps.lastDisconnect = os.time()
                Players[pid].data.timestamps.lastSessionDuration = os.time() - Players[pid].data.timestamps.lastLogin

                -- Adjust the time left for this player's active spells
                Players[pid]:UpdateActiveSpellTimes()

                Players[pid]:DeleteSummons()

                -- Was this player confiscating from someone? If so, clear that
                if Players[pid].confiscationTargetName ~= nil then
                    local targetName = Players[pid].confiscationTargetName
                    local targetPlayer = logicHandler.GetPlayerByName(targetName)
                    targetPlayer:SetConfiscationState(false)
                end

                Players[pid]:SaveCell(packetReader.GetPlayerPacketTables(pid, "PlayerCellChange"))
                Players[pid]:SaveStatsDynamic(packetReader.GetPlayerPacketTables(pid, "PlayerStatsDynamic"))
                tes3mp.LogMessage(enumerations.log.INFO, "Saving player " .. logicHandler.GetChatName(pid))
                Players[pid]:SaveToDrive()

                -- Unload every cell for this player
                for index, loadedCellDescription in pairs(Players[pid].cellsLoaded) do
                    local eventStatus = Deps.customEventHooks.triggerValidators("OnCellUnload",
                        { pid, loadedCellDescription })
                    if eventStatus.validDefaultHandler then
                        logicHandler.UnloadCellForPlayer(pid, loadedCellDescription)
                    end
                    Deps.customEventHooks.triggerHandlers("OnCellUnload", eventStatus, { pid, loadedCellDescription })
                end

                if Players[pid].data.location.regionName ~= nil then
                    logicHandler.UnloadRegionForPlayer(pid, Players[pid].data.location.regionName)
                end
            end

            Deps.customEventHooks.triggerHandlers("OnPlayerDisconnect", eventStatus, { pid })

            Players[pid]:Destroy()
            Players[pid] = nil
        end
    end

    -- If the server is now empty, quick saving of data isn't important anymore, so do a slower save of
    -- the world and record store data to human-readable JSON
    if not tableHelper.isEmpty(Players) then return end

    WorldInstance:SaveToDrive()

    for _, recordStore in pairs(RecordStores) do
        recordStore:DeleteUnlinkedRecords()
        recordStore:SaveToDrive()
    end
end

---@param pid PlayerId
---@param message string
function eventHandler.OnPlayerSendMessage(pid, message)
    assert(Deps)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    tes3mp.LogMessage(enumerations.log.INFO, logicHandler.GetChatName(pid) .. ": " .. message)

    local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerSendMessage", { pid, message })

    if eventStatus.validDefaultHandler then
        -- Is this a chat command? If so, pass it over to the commandHandler
        if message:sub(1, 1) ~= '/' then
            message = color.White .. logicHandler.GetChatName(pid) .. ": " .. message .. "\n"

            -- Check for chat overrides that add extra text
            if Players[pid]:IsServerStaff() then
                if Players[pid]:IsServerOwner() then
                    message = config.rankColors.serverOwner .. "[Owner] " .. message
                elseif Players[pid]:IsAdmin() then
                    message = config.rankColors.admin .. "[Admin] " .. message
                elseif Players[pid]:IsModerator() then
                    message = config.rankColors.moderator .. "[Mod] " .. message
                end
            end

            tes3mp.SendMessage(pid, message, true)
        end
    end

    Deps.customEventHooks.triggerHandlers("OnPlayerSendMessage", eventStatus, { pid, message })
end

eventHandler.OnPlayerEndCharGen = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerEndCharGen", { pid })
        if eventStatus.validDefaultHandler then
            Players[pid]:EndCharGen()
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerEndCharGen", eventStatus, { pid })
        Deps.customEventHooks.triggerHandlers("OnPlayerAuthentified", eventStatus, { pid })
    end
end

eventHandler.OnGenericPlayerEvent = function(pid, packetType)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local playerPacket = packetReader.GetPlayerPacketTables(pid, packetType)

        local eventStatus = Deps.customEventHooks.triggerValidators("On" .. packetType, { pid, playerPacket })
        if eventStatus.validDefaultHandler then
            Players[pid]:SaveDataByPacketType(packetType, playerPacket)
        end
        Deps.customEventHooks.triggerHandlers("On" .. packetType, eventStatus, { pid, playerPacket })
    end
end

eventHandler.OnPlayerAttribute = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerAttribute")
end

eventHandler.OnPlayerSkill = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerSkill")
end

eventHandler.OnPlayerLevel = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerLevel")
end

eventHandler.OnPlayerShapeshift = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerShapeshift")
end

eventHandler.OnPlayerEquipment = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerEquipment")
end

eventHandler.OnPlayerInventory = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerInventory")
end

eventHandler.OnPlayerSpellbook = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerSpellbook")
end

eventHandler.OnPlayerCooldowns = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerCooldowns")
end

eventHandler.OnPlayerQuickKeys = function(pid)
    eventHandler.OnGenericPlayerEvent(pid, "PlayerQuickKeys")
end

eventHandler.OnPlayerSpellsActive = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local playerPacket = packetReader.GetPlayerPacketTables(pid, "PlayerSpellsActive")

        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerSpellsActive", { pid, playerPacket })
        if eventStatus.validDefaultHandler then
            Players[pid]:SaveSpellsActive(playerPacket)

            -- Send this PlayerSpellsActive packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendSpellsActiveChanges(pid, true, true)
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerSpellsActive", eventStatus, { pid, playerPacket })
    end
end

eventHandler.OnPlayerCellChange = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local playerPacket = packetReader.GetPlayerPacketTables(pid, "PlayerCellChange")
        local currentCellDescription = playerPacket.location.cell

        if not tableHelper.containsValue(config.forbiddenCells, currentCellDescription) then
            local previousCellDescription = Players[pid].data.location.cell

            local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerCellChange",
                { pid, playerPacket, previousCellDescription })

            if eventStatus.validDefaultHandler then
                -- If this player is changing their region, add them to the visitors of the new
                -- region while removing them from the visitors of their old region
                if tes3mp.IsChangingRegion(pid) then
                    local regionName = string.lower(tes3mp.GetRegion(pid))

                    if regionName ~= "" then
                        local debugMessage = logicHandler.GetChatName(pid) .. " has "

                        local hasFinishedInitialTeleportation = Players[pid].hasFinishedInitialTeleportation
                        local previousCellIsStillLoaded = tableHelper.containsValue(Players[pid].cellsLoaded,
                            previousCellDescription)

                        -- It's possible we've been teleported to a cell we had already loaded when
                        -- spawning on the server, so also check whether this is the player's first
                        -- cell change since joining
                        local isTeleported = not previousCellIsStillLoaded or not hasFinishedInitialTeleportation

                        if isTeleported then
                            debugMessage = debugMessage .. "teleported"
                        else
                            debugMessage = debugMessage .. "walked"
                        end

                        debugMessage = debugMessage .. " to region " .. regionName .. "\n"
                        tes3mp.LogMessage(enumerations.log.INFO, debugMessage)

                        logicHandler.LoadRegionForPlayer(pid, regionName, isTeleported)
                    end

                    local previousRegionName = Players[pid].data.location.regionName

                    if previousRegionName ~= nil and previousRegionName ~= regionName then
                        logicHandler.UnloadRegionForPlayer(pid, previousRegionName)
                    end

                    Players[pid].data.location.regionName = regionName
                    Players[pid].hasFinishedInitialTeleportation = true
                end

                Players[pid]:SaveCell(packetReader.GetPlayerPacketTables(pid, "PlayerCellChange"))
                Players[pid]:SaveStatsDynamic(packetReader.GetPlayerPacketTables(pid, "PlayerStatsDynamic"))
                Players[pid]:QuicksaveToDrive()

                -- Exchange generated records with the other players who have this cell loaded
                if LoadedCells[currentCellDescription] ~= nil then
                    logicHandler.ExchangeGeneratedRecords(pid, LoadedCells[currentCellDescription].visitors)
                end

                if config.shareMapExploration == true then
                    WorldInstance:SaveMapExploration(pid)
                    WorldInstance:QuicksaveToDrive()
                end
            end

            Deps.customEventHooks.triggerHandlers("OnPlayerCellChange", eventStatus,
                { pid, playerPacket, previousCellDescription })
        else
            Players[pid].data.location.posX = tes3mp.GetPreviousCellPosX(pid)
            Players[pid].data.location.posY = tes3mp.GetPreviousCellPosY(pid)
            Players[pid].data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
            Players[pid]:LoadCell()
            tes3mp.MessageBox(pid, -1, "You are forbidden from entering that area.")
        end
    end
end

eventHandler.OnPlayerDeath = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerDeath", { pid })
        if eventStatus.validDefaultHandler then
            Players[pid]:ProcessDeath()
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerDeath", eventStatus, { pid })
    end
end

eventHandler.OnPlayerJournal = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local playerPacket = packetReader.GetPlayerPacketTables(pid, "PlayerJournal")

        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerJournal", { pid, playerPacket })
        if eventStatus.validDefaultHandler then
            if config.shareJournal == true then
                WorldInstance:SaveJournal(playerPacket)

                -- Send this PlayerJournal packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendJournalChanges(pid, true, true)
            else
                Players[pid]:SaveJournal(playerPacket)
            end
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerJournal", eventStatus, { pid, playerPacket })
    end
end

eventHandler.OnPlayerFaction = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local action = tes3mp.GetFactionChangesAction(pid)

        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerFaction", { pid, action })

        if eventStatus.validDefaultHandler then
            if action == enumerations.faction.RANK then
                if config.shareFactionRanks == true then
                    WorldInstance:SaveFactionRanks(pid)
                    -- Send this PlayerFaction packet to other players (sendToOthersPlayers is true),
                    -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                    tes3mp.SendFactionChanges(pid, true, true)
                else
                    Players[pid]:SaveFactionRanks()
                end
            elseif action == enumerations.faction.EXPULSION then
                if config.shareFactionExpulsion == true then
                    WorldInstance:SaveFactionExpulsion(pid)
                    -- As above, send this to everyone other than the original sender
                    tes3mp.SendFactionChanges(pid, true, true)
                else
                    Players[pid]:SaveFactionExpulsion()
                end
            elseif action == enumerations.faction.REPUTATION then
                if config.shareFactionReputation == true then
                    WorldInstance:SaveFactionReputation(pid)

                    -- As above, send this to everyone other than the original sender
                    tes3mp.SendFactionChanges(pid, true, true)
                else
                    Players[pid]:SaveFactionReputation()
                end
            end
        end

        Deps.customEventHooks.triggerHandlers("OnPlayerFaction", eventStatus, { pid, action })
    end
end

eventHandler.OnPlayerTopic = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerTopic", { pid })

        if eventStatus.validDefaultHandler then
            if config.shareTopics == true then
                WorldInstance:SaveTopics(pid)
                -- Send this PlayerTopic packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendTopicChanges(pid, true, true)
            else
                Players[pid]:SaveTopics()
            end
        end

        Deps.customEventHooks.triggerHandlers("OnPlayerTopic", eventStatus, { pid })
    end
end

eventHandler.OnPlayerBounty = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerBounty", { pid })

        if eventStatus.validDefaultHandler then
            if config.shareBounty == true then
                WorldInstance:SaveBounty(pid)

                -- Bounty packets are special in that they are always sent
                -- to all players, but only affect their target player on
                -- any given client
                --
                -- To set the same bounty for each LocalPlayer, we need
                -- to separately set each player as the target and
                -- send the packet
                local bountyValue = tes3mp.GetBounty(pid)

                for playerIndex, player in pairs(Players) do
                    if player.pid ~= pid then
                        tes3mp.SetBounty(player.pid, bountyValue)
                        tes3mp.SendBounty(player.pid)
                    end
                end
            else
                Players[pid]:SaveBounty()
            end
        end

        Deps.customEventHooks.triggerHandlers("OnPlayerBounty", eventStatus, { pid })
    end
end

eventHandler.OnPlayerReputation = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerReputation", { pid })

        if eventStatus.validDefaultHandler then
            if config.shareReputation == true then
                WorldInstance:SaveReputation(pid)
                -- Send this PlayerReputation packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendReputation(pid, true, true)
            else
                Players[pid]:SaveReputation()
            end
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerReputation", eventStatus, { pid })
    end
end

eventHandler.OnPlayerBook = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerBook", { pid })
        if eventStatus.validDefaultHandler then
            Players[pid]:AddBooks()
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerBook", eventStatus, { pid })
    end
end

eventHandler.OnPlayerItemUse = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local itemRefId = tes3mp.GetUsedItemRefId(pid)
        local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerItemUse", { pid, itemRefId })

        if eventStatus.validDefaultHandler then
            tes3mp.LogMessage(enumerations.log.INFO,
                logicHandler.GetChatName(pid) .. " used inventory item " .. itemRefId)

            -- Unilateral use of items is disabled on clients, so we need to send
            -- this packet back to the player before they can use the item
            tes3mp.SendItemUse(pid)
        end
        Deps.customEventHooks.triggerHandlers("OnPlayerItemUse", eventStatus, { pid, itemRefId })
    end
end

eventHandler.OnPlayerMiscellaneous = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local changeType = tes3mp.GetMiscellaneousChangeType(pid)

        if changeType == enumerations.miscellaneous.MARK_LOCATION then
            local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerMarkLocation", { pid })
            if eventStatus.validDefaultHandler then
                Players[pid]:SaveMarkLocation()
            end
            Deps.customEventHooks.triggerHandlers("OnPlayerMarkLocation", eventStatus, { pid })
        elseif changeType == enumerations.miscellaneous.SELECTED_SPELL then
            local eventStatus = Deps.customEventHooks.triggerValidators("OnPlayerSelectedSpell", { pid })
            if eventStatus.validDefaultHandler then
                Players[pid]:SaveSelectedSpell()
            end
            Deps.customEventHooks.triggerHandlers("OnPlayerSelectedSpell", eventStatus, { pid })
        end
    end
end

eventHandler.OnCellLoad = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnCellLoad", { pid, cellDescription })
        if eventStatus.validDefaultHandler then
            logicHandler.LoadCellForPlayer(pid, cellDescription)
        end
        Deps.customEventHooks.triggerHandlers("OnCellLoad", eventStatus, { pid, cellDescription })
    else
        tes3mp.LogMessage(enumerations.log.WARN, "Undefined behavior: invalid player " .. pid ..
            " loaded cell " .. cellDescription)
    end
end

eventHandler.OnCellUnload = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local eventStatus = Deps.customEventHooks.triggerValidators("OnCellUnload", { pid, cellDescription })
        if eventStatus.validDefaultHandler then
            logicHandler.UnloadCellForPlayer(pid, cellDescription)
        end
        Deps.customEventHooks.triggerHandlers("OnCellUnload", eventStatus, { pid, cellDescription })
    end
end

eventHandler.OnCellDeletion = function(cellDescription)
    assert(Deps)
    local eventStatus = Deps.customEventHooks.triggerValidators("OnCellDeletion", { cellDescription })
    if eventStatus.validDefaultHandler then
        logicHandler.UnloadCell(cellDescription)
    end
    Deps.customEventHooks.triggerHandlers("OnCellDeletion", eventStatus, { cellDescription })
end

eventHandler.OnGenericActorEvent = function(pid, cellDescription, packetType)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            tes3mp.ReadReceivedActorList()
            local actors = packetReader.GetActorPacketTables(packetType).actors

            local eventStatus = Deps.customEventHooks.triggerValidators("On" .. packetType,
                { pid, cellDescription, actors })

            if eventStatus.validDefaultHandler then
                tes3mp.LogMessage(enumerations.log.INFO, "Saving " .. packetType ..
                    " from " .. logicHandler.GetChatName(pid) .. " about " .. cellDescription)

                LoadedCells[cellDescription]:SaveActorsByPacketType(packetType, actors)
            end
            Deps.customEventHooks.triggerHandlers("On" .. packetType, eventStatus,
                { pid, cellDescription, actors })
        else
            tes3mp.LogMessage(enumerations.log.WARN, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent " .. packetType .. " for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnActorList = function(pid, cellDescription)
    eventHandler.OnGenericActorEvent(pid, cellDescription, "ActorList")
end

eventHandler.OnActorEquipment = function(pid, cellDescription)
    eventHandler.OnGenericActorEvent(pid, cellDescription, "ActorEquipment")
end

eventHandler.OnActorSpellsActive = function(pid, cellDescription)
    eventHandler.OnGenericActorEvent(pid, cellDescription, "ActorSpellsActive")
end

eventHandler.OnActorAI = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            local eventStatus = Deps.customEventHooks.triggerValidators("OnActorAI", { pid, cellDescription })
            if eventStatus.validDefaultHandler then
                tes3mp.ReadReceivedActorList()
                tes3mp.CopyReceivedActorListToStore()

                -- Actor AI packages are currently enabled unilaterally on the client
                -- that has sent them, so we only need to send them to other players,
                -- and can skip the original sender
                -- i.e. sendToOtherVisitors is true and skipAttachedPlayer is true
                tes3mp.SendActorAI(true, true)
            end
            Deps.customEventHooks.triggerHandlers("OnActorAI", eventStatus, { pid, cellDescription })
        else
            tes3mp.LogMessage(enumerations.log.WARN, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorAI for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnActorDeath = function(pid, cellDescription)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            tes3mp.ReadReceivedActorList()
            local actors = packetReader.GetActorPacketTables("ActorDeath").actors

            local eventStatus = Deps.customEventHooks.triggerValidators("OnActorDeath", { pid, cellDescription, actors })

            if eventStatus.validDefaultHandler then
                tes3mp.LogMessage(enumerations.log.INFO, "Saving ActorDeath from " .. logicHandler.GetChatName(pid) ..
                    " about " .. cellDescription)

                for uniqueIndex, actor in pairs(actors) do
                    local deathReason = "committed suicide"
                    local debugMessage = "- " .. uniqueIndex .. ", deathReason: "

                    if actor.killer.pid ~= nil then
                        deathReason = "killed by player " .. logicHandler.GetChatName(actor.killer.pid)
                    elseif actor.killer.name ~= "" then
                        deathReason = "killed by actor " .. actor.killer.refId .. " " .. actor.killer.uniqueIndex
                    end

                    tes3mp.LogAppend(enumerations.log.INFO, debugMessage .. deathReason)
                end

                LoadedCells[cellDescription]:SaveActorsByPacketType("ActorDeath", actors)
            end
            Deps.customEventHooks.triggerHandlers("OnActorDeath", eventStatus, { pid, cellDescription, actors })
        else
            tes3mp.LogMessage(enumerations.log.WARN, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorDeath for unloaded " .. cellDescription)
        end
    end
end

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

eventHandler.OnClientScriptGlobal = function(pid)
    assert(Deps)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.ReadReceivedWorldstate()

        local variables = packetReader.GetClientScriptGlobalPacketTable()
        local eventStatus = Deps.customEventHooks.triggerValidators("OnClientScriptGlobal", { pid, variables })

        if eventStatus.validDefaultHandler then
            local shouldSync = false

            -- Iterate through the global IDs in the ClientScriptGlobal packet and only sync and save them
            -- when applicable
            for id, variable in pairs(variables) do
                local isKillSync, isQuestSync, isFactionRanksSync, isFactionExpulsionSync, isWorldwideSync =
                    false, false, false, false, false

                isKillSync = tableHelper.containsCaseInsensitiveString(clientVariableScopes.globals.kills, id)

                if not isKillSync then
                    isQuestSync = config.shareJournal == true and
                        tableHelper.containsCaseInsensitiveString(clientVariableScopes.globals.quest, id)
                end

                if not isQuestSync then
                    isFactionRanksSync = config.shareFactionRanks == true and
                        tableHelper.containsCaseInsensitiveString(clientVariableScopes.globals.factionRanks, id)
                end

                if not isFactionRanksSync then
                    isFactionExpulsionSync = config.shareFactionExpulsion == true and
                        tableHelper.containsCaseInsensitiveString(clientVariableScopes.globals.factionExpulsion, id)
                end

                if not isFactionExpulsionSync then
                    isWorldwideSync = tableHelper.containsCaseInsensitiveString(clientVariableScopes.globals.worldwide,
                        id)
                end

                if isKillSync or isQuestSync or isFactionRanksSync or isFactionExpulsionSync or isWorldwideSync then
                    WorldInstance:SaveClientScriptGlobal(variables)
                    shouldSync = true
                else
                    Players[pid]:SaveClientScriptGlobal(variables)
                end
            end

            if shouldSync then
                tes3mp.CopyReceivedWorldstateToStore()
                -- The client already has this global value on their client, so we
                -- only send it to other players
                -- i.e. sendToOtherPlayers is true and skipAttachedPlayer is true
                tes3mp.SendClientScriptGlobal(pid, true, true)
                tes3mp.LogMessage(enumerations.log.INFO, "Synchronized ClientScriptGlobal from " ..
                    logicHandler.GetChatName(pid) .. " about " .. tableHelper.concatenateTableIndices(variables, ", "))
            end
        end

        Deps.customEventHooks.triggerHandlers("OnClientScriptGlobal", eventStatus, { pid, variables })
    else
        tes3mp.Kick(pid)
    end
end

return eventHandler
