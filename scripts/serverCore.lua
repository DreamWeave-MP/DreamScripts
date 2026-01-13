local enumerations = require 'tes3mp.enumerations'
local dataTableBuilder = require 'dataTableBuilder'
local guiHelper = require 'tes3mp.util.gui'
---@type InventoryHelper
local inventoryHelper = require 'tes3mp.util.menu'
local jsonInterface = require 'jsonInterface'
local packetBuilder = require 'tes3mp.packet.builder'
local tableHelper = require 'tes3mp.util.table'

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
hourCounter = nil

---@global
updateTimerId = nil

---@global
banList = {}

local miscUtil = require 'tes3mp.util.misc'

local config = require 'tes3mp.config'
local time = require 'time'

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

--- MenuHelper is stateful and should load prior to any module which possibly depends on it
local menuHelper = require 'tes3mp.util.menu'
local logicHandler = require 'tes3mp.logicHandler'

-- commandHandler = require 'commandHandler'

--- The eventHandler uses customEventHooks as a dependency due to registering many built-in eventHandlers/Validators itself
--- We probably should change this so that all the built-in validators and handlers are loaded naturally as a consequence of the server's
--- Initialization instead of making onServerPostInit subject to it
--- *possibly*, we should delete eventHandler altogether
--- and merge its validators/handlers into builtin scripts that load after customEventHooks
local eventHandler = require 'eventHandler'

animHelper = require 'animHelper'

---@type DScriptLoader
local ScriptLoader = require 'dUtil.scriptLoader' {
    menuHelper = menuHelper,
}

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
            hourCounter = hourCounter + (0.0083 * WorldInstance.frametimeMultiplier)

            local hourFloor = math.floor(hourCounter)

            if previousHourFloor == nil then
                previousHourFloor = hourFloor
            elseif hourFloor > previousHourFloor then
                if hourFloor >= 24 then
                    hourCounter = hourCounter - hourFloor
                    hourFloor = 0

                    tes3mp.LogMessage(enumerations.log.INFO, "The world time day has been incremented")
                    WorldInstance:IncrementDay()
                end

                tes3mp.LogMessage(enumerations.log.INFO, "The world time hour is now " .. hourFloor)
                WorldInstance.data.time.hour = hourCounter

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
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnServerInit\"")

    local expectedVersionPrefix = "0.8.1"
    local serverVersion = tes3mp.GetServerVersion()

    if string.sub(serverVersion, 1, string.len(expectedVersionPrefix)) ~= expectedVersionPrefix then
        tes3mp.LogAppend(enumerations.log.ERROR, "- Version mismatch between server and Core scripts!")
        tes3mp.LogAppend(enumerations.log.ERROR, "- The Core scripts require a server version that starts with " ..
            expectedVersionPrefix)
        tes3mp.StopServer(1)
    end

    WorldInstance = World()

    ScriptLoader.loadAllScripts()
    print(ScriptLoader.Interfaces)
    if not ScriptLoader.Interfaces.customEventHooks then
        tes3mp.LogAppend(enumerations.log.ERROR, 'Failed to locate customEventHooks Interface! Server refusing to start!')
        tes3mp.StopServer(16)
    end

    -- If the world has a data entry, load it
    if WorldInstance:HasEntry() then
        WorldInstance:LoadFromDrive()
        WorldInstance:EnsureCoreVariablesExist()
        WorldInstance:EnsureTimeDataExists()

        -- Get the current mpNum from the loaded world
        tes3mp.SetCurrentMpNum(WorldInstance:GetCurrentMpNum())

        ScriptLoader.Interfaces.customEventHooks.triggerHandlers("OnWorldReload",
            ScriptLoader.Interfaces.customEventHooks.makeEventStatus(true, true), {})

        -- Otherwise, create a data file for it
    else
        WorldInstance:CreateEntry()
    end

    for _, recordStoreTypes in ipairs(config.recordStoreLoadOrder) do
        for _, storeType in ipairs(recordStoreTypes) do
            logicHandler.LoadRecordStore(storeType)
        end
    end

    hourCounter = WorldInstance.data.time.hour
    WorldInstance:UpdateFrametimeMultiplier()

    updateTimerId = tes3mp.CreateTimer("UpdateTime", time.seconds(1))
    tes3mp.StartTimer(updateTimerId)

    logicHandler.PushPlayerList(Players)

    LoadBanList()

    tes3mp.SetDataFileEnforcementState(config.enforceDataFiles)
    tes3mp.SetScriptErrorIgnoringState(config.ignoreScriptErrors)
end

function OnServerPostInit()
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnServerPostInit\"")

    local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators("OnServerPostInit", {})

    if eventStatus.validDefaultHandler then
        tes3mp.SetGameMode(config.gameMode)

        local consoleRuleString = "allowed"
        if not config.allowConsole then
            consoleRuleString = "not " .. consoleRuleString
        end

        local bedRestRuleString = "allowed"
        if not config.allowBedRest then
            bedRestRuleString = "not " .. bedRestRuleString
        end

        local wildRestRuleString = "allowed"
        if not config.allowWildernessRest then
            wildRestRuleString = "not " .. wildRestRuleString
        end

        local waitRuleString = "allowed"
        if not config.allowWait then
            waitRuleString = "not " .. waitRuleString
        end

        tes3mp.SetRuleString("enforceDataFiles", tostring(config.enforceDataFiles))
        tes3mp.SetRuleString("ignoreScriptErrors", tostring(config.ignoreScriptErrors))
        tes3mp.SetRuleValue("difficulty", config.difficulty)
        tes3mp.SetRuleValue("deathPenaltyJailDays", config.deathPenaltyJailDays)
        tes3mp.SetRuleString("console", consoleRuleString)
        tes3mp.SetRuleString("bedResting", bedRestRuleString)
        tes3mp.SetRuleString("wildernessResting", wildRestRuleString)
        tes3mp.SetRuleString("waiting", waitRuleString)
        tes3mp.SetRuleValue("enforcedLogLevel", config.enforcedLogLevel)
        tes3mp.SetRuleValue("physicsFramerate", config.physicsFramerate)
        tes3mp.SetRuleString("shareJournal", tostring(config.shareJournal))
        tes3mp.SetRuleString("shareFactionRanks", tostring(config.shareFactionRanks))
        tes3mp.SetRuleString("shareFactionExpulsion", tostring(config.shareFactionExpulsion))
        tes3mp.SetRuleString("shareFactionReputation", tostring(config.shareFactionReputation))
        tes3mp.SetRuleString("shareTopics", tostring(config.shareTopics))
        tes3mp.SetRuleString("shareBounty", tostring(config.shareBounty))
        tes3mp.SetRuleString("shareReputation", tostring(config.shareReputation))
        tes3mp.SetRuleString("shareMapExploration", tostring(config.shareMapExploration))
        tes3mp.SetRuleString("enablePlacedObjectCollision", tostring(config.enablePlacedObjectCollision))

        local respawnCell

        if config.respawnAtImperialShrine == true then
            respawnCell = "nearest Imperial shrine"

            if config.respawnAtTribunalTemple == true then
                respawnCell = respawnCell .. " or Tribunal temple"
            end
        elseif config.respawnAtTribunalTemple == true then
            respawnCell = "nearest Tribunal temple"
        else
            respawnCell = config.defaultRespawn.cellDescription
        end

        tes3mp.SetRuleString("respawnCell", respawnCell)
    end

    ScriptLoader.Interfaces.customEventHooks.triggerHandlers("OnServerPostInit", eventStatus, {})
end

function OnServerExit(errorState)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnServerExit\"")
    tes3mp.LogMessage(enumerations.log.ERROR, "Error state: " .. tostring(errorState))
    ScriptLoader.Interfaces.customEventHooks.triggerHandlers("OnServerExit",
        ScriptLoader.Interfaces.customEventHooks.makeEventStatus(true, true), { errorState })
end

function OnServerScriptCrash(errorMessage)
    tes3mp.LogMessage(enumerations.log.ERROR, "Server crash from script error!")
    tes3mp.StopServer(7)
    if not ScriptLoader.Interfaces.customEventHooks then return end
    ScriptLoader.Interfaces.customEventHooks.triggerHandlers("OnServerExit",
        ScriptLoader.Interfaces.customEventHooks.makeEventStatus(true, true), { errorMessage })
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
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerConnect\" for pid " .. pid)

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

    local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators('OnPlayerConnect', { pid })

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

    ScriptLoader.Interfaces.customEventHooks.triggerHandlers('OnPlayerConnect', eventStatus, { pid })
end

function OnPlayerDisconnect(pid)
    tes3mp.LogMessage(
        enumerations.log.INFO,
        ('Called "OnPlayerDisconnect" for '):format(logicHandler.GetChatName(pid))
    )

    eventHandler.OnPlayerDisconnect(pid)
end

function OnPlayerResurrect(pid)
    ScriptLoader.Interfaces.customEventHooks.triggerHandlers(
        'OnPlayerResurrect',
        ScriptLoader.Interfaces.customEventHooks.makeEventStatus(true, true),
        { pid }
    )
end

function OnPlayerSendMessage(pid, message)
    eventHandler.OnPlayerSendMessage(pid, message)
end

function OnPlayerDeath(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerDeath\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerDeath(pid)
end

function OnPlayerAttribute(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerAttribute\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerAttribute(pid)
end

function OnPlayerSkill(pid)
    eventHandler.OnPlayerSkill(pid)
end

function OnPlayerLevel(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerLevel\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerLevel(pid)
end

function OnPlayerShapeshift(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerShapeshift\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerShapeshift(pid)
end

function OnPlayerCellChange(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerCellChange\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerCellChange(pid)
end

function OnPlayerEquipment(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerEquipment\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerEquipment(pid)
end

function OnPlayerInventory(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerInventory\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerInventory(pid)
end

function OnPlayerSpellbook(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerSpellbook\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerSpellbook(pid)
end

function OnPlayerSpellsActive(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerSpellsActive\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerSpellsActive(pid)
end

function OnPlayerCooldowns(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerCooldowns\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerCooldowns(pid)
end

function OnPlayerQuickKeys(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerQuickKeys\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerQuickKeys(pid)
end

function OnPlayerJournal(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerJournal\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerJournal(pid)
end

function OnPlayerFaction(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerFaction\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerFaction(pid)
end

function OnPlayerTopic(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerTopic\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerTopic(pid)
end

function OnPlayerBounty(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerBounty\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerBounty(pid)
end

function OnPlayerReputation(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerReputation\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerReputation(pid)
end

function OnPlayerBook(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerBook\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerBook(pid)
end

function OnPlayerItemUse(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerItemUse\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerItemUse(pid)
end

function OnPlayerMiscellaneous(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerMiscellaneous\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerMiscellaneous(pid)
end

function OnPlayerEndCharGen(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnPlayerEndCharGen\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnPlayerEndCharGen(pid)
end

function OnCellLoad(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnCellLoad\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnCellLoad(pid, cellDescription)
end

function OnCellUnload(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnCellUnload\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnCellUnload(pid, cellDescription)
end

function OnCellDeletion(cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnCellDeletion\" for cell " .. cellDescription)
    eventHandler.OnCellDeletion(cellDescription)
end

function OnActorList(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorList\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorList(pid, cellDescription)
end

function OnActorEquipment(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorEquipment\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorEquipment(pid, cellDescription)
end

function OnActorAI(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorAI\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorAI(pid, cellDescription)
end

function OnActorDeath(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorDeath\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorDeath(pid, cellDescription)
end

function OnActorSpellsActive(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorSpellsActive\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorSpellsActive(pid, cellDescription)
end

function OnActorCellChange(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnActorCellChange\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnActorCellChange(pid, cellDescription)
end

function OnObjectActivate(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectActivate\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectActivate(pid, cellDescription)
end

function OnObjectHit(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectHit\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectHit(pid, cellDescription)
end

function OnObjectPlace(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectPlace\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectPlace(pid, cellDescription)
end

function OnObjectSpawn(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectSpawn\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectSpawn(pid, cellDescription)
end

function OnObjectDelete(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectDelete\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectDelete(pid, cellDescription)
end

function OnObjectLock(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectLock\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectLock(pid, cellDescription)
end

function OnObjectDialogueChoice(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectDialogueChoice\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectDialogueChoice(pid, cellDescription)
end

function OnObjectMiscellaneous(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectMiscellaneous\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectMiscellaneous(pid, cellDescription)
end

function OnObjectRestock(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectRestock\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectRestock(pid, cellDescription)
end

function OnObjectTrap(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectTrap\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectTrap(pid, cellDescription)
end

function OnObjectScale(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectScale\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectScale(pid, cellDescription)
end

function OnObjectSound(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectSound\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectSound(pid, cellDescription)
end

function OnObjectState(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnObjectState\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnObjectState(pid, cellDescription)
end

function OnDoorState(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnDoorState\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnDoorState(pid, cellDescription)
end

function OnConsoleCommand(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnConsoleCommand\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnConsoleCommand(pid, cellDescription)
end

function OnContainer(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnContainer\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnContainer(pid, cellDescription)
end

function OnVideoPlay(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnVideoPlay\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnVideoPlay(pid)
end

function OnRecordDynamic(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnRecordDynamic\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnRecordDynamic(pid)
end

function OnWorldKillCount(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnWorldKillCount\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnWorldKillCount(pid)
end

function OnWorldMap(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnWorldMap\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnWorldMap(pid)
end

function OnWorldWeather(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnWorldWeather\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnWorldWeather(pid)
end

function OnClientScriptLocal(pid, cellDescription)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnClientScriptLocal\" for " .. logicHandler.GetChatName(pid) ..
        " and cell " .. cellDescription)
    eventHandler.OnClientScriptLocal(pid, cellDescription)
end

function OnClientScriptGlobal(pid)
    tes3mp.LogMessage(enumerations.log.INFO, "Called \"OnClientScriptGlobal\" for " .. logicHandler.GetChatName(pid))
    eventHandler.OnClientScriptGlobal(pid)
end

---@param pid PlayerId
---@param idGui GUIID
---@param data string|integer
function OnGUIAction(pid, idGui, data)
    tes3mp.LogMessage(
        enumerations.log.INFO,
        ('Called "OnGUIAction" for %s'):format(logicHandler.GetChatName(pid))
    )

    local player = Players[pid]
    if not player then return end

    data = tostring(data) -- data can be numeric, but we should convert it to a string

    local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators(
        'OnGUIAction',
        { pid, idGui, data }
    )

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

                local destination = menuHelper.GetButtonDestination(pid, buttonPressed)

                player.previousCustomMenu = player.currentCustomMenu
                menuHelper.ProcessEffects(pid, destination.effects)

                if destination.targetMenu then
                    menuHelper.DisplayMenu(pid, destination.targetMenu)
                    player.currentCustomMenu = destination.targetMenu
                end
            end
        else
            if idGui == guiHelper.ID.LOGIN then
                if not data then
                    player:Message("Incorrect password!\n")
                    guiHelper.ShowLogin(pid)
                    return
                end

                player:LoadFromDrive()
                local passwordSalt = player.data.login.passwordSalt

                if player.data.login.passwordHash ~= tes3mp.GetSHA256Hash(data .. passwordSalt) then
                    player:Message('Incorrect password!\n')
                    guiHelper.ShowLogin(pid)
                    return
                end

                -- Is this player on the banlist? If so, store their new IP and ban them
                if tableHelper.containsValue(banList.playerNames, player.accountName:lower()) then
                    player:SaveIpAddress()

                    player:Message(('%s is banned from this server.\n'):format(player.accountName))
                    tes3mp.BanAddress(tes3mp.GetIP(pid))
                else
                    player:FinishLogin()
                    player:Message(('You have successfully logged in.\n%s'):format(config.chatWindowInstructions))

                    if not WorldInstance:HasRunStartupScripts() then
                        player:Message(config.startupScriptsInstructions)
                    end
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

    ScriptLoader.Interfaces.customEventHooks.triggerHandlers(
        'OnGUIAction',
        eventStatus,
        { pid, idGui, data }
    )
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

    local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators(
        'OnLoginTimeExpiration',
        { pid }
    )

    if eventStatus.validDefaultHandler then
        logicHandler.AuthCheck(pid)
    end

    ScriptLoader.Interfaces.customEventHooks.triggerHandlers(
        'OnLoginTimeExpiration',
        eventStatus,
        { pid }
    )
end

function OnDeathTimeExpiration(pid, accountName)
    local player = Players[pid]
    if not player or not player:IsLoggedIn() or player.accountName ~= accountName then return end

    local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators(
        'OnDeathTimeExpiration',
        { pid }
    )
    if eventStatus.validDefaultHandler then
        player:Resurrect()
    end

    ScriptLoader.Interfaces.customEventHooks.triggerHandlers(
        'OnDeathTimeExpiration',
        eventStatus,
        { pid }
    )
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
        local eventStatus = ScriptLoader.Interfaces.customEventHooks.triggerValidators(
            'OnObjectLoopTimeExpiration',
            { pid, loopIndex }
        )

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

        ScriptLoader.Interfaces.customEventHooks.triggerHandlers(
            'OnObjectLoopTimeExpiration',
            eventStatus,
            { pid, loopIndex }
        )
    else
        loopEnded = true
    end

    if loopEnded then
        ObjectLoops[loopIndex] = nil
    end
end
