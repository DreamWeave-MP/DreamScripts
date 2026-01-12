local color = require 'color'
local config = require 'tes3mp.config'
local guiHelper = require 'tes3mp.util.gui'
local logicHandler = require 'tes3mp.logicHandler'
local patterns = require 'patterns'

---@type DUtilModule
local dUtil = require 'dUtil.init'

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
local function greenText(pid, cmd)
    local message = logicHandler.GetChatName(pid) .. ": " .. color.GreenText ..
        ">" .. tableHelper.concatenateFromIndex(cmd, 2) .. "\n"
    tes3mp.SendMessage(pid, message, true)
end

---@type CommandHandler
local function inviteAlly(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid then return end

    local callingPlayer, targetPlayer, senderMessage = Players[pid], Players[targetPid], nil
    local targetName = logicHandler.getChatName(targetPid)

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
    if not isValid then return end

    local callingPlayer, targetPlayer, senderMessage = Players[pid], Players[targetPid], nil
    local targetName = logicHandler.getChatName(targetPid)

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
local function leaveTeam(pid, cmd)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
    if not isValid then return end

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
    if not isValid then return end

    local message = ('%s to %s: %s\n'):format(
        logicHandler.GetChatName(pid),
        logicHandler.GetChatName(targetPid),
        tableHelper.concatenateFromIndex(cmd, 3)
    )

    tes3mp.SendMessage(pid, message, false)
    tes3mp.SendMessage(targetPid, message, false)
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

---@type TES3MPScriptRegistration
return {
    chatCommands = {
        -- Short commands
        gt = { callback = greenText },
        ips = { callback = ipaddresses, },
        l = { callback = localMessage, },
        lm = { callback = localMessage, },
        msg = { callback = msg, },

        -- Long commands
        ban = { callback = ban, },
        banlist = { callback = banlist, },
        cells = { callback = cells, },
        greentext = { callback = greenText, },
        invite = { callback = inviteAlly, },
        ipaddresses = { callback = ipaddresses, },
        localMessage = { callback = localMessage, },
        join = { callback = joinTeam, },
        leave = { callback = leaveTeam, },
        list = { callback = players, },
        me = { callback = me, },
        message = { callback = msg, },
        overridedestination = { callback = overrideDestination, },
        players = { callback = players, },
        regions = { callback = regions, },
        resetcell = { callback = resetCell, },
        runstartup = { callback = runStartup, },
        setmodel = { callback = setPlayerModel, },
        unban = { callback = unban, },
    },
}
