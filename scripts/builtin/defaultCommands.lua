---@type DreamWeaveScriptEnv
_ENV = _ENV

local animHelper = require 'tes3mp.util.anim'
local color = require 'packages.color'
local config = require 'config'
local dataTableBuilder = require 'packages.dataTableBuilder'
local enumerations = require 'packages.networkEnums'
local guiHelper = require 'tes3mp.util.gui'
local logicHandler = require 'packages.logicHandler'
local patterns = require 'packages.misc.patterns'
local recordHelper = require 'tes3mp.util.record'
local tableHelper = require 'tes3mp.util.table'

---@type DefaultInterfaces
local I = require 'interfaces'

---@type MenuHelper
local menuHelper = I.menuHelper
---@type SpeechHelper
local speechHelper = I.speechHelper

---@type DUtilModule
local dUtil = require 'dUtil'

local function invalidCommand(pid)
    assert(logicHandler.CheckPlayerValidity(nil, pid),
        'Invalid/not logged in playerId provided to invalidCommand! This should never happen!')

    tes3mp.SendMessage(
        pid,
        ('%sNot a valid command. Type /help for more info.%s\n'):format(color.Error, color.Default),
        false
    )
end

---@type CommandHandler
local function addAdmin(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local targetPlayer = Players[targetPid]
    local targetName = targetPlayer.name

    if targetPlayer:IsAdmin() then
        return tes3mp.SendMessage(pid, ('%s is already an Admin.\n'):format(targetName), false)
    end

    tes3mp.SendMessage(pid, ('%s was promoted to Admin!\n'):format(targetName), true)
    targetPlayer.data.settings.staffRank = 2
    targetPlayer:QuicksaveToDrive()
end

---@type CommandHandler
local function addModerator(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local isMod, isAdmin = dUtil.misc.getRanks(targetPid)
    local targetPlayer = Players[targetPid]

    if isAdmin then
        return tes3mp.SendMessage(pid, ('%s is already an Admin.\n'):format(targetPlayer.name), false)
    elseif isMod then
        return tes3mp.SendMessage(pid, ('%s is already a Moderator.\n'):format(targetPlayer.name), false)
    end

    tes3mp.SendMessage(pid, ('%s was promoted to Moderator!\n'):format(targetPlayer.name), true)
    targetPlayer.data.settings.staffRank = 1
    targetPlayer:QuicksaveToDrive()
end

--- Check 'scripts/menu/advancedExample.lua' if you want to change the advanced menu example
---@type CommandHandler
local function advancedExample(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local player = Players[targetPid]

    player.currentCustomMenu = 'advanced example origin'
    menuHelper.DisplayMenu(pid, player.currentCustomMenu)
end

---@type CommandHandler
local function anim(pid, cmd)
    if not animHelper.PlayAnimation(pid, cmd[2]) then
        Players[pid]:Message(
            ('That is not a valid animation. Try one of the following:\n%s\n'):format(animHelper.GetValidList(pid))
        )
    end
end

---@type CommandHandler
local function ban(pid, cmd)
    if not dUtil.misc.getRanks(pid) then
        return invalidCommand(pid)
    end

    if cmd[2] == "ip" and cmd[3] then
        local ipAddress = cmd[3]

        if not tableHelper.containsValue(banList.ipAddresses, ipAddress) then
            table.insert(banList.ipAddresses, ipAddress)
            SaveBanList()

            tes3mp.SendMessage(pid, ('%s is now banned.\n'):format(ipAddress), false)

            if dUtil.misc.isValidIP(ipAddress) then
                tes3mp.BanAddress(ipAddress)
            else
                tes3mp.SendMessage(pid, ('%s is not a valid IP Address! Cannot ban it!'):format(ipAddress))
            end
        else
            tes3mp.SendMessage(pid, ('%s was already banned.\n'):format(ipAddress), false)
        end
    elseif (cmd[2] == "name" or cmd[2] == "player") and cmd[3] then
        local targetName = tableHelper.concatenateFromIndex(cmd, 3)
        logicHandler.BanPlayer(pid, targetName)
    else
        local isValidPlayer, targetPid = logicHandler.CheckPlayerValidity(nil, cmd[2])
        if isValidPlayer then
            logicHandler.BanPlayer(pid, Players[targetPid].name)
        else
            tes3mp.SendMessage(pid, ('Invalid input for ban: %s\n'):format(cmd[2]), false)
        end
    end
end

---@type CommandHandler
local function banlist(pid, cmd)
    if not dUtil.misc.getRanks(pid) then
        return invalidCommand(pid)
    end

    cmd[2] = cmd[2] or ''
    local filter, message = cmd[2]:lower()

    if filter == 'names' or filter == 'name' or filter == 'players' then
        if not next(banList.playerNames) then
            message = 'No player names have been banned.\n'
        else
            message = 'The following player names are banned:\n'

            for index, targetName in pairs(banList.playerNames) do
                message = message .. targetName

                if index < #banList.playerNames then
                    message = message .. ', '
                end
            end

            message = message .. '\n'
        end
    elseif filter == 'ips' or filter == 'ip' then
        if not next(banList.ipAddresses) then
            message = 'No IP addresses have been banned.\n'
        else
            message = 'The following IP addresses unattached to players are banned:\n'

            for index, ipAddress in pairs(banList.ipAddresses) do
                message = message .. ipAddress

                if index < #banList.ipAddresses then
                    message = message .. ', '
                end
            end

            message = message .. '\n'
        end
    end

    if not message then
        message = 'Please specify whether you want the banlist for IPs or for names.\n'
    end

    tes3mp.SendMessage(pid, message, false)
end

---@type CommandHandler
local function cells(pid, _)
    if dUtil.misc.getRanks(pid) then
        return invalidCommand(pid)
    end

    guiHelper.ShowCellList(pid)
end

---@type CommandHandler
local function confiscate(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end
    local callingPlayer, targetPlayer = Players[pid], Players[targetPid]

    if targetPid == pid then
        callingPlayer:Message('You can\'t confiscate from yourself!\n')
    elseif targetPlayer.data.customVariables.isConfiscationTarget then
        callingPlayer:Message('Someone is already confiscating from that player\n')
    else
        callingPlayer.confiscationTargetName = targetPlayer.accountName

        targetPlayer:SetConfiscationState(true)

        tableHelper.cleanNils(targetPlayer.data.inventory)
        guiHelper.ShowInventoryList(config.customMenuIds.confiscate, pid, targetPid)
    end
end

--- Check 'scripts/menu/defaultCrafting.lua' if you want to change the example craft menu
---@type CommandHandler
local function craft(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local player = Players[targetPid]

    player.currentCustomMenu = 'default crafting origin'
    menuHelper.DisplayMenu(pid, player.currentCustomMenu)
end

---@type CommandHandler
local function createRecord(pid, cmd)
    if not cmd[2] then return end
    recordHelper.createRecord(pid, cmd)
end

---@type CommandHandler
local function disguise(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return invalidCommand(pid) end

    local creatureRefId = tableHelper.concatenateFromIndex(cmd, 3)

    local player = Players[targetPid]
    player.data.shapeshift.creatureRefId = creatureRefId
    tes3mp.SetCreatureRefId(targetPid, creatureRefId)
    tes3mp.SendShapeshift(targetPid)

    if creatureRefId == '' then
        creatureRefId = 'nothing'
    end

    tes3mp.SendMessage(pid, ('%s is now disguised as %s.\n'):format(player.accountName, creatureRefId), false)

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, 'You are now disguised as ' .. creatureRefId .. '\n', false)
    end
end

---@type CommandHandler
local function fixMe(pid, _)
    local player = Players[pid]
    if not config.allowFixmeCommand then
        return player:Message('That command is disabled on this server.\n')
    end

    local currentTime, timestamps = os.time(), player.data.timestamps

    if not tes3mp.IsInExterior(pid) then
        player:Message(('Sorry! You can only use %s/fixme%s in exteriors.\n'):format(color.Yellow, color.White))
    elseif not timestamps.lastFixMe or
        currentTime >= timestamps.lastFixMe + config.fixmeInterval then
        logicHandler.RunConsoleCommandOnPlayer(pid, 'fixme')
        timestamps.lastFixMe = currentTime
        tes3mp.SendMessage(pid, 'You have fixed your position!\n', false)
    else
        local remainingSeconds = (timestamps.lastFixMe + config.fixmeInterval) - currentTime

        if remainingSeconds > 1 then
            player:Message(('Sorry! You can\'t use %s/fixme%s for another %s seconds.\n'):format(color.Yellow,
                color.White, remainingSeconds))
        else
            player:Message(('Sorry! You can\'t use %s/fixme%s for another second.\n'):format(color.Yellow, color.White))
        end
    end
end

---@type CommandHandler
local function getPos(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return invalidCommand(pid) end
    logicHandler.PrintPlayerPosition(pid, targetPid)
end

---@type CommandHandler
local function greenText(pid, cmd)
    local message = logicHandler.GetChatName(pid) .. ": " .. color.GreenText ..
        ">" .. tableHelper.concatenateFromIndex(cmd, 2) .. "\n"
    tes3mp.SendMessage(pid, message, true)
end

---@type CommandHandler
local function inviteAlly(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local callingPlayer, targetPlayer, senderMessage = Players[pid], Players[targetPid], nil
    local targetName = logicHandler.GetChatName(targetPid)

    if not callingPlayer.allyInvitesSent then callingPlayer.allyInvitesSent = {} end
    if not targetPlayer.allyInvitesReceived then targetPlayer.allyInvitesReceived = {} end

    if tableHelper.containsValue(callingPlayer.data.alliedPlayers, targetPlayer.accountName) then
        senderMessage = ('%s is already your ally.\n'):format(targetName)
    elseif tableHelper.containsValue(callingPlayer.allyInvitesSent, targetPlayer.accountName) then
        senderMessage = ('You have already invited %s to be your ally.\n'):format(targetName)
    else
        senderMessage = ('You have invited %s to be your ally.\n'):format(targetName)

        table.insert(callingPlayer.allyInvitesSent, targetPlayer.accountName)
        table.insert(targetPlayer.allyInvitesReceived, callingPlayer.accountName)

        tes3mp.SendMessage(
            targetPid,
            ('%s has invited you to become their ally. Write %s/join%s %s to accept.\n'):format(
                logicHandler.GetChatName(pid), color.Yellow, pid, color.White),
            false
        )
    end

    tes3mp.SendMessage(pid, senderMessage, false)
end

--- Check 'scripts/menu/help.lua' if you want to change the contents of the help menus
---@type CommandHandler
local function help(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return end

    local player = Players[pid]

    player.currentCustomMenu = 'help player'
    menuHelper.DisplayMenu(pid, player.currentCustomMenu)
end

---@type CommandHandler
local function ipaddresses(pid, cmd)
    if not dUtil.misc.getRanks(pid) or not cmd[2] then
        return invalidCommand(pid)
    end

    local targetName = tableHelper.concatenateFromIndex(cmd, 2)
    local targetPlayer = logicHandler.GetPlayerByName(targetName)

    if not targetPlayer then
        return tes3mp.SendMessage(pid, ('Player %s does not exist!'):format(targetName), false)
    end

    if not targetPlayer.data.ipAddresses then
        return tes3mp.SendMessage(
            pid,
            ('Player %s does not have any recorded IP addresses. That\'s bad!\n'):format(targetPlayer.accountName),
            false
        )
    end

    local message = ('Player %s has used the following IP addresses:\n'):format(targetPlayer.accountName)

    for index, ipAddress in pairs(targetPlayer.data.ipAddresses) do
        message = message .. ipAddress

        if index < #targetPlayer.data.ipAddresses then
            message = message .. ', '
        end
    end

    message = message .. '\n'
    tes3mp.SendMessage(pid, message, false)
end

---@type CommandHandler
local function joinTeam(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local callingPlayer, targetPlayer, senderMessage = Players[pid], Players[targetPid], nil
    local targetName = logicHandler.GetChatName(targetPid)

    if not callingPlayer.allyInvitesReceived then callingPlayer.allyInvitesReceived = {} end

    if tableHelper.containsValue(callingPlayer.data.alliedPlayers, targetPlayer.accountName) then
        senderMessage = ('%s is already your ally!\n'):format(targetName)
    elseif tableHelper.containsValue(callingPlayer.allyInvitesReceived, targetPlayer.accountName) then
        senderMessage = ('%s is now your ally. Write %s/leave %s%s if you later decide to leave the partnership.\n')
            :format(targetName, color.Yellow, targetPid, color.White)

        tes3mp.SendMessage(
            targetPid,
            ('%s has agreed to become your ally.\n'):format(logicHandler.GetChatName(pid)),
            false
        )

        table.insert(callingPlayer.data.alliedPlayers, targetPlayer.accountName)
        table.insert(targetPlayer.data.alliedPlayers, callingPlayer.accountName)
        callingPlayer:Save()
        callingPlayer:LoadAllies()
        targetPlayer:Save()
        targetPlayer:LoadAllies()
    else
        senderMessage = ('%s hasn\'t yet invited you to join their party. Sorry!\n'):format(targetName)
    end

    tes3mp.SendMessage(pid, senderMessage, false)
end

---@type CommandHandler
local function kick(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local targetPlayer = Players[targetPid]
    local targetIsMod, targetIsAdmin = dUtil.misc.getRanks(targetPid)
    local _, callerIsAdmin = dUtil.misc.getRanks(targetPid)

    if targetIsAdmin then
        return tes3mp.SendMessage(
            pid,
            ('You cannot kick (%s): %s from the server as they are a server administrator.\n')
            :format(targetPid, targetPlayer.accountName),
            false
        )
    elseif targetIsMod and not callerIsAdmin then
        return tes3mp.SendMessage(
            pid,
            ('You cannot kick (%s): %s from the server as they are a fellow moderator.\n')
            :format(targetPid, targetPlayer.accountName),
            false
        )
    end

    targetPlayer:Kick()
    tes3mp.SendMessage(
        pid,
        ('%s was kicked from the server by %s.\n'):format(targetPlayer.accountName, Players[pid].accountName),
        true
    )
end

---@type CommandHandler
local function leaveTeam(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local senderMessage = ('You are not an ally of %s\n'):format(logicHandler.GetChatName(targetPid))

    local callingPlayer, targetPlayer = Players[pid], Players[targetPid]
    local callingAllies, targetAllies = callingPlayer.data.alliedPlayers, targetPlayer.data.alliedPlayers

    if tableHelper.containsValue(callingAllies, targetPlayer.accountName) then
        senderMessage = ('You have stopped having %s as an ally.\n'):format(logicHandler.GetChatName(pid))
        tes3mp.SendMessage(
            targetPid,
            ('%s has stopped having you as an ally.\n'):format(logicHandler.GetChatName(pid)),
            false
        )

        tableHelper.removeValue(callingAllies, Players[targetPid].accountName)
        tableHelper.cleanNils(callingAllies)
        tableHelper.removeValue(targetAllies, Players[pid].accountName)
        tableHelper.cleanNils(targetAllies)
        callingPlayer:Save()
        callingPlayer:LoadAllies()
        targetPlayer:Save()
        targetPlayer:LoadAllies()
    end

    tes3mp.SendMessage(pid, senderMessage, false)
end

---@type CommandHandler
local function loadAllScripts(pid, _)
    I.scriptLoader.loadAllScripts()
    Players[pid]:Message(('Successfully reloaded all scripts!\n'))
end

local LoadedScriptPaths = {}

for _, scriptPath in ipairs(config.customScripts) do
    LoadedScriptPaths[scriptPath:scriptPath():lower()] = true
end

---@type CommandHandler
local function loadScript(pid, cmd)
    local scriptName, player = cmd[2], Players[pid]

    if not scriptName then
        return player:Message('Use /load <scriptName>\n')
    end

    if LoadedScriptPaths[scriptName:scriptPath():lower()] then
        return player:Message(
            'For load order reasons, you may only reload scripts which were not already defined by config.lua. To reload an existing script, reload the entire environment with /reloadlua.\n'
        )
    end

    if I.scriptLoader.loadScript(scriptName, pid) then
        player:Message(('Successfully loaded the script at scripts/custom/%s.lua\n'):format(scriptName))
    else
        player:Message(('Failed to load the script at scripts/custom/%s.lua\n'):format(scriptName))
    end
end

---@type CommandHandler
local function localMessage(pid, cmd)
    local player = Players[pid]
    local cellDescription = player.data.location.cell

    if not logicHandler.IsCellLoaded(cellDescription) then return end
    local message = ('%s to local area: %s\n'):format(
        logicHandler.GetChatName(pid),
        tableHelper.concatenateFromIndex(cmd, 2)
    )

    for _, visitorPid in pairs(LoadedCells[cellDescription].visitors) do
        tes3mp.SendMessage(visitorPid, message, false)
    end
end

---@type CommandHandler
local function me(pid, cmd)
    tes3mp.SendMessage(
        pid,
        ('%s %s\n'):format(
            logicHandler.GetChatName(pid), tableHelper.concatenateFromIndex(cmd, 2)
        ),
        true)
end

---@type CommandHandler
local function msg(pid, cmd)
    if #cmd < 3 then
        return tes3mp.SendMessage(pid, 'Usage: /message [targetPid] MESSAGE\n')
    end

    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local message = ('%s to %s: %s\n'):format(
        logicHandler.GetChatName(pid),
        logicHandler.GetChatName(targetPid),
        tableHelper.concatenateFromIndex(cmd, 3)
    )

    tes3mp.SendMessage(pid, message, false)
    tes3mp.SendMessage(targetPid, message, false)
end

---@type CommandHandler
local function overrideCollision(pid, cmd)
    local refId, state = cmd[2], cmd[3]
    local player = Players[pid]
    if not refId or (state ~= 'on' and state ~= 'off') then
        return player:Message('Not a valid argument. Use /overridecollision <refId> on/off\n')
    end

    local collisionState = state == 'on'

    local message

    if tableHelper.containsValue(config.enforcedCollisionRefIds, refId) then
        if collisionState then
            message = 'A collision-enabling override is already on'
        else
            tableHelper.removeValue(config.enforcedCollisionRefIds, refId)
            message = 'A collision-enabling override is now off'
        end
    else
        if collisionState then
            table.insert(config.enforcedCollisionRefIds, refId)
            message = 'A collision-enabling override is now on'
        else
            message = 'A collision-enabling override is already off'
        end
    end

    logicHandler.SendConfigCollisionOverrides(pid, true)
    player:Message(('%s for %s in newly loaded cells.\n'):format(message, refId))
end

---@type CommandHandler
local function overrideDestination(pid, cmd)
    if not dUtil.misc.getRanks(pid) then
        return invalidCommand(pid)
    elseif #cmd < 3 then
        return tes3mp.SendMessage(pid,
            'Invalid inputs! Use /overridedestination all/<pid> "Old Cell Name" "New Cell Name"\n')
    elseif cmd[2] ~= "all" and not logicHandler.CheckPlayerValidity(pid, cmd[2]) then
        return
    end

    local inputConcatenation = tableHelper.concatenateFromIndex(cmd, 3)
    local cellDescriptions = tableHelper.getTableFromSplit(inputConcatenation, patterns.quoteSplit)

    if #cellDescriptions ~= 2 then
        return tes3mp.SendMessage(pid,
            "Invalid inputs! Please specify two different cells with their names between quotation marks.\n")
    end

    local stateObject, targetPid

    if cmd[2] == "all" then
        stateObject = WorldInstance
    else
        targetPid = tonumber(cmd[2])
        stateObject = Players[targetPid]
    end

    -- Get rid of quotation marks
    for currentIndex, cellDescription in pairs(cellDescriptions) do
        cellDescriptions[currentIndex] = string.gsub(cellDescription, '"', '')
    end

    stateObject.data.destinationOverrides[cellDescriptions[1]] = cellDescriptions[2]
    stateObject:Save()

    if cmd[2] == "all" then
        for onlinePid, player in pairs(Players) do
            if player:IsLoggedIn() then
                WorldInstance:LoadDestinationOverrides(onlinePid)
            end
        end
    else
        Players[targetPid]:LoadDestinationOverrides()
    end

    tes3mp.SendMessage(pid, "Doors and clientside commands leading to " .. cellDescriptions[1] .. " now lead to " ..
        cellDescriptions[2] .. " instead.\n")
end

---@type CommandHandler
local function placeAt(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 3 then return end

    local refId, packetType = tableHelper.concatenateFromIndex(cmd, 3)

    if cmd[1] == 'placeat' then
        packetType = 'place'
    else
        packetType = 'spawn'
    end

    logicHandler.CreateObjectAtPlayer(targetPid, dataTableBuilder.BuildObjectData(refId), packetType)
end

---@type CommandHandler
local function players(pid, _)
    guiHelper.ShowPlayerList(pid)
end

---@type CommandHandler
local function regions(pid, _)
    local moderator = dUtil.misc.getRanks(pid)

    if not moderator then
        return invalidCommand(pid)
    end

    guiHelper.ShowRegionList(pid)
end

---@type CommandHandler
local function removeAdmin(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local targetPlayer = Players[targetPid]
    local targetName = targetPlayer.name
    local isMod, isAdmin, isOwner = dUtil.misc.getRanks(targetPid)

    if not isMod then
        return tes3mp.SendMessage(pid, ('%s is not an Admin.\n'):format(targetName), false)
    end

    if isOwner then
        tes3mp.SendMessage(pid, ('Cannot demote %s because they are a Server Owner.\n'):format(targetName), false)
    elseif isAdmin then
        tes3mp.SendMessage(pid, ('%s was demoted from Admin to Moderator!\n'):format(targetName), true)
        targetPlayer.data.settings.staffRank = 1
        targetPlayer:QuicksaveToDrive()
    end
end

---@type CommandHandler
local function removeModerator(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local targetPlayer = Players[targetPid]
    local targetName = targetPlayer.name
    local isMod, isAdmin, isOwner = dUtil.misc.getRanks(targetPid)

    if not isMod then
        return tes3mp.SendMessage(pid, ('%s is not a moderator.\n'):format(targetName), false)
    end

    if isAdmin then
        return tes3mp.SendMessage(
            pid,
            ('Cannot demote %s because they are a a Server Administrator.\n'):format(targetName),
            false
        )
    end

    tes3mp.SendMessage(pid, ('%s was demoted from Moderator!\n'):format(targetName), true)
    targetPlayer.data.settings.staffRank = 1
    targetPlayer:QuicksaveToDrive()
end

---@type CommandHandler
local function resetCell(pid, cmd)
    if not dUtil.misc.getRanks(pid) then
        return tes3mp.SendMessage(pid, "You need to be a moderator to run this command\n")
    elseif not cmd[2] then
        return tes3mp.SendMessage(pid, 'Invalid inputs! Use /resetcell "Cell Name"\n')
    end

    local inputConcatenation = tableHelper.concatenateFromIndex(cmd, 2)
    local cellDescription = string.gsub(inputConcatenation, '"', '')

    logicHandler.ResetCell(pid, cellDescription)
end

--- Set all currently recorded kills to 0 for connected players
---@type CommandHandler
local function resetKillsShared(pid, _)
    if not config.shareKills then return end

    for refId in pairs(WorldInstance.data.kills) do
        WorldInstance.data.kills[refId] = 0
    end

    WorldInstance:QuicksaveToDrive()
    WorldInstance:LoadKills(pid, true)
    tes3mp.SendMessage(pid, 'All the kill counts for creatures and NPCs have been reset.\n', true)
end

--- Set all currently recorded kills to 0 for the caller only
---@type CommandHandler
local function resetKillsUnshared(pid, _)
    if config.shareKills then return end
    local player = Players[pid]
    player.data.kills = player.data.kills or {}

    -- Set all currently recorded kills to 0 for the called
    for refId in pairs(player.data.kills) do
        player.data.kills[refId] = 0
    end

    player:QuicksaveToDrive()
    player:LoadKills(pid, false)
    tes3mp.SendMessage(pid, 'All the kill counts for creatures and NPCs have been reset.\n', false)
end

---@type CommandHandler
local function runConsole(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid then return end

    local callingPlayer, targetPlayer = Players[pid], Players[targetPid]

    if not targetPlayer.storedConsoleCommand then
        return callingPlayer:Message(
            ('There is no console command stored for player %s. Please run /storeconsole on them first.\n')
            :format(targetPid)
        )
    end

    local consoleCommand = targetPlayer.storedConsoleCommand

    local count = tonumber(cmd[3])
    if not count or count <= 1 then return end

    count = count - 1
    local interval, newInterval = 1, tonumber(cmd[4])

    if newInterval ~= nil and newInterval > 1 then
        interval = newInterval
    end

    local loopIndex = tableHelper.getUnusedNumericalIndex(ObjectLoops)
    local timerId = tes3mp.CreateTimerEx('OnObjectLoopTimeExpiration', interval, 'i', loopIndex)

    ObjectLoops[loopIndex] = {
        packetType = 'console',
        timerId = timerId,
        interval = interval,
        count = count,
        targetPid = targetPid,
        targetName = targetPlayer.accountName,
        consoleCommand = consoleCommand
    }

    tes3mp.StartTimer(timerId)
end

---@type CommandHandler
local function runStartup(pid, _)
    local _, isAdmin = dUtil.misc.getRanks(pid)

    if not isAdmin then
        return tes3mp.SendMessage(pid, "You need to be an admin to run this command\n")
    end

    for _, scriptName in ipairs(config.worldStartupScripts) do
        tes3mp.SendMessage(pid, ('Running %s%s%s script\n'):format(color.Yellow, scriptName, color.White))
        logicHandler.RunConsoleCommandOnPlayer(pid, ('startscript %s'):format(scriptName), false)
    end

    tes3mp.SendMessage(pid,
        ('%sWarning:%s Make sure to run this command again later if you reset the cells on this server.\n'):format(
            color.Red, color.White)
    )

    WorldInstance.coreVariables.hasRunStartupScripts = true
end

---@type CommandHandler
local function setAttribute(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 4 then return end

    local attributeId, attributeValue = tonumber(cmd[3]), tonumber(cmd[4])

    if not attributeId then
        attributeId = tes3mp.GetAttributeId(cmd[3])
    end

    if attributeId == -1 or attributeId >= tes3mp.GetAttributeCount() then
        return
    end

    tes3mp.SetAttributeBase(targetPid, attributeId, attributeValue)
    tes3mp.SendAttributes(targetPid)

    tes3mp.SendMessage(
        pid,
        ('%s\'s %s is now %s.\n')
        :format(Players[targetPid].name, tes3mp.GetAttributeName(attributeId), attributeValue),
        true
    )

    local attributeName = tes3mp.GetAttributeName(attributeId)
    Players[targetPid].data.attributes[attributeName].base = attributeValue
end

---@type CommandHandler
local function setAI(pid, cmd)
    local player = Players[pid]
    if #cmd < 3 then return player:Message('Invalid input to /setai') end

    local actionInput = tonumber(cmd[3])
    local actionNumericalId

    -- Allow both numerical and string input for actions (i.e. 1 or COMBAT), but
    -- convert the latter into the former
    if actionInput then
        actionNumericalId = actionInput
    else
        actionNumericalId = enumerations.ai[cmd[3]:upper()]
    end

    if not actionNumericalId then
        return player:Message(
            ('%s is not a valid AI action. Valid choices are %s\n')
            :format(actionInput, tableHelper.concatenateTableIndices(enumerations.ai, ', '))
        )
    end

    local uniqueIndex = cmd[2]
    local cell = logicHandler.GetCellContainingActor(uniqueIndex)

    if not cell then
        return player:Message(
            ('Could not find actor %s in any loaded cell.\n'):format(uniqueIndex)
        )
    end

    local actionName = tableHelper.getIndexByValue(enumerations.ai, actionNumericalId)
    local messageAction = enumerations.aiPrintableAction[actionName]

    if actionNumericalId == enumerations.ai.CANCEL then
        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId)
        player:Message(
            ('%s is now %s\n'):format(uniqueIndex, messageAction)
        )
    elseif actionNumericalId == enumerations.ai.TRAVEL then
        local posX, posY, posZ = tonumber(cmd[4]), tonumber(cmd[5]), tonumber(cmd[6])
        if not posX or not posY or not posZ then
            return player:Message('Invalid travel coordinates! Use /setai <uniqueIndex> travel <x> <y> <z>\n')
        end

        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, nil, nil, posX, posY, posZ)
        player:Message(
            ('%s is now %s %s %s %s\n'):format(uniqueIndex, messageAction, posX, posY, posZ)
        )
    elseif actionNumericalId == enumerations.ai.WANDER then
        local distance, duration = tonumber(cmd[4]), tonumber(cmd[5])
        if not distance or not duration then
            return player:Message(
                'Invalid wander parameters! Use /setai <uniqueIndex> wander <distance> <duration> true/false\n')
        end

        local shouldRepeat = cmd[6] == true

        logicHandler.SetAIForActor(
            cell,
            uniqueIndex,
            actionNumericalId,
            nil,
            nil,
            nil,
            nil,
            nil,
            distance,
            duration,
            shouldRepeat
        )

        player:Message(
            ('%s is now %s a distance of %s for a duration of %s.\n')
            :format(uniqueIndex, messageAction, distance, duration)
        )
    elseif cmd[4] then
        ---@type number|string
        local target = cmd[4]
        local numericalTarget, hasPlayerTarget = tonumber(cmd[4]), false

        if numericalTarget and logicHandler.CheckPlayerValidity(pid, target) then
            target = numericalTarget
            hasPlayerTarget = true
        end

        if hasPlayerTarget then
            logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, target)
            player:Message(
                ('%s is now %s player %s\n')
                :format(uniqueIndex, messageAction, Players[target].name)
            )
        else
            logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, nil, target)
            player:Message(
                ('%s is now %s object %s\n')
                :format(uniqueIndex, messageAction, Players[target].name)
            )
        end
    else
        player:Message('Invalid AI action!\n')
    end
end

---@type CommandHandler
local function setAuthority(pid, cmd)
    if #cmd < 3 then return end

    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local cellDescription = tableHelper.concatenateFromIndex(cmd, 3)

    -- Get rid of quotation marks
    cellDescription = cellDescription:gsub('"', '')

    if not logicHandler.IsCellLoaded(cellDescription) then
        return tes3mp.SendMessage(pid, 'Cell "' .. cellDescription .. '" isn\'t loaded!\n', false)
    end

    logicHandler.SetCellAuthority(targetPid, cellDescription)
end

local ValidStates = {
    disabled = true,
    on = true,
    off = true,
}

---@type CommandHandler
local function setBedRest(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local mode, state = (cmd[3] or ''):lower(), ''

    if not ValidStates[mode] then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setbedrest <pid> on/off/default\n', false)
    end

    local player = Players[targetPid]
    if mode == 'on' then
        player:SetBedRestAllowed(true)
        state = 'enabled'
    elseif mode == 'off' then
        player:SetBedRestAllowed(false)
        state = 'disabled'
    elseif mode == 'default' then
        player:SetBedRestAllowed('default')
        state = 'reset to default'
    end

    player:LoadSettings()
    tes3mp.SendMessage(pid, ('Bed resting for %s %s.\n'):format(player.name, state), false)

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, ('Bed resting %s.\n'):format(state), false)
    end
end

---@type CommandHandler
local function setCollision(pid, cmd)
    if not cmd[2] or (cmd[3] ~= 'on' and cmd[3] ~= 'off') then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setcollision <category> on/off\n', false)
    end

    local collisionState, categoryInput = cmd[3] == 'on', cmd[2]:upper()
    local categoryValue = enumerations.objectCategories[categoryInput]

    if not categoryValue then
        return tes3mp.SendMessage(
            pid,
            ('%s is not a valid object category. Valid choices are %s\n')
            :format(categoryInput, tableHelper.concatenateTableIndices(enumerations.objectCategories, ', ')),
            false
        )
    end

    if categoryValue == enumerations.objectCategories.PLAYER then
        tes3mp.SetPlayerCollisionState(collisionState)
    elseif categoryValue == enumerations.objectCategories.ACTOR then
        tes3mp.SetActorCollisionState(collisionState)
    elseif categoryValue == enumerations.objectCategories.PLACED_OBJECT then
        tes3mp.SetPlacedObjectCollisionState(collisionState)

        if cmd[4] == 'on' then
            tes3mp.UseActorCollisionForPlacedObjects(true)
        elseif cmd[4] == 'off' then
            tes3mp.UseActorCollisionForPlacedObjects(false)
        end
    end

    tes3mp.SendWorldCollisionOverride(pid, true)
    tes3mp.SendMessage(
        pid,
        ('Collision for %s is now %s for all newly loaded cells.\n'):format(categoryInput, cmd[3]),
        false
    )
end

---@type CommandHandler
local function setConsole(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local mode, state = (cmd[3] or ''):lower(), ''

    if not ValidStates[mode] then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setconsole <pid> on/off/default\n', false)
    end

    local player = Players[targetPid]
    if mode == 'on' then
        player:SetConsoleAllowed(true)
        state = 'enabled'
    elseif mode == 'off' then
        player:SetConsoleAllowed(false)
        state = 'disabled'
    elseif mode == 'default' then
        player:SetConsoleAllowed('default')
        state = 'reset to default'
    end

    player:LoadSettings()
    tes3mp.SendMessage(pid, ('Console for %s %s\n'):format(player.name, state), false)

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, ('Console %s.\n'):format(state), false)
    end
end

---@type CommandHandler
local function setDay(pid, cmd)
    local inputValue = tonumber(cmd[2])

    if type(inputValue) ~= "number" then return end

    local daysInMonth = WorldInstance.monthLengths[WorldInstance.data.time.month]

    if inputValue > daysInMonth then
        return tes3mp.SendMessage(
            pid,
            ('There are only %s days in the current month.\n')
            :format(daysInMonth),
            false
        )
    end

    WorldInstance.data.time.day = inputValue
    WorldInstance:QuicksaveToDrive()
    WorldInstance:LoadTime(pid, true)
end

---@type CommandHandler
local function setDifficulty(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 3 then return end

    ---@type number|string|nil
    local difficulty = tonumber(cmd[3])
    if not difficulty then
        if cmd[3] ~= 'default' then
            return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setdifficulty <pid> <value>\n', false)
        end

        difficulty = cmd[3]
    end

    local player = Players[targetPid]
    player:SetDifficulty(difficulty)
    player:LoadSettings()
    tes3mp.SendMessage(
        pid,
        ('Difficulty for %s is now %s.\n'):format(player.name, difficulty),
        true)
end

---@type CommandHandler
local function setExterior(pid, cmd)
    local xCoord, yCoord = tonumber(cmd[2]), tonumber(cmd[3])

    if not xCoord or not yCoord then
        return tes3mp.SendMessage(pid, 'Invalid input to setExt command! Usage: /setext <X> <Y>')
    end

    tes3mp.SetExteriorCell(pid, xCoord, yCoord)
end

---@type CommandHandler
local function setHair(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local newHair = tableHelper.concatenateFromIndex(cmd, 3)

    Players[targetPid].data.character.hair = newHair
    tes3mp.SetHair(targetPid, newHair)
    tes3mp.SetResetStats(targetPid, false)
    tes3mp.SendBaseInfo(targetPid)
end

---@type CommandHandler
local function setHead(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local newHead = tableHelper.concatenateFromIndex(cmd, 3)

    Players[targetPid].data.character.head = newHead
    tes3mp.SetHead(targetPid, newHead)
    tes3mp.SetResetStats(targetPid, false)
    tes3mp.SendBaseInfo(targetPid)
end

---@type CommandHandler
local function setHour(pid, cmd)
    local inputValue = tonumber(cmd[2])
    if not inputValue then return end

    if inputValue == 24 then
        inputValue = 0
    elseif inputValue < 0 or inputValue >= 24 then
        return tes3mp.SendMessage(pid, 'There aren\'t that many hours in a day.\n', false)
    end


    WorldInstance.data.time.hour = inputValue
    WorldInstance:QuicksaveToDrive()
    WorldInstance:LoadTime(pid, true)
    HourCounter = inputValue
end

---@type CommandHandler
local function setLogLevel(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    ---@type string|integer
    local logLevel = cmd[3]

    local logLevNum = tonumber(logLevel)
    if type(logLevNum) == 'number' then
        logLevel = math.floor(logLevNum)
    end

    if logLevel ~= 'default' and type(logLevel) ~= 'number' then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setloglevel <pid> <value>\n', false)
    end

    local player = Players[targetPid]
    player:SetEnforcedLogLevel(logLevel)
    player:LoadSettings()
    tes3mp.SendMessage(
        pid,
        ('Enforced log level for %s is now %s\n'):format(player.name, logLevel),
        true
    )
end

---@type CommandHandler
local function setPhysicsFPS(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 3 then return end

    ---@type number|string|nil
    local physicsFramerate = tonumber(cmd[3])
    if not physicsFramerate then
        if cmd[3] ~= 'default' then
            return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setphysicsfps <pid> <value>\n', false)
        end

        physicsFramerate = cmd[3]
    end

    local player = Players[targetPid]
    player:SetPhysicsFramerate(physicsFramerate)
    player:LoadSettings()
    tes3mp.SendMessage(pid, ('Physics framerate for %s is now %s.\n'):format(player.name, physicsFramerate), true)
end

---@type CommandHandler
local function setPlayerModel(pid, cmd)
    local _, isAdmin = dUtil.misc.getRanks(pid)

    if not isAdmin then
        return tes3mp.SendMessage(pid, "You need to be an admin to run this command\n")
    elseif not cmd[3] then
        return tes3mp.SendMessage(pid, 'Invalid inputs! Use /setmodel <pid> "Model name"\n')
    end

    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid then return end

    local targetPlayer = Players[targetPid]

    local inputConcatenation = tableHelper.concatenateFromIndex(cmd, 3)
    local modelName = string.gsub(inputConcatenation, '"', '')

    targetPlayer.data.character.modelOverride = modelName
    targetPlayer:LoadCharacter()
    targetPlayer:Message("Your model has been changed.\n")
end

---@type CommandHandler
local function setMomentum(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local xValue, yValue, zValue = tonumber(cmd[3]), tonumber(cmd[4]), tonumber(cmd[5])
    if not xValue or not yValue or not zValue then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setmomentum <pid> <x> <y> <z>\n', false)
    end

    tes3mp.SetMomentum(targetPid, xValue, yValue, zValue)
    tes3mp.SendMomentum(targetPid)
end

---@type CommandHandler
local function setMonth(pid, cmd)
    local inputValue = tonumber(cmd[2])

    if type(inputValue) ~= "number" then return end

    WorldInstance.data.time.month = inputValue
    WorldInstance:QuicksaveToDrive()
    WorldInstance:LoadTime(pid, true)
end

---@type CommandHandler
local function setRace(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local newRace = tableHelper.concatenateFromIndex(cmd, 3)

    Players[targetPid].data.character.race = newRace
    tes3mp.SetRace(targetPid, newRace)
    tes3mp.SetResetStats(targetPid, false)
    tes3mp.SendBaseInfo(targetPid)
end

---@type CommandHandler
local function setScale(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local scale = tonumber(cmd[3])

    if type(scale) ~= 'number' then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setscale <pid> <value>.\n', false)
    end

    local player = Players[targetPid]
    player:SetScale(scale)
    player:LoadShapeshift()

    tes3mp.SendMessage(
        pid,
        ('Scale for %s is now %s\n'):format(player.name, scale),
        false
    )

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, ('Your scale is now %s\n'):format(scale), false)
    end
end

---@type CommandHandler
local function setSkill(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 4 then return end

    local skillId, skillValue = tonumber(cmd[3]), tonumber(cmd[4])

    if not skillId then
        skillId = tes3mp.GetSkillId(cmd[3])
    end

    if skillId == -1 or skillId >= tes3mp.GetSkillCount() then
        return
    end

    tes3mp.SetSkillBase(targetPid, skillId, skillValue)
    tes3mp.SendSkills(targetPid)

    tes3mp.SendMessage(
        pid,
        ('%s\'s %s is now %s.\n')
        :format(Players[targetPid].name, tes3mp.GetSkillName(skillId), skillValue),
        true
    )

    local skillName = tes3mp.GetSkillName(skillId)
    Players[targetPid].data.skills[skillName].base = skillValue
end

local ValidTimeInputs = {
    both = true,
    day = true,
    night = true,
}

---@type CommandHandler
local function setTimescale(pid, cmd)
    local inputPeriod = cmd[2]:lower()
    local inputValue = tonumber(cmd[3])

    if inputValue or not ValidTimeInputs[inputPeriod] then
        return tes3mp.SendMessage(pid, 'Invalid input! Please use /settimescale day/night/both <value>\n', false)
    end


    if inputPeriod == 'day' or inputPeriod == 'both' then
        WorldInstance.data.time.dayTimeScale = inputValue
    end

    if inputPeriod == 'night' or inputPeriod == 'both' then
        WorldInstance.data.time.nightTimeScale = inputValue
    end

    WorldInstance:QuicksaveToDrive()
    WorldInstance:UpdateFrametimeMultiplier()
    WorldInstance:LoadTime(pid, true)
end

---@type CommandHandler
local function setWait(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local mode, state = (cmd[3] or ''):lower(), ''

    if not ValidStates[mode] then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwait <pid> on/off/default\n', false)
    end

    local player = Players[targetPid]
    if mode == 'on' then
        player:SetWaitAllowed(true)
        state = 'enabled'
    elseif mode == 'off' then
        player:SetWaitAllowed(false)
        state = 'disabled'
    elseif mode == 'default' then
        player:SetWaitAllowed('default')
        state = 'reset to default'
    end

    player:LoadSettings()
    tes3mp.SendMessage(pid, ('Waiting for %s %s\n'):format(player.name, state), false)

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, ('Waiting %s.\n'):format(state), false)
    end
end

---@type CommandHandler
local function setWerewolf(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local player = Players[targetPid]
    local message

    if cmd[3] == 'on' then
        player:SetWerewolfState(true)
        message = ('Werewolf state for %s enabled\n'):format(player.name)
    elseif cmd[3] == 'off' then
        player:SetWerewolfState(false)
        message = ('Werewolf state for %s disabled\n'):format(player.name)
    else
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwerewolf <pid> on/off.\n', false)
    end

    player:LoadShapeshift()

    tes3mp.SendMessage(pid, message)
end

---@type CommandHandler
local function setWildernessRest(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid then return end

    local mode, state = (cmd[3] or ''):lower(), ''

    if not ValidStates[mode] then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwildrest <pid> on/off/default\n', false)
    end

    local player = Players[targetPid]
    if mode == 'on' then
        player:SetWildernessRestAllowed(true)
        state = 'enabled'
    elseif mode == 'off' then
        player:SetWildernessRestAllowed(false)
        state = 'disabled'
    elseif mode == 'default' then
        player:SetWildernessRestAllowed('default')
        state = 'reset to default'
    end

    player:LoadSettings()
    tes3mp.SendMessage(pid, ('Wilderness resting for %s %s\n'):format(player.name, state), false)

    if targetPid ~= pid then
        tes3mp.SendMessage(targetPid, ('Wilderness resting %s.\n'):format(state), false)
    end
end

---@type CommandHandler
local function speech(pid, cmd)
    local speechNum = tonumber(cmd[3])

    if #cmd < 3 or not speechNum or not speechHelper.PlaySpeech(pid, cmd[2], speechNum) then
        return Players[pid]:Message(
            ('That is not a valid speech. Try one of the following:\n%s\n')
            :format(speechHelper.GetPrintableValidListForPid(pid))
        )
    end
end

---@type CommandHandler
local function storeConsole(pid, cmd)
    if not cmd[2] or not cmd[3] then return end

    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid then return end

    Players[targetPid].storedConsoleCommand = tableHelper.concatenateFromIndex(cmd, 3)
    Players[pid]:Message(('That console command is now stored for player %s\n'):format(targetPid))
end

---@type CommandHandler
local function storeRecord(pid, cmd)
    if not cmd[2] or not cmd[3] then return end
    recordHelper.storeRecord(pid, cmd)
end

---@type CommandHandler
local function suicide(pid, _)
    if config.allowSuicideCommand then
        tes3mp.SetHealthCurrent(pid, 0)
        tes3mp.SendStatsDynamic(pid)
    else
        tes3mp.SendMessage(pid, 'That command is disabled on this server.\n', false)
    end
end

---@type CommandHandler
local function teleport(pid, cmd)
    if cmd[2] == "all" then
        for iteratorPid, player in pairs(Players) do
            if iteratorPid ~= pid then
                if player:IsLoggedIn() then
                    logicHandler.TeleportToPlayer(pid, iteratorPid, pid)
                end
            end
        end
    else
        logicHandler.TeleportToPlayer(pid, cmd[2], pid)
    end
end

---@type CommandHandler
local function teleportTo(pid, cmd)
    logicHandler.TeleportToPlayer(pid, pid, cmd[2])
end

---@type CommandHandler
local function unban(pid, cmd)
    if not dUtil.misc.getRanks(pid) or #cmd < 3 then
        return invalidCommand(pid)
    end

    if cmd[2] == "ip" then
        local ipAddress = cmd[3]

        if tableHelper.containsValue(banList.ipAddresses, ipAddress) then
            tableHelper.removeValue(banList.ipAddresses, ipAddress)
            SaveBanList()

            tes3mp.SendMessage(pid, ('%s is now unbanned.\n'):format(ipAddress), false)

            if dUtil.misc.isValidIP(ipAddress) then
                tes3mp.UnbanAddress(ipAddress)
            else
                tes3mp.SendMessage(pid, ('%s is not a valid IP Address! Cannot unban it!'):format(ipAddress))
            end
        else
            tes3mp.SendMessage(pid, ('%s is not banned.\n'):format(ipAddress), false)
        end
    elseif cmd[2] == "name" or cmd[2] == "player" then
        local targetName = tableHelper.concatenateFromIndex(cmd, 3)
        logicHandler.UnbanPlayer(pid, targetName)
    else
        tes3mp.SendMessage(pid, 'Invalid input for unban.\n', false)
    end
end

---@type CommandHandler
local function useCreatureName(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid or not targetPid or #cmd < 3 then return end

    if cmd[3] ~= 'on' and cmd[3] ~= 'off' then
        return tes3mp.SendMessage(pid, 'Not a valid argument. Use /usecreaturename <pid> on/off\n', false)
    end

    local nameState = cmd[3] == 'on'
    Players[targetPid].data.shapeshift.displayCreatureName = nameState
    tes3mp.SetCreatureNameDisplayState(targetPid, nameState)
    tes3mp.SendShapeshift(targetPid)
end

---@type TES3MPScriptRegistration
return {
    chatCommands = {
        -- Short commands
        a = { callback = anim, },
        gt = { callback = greenText },
        ips = { callback = ipaddresses, },
        l = { callback = localMessage, },
        lm = { callback = localMessage, },
        msg = { callback = msg, },
        s = { callback = speech, },
        tp = { callback = teleport, rankRequirement = enumerations.staffRank.MODERATOR, },
        tpto = { callback = teleportTo, rankRequirement = enumerations.staffRank.MODERATOR, },

        -- Long commands
        addAdmin = { callback = addAdmin, rankRequirement = enumerations.staffRank.ADMIN, },
        addModerator = { callback = addModerator, rankRequirement = enumerations.staffRank.ADMIN, },
        advex = { callback = advancedExample, },
        advancedExample = { callback = advancedExample, },
        anim = { callback = anim, },
        ban = { callback = ban, },
        banlist = { callback = banlist, },
        cells = { callback = cells, },
        confiscate = { callback = confiscate, rankRequirement = enumerations.staffRank.MODERATOR, },
        craft = { callback = craft, },
        createRecord = { callback = createRecord, rankRequirement = enumerations.staffRank.ADMIN, },
        disguise = { callback = disguise, enumerations.staffRank.ADMIN, },
        fixMe = { callback = fixMe, },
        getPos = { callback = getPos, rankRequirement = enumerations.staffRank.MODERATOR, },
        greentext = { callback = greenText, },
        invite = { callback = inviteAlly, },
        ipaddresses = { callback = ipaddresses, },
        localMessage = { callback = localMessage, },
        help = { callback = help, },
        join = { callback = joinTeam, },
        kick = { callback = kick, rankRequirement = enumerations.staffRank.MODERATOR, },
        leave = { callback = leaveTeam, },
        list = { callback = players, },
        load = { callback = loadScript, rankRequirement = enumerations.staffRank.ADMIN, },
        loadScript = { callback = loadScript, rankRequirement = enumerations.staffRank.ADMIN, },
        me = { callback = me, },
        message = { callback = msg, },
        overideCollision = { callback = overrideCollision, rankRequirement = enumerations.staffRank.ADMIN, },
        overridedestination = { callback = overrideDestination, },
        placeAt = { callback = placeAt, rankRequirement = enumerations.staffRank.ADMIN, },
        players = { callback = players, },
        regions = { callback = regions, },
        reloadLua = { callback = loadAllScripts, rankRequirement = enumerations.staffRank.ADMIN, },
        resetcell = { callback = resetCell, },
        removeAdmin = { callback = removeAdmin, rankRequirement = enumerations.staffRank.OWNER, },
        resetKills = { callback = resetKillsShared, rankRequirement = enumerations.staffRank.MODERATOR, },
        removeModerator = { callback = removeModerator, rankRequirement = enumerations.staffRank.ADMIN, },
        resetMyKills = { callback = resetKillsUnshared, rankRequirement = enumerations.staffRank.MODERATOR, },
        runConsole = { callback = runConsole, rankRequirement = enumerations.staffRank.ADMIN, },
        runstartup = { callback = runStartup, },
        setAI = { callback = setAI, rankRequirement = enumerations.staffRank.ADMIN, },
        setAttribute = { callback = setAttribute, rankRequirement = enumerations.staffRank.MODERATOR, },
        setauthority = { callback = setAuthority, rankRequirement = enumerations.staffRank.MODERATOR, },
        setBedRest = { callback = setBedRest, rankRequirement = enumerations.staffRank.ADMIN, },
        setCollision = { callback = setCollision, rankRequirement = enumerations.staffRank.ADMIN, },
        setConsole = { callback = setConsole, rankRequirement = enumerations.staffRank.ADMIN, },
        setday = { callback = setDay, rankRequirement = enumerations.staffRank.MODERATOR, },
        setDifficulty = { callback = setDifficulty, rankRequirement = enumerations.staffRank.ADMIN, },
        setEnforcedLogLevel = { callback = setLogLevel, rankRequirement = enumerations.staffRank.ADMIN, },
        setExt = { callback = setExterior, rankRequirement = enumerations.staffRank.ADMIN, },
        setExterior = { callback = setExterior, rankRequirement = enumerations.staffRank.ADMIN, },
        sethair = { callback = setHair, rankRequirement = enumerations.staffRank.ADMIN, },
        sethead = { callback = setHead, rankRequirement = enumerations.staffRank.ADMIN, },
        setHour = { callback = setHour, rankRequirement = enumerations.staffRank.MODERATOR, },
        setLogLevel = { callback = setLogLevel, rankRequirement = enumerations.staffRank.ADMIN, },
        setmodel = { callback = setPlayerModel, },
        setMomentum = { callback = setMomentum, rankRequirement = enumerations.staffRank.MODERATOR, },
        setmonth = { callback = setMonth, rankRequirement = enumerations.staffRank.MODERATOR, },
        setPhysicsFPS = { callback = setPhysicsFPS, rankRequirement = enumerations.staffRank.ADMIN, },
        setrace = { callback = setRace, rankRequirement = enumerations.staffRank.ADMIN, },
        setScale = { callback = setScale, rankRequirement = enumerations.staffRank.ADMIN, },
        setSkill = { callback = setSkill, rankRequirement = enumerations.staffRank.MODERATOR, },
        setTimescale = { callback = setTimescale, rankRequirement = enumerations.staffRank.MODERATOR, },
        setWait = { callback = setWait, rankRequirement = enumerations.staffRank.ADMIN, },
        setWerewolf = { callback = setWerewolf, rankRequirement = enumerations.staffRank.ADMIN, },
        setWildRest = { callback = setWildernessRest, rankRequirement = enumerations.staffRank.ADMIN, },
        spawnAt = { callback = placeAt, rankRequirement = enumerations.staffRank.ADMIN, },
        speech = { callback = speech, },
        storeConsole = { callback = storeConsole, rankRequirement = enumerations.staffRank.ADMIN, },
        storeRecord = { callback = storeRecord, rankRequirement = enumerations.staffRank.ADMIN, },
        suicide = { callback = suicide, },
        teleport = { callback = teleport, rankRequirement = enumerations.staffRank.MODERATOR, },
        teleportto = { callback = teleportTo, rankRequirement = enumerations.staffRank.MODERATOR, },
        unban = { callback = unban, },
        useCreatureName = { callback = useCreatureName, rankRequirement = enumerations.staffRank.ADMIN, },
    },
}
