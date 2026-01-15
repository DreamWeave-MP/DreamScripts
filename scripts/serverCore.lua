local color = require 'color'
local config = require 'tes3mp.config'
local enumerations = require 'tes3mp.enumerations'
local dataTableBuilder = require 'dataTableBuilder'
local guiHelper = require 'tes3mp.util.gui'
local inventoryHelper = require 'tes3mp.util.inventory'
local jsonInterface = require 'jsonInterface'
local logicHandler = require 'tes3mp.logicHandler'
local miscUtil = require 'tes3mp.util.misc'
local packetBuilder = require 'tes3mp.packet.builder'
local packetReader = require 'tes3mp.packet.reader'
local tableHelper = require 'tes3mp.util.table'
local time = require 'time'

---@type DUtilModule
local dUtil = require 'dUtil.init'

require 'doc.tes3mpDocs'

--- Global string overrides load before any possibly-dependent modules
require 'dUtil.stringMeta'

---@global
Players = {}

---@global
LoadedCells = {}

---@global
RecordStores = {}

---@global
ObjectLoops = {}

---@global
WorldInstance = nil

---@global
Database = nil

---@global
Player = nil

---@global
Cell = nil

---@global
RecordStore = nil

---@global
World = nil

---@global
pidsByIpAddress = {}

---@global
---@type DataFileRequirements
ClientDataFiles = dUtil.loadRequiredDataFiles(false)

---@global
---@type integer?
HourCounter = nil

---@global
updateTimerId = nil

---@global
banList = {}

--- If the CustomEventHooks interface is loaded,
--- Then the OnServerInit event initializes this value
---@type CustomEventHooks?
local CustomEventHooks

local clientVariableScopes = require 'tes3mp.clientVariableScopes'
local consoleKickMessage = '%s has been kicked for using the console despite not having the permission to do so.\n'

if (config.databaseType ~= nil and config.databaseType ~= "json") and miscUtil.doesModuleExist("luasql." .. config.databaseType) then
    Database = require("database")
    Database:LoadDriver(config.databaseType)

    tes3mp.LogMessage(enumerations.log.INFO, "Using " .. Database.driver._VERSION .. " with " .. config.databaseType ..
        " driver")

    Database:Connect(config.databasePath)

    -- Make sure we enable foreign keys
    Database:Execute("PRAGMA foreign_keys = ON;")

    Database:CreatePlayerTables()
    Database:CreateWorldTables()

    Player = require("player.sql")
    Cell = require("cell.sql")
    RecordStore = require("recordstore.sql")
    World = require("world.sql")
else
    World = require("world.json")
    RecordStore = require("recordstore.json")
    Cell = require("cell.json")
    Player = require("player.json")
end

---@type DScriptLoader
local ScriptLoader = require 'dUtil.scriptLoader'

---@param pid PlayerId
---@param packetType string
---@param cellDescription CellDescription
local function logUndefinedBehavior(pid, packetType, cellDescription)
    tes3mp.LogMessage(
        enumerations.log.WARN,
        ('Undefined behavior: %s sent %s for unloaded %s')
        :format(logicHandler.getChatName(pid), packetType, cellDescription)
    )
end

---@param eventName string
---@param cellDescription CellDescription
local function logCellEvent(eventName, cellDescription)
    tes3mp.LogMessage(
        enumerations.log.INFO,
        ('Called "%s" for cell %s'):format(eventName, logicHandler.GetChatName(pid))
    )
end

---@param eventName string
---@param pid PlayerId
---@param cellDescription CellDescription
local function logPlayerCellEvent(eventName, pid, cellDescription)
    tes3mp.LogMessage(
        enumerations.log.INFO,
        ('Called "%s" for %s and cell %s'):format(eventName, logicHandler.GetChatName(pid), cellDescription)
    )
end

---@param eventName string
---@param pid PlayerId
local function logPlayerEvent(eventName, pid)
    tes3mp.LogMessage(
        enumerations.log.INFO,
        ('Called "%s" for %s'):format(eventName, logicHandler.GetChatName(pid))
    )
end

---@param pid PlayerId
---@param cellDescription CellDescription
---@param packetType string
local function onGenericObjectEvent(pid, cellDescription, packetType)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return tes3mp.Kick(pid) end

    tes3mp.ReadReceivedObjectList()
    local packetOrigin = tes3mp.GetObjectListOrigin()
    local clientScript
    tes3mp.LogAppend(
        enumerations.log.INFO,
        ('- packetOrigin was %s')
        :format(tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))
    )

    if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) then
        tes3mp.Kick(pid)
        return tes3mp.SendMessage(pid, consoleKickMessage:format(logicHandler.GetChatName(pid)), true)
    elseif logicHandler.IsPacketFromClientScript(packetOrigin) then
        clientScript = tes3mp.GetObjectListClientScript()
        tes3mp.LogAppend(enumerations.log.INFO, ('- clientScript was %s'):format(clientScript))
    end

    local cell = LoadedCells[cellDescription]

    if not cell and logicHandler.DoesPacketOriginRequireLoadedCell(packetOrigin) then
        return tes3mp.LogMessage(
            enumerations.log.WARN,
            ('Invalid %s%s used impossible packetOrigin for unloaded %s')
            :format(packetType, logicHandler.GetChatName(pid), cellDescription)
        )
    end

    local packetTables = packetReader.GetObjectPacketTables(packetType)
    local objects = packetTables.objects
    local targetPlayers = packetTables.players

    if tableHelper.isEmpty(objects) or tableHelper.isEmpty(targetPlayers) then return end

    if not cell then
        logicHandler.LoadCell(cellDescription)
    end

    local eventName, eventStatus = ('On%s'):format(packetType)
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            eventName,
            { pid, cellDescription, objects, targetPlayers }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        local debugMessage = ('Accepted %s from %s about %s for ')
            :format(packetType, logicHandler.GetChatName(pid), cellDescription)

        if next(objects) ~= nil then
            debugMessage = debugMessage .. 'objects: '
            local includeComma = false

            for uniqueIndex, object in pairs(objects) do
                if includeComma then
                    debugMessage = ('%s, %s %s'):format(debugMessage, object.refId, uniqueIndex)
                else
                    debugMessage = ('%s%s %s'):format(debugMessage, object.refId, uniqueIndex)
                end

                includeComma = true
            end
        end

        if next(targetPlayers) ~= nil then
            local chatNames = logicHandler.GetChatNames(tableHelper.getArrayFromIndices(targetPlayers))
            debugMessage = ('%splayers: %s')
                :format(debugMessage, tableHelper.concatenateArrayValues(chatNames, 1, ', '))
        end

        tes3mp.LogMessage(enumerations.log.INFO, debugMessage)

        local loadedCell = LoadedCells[cellDescription]
        loadedCell:SaveObjectsByPacketType(packetType, objects)
        loadedCell:LoadObjectsByPacketType(packetType, pid, objects, tableHelper.getArrayFromIndices(objects), true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            eventName,
            eventStatus,
            { pid, cellDescription, objects, targetPlayers }
        )
    end

    if not cell then
        logicHandler.UnloadCell(cellDescription)
    end
end

---@param pid PlayerId
---@param packetType string
local function onGenericPlayerEvent(pid, packetType)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end
    local player = Players[targetPid]

    local playerPacket = packetReader.GetPlayerPacketTables(pid, packetType)

    if not CustomEventHooks then
        return player:SaveDataByPacketType(packetType, playerPacket)
    end

    local eventName, eventStatus = ('On'):format(packetType)
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(eventName, { pid, playerPacket })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        player:SaveDataByPacketType(packetType, playerPacket)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(eventName,
            eventStatus,
            { pid, playerPacket }
        )
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
---@param packetType string Make this an enum later!!!!!
local function onGenericActorEvent(pid, cellDescription, packetType)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then
        return tes3mp.Kick(pid)
    end

    local cell = LoadedCells[cellDescription]

    if not cell then
        return logUndefinedBehavior(pid, packetType, cellDescription)
    end

    tes3mp.ReadReceivedActorList()
    local actors = packetReader.GetActorPacketTables(packetType).actors

    local eventName, eventStatus = ('On'):format(packetType)
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            eventName,
            { pid, cellDescription, actors }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.LogMessage(
            enumerations.log.INFO,
            ('Saving %s from %s about %s')
            :format(packetType, logicHandler.getChatName(pid), cellDescription)
        )

        cell:SaveActorsByPacketType(packetType, actors)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            eventName,
            eventStatus,
            { pid, cellDescription, actors }
        )
    end
end

function LoadBanList()
    tes3mp.LogMessage(enumerations.log.INFO, "Reading banlist.json")
    banList = jsonInterface.load("banlist.json")

    if banList.playerNames == nil then
        banList.playerNames = {}
    elseif banList.ipAddresses == nil then
        banList.ipAddresses = {}
    end

    if #banList.ipAddresses > 0 then
        local message = "- Banning manually-added IP addresses:\n"

        for index, ipAddress in pairs(banList.ipAddresses) do
            message = message .. ipAddress

            if index < #banList.ipAddresses then
                message = message .. ", "
            end

            tes3mp.BanAddress(ipAddress)
        end

        tes3mp.LogAppend(enumerations.log.WARN, message)
    end

    if #banList.playerNames > 0 then
        local message = "- Banning all IP addresses stored for players:\n"

        for index, targetName in pairs(banList.playerNames) do
            message = message .. targetName

            if index < #banList.playerNames then
                message = message .. ", "
            end

            local targetPlayer = logicHandler.GetPlayerByName(targetName)

            if targetPlayer ~= nil then
                for index, ipAddress in pairs(targetPlayer.data.ipAddresses) do
                    tes3mp.BanAddress(ipAddress)
                end
            end
        end

        tes3mp.LogAppend(enumerations.log.WARN, message)
    end
end

function SaveBanList()
    jsonInterface.save("banlist.json", banList)
end

do
    local previousHourFloor = nil

    function UpdateTime()
        if config.passTimeWhenEmpty or tableHelper.getCount(Players) > 0 then
            HourCounter = HourCounter + (0.0083 * WorldInstance.frametimeMultiplier)

            local hourFloor = math.floor(HourCounter)

            if previousHourFloor == nil then
                previousHourFloor = hourFloor
            elseif hourFloor > previousHourFloor then
                if hourFloor >= 24 then
                    HourCounter = HourCounter - hourFloor
                    hourFloor = 0

                    tes3mp.LogMessage(enumerations.log.INFO, "The world time day has been incremented")
                    WorldInstance:IncrementDay()
                end

                tes3mp.LogMessage(enumerations.log.INFO, "The world time hour is now " .. hourFloor)
                WorldInstance.data.time.hour = HourCounter

                WorldInstance:UpdateFrametimeMultiplier()

                if tableHelper.getCount(Players) > 0 then
                    WorldInstance:LoadTime(tableHelper.getAnyValue(Players).pid, true)
                end

                previousHourFloor = hourFloor
            end
        end

        tes3mp.RestartTimer(updateTimerId, time.seconds(1))
    end
end

function OnServerInit()
    tes3mp.LogMessage(enumerations.log.INFO, 'Called "OnServerInit"')

    local expectedVersionPrefix = '0.8.1'
    local serverVersion = tes3mp.GetServerVersion()

    if serverVersion:sub(1, string.len(expectedVersionPrefix)) ~= expectedVersionPrefix then
        tes3mp.LogAppend(
            enumerations.log.ERROR,
            ([[- Version mismatch between server and Core scripts!
- The Core scripts require a server version that starts with %s]])
            :format(expectedVersionPrefix)
        )
        tes3mp.StopServer(1)
    end

    WorldInstance = World()

    ScriptLoader.loadAllScripts()
    print(ScriptLoader.Interfaces)
    if ScriptLoader.Interfaces.customEventHooks then
        CustomEventHooks = ScriptLoader.Interfaces.customEventHooks
    end

    -- If the world has a data entry, load it
    if WorldInstance:HasEntry() then
        WorldInstance:LoadFromDrive()
        WorldInstance:EnsureCoreVariablesExist()
        WorldInstance:EnsureTimeDataExists()

        -- Get the current mpNum from the loaded world
        tes3mp.SetCurrentMpNum(WorldInstance:GetCurrentMpNum())

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers(
                'OnWorldReload',
                dUtil.misc.makeEventStatus(),
                {}
            )
        end

        -- Otherwise, create a data file for it
    else
        WorldInstance:CreateEntry()
    end

    for _, recordStoreTypes in ipairs(config.recordStoreLoadOrder) do
        for _, storeType in ipairs(recordStoreTypes) do
            logicHandler.LoadRecordStore(storeType)
        end
    end

    HourCounter = WorldInstance.data.time.hour
    WorldInstance:UpdateFrametimeMultiplier()

    updateTimerId = tes3mp.CreateTimer("UpdateTime", time.seconds(1))
    tes3mp.StartTimer(updateTimerId)

    logicHandler.PushPlayerList(Players)

    LoadBanList()

    tes3mp.SetDataFileEnforcementState(config.enforceDataFiles)
    tes3mp.SetScriptErrorIgnoringState(config.ignoreScriptErrors)
end

function OnServerPostInit()
    tes3mp.LogMessage(enumerations.log.INFO, 'Called "OnServerPostInit"')

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnServerPostInit', {})
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.SetGameMode(config.gameMode)

        local consoleRuleString = 'allowed'
        if not config.allowConsole then
            consoleRuleString = 'not ' .. consoleRuleString
        end

        local bedRestRuleString = 'allowed'
        if not config.allowBedRest then
            bedRestRuleString = 'not ' .. bedRestRuleString
        end

        local wildRestRuleString = 'allowed'
        if not config.allowWildernessRest then
            wildRestRuleString = 'not ' .. wildRestRuleString
        end

        local waitRuleString = 'allowed'
        if not config.allowWait then
            waitRuleString = 'not ' .. waitRuleString
        end

        tes3mp.SetRuleString('enforceDataFiles', tostring(config.enforceDataFiles))
        tes3mp.SetRuleString('ignoreScriptErrors', tostring(config.ignoreScriptErrors))
        tes3mp.SetRuleValue('difficulty', config.difficulty)
        tes3mp.SetRuleValue('deathPenaltyJailDays', config.deathPenaltyJailDays)
        tes3mp.SetRuleString('console', consoleRuleString)
        tes3mp.SetRuleString('bedResting', bedRestRuleString)
        tes3mp.SetRuleString('wildernessResting', wildRestRuleString)
        tes3mp.SetRuleString('waiting', waitRuleString)
        tes3mp.SetRuleValue('enforcedLogLevel', config.enforcedLogLevel)
        tes3mp.SetRuleValue('physicsFramerate', config.physicsFramerate)
        tes3mp.SetRuleString('shareJournal', tostring(config.shareJournal))
        tes3mp.SetRuleString('shareFactionRanks', tostring(config.shareFactionRanks))
        tes3mp.SetRuleString('shareFactionExpulsion', tostring(config.shareFactionExpulsion))
        tes3mp.SetRuleString('shareFactionReputation', tostring(config.shareFactionReputation))
        tes3mp.SetRuleString('shareTopics', tostring(config.shareTopics))
        tes3mp.SetRuleString('shareBounty', tostring(config.shareBounty))
        tes3mp.SetRuleString('shareReputation', tostring(config.shareReputation))
        tes3mp.SetRuleString('shareMapExploration', tostring(config.shareMapExploration))
        tes3mp.SetRuleString('enablePlacedObjectCollision', tostring(config.enablePlacedObjectCollision))

        local respawnCell

        if config.respawnAtImperialShrine == true then
            respawnCell = 'nearest Imperial shrine'

            if config.respawnAtTribunalTemple == true then
                respawnCell = respawnCell .. ' or Tribunal temple'
            end
        elseif config.respawnAtTribunalTemple == true then
            respawnCell = 'nearest Tribunal temple'
        else
            respawnCell = config.defaultRespawn.cellDescription
        end

        tes3mp.SetRuleString('respawnCell', respawnCell)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnServerPostInit', eventStatus, {})
    end
end

function OnServerExit(errorState)
    tes3mp.LogMessage(enumerations.log.INFO, 'Called "OnServerExit"')
    tes3mp.LogMessage(enumerations.log.ERROR, 'Error state: ' .. tostring(errorState))

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnServerExit',
            dUtil.misc.makeEventStatus(),
            { errorState }
        )
    end
end

function OnServerScriptCrash(errorMessage)
    tes3mp.LogMessage(enumerations.log.ERROR, 'Server crash from script error!')

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnServerExit',
            dUtil.misc.makeEventStatus(),
            { errorMessage }
        )
    end

    -- tes3mp.StopServer(7)
end

function OnRequestDataFileList()
    dUtil.loadRequiredDataFiles(true)
end

-- Older server builds will call an "OnRequestPluginList" event instead of
-- "OnRequestDataFileList", so keep this around for backwards compatibility
function OnRequestPluginList()
    OnRequestDataFileList()
end

function OnPlayerConnect(pid)
    tes3mp.LogMessage(enumerations.log.INFO, ('Called "OnPlayerConnect" for pid %d'):format(pid))

    local playerName = tes3mp.GetName(pid)

    if string.len(playerName) > 35 then
        playerName = string.sub(playerName, 0, 35)
    end

    if not logicHandler.IsNameAllowed(playerName) then
        tes3mp.SendMessage(
            pid,
            ('%s (%s) joined and tried to use a disallowed name.\n')
            :format(playerName, pid),
            true
        )
        tes3mp.Kick(pid)
        return
    end

    if logicHandler.IsPlayerNameLoggedIn(playerName) then
        tes3mp.SendMessage(
            pid,
            ('%s (%s) joined and tried to use an existing player\'s name.\n')
            :format(playerName, pid),
            true
        )
        tes3mp.Kick(pid)
        return
    end

    tes3mp.LogAppend(
        enumerations.log.INFO,
        ('- New player is named %s'):format(playerName)
    )

    Players[pid] = Player(pid, playerName)
    local player = Players[pid]
    player.name = playerName

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerConnect', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        -- Send instanced spawn cell record now so it has time to arrive
        if config.useInstancedSpawn and config.instancedSpawn then
            local spawnUsed = tableHelper.shallowCopy(config.instancedSpawn)
            local originalCellDescription = spawnUsed.cellDescription
            spawnUsed.cellDescription = ('%s - Instance for %s'):format(originalCellDescription, playerName)

            tes3mp.ClearRecords()
            tes3mp.SetRecordType(enumerations.recordType.CELL)
            packetBuilder.AddCellRecord(spawnUsed.cellDescription, { baseId = originalCellDescription })
            tes3mp.SendRecordDynamic(pid, false, false)
        end

        -- Load high priority permanent records
        for _, storeType in ipairs(config.recordStoreLoadOrder[1]) do
            local recordStore = RecordStores[storeType]

            -- Load all the permanent records in this record store
            recordStore:LoadRecords(pid, recordStore.data.permanentRecords,
                tableHelper.getArrayFromIndices(recordStore.data.permanentRecords))
        end

        tes3mp.SetDifficulty(pid, config.difficulty)
        tes3mp.SetConsoleAllowed(pid, config.allowConsole)
        tes3mp.SetBedRestAllowed(pid, config.allowBedRest)
        tes3mp.SetWildernessRestAllowed(pid, config.allowWildernessRest)
        tes3mp.SetWaitAllowed(pid, config.allowWait)
        tes3mp.SetPhysicsFramerate(pid, config.physicsFramerate)
        tes3mp.SetEnforcedLogLevel(pid, config.enforcedLogLevel)
        tes3mp.SendSettings(pid)

        logicHandler.SendClientScriptDisables(pid, false)
        logicHandler.SendClientScriptSettings(pid, false)

        tes3mp.SetPlayerCollisionState(config.enablePlayerCollision)
        tes3mp.SetActorCollisionState(config.enableActorCollision)
        tes3mp.SetPlacedObjectCollisionState(config.enablePlacedObjectCollision)
        tes3mp.UseActorCollisionForPlacedObjects(config.useActorCollisionForPlacedObjects)

        logicHandler.SendConfigCollisionOverrides(pid, false)

        WorldInstance:LoadTime(pid, false)

        local chatName = logicHandler.GetChatName(pid)
        local message = ('%s has joined the server'):format(chatName)

        local ipAddress = tes3mp.GetIP(pid)
        Players[pid].ipAddress = ipAddress

        if not pidsByIpAddress[ipAddress] then pidsByIpAddress[ipAddress] = {} end

        if not tableHelper.isEmpty(pidsByIpAddress[ipAddress]) then
            local otherPlayerNames = {}

            for _, otherPid in pairs(pidsByIpAddress[ipAddress]) do
                table.insert(otherPlayerNames, logicHandler.GetChatName(otherPid))
            end

            message = ('%s, from the same IP address as %s'):format(
                message,
                tableHelper.concatenateArrayValues(otherPlayerNames, 1, ', ')
            )
        end

        message = message .. '.\n'
        tes3mp.SendMessage(pid, message, true)

        if tableHelper.getCount(pidsByIpAddress[ipAddress]) + 1 > config.maxClientsPerIP then
            tes3mp.SendMessage(
                pid,
                ('%s has been kicked because this server allows a maximum of %s clients from the same IP address.\n')
                :format(chatName, config.maxClientsPerIP),
                true
            )
            tes3mp.Kick(pid)
            Players[pid] = nil
            return
        else
            table.insert(pidsByIpAddress[ipAddress], pid)
        end

        message = ('Welcome %s\nYou have %s seconds to '):format(playerName, config.loginTime)

        if player:HasAccount() then
            message = message .. 'log in.\n'
            guiHelper.ShowLogin(pid)
        else
            message = message .. 'register.\n'
            guiHelper.ShowRegister(pid)
        end

        tes3mp.SendMessage(pid, message, false)

        player.loginTimerId = tes3mp.CreateTimerEx(
            'OnLoginTimeExpiration',
            time.seconds(config.loginTime),
            'is',
            pid,
            Players[pid].accountName
        )

        tes3mp.StartTimer(Players[pid].loginTimerId)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerConnect', eventStatus, { pid })
    end
end

function OnPlayerDisconnect(pid)
    logPlayerEvent('OnPlayerDisconnect', pid)

    tes3mp.SendMessage(
        pid,
        ('%s has left the server.\n'):format(logicHandler.GetChatName(pid)),
        true
    )

    -- If this player has disconnected before properly logging in, remove their pid
    -- from the table tracking IP addresses
    if tes3mp.GetIP(pid) == 'UNASSIGNED_SYSTEM_ADDRESS' then
        for _, pids in pairs(pidsByIpAddress) do
            if tableHelper.containsValue(pids, pid) then
                tableHelper.removeValue(pids, pid)
            end
        end
    end

    local player = Players[pid]
    if player and player:IsLoggedIn() then
        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators('OnPlayerDisconnect', { pid })
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            local ipAddress = player.ipAddress

            if pidsByIpAddress[ipAddress] and tableHelper.containsValue(pidsByIpAddress[ipAddress], pid) then
                tableHelper.removeValue(pidsByIpAddress[ipAddress], pid)
            end

            player.data.timestamps.lastDisconnect = os.time()
            player.data.timestamps.lastSessionDuration = os.time() - player.data.timestamps.lastLogin

            -- Adjust the time left for this player's active spells
            player:UpdateActiveSpellTimes()

            player:DeleteSummons()

            -- Was this player confiscating from someone? If so, clear that
            if player.confiscationTargetName then
                local targetName = player.confiscationTargetName
                local targetPlayer = logicHandler.GetPlayerByName(targetName)
                targetPlayer:SetConfiscationState(false)
            end

            player:SaveCell(packetReader.GetPlayerPacketTables(pid, 'PlayerCellChange'))
            player:SaveStatsDynamic(packetReader.GetPlayerPacketTables(pid, 'PlayerStatsDynamic'))
            tes3mp.LogMessage(enumerations.log.INFO, 'Saving player ' .. logicHandler.GetChatName(pid))
            player:SaveToDrive()

            -- Unload every cell for this player
            for _, loadedCellDescription in pairs(player.cellsLoaded) do
                if CustomEventHooks then
                    local cellUnloadStatus = CustomEventHooks.triggerValidators(
                        'OnCellUnload',
                        { pid, loadedCellDescription }
                    )

                    if cellUnloadStatus.validDefaultHandler then
                        logicHandler.UnloadCellForPlayer(pid, loadedCellDescription)
                    end

                    CustomEventHooks.triggerHandlers(
                        'OnCellUnload',
                        cellUnloadStatus,
                        { pid, loadedCellDescription }
                    )
                else
                    logicHandler.UnloadCellForPlayer(pid, loadedCellDescription)
                end
            end

            if player.data.location.regionName ~= nil then
                logicHandler.UnloadRegionForPlayer(pid, player.data.location.regionName)
            end
        end

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers('OnPlayerDisconnect', eventStatus, { pid })
        end

        player:Destroy()
        player = nil
    end

    -- If the server is now empty, quick saving of data isn't important anymore, so do a slower save of
    -- the world and record store data to human-readable JSON
    if next(Players) ~= nil then return end

    WorldInstance:SaveToDrive()

    for _, recordStore in pairs(RecordStores) do
        recordStore:DeleteUnlinkedRecords()
        recordStore:SaveToDrive()
    end
end

function OnPlayerResurrect(pid)
    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnPlayerResurrect',
            dUtil.misc.makeEventStatus(),
            { pid }
        )
    end
end

---@param pid PlayerId
---@param message string
function OnPlayerSendMessage(pid, message)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local logMessage = ('%s: %s'):format(logicHandler.GetChatName(pid), message)
    tes3mp.LogMessage(enumerations.log.INFO, logMessage)

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerSendMessage', { pid, message })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler and message:sub(1, 1) ~= '/' then
        local chatMessage = ('%s%s\n'):format(color.White, logMessage)
        local isModerator, isAdmin, isOwner = dUtil.misc.getRanks(targetPid)

        -- Check for chat overrides that add extra text
        if isOwner then
            chatMessage = ('%s[Owner] %s'):format(config.rankColors.serverOwner, chatMessage)
        elseif isAdmin then
            chatMessage = ('%s[Admin] %s'):format(config.rankColors.admin, chatMessage)
        elseif isModerator then
            chatMessage = ('%s[Mod] %s'):format(config.rankColors.moderator, chatMessage)
        end

        tes3mp.SendMessage(targetPid, chatMessage, true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerSendMessage', eventStatus, { pid, message })
    end
end

---@param pid PlayerId
function OnPlayerDeath(pid)
    logPlayerEvent('OnPlayerDeath', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators("OnPlayerDeath", { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        Players[pid]:ProcessDeath()
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerDeath', eventStatus, { pid })
    end
end

---@param pid PlayerId
function OnPlayerAttribute(pid)
    logPlayerEvent('OnPlayerAttribute', pid)
    onGenericPlayerEvent(pid, 'PlayerAttribute')
end

---@param pid PlayerId
function OnPlayerSkill(pid)
    logPlayerEvent('OnPlayerSkill', pid)
    onGenericPlayerEvent(pid, 'PlayerSkill')
end

---@param pid PlayerId
function OnPlayerLevel(pid)
    logPlayerEvent('OnPlayerLevel', pid)
    onGenericPlayerEvent(pid, 'PlayerLevel')
end

---@param pid PlayerId
function OnPlayerShapeshift(pid)
    logPlayerEvent('OnPlayerShapeshift', pid)
    onGenericPlayerEvent(pid, "PlayerShapeshift")
end

---@param pid PlayerId
function OnPlayerEquipment(pid)
    logPlayerEvent('OnPlayerEquipment', pid)
    onGenericPlayerEvent(pid, "PlayerEquipment")
end

---@param pid PlayerId
function OnPlayerInventory(pid)
    logPlayerEvent('OnPlayerInventory', pid)
    onGenericPlayerEvent(pid, "PlayerInventory")
end

---@param pid PlayerId
function OnPlayerSpellbook(pid)
    logPlayerEvent('OnPlayerSpellbook', pid)
    onGenericPlayerEvent(pid, "PlayerSpellbook")
end

---@param pid PlayerId
function OnPlayerCooldowns(pid)
    logPlayerEvent('OnPlayerCooldowns', pid)
    onGenericPlayerEvent(pid, "PlayerCooldowns")
end

---@param pid PlayerId
function OnPlayerQuickKeys(pid)
    logPlayerEvent('OnPlayerQuickKeys', pid)
    onGenericPlayerEvent(pid, "PlayerQuickKeys")
end

---@param pid PlayerId
function OnPlayerCellChange(pid)
    logPlayerEvent('OnPlayerCellChange', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local playerPacket = packetReader.GetPlayerPacketTables(pid, 'PlayerCellChange')
    local currentCellDescription = playerPacket.location.cell
    local player = Players[targetPid]

    if tableHelper.containsValue(config.forbiddenCells, currentCellDescription) then
        player.data.location.posX = tes3mp.GetPreviousCellPosX(pid)
        player.data.location.posY = tes3mp.GetPreviousCellPosY(pid)
        player.data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
        player:LoadCell()
        tes3mp.MessageBox(pid, -1, 'You are forbidden from entering that area.')
    else
        local previousCellDescription = Players[pid].data.location.cell

        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators(
                'OnPlayerCellChange',
                { pid, playerPacket, previousCellDescription }
            )
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            -- If this player is changing their region, add them to the visitors of the new
            -- region while removing them from the visitors of their old region
            if tes3mp.IsChangingRegion(pid) then
                local regionName = tes3mp.GetRegion(pid):lower()

                if regionName ~= '' then
                    local debugMessage = ('%s has '):format(logicHandler.GetChatName(pid))

                    local hasFinishedInitialTeleportation = player.hasFinishedInitialTeleportation

                    local previousCellIsStillLoaded = tableHelper.containsValue(
                        player.cellsLoaded,
                        previousCellDescription
                    )

                    -- It's possible we've been teleported to a cell we had already loaded when
                    -- spawning on the server, so also check whether this is the player's first
                    -- cell change since joining
                    local isTeleported = not previousCellIsStillLoaded or not hasFinishedInitialTeleportation

                    local changeType
                    if isTeleported then
                        changeType = 'teleported'
                    else
                        changeType = 'walked'
                    end

                    debugMessage = ('%s%s'):format(debugMessage, changeType)

                    tes3mp.LogMessage(
                        enumerations.log.INFO,
                        ('%s to region %s\n'):format(debugMessage, regionName)
                    )

                    logicHandler.LoadRegionForPlayer(pid, regionName, isTeleported)
                end

                local previousRegionName = player.data.location.regionName

                if previousRegionName ~= nil and previousRegionName ~= regionName then
                    logicHandler.UnloadRegionForPlayer(pid, previousRegionName)
                end

                player.data.location.regionName = regionName
                player.hasFinishedInitialTeleportation = true
            end

            player:SaveCell(packetReader.GetPlayerPacketTables(pid, 'PlayerCellChange'))
            player:SaveStatsDynamic(packetReader.GetPlayerPacketTables(pid, 'PlayerStatsDynamic'))
            player:QuicksaveToDrive()

            -- Exchange generated records with the other players who have this cell loaded
            if LoadedCells[currentCellDescription] ~= nil then
                logicHandler.ExchangeGeneratedRecords(pid, LoadedCells[currentCellDescription].visitors)
            end

            if config.shareMapExploration == true then
                WorldInstance:SaveMapExploration(pid)
                WorldInstance:QuicksaveToDrive()
            end
        end

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers(
                'OnPlayerCellChange',
                eventStatus,
                { pid, playerPacket, previousCellDescription }
            )
        end
    end
end

---@param pid PlayerId
function OnPlayerSpellsActive(pid)
    logPlayerEvent('OnPlayerSpellsActive', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local playerPacket = packetReader.GetPlayerPacketTables(pid, 'PlayerSpellsActive')

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerSpellsActive', { pid, playerPacket })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        Players[targetPid]:SaveSpellsActive(playerPacket)

        -- Send this PlayerSpellsActive packet to other players (sendToOthersPlayers is true),
        -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
        tes3mp.SendSpellsActiveChanges(pid, true, true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerSpellsActive', eventStatus, { pid, playerPacket })
    end
end

---@param pid PlayerId
function OnPlayerJournal(pid)
    logPlayerEvent('OnPlayerJournal', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local playerPacket = packetReader.GetPlayerPacketTables(targetPid, 'PlayerJournal')

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerJournal', { targetPid, playerPacket })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        if config.shareJournal then
            WorldInstance:SaveJournal(playerPacket)

            -- Send this PlayerJournal packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendJournalChanges(targetPid, true, true)
        else
            Players[pid]:SaveJournal(playerPacket)
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerJournal', eventStatus, { targetPid, playerPacket })
    end
end

---@param pid PlayerId
function OnPlayerFaction(pid)
    logPlayerEvent('OnPlayerFaction', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local action = tes3mp.GetFactionChangesAction(targetPid)

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerFaction', { targetPid, action })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    local player = Players[targetPid]
    if eventStatus.validDefaultHandler then
        if action == enumerations.faction.RANK then
            if config.shareFactionRanks then
                WorldInstance:SaveFactionRanks(targetPid)
                -- Send this PlayerFaction packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendFactionChanges(targetPid, true, true)
            else
                player:SaveFactionRanks()
            end
        elseif action == enumerations.faction.EXPULSION then
            if config.shareFactionExpulsion then
                WorldInstance:SaveFactionExpulsion(targetPid)
                -- As above, send this to everyone other than the original sender
                tes3mp.SendFactionChanges(targetPid, true, true)
            else
                player:SaveFactionExpulsion()
            end
        elseif action == enumerations.faction.REPUTATION then
            if config.shareFactionReputation then
                WorldInstance:SaveFactionReputation(targetPid)

                -- As above, send this to everyone other than the original sender
                tes3mp.SendFactionChanges(targetPid, true, true)
            else
                player:SaveFactionReputation()
            end
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers("OnPlayerFaction", eventStatus, { targetPid, action })
    end
end

---@param pid PlayerId
function OnPlayerTopic(pid)
    logPlayerEvent('OnPlayerTopic', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerTopic', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        if config.shareTopics then
            WorldInstance:SaveTopics(targetPid)
            -- Send this PlayerTopic packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendTopicChanges(targetPid, true, true)
        else
            Players[targetPid]:SaveTopics()
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerTopic', eventStatus, { pid })
    end
end

---@param pid PlayerId
function OnPlayerBounty(pid)
    logPlayerEvent('OnPlayerBounty', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerBounty', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        if config.shareBounty then
            WorldInstance:SaveBounty(targetPid)

            -- Bounty packets are special in that they are always sent
            -- to all players, but only affect their target player on
            -- any given client
            --
            -- To set the same bounty for each LocalPlayer, we need
            -- to separately set each player as the target and
            -- send the packet
            local bountyValue = tes3mp.GetBounty(targetPid)

            for _, player in pairs(Players) do
                if player.pid ~= targetPid then
                    tes3mp.SetBounty(player.pid, bountyValue)
                    tes3mp.SendBounty(player.pid)
                end
            end
        else
            Players[targetPid]:SaveBounty()
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerBounty', eventStatus, { pid })
    end
end

---@param pid PlayerId
function OnPlayerReputation(pid)
    logPlayerEvent('OnPlayerReputation', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerReputation', { targetPid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        if config.shareReputation then
            WorldInstance:SaveReputation(targetPid)
            -- Send this PlayerReputation packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendReputation(targetPid, true, true)
        else
            Players[targetPid]:SaveReputation()
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerReputation', eventStatus, { targetPid })
    end
end

---@param pid PlayerId
function OnPlayerBook(pid)
    logPlayerEvent('OnPlayerBook', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerBook', { targetPid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        Players[targetPid]:AddBooks()
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerBook', eventStatus, { targetPid })
    end
end

---@param pid PlayerId
function OnPlayerItemUse(pid)
    logPlayerEvent('OnPlayerItemUse', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local itemRefId = tes3mp.GetUsedItemRefId(targetPid)
    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerItemUse', { targetPid, itemRefId })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.LogMessage(enumerations.log.INFO,
            ('%s used inventory item %s'):format(logicHandler.GetChatName(targetPid), itemRefId)
        )

        -- Unilateral use of items is disabled on clients, so we need to send
        -- this packet back to the player before they can use the item
        tes3mp.SendItemUse(targetPid)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnPlayerItemUse',
            eventStatus,
            { targetPid, itemRefId }
        )
    end
end

---@param pid PlayerId
function OnPlayerMiscellaneous(pid)
    logPlayerEvent('OnPlayerMiscellaneous', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local player = Players[targetPid]
    local changeType = tes3mp.GetMiscellaneousChangeType(targetPid)

    if changeType == enumerations.miscellaneous.MARK_LOCATION then
        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators("OnPlayerMarkLocation", { targetPid })
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            player:SaveMarkLocation()
        end

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers("OnPlayerMarkLocation", eventStatus, { targetPid })
        end
    elseif changeType == enumerations.miscellaneous.SELECTED_SPELL then
        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators("OnPlayerSelectedSpell", { targetPid })
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            player:SaveSelectedSpell()
        end

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers("OnPlayerSelectedSpell", eventStatus, { targetPid })
        end
    end
end

---@param pid PlayerId
function OnPlayerEndCharGen(pid)
    logPlayerEvent('OnPlayerEndCharGen', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local player = Players[targetPid]

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnPlayerEndCharGen', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        player:EndCharGen()
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnPlayerEndCharGen', eventStatus, { pid })
        CustomEventHooks.triggerHandlers('OnPlayerAuthentified', eventStatus, { pid })
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnCellLoad(pid, cellDescription)
    logPlayerCellEvent('OnCellLoad', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)

    if not isValid or not targetPid then
        return tes3mp.LogMessage(
            enumerations.log.WARN,
            ('Undefined behavior: invalid player %s loaded cell %s'):format(pid, cellDescription)
        )
    end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            'OnCellLoad',
            { pid, cellDescription }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        logicHandler.LoadCellForPlayer(pid, cellDescription)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnCellLoad', eventStatus, { pid, cellDescription })
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnCellUnload(pid, cellDescription)
    logPlayerCellEvent('OnCellUnload', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cellDescription)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnCellUnload', { pid, cellDescription })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        logicHandler.UnloadCellForPlayer(pid, cellDescription)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnCellUnload',
            eventStatus,
            { pid, cellDescription }
        )
    end
end

---@param cellDescription CellDescription
function OnCellDeletion(cellDescription)
    logCellEvent('OnCellDeletion', cellDescription)

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            "OnCellDeletion",
            { cellDescription }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        logicHandler.UnloadCell(cellDescription)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers("OnCellDeletion", eventStatus, { cellDescription })
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorList(pid, cellDescription)
    logPlayerCellEvent('OnActorList', pid, cellDescription)
    onGenericActorEvent(pid, cellDescription, 'ActorList')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorEquipment(pid, cellDescription)
    logPlayerCellEvent('OnActorEquipment', pid, cellDescription)
    onGenericActorEvent(pid, cellDescription, 'ActorEquipment')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorAI(pid, cellDescription)
    logPlayerCellEvent('OnActorAI', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return tes3mp.Kick(pid) end

    local cell = LoadedCells[cellDescription]
    if not cell then return logUndefinedBehavior(pid, 'ActorAI', cellDescription) end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnActorAI', { pid, cellDescription })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.ReadReceivedActorList()
        tes3mp.CopyReceivedActorListToStore()

        -- Actor AI packages are currently enabled unilaterally on the client
        -- that has sent them, so we only need to send them to other players,
        -- and can skip the original sender
        -- i.e. sendToOtherVisitors is true and skipAttachedPlayer is true
        tes3mp.SendActorAI(true, true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnActorAI',
            eventStatus,
            { pid, cellDescription }
        )
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorDeath(pid, cellDescription)
    logPlayerCellEvent('OnActorDeath', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local cell = LoadedCells[cellDescription]
    if not cell then
        return logUndefinedBehavior(pid, 'ActorDeath', cellDescription)
    end

    tes3mp.ReadReceivedActorList()
    local actors = packetReader.GetActorPacketTables('ActorDeath').actors

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnActorDeath', { pid, cellDescription, actors })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.LogMessage(
            enumerations.log.INFO,
            ('Saving ActorDeath from %s about %s')
            :format(logicHandler.GetChatName(pid), cellDescription)
        )

        for uniqueIndex, actor in pairs(actors) do
            local debugMessage

            if actor.killer.pid then
                debugMessage = ('- %s, deathReason: killed by player %s')
                    :format(uniqueIndex, logicHandler.GetChatName(actor.killer.pid))
            elseif actor.killer.name ~= '' then
                debugMessage = ('- %s, deathReason: killed by actor %s %s')
                    :format(uniqueIndex, actor.killer.refId, actor.killer.uniqueIndex)
            else
                debugMessage = ('- %s, deathReason: committed suicide'):format(uniqueIndex)
            end

            tes3mp.LogAppend(enumerations.log.INFO, debugMessage .. deathReason)
        end

        cell:SaveActorsByPacketType('ActorDeath', actors)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnActorDeath', eventStatus, { pid, cellDescription, actors })
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorSpellsActive(pid, cellDescription)
    logPlayerCellEvent('OnActorSpellsActive', pid, cellDescription)
    onGenericActorEvent(pid, cellDescription, 'ActorSpellsActive')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnActorCellChange(pid, cellDescription)
    logPlayerCellEvent('OnActorCellChange', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return tes3mp.Kick(pid) end

    local loadedCell = LoadedCells[cellDescription]

    if not loadedCell then
        logicHandler.LoadCell(cellDescription)
    end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators("OnActorCellChange", { pid, cellDescription })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        LoadedCells[cellDescription]:SaveActorCellChanges(pid)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers("OnActorCellChange", eventStatus, { pid, cellDescription })
    end

    if not loadedCell then
        logicHandler.UnloadCell(cellDescription)
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectActivate(pid, cellDescription)
    logPlayerCellEvent('OnObjectActivate', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectActivate')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectHit(pid, cellDescription)
    logPlayerCellEvent('OnObjectHit', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectHit')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectPlace(pid, cellDescription)
    logPlayerCellEvent('OnObjectPlace', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectPlace')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectSpawn(pid, cellDescription)
    logPlayerCellEvent('OnObjectSpawn', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectSpawn')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectDelete(pid, cellDescription)
    logPlayerCellEvent('OnObjectDelete', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectDelete')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectLock(pid, cellDescription)
    logPlayerCellEvent('OnObjectLock', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectLock')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectDialogueChoice(pid, cellDescription)
    logPlayerCellEvent('OnObjectDialogueChoice', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectDialogueChoice')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectMiscellaneous(pid, cellDescription)
    logPlayerCellEvent('OnObjectMiscellaneous', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectMiscellaneous')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectRestock(pid, cellDescription)
    logPlayerCellEvent('OnObjectRestock', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectRestock')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectTrap(pid, cellDescription)
    logPlayerCellEvent('OnObjectTrap', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectTrap')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectScale(pid, cellDescription)
    logPlayerCellEvent('OnObjectScale', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectScale')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectSound(pid, cellDescription)
    logPlayerCellEvent('OnObjectSound', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectSound')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnObjectState(pid, cellDescription)
    logPlayerCellEvent('OnObjectState', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'ObjectState')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnDoorState(pid, cellDescription)
    logPlayerCellEvent('OnDoorState', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, 'DoorState')
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnConsoleCommand(pid, cellDescription)
    logPlayerCellEvent('OnConsoleCommand', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return tes3mp.Kick(pid) end

    tes3mp.ReadReceivedObjectList()

    local packetTables = packetReader.GetObjectPacketTables('ConsoleCommand')
    local objects = packetTables.objects
    local targetPlayers = packetTables.players
    local consoleCommand = tes3mp.GetObjectListConsoleCommand()

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            'OnConsoleCommand',
            { pid, cellDescription, consoleCommand, objects, targetPlayers }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        local debugMessage =
            ([[Accepted ConsoleCommand from %s about %s
consoleCommand: %s]])
            :format(logicHandler.GetChatName(pid), cellDescription, consoleCommand)

        for uniqueIndex, object in pairs(objects) do
            debugMessage = ('%s\n- object target: %s %s'):format(debugMessage, object.refId, uniqueIndex)
        end

        for targetedPid, targetPlayer in pairs(targetPlayers) do
            debugMessage = ('%s\n- player target: %s'):format(debugMessage, logicHandler.GetChatName(targetedPid))
        end

        local isQueuedConsoleCommand = false

        local player = Players[targetPid]
        -- Clear this only once from the console commands queued for this player, if found in that table
        for arrayIndex, consoleCommandQueued in pairs(player.consoleCommandsQueued) do
            if consoleCommandQueued == consoleCommand then
                player.consoleCommandsQueued[arrayIndex] = nil
                isQueuedConsoleCommand = true
                debugMessage = ('%s\n- was a console command executed at the server\'s request'):format(debugMessage)
                break
            end
        end

        if not isQueuedConsoleCommand then
            debugMessage = ('%s\n- was a console command executed unilaterally from the client'):format(debugMessage)
        end

        tes3mp.LogMessage(enumerations.log.INFO, debugMessage)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnConsoleCommand',
            eventStatus,
            { pid, cellDescription, consoleCommand, objects, targetPlayers }
        )
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnContainer(pid, cellDescription)
    logPlayerCellEvent('OnContainer', pid, cellDescription)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return tes3mp.Kick(pid) end

    tes3mp.ReadReceivedObjectList()
    local packetOrigin = tes3mp.GetObjectListOrigin()

    tes3mp.LogAppend(
        enumerations.log.INFO,
        ('- packetOrigin was %s'):format(tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))
    )

    if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) then
        tes3mp.Kick(pid)
        return tes3mp.SendMessage(
            pid,
            consoleKickMessage:format(logicHandler.GetChatName(pid)),
            true
        )
    end

    local cell = LoadedCells[cellDescription]

    if not config.allowOnContainerForUnloadedCells and not cell and logicHandler.DoesPacketOriginRequireLoadedCell(packetOrigin) then
        tes3mp.LogMessage(
            enumerations.log.WARN,
            ('Invalid Container: %s used impossible packetOrigin for unloaded %s')
            :format(logicHandler.GetChatName(pid), cellDescription)
        )
        return
    end

    -- Iterate through the objects in the Container packet and only sync and save the
    -- ones whose refIds are valid
    --local objects = packetReader.GetObjectPacketTables('container').objects
    --local acceptedObjects, rejectedObjects = {}, {}
    local isAllowed = true
    local rejectedObjects = {}

    -- Don't allow container changes in currently dying actors
    local unusableContainerUniqueIndexes = {}

    if cell then
        unusableContainerUniqueIndexes = cell.unusableContainerUniqueIndexes
    end

    local subAction = tes3mp.GetObjectListContainerSubAction()

    local objects = {}

    for index = 0, tes3mp.GetObjectListSize() - 1 do
        local object = {}
        object.refId = tes3mp.GetObjectRefId(index)
        object.uniqueIndex = tes3mp.GetObjectRefNum(index) .. '-' .. tes3mp.GetObjectMpNum(index)

        if tableHelper.containsValue(unusableContainerUniqueIndexes, object.uniqueIndex) then
            if subAction == enumerations.containerSub.REPLY_TO_REQUEST then
                tableHelper.removeValue(unusableContainerUniqueIndexes, object.uniqueIndex)

                tes3mp.LogMessage(
                    enumerations.log.INFO,
                    ('Making container %s usable as a result of request reply'):format(object.uniqueIndex)
                )

                table.insert(objects, object)
            else
                table.insert(rejectedObjects, object.refId .. ' ' .. object.uniqueIndex)
                isAllowed = false

                Players[pid]:Message('That container is currently unusable for synchronization reasons.\n')
            end
        else
            table.insert(objects, object)
        end
    end

    if isAllowed then
        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators(
                'OnContainer',
                { pid, cellDescription, objects }
            )
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            local useTemporaryLoad = false

            if not cell then
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

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers(
                'OnContainer',
                eventStatus,
                { pid, cellDescription, objects }
            )
        end
    else
        tes3mp.LogMessage(
            enumerations.log.INFO,
            ('Rejected Container from %s about %s')
            :format(logicHandler.GetChatName(pid), tableHelper.concatenateArrayValues(rejectedObjects, 1, ', '))
        )
    end
end

---@param pid PlayerId
function OnVideoPlay(pid)
    logPlayerEvent('OnVideoPlay', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    tes3mp.ReadReceivedObjectList()
    local packetOrigin = tes3mp.GetObjectListOrigin()

    tes3mp.LogAppend(
        enumerations.log.INFO,
        ('- packetOrigin was %s'):format(tableHelper.getIndexByValue(enumerations.packetOrigin, packetOrigin))
    )

    local player = Players[targetPid]
    local consoleCommand = tes3mp.GetObjectListConsoleCommand()
    local hasConsoleVideoQueued = tableHelper.containsValue(player.consoleVideosQueued, consoleCommand)

    if logicHandler.IsPacketFromConsole(packetOrigin) and not logicHandler.IsPlayerAllowedConsole(pid) and not hasConsoleVideoQueued then
        tes3mp.Kick(pid)
        return tes3mp.SendMessage(pid, consoleKickMessage:format(logicHandler.GetChatName(pid)), true)
    end

    if hasConsoleVideoQueued then
        player.consoleVideosQueued = {}
    end

    if not config.shareVideos then return end

    tes3mp.LogMessage(enumerations.log.INFO, ('Sharing VideoPlay from %s'):format(logicHandler.GetChatName(pid)))

    local videos = {}

    for i = 0, tes3mp.GetObjectListSize() - 1 do
        local videoFilename = tes3mp.GetVideoFilename(i)
        table.insert(videos, videoFilename)
        tes3mp.LogAppend(enumerations.log.WARN, '- videoFilename ' .. videoFilename)
    end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnVideoPlay', { pid, videos })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.CopyReceivedObjectListToStore()
        -- Send this VideoPlay packet to other players (sendToOthersPlayers is true),
        -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
        tes3mp.SendVideoPlay(true, true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnVideoPlay', eventStatus, { pid, videos })
    end
end

---@param pid PlayerId
function OnRecordDynamic(pid)
    logPlayerEvent('OnRecordDynamic', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end
    local player = Players[pid]

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

                player:Message(
                    ('You are not allowed to create a record called %s\n'):format(record.name)
                )
            end
        end
    end

    if not isAllowed then
        return tes3mp.LogMessage(
            enumerations.log.INFO,
            ('Rejected RecordDynamic from %s about %s')
            :format(logicHandler.GetChatName(pid), tableHelper.concatenateArrayValues(rejectedRecords, 1, ', '))
        )
    end

    local storeType = tableHelper.getIndexByValue(enumerations.recordType, recordNumericalType):lower()
    local recordStore = RecordStores[storeType]

    if not recordStore then
        return tes3mp.LogMessage(
            enumerations.log.WARN,
            ('Rejected RecordDynamic for invalid record store of type %s'):format(recordNumericalType)
        )
    end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnRecordDynamic', { pid, recordArray, storeType })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    local isEnchantable = tableHelper.containsValue(config.enchantableRecordTypes, storeType)

    if eventStatus.validDefaultHandler then
        for _, record in ipairs(recordArray) do
            local recordId

            -- Is there already a record exactly like this one, icon and model aside?
            -- If so, we'll just reuse it the way OpenMW would
            if storeType == 'potion' then
                recordId = recordStore:GetMatchingRecordId(
                    record,
                    recordStore.data.generatedRecords,
                    player.data.recordLinks[storeType],
                    { 'icon', 'model', 'quantity' },
                    true,
                    25
                )
            end

            if not recordId then
                recordId = recordStore:GenerateRecordId()
            end

            if storeType == 'enchantment' then
                -- We need to store this enchantment's original client-generated id
                -- on this player so we can match it with its server-generated correct
                -- id once the player sends the record of the enchanted item they've
                -- used it on
                player.unresolvedEnchantments[record.clientsideEnchantmentId] = recordId
                record.clientsideEnchantmentId = nil
            end

            recordTable[recordId] = record
        end

        recordStore:SaveGeneratedRecords(recordTable)
        recordStore:LoadGeneratedRecords(pid, recordTable, tableHelper.getArrayFromIndices(recordTable), true)

        for _, targetPlayer in pairs(Players) do
            for recordId in pairs(recordTable) do
                table.insert(targetPlayer.generatedRecordsReceived, recordId)
            end
        end

        -- Add the final spell to the player's spellbook
        if storeType == 'spell' then
            tes3mp.ClearSpellbookChanges(pid)
            tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.ADD)

            for recordId in pairs(recordTable) do
                table.insert(player.data.spellbook, recordId)
                tes3mp.AddSpell(pid, recordId)

                player:AddLinkToRecord(storeType, recordId)
            end

            recordStore:QuicksaveToDrive()
            player:QuicksaveToDrive()
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

                inventoryHelper.addItem(
                    player.data.inventory,
                    item.refId,
                    item.count,
                    item.charge,
                    item.enchantmentCharge,
                    item.soul
                )

                table.insert(itemArray, item)

                player:AddLinkToRecord(storeType, recordId)

                -- If this is an enchantable item record, add a link to it from its associated
                -- enchantment record
                if isEnchantable then
                    enchantmentStore:AddLinkToRecord(record.enchantmentId,
                        recordId, storeType)
                end
            end

            if isEnchantable then enchantmentStore:QuicksaveToDrive() end

            recordStore:QuicksaveToDrive()
            player:QuicksaveToDrive()
            player:LoadItemChanges(itemArray, enumerations.inventory.ADD)
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnRecordDynamic', eventStatus, { pid, recordTable, storeType })
    end
end

---@param pid PlayerId
function OnWorldKillCount(pid)
    logPlayerEvent('OnWorldKillCount', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnWorldKillCount', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        WorldInstance:SaveKills(pid)
        tes3mp.CopyReceivedWorldstateToStore()

        -- Send this WorldKillCount packet to other players (sendToOthersPlayers is true),
        -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
        tes3mp.SendWorldKillCount(pid, true, true)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnWorldKillCount', eventStatus, { pid })
    end
end

---@param pid PlayerId
function OnWorldMap(pid)
    logPlayerEvent('OnWorldMap', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    tes3mp.ReadReceivedWorldstate()
    local mapTileArray = packetReader.GetWorldMapTileArray()

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnWorldMap', { pid, mapTileArray })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        WorldInstance:SaveMapTiles(mapTileArray)

        if config.shareMapExploration then
            tes3mp.CopyReceivedWorldstateToStore()

            -- Send this WorldMap packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendWorldMap(pid, true, true)
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnWorldMap', eventStatus, { pid, mapTileArray })
    end
end

---@param pid PlayerId
function OnWorldWeather(pid)
    logPlayerEvent('OnWorldWeather', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnWorldWeather', { pid })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        tes3mp.ReadReceivedWorldstate()

        local regionName = tes3mp.GetWeatherRegion():lower()

        -- Track current weather in each region
        if WorldInstance.storedRegions[regionName] then
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

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnWorldWeather', eventStatus, { pid })
    end
end

---@param pid PlayerId
---@param cellDescription CellDescription
function OnClientScriptLocal(pid, cellDescription)
    logPlayerCellEvent('OnClientScriptLocal', pid, cellDescription)
    onGenericObjectEvent(pid, cellDescription, "ClientScriptLocal")
end

---@param pid PlayerId
function OnClientScriptGlobal(pid)
    logPlayerEvent('OnClientScriptGlobal', pid)

    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then
        return tes3mp.Kick(pid)
    end

    tes3mp.ReadReceivedWorldstate()

    local variables, eventStatus = packetReader.GetClientScriptGlobalPacketTable()
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators('OnClientScriptGlobal', { pid, variables })
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        local shouldSync = false

        -- Iterate through the global IDs in the ClientScriptGlobal packet and only sync and save them
        -- when applicable
        for id in pairs(variables) do
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
            tes3mp.LogMessage(
                enumerations.log.INFO,
                ('Synchronized ClientScriptGlobal from %s about %s')
                :format(logicHandler.GetChatName(pid), tableHelper.concatenateTableIndices(variables, ', '))
            )
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers('OnClientScriptGlobal', eventStatus, { pid, variables })
    end
end

---@param pid PlayerId
---@param idGui GUIID
---@param data string|integer
function OnGUIAction(pid, idGui, data)
    logPlayerEvent('OnGUIAction', pid)

    local player = Players[pid]
    if not player then return end

    data = tostring(data) -- data can be numeric, but we should convert it to a string

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            'OnGUIAction',
            { pid, idGui, data }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        if player:IsLoggedIn() then
            if idGui == config.customMenuIds.confiscate and player.confiscationTargetName ~= nil then
                local targetName = player.confiscationTargetName
                local targetPlayer = logicHandler.GetPlayerByName(targetName)
                assert(targetPlayer)

                -- Because the window's item index starts from 0 while the Lua table for
                -- inventories starts from 1, adjust the former here
                local inventoryItemIndex = data + 1
                local item = targetPlayer.data.inventory[inventoryItemIndex]

                if item then
                    inventoryHelper.addItem(
                        player.data.inventory,
                        item.refId,
                        item.count,
                        item.charge,
                        item.enchantmentCharge,
                        item.soul
                    )
                    player:LoadItemChanges({ item }, enumerations.inventory.ADD)

                    -- If the item is equipped by the target, unequip it first
                    if inventoryHelper.containsItem(targetPlayer.data.equipment, item.refId, item.charge) then
                        local equipmentItemIndex = inventoryHelper.getItemIndex(targetPlayer.data.equipment,
                            item.refId, item.charge)
                        if equipmentItemIndex then
                            targetPlayer.data.equipment[equipmentItemIndex] = nil
                        end
                    end

                    targetPlayer.data.inventory[inventoryItemIndex] = nil
                    tableHelper.cleanNils(targetPlayer.data.inventory)

                    player:Message(('You\'ve confiscated %s from %s\n'):format(item.refId, targetName))

                    if targetPlayer:IsLoggedIn() then
                        targetPlayer:LoadItemChanges({ item }, enumerations.inventory.REMOVE)
                    end
                else
                    player:Message('Invalid item index\n')
                end

                targetPlayer:SetConfiscationState(false)
                targetPlayer:QuicksaveToDrive()

                player.confiscationTargetName = nil
            elseif idGui == config.customMenuIds.menuHelper and Players[pid].currentCustomMenu then
                local buttonIndex = tonumber(data) + 1
                local buttonPressed = player.displayedMenuButtons[buttonIndex]

                local menuHelper = ScriptLoader.Interfaces.menuHelper

                if not menuHelper then
                    Players[pid]:Message(
                        'The menuHelper interface does not exist, so this interface cannot be loaded!'
                    )
                else
                    local destination = ScriptLoader.Interfaces.menuHelper.GetButtonDestination(pid, buttonPressed)

                    player.previousCustomMenu = player.currentCustomMenu
                    menuHelper.ProcessEffects(pid, destination.effects)

                    if destination.targetMenu then
                        menuHelper.DisplayMenu(pid, destination.targetMenu)
                        player.currentCustomMenu = destination.targetMenu
                    end
                end
            end
        else
            if idGui == guiHelper.ID.LOGIN then
                if not data then
                    player:Message("Incorrect password!\n")
                    return guiHelper.ShowLogin(pid)
                end

                player:LoadFromDrive()
                local passwordSalt = player.data.login.passwordSalt

                if player.data.login.passwordHash ~= tes3mp.GetSHA256Hash(data .. passwordSalt) then
                    player:Message('Incorrect password!\n')
                    return guiHelper.ShowLogin(pid)
                end

                -- Is this player on the banlist? If so, store their new IP and ban them
                if tableHelper.containsValue(banList.playerNames, player.accountName:lower()) then
                    player:SaveIpAddress()

                    player:Message(('%s is banned from this server.\n'):format(player.accountName))
                    tes3mp.BanAddress(tes3mp.GetIP(pid))
                elseif player:FinishLogin() then
                    if CustomEventHooks then
                        CustomEventHooks.triggerHandlers(
                            'OnPlayerFinishLogin',
                            dUtil.misc.makeEventStatus(),
                            { player.pid }
                        )

                        CustomEventHooks.triggerHandlers(
                            'OnPlayerAuthentified',
                            dUtil.misc.makeEventStatus(),
                            { player.pid }
                        )
                    end

                    player:Message(('You have successfully logged in.\n%s'):format(config.chatWindowInstructions))

                    if not WorldInstance:HasRunStartupScripts() then
                        player:Message(config.startupScriptsInstructions)
                    end
                else
                    tes3mp.LogAppend(enumerations.log.WARN, ('Login failed for playerId: %s'):format(pid))
                    tes3mp.Kick(pid)
                end
            elseif idGui == guiHelper.ID.REGISTER then
                if player:HasAccount() then
                    tes3mp.LogMessage(
                        enumerations.log.ERROR,
                        ('Warning! %s replied to login for existing account with regsitration attempt and has been banned.')
                        :format(logicHandler.GetChatName(pid))
                    )

                    local ipAddress = tes3mp.GetIP(pid)
                    table.insert(banList.ipAddresses, ipAddress)

                    SaveBanList()
                    tes3mp.BanAddress(ipAddress)
                    return
                elseif not data then
                    player:Message('Password can not be empty\n')
                    guiHelper.ShowRegister(pid)
                    return
                end

                player:Register(data)
                player:Message(('You have successfully registered.\n%s'):format(config.chatWindowInstructions))

                if not WorldInstance:HasRunStartupScripts() then
                    player:Message(config.startupScriptsInstructions)
                end
            end
        end
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnGUIAction',
            eventStatus,
            { pid, idGui, data }
        )
    end
end

function OnMpNumIncrement(currentMpNum)
    WorldInstance:SetCurrentMpNum(currentMpNum)
end

-- Timer-based events
---@param pid PlayerId
---@param accountName string
function OnLoginTimeExpiration(pid, accountName)
    local player = Players[pid]
    if not player or player.accountName ~= accountName then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            'OnLoginTimeExpiration',
            { pid }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        logicHandler.AuthCheck(pid)
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnLoginTimeExpiration',
            eventStatus,
            { pid }
        )
    end
end

---@param pid PlayerId
---@param accountName string
function OnDeathTimeExpiration(pid, accountName)
    local player = Players[pid]
    if not player or not player:IsLoggedIn() or player.accountName ~= accountName then return end

    local eventStatus
    if CustomEventHooks then
        eventStatus = CustomEventHooks.triggerValidators(
            'OnDeathTimeExpiration',
            { pid }
        )
    else
        eventStatus = dUtil.misc.makeEventStatus()
    end

    if eventStatus.validDefaultHandler then
        player:Resurrect()
    end

    if CustomEventHooks then
        CustomEventHooks.triggerHandlers(
            'OnDeathTimeExpiration',
            eventStatus,
            { pid }
        )
    end
end

---@param loopIndex integer
function OnObjectLoopTimeExpiration(loopIndex)
    local objectLoop = ObjectLoops[loopIndex]
    if not objectLoop then return end

    local loop = ObjectLoops[loopIndex]
    local pid = loop.targetPid
    local loopEnded = false

    local player = Players[pid]
    if player and player:IsLoggedIn() and player.accountName == loop.targetName then
        local eventStatus
        if CustomEventHooks then
            eventStatus = CustomEventHooks.triggerValidators(
                'OnObjectLoopTimeExpiration',
                { pid, loopIndex }
            )
        else
            eventStatus = dUtil.misc.makeEventStatus()
        end

        if eventStatus.validDefaultHandler then
            if loop.packetType == 'place' or loop.packetType == 'spawn' then
                logicHandler.CreateObjectAtPlayer(pid, dataTableBuilder.BuildObjectData(loop.refId), loop.packetType)
            elseif loop.packetType == 'console' then
                logicHandler.RunConsoleCommandOnPlayer(pid, loop.consoleCommand)
            end

            loop.count = loop.count - 1

            if loop.count > 0 then
                ObjectLoops[loopIndex] = loop
                tes3mp.RestartTimer(loop.timerId, loop.interval)
            else
                loopEnded = true
            end
        end

        if CustomEventHooks then
            CustomEventHooks.triggerHandlers(
                'OnObjectLoopTimeExpiration',
                eventStatus,
                { pid, loopIndex }
            )
        end
    else
        loopEnded = true
    end

    if loopEnded then
        ObjectLoops[loopIndex] = nil
    end
end
