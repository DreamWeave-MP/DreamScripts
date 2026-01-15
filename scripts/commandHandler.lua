---@class CommandHandler
local commandHandler = {}

function commandHandler.ProcessCommand(pid, cmd)
    if cmd[1] == nil then
        local message = 'Please use a command after the / symbol.\n'
        tes3mp.SendMessage(pid, color.Error .. message .. color.Default, false)
        return false
    else
        -- The command itself should always be lowercase
        cmd[1] = string.lower(cmd[1])
    end

    local serverOwner = false
    local admin = false
    local moderator = false

    if Players[pid]:IsServerOwner() then
        serverOwner = true
        admin = true
        moderator = true
    elseif Players[pid]:IsAdmin() then
        admin = true
        moderator = true
    elseif Players[pid]:IsModerator() then
        moderator = true
    end

    if cmd[1] == 'setattr' and moderator then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = Players[targetPid].name

            if cmd[3] ~= nil and cmd[4] ~= nil and tonumber(cmd[4]) ~= nil then
                local attrId
                local value = tonumber(cmd[4])

                if tonumber(cmd[3]) ~= nil then
                    attrId = tonumber(cmd[3])
                else
                    attrId = tes3mp.GetAttributeId(cmd[3])
                end

                if attrId ~= -1 and attrId < tes3mp.GetAttributeCount() then
                    tes3mp.SetAttributeBase(targetPid, attrId, value)
                    tes3mp.SendAttributes(targetPid)

                    local message = targetName .. '\'s ' .. tes3mp.GetAttributeName(attrId) ..
                        ' is now ' .. value .. '\n'
                    tes3mp.SendMessage(pid, message, true)
                    local attributeName = tes3mp.GetAttributeName(attrId)
                    Players[targetPid].data.attributes[attributeName].base = value
                end
            end
        end
    elseif cmd[1] == 'setskill' and moderator then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = Players[targetPid].name

            if cmd[3] ~= nil and cmd[4] ~= nil and tonumber(cmd[4]) ~= nil then
                local skillId
                local value = tonumber(cmd[4])

                if tonumber(cmd[3]) ~= nil then
                    skillId = tonumber(cmd[3])
                else
                    skillId = tes3mp.GetSkillId(cmd[3])
                end

                if skillId ~= -1 and skillId < tes3mp.GetSkillCount() then
                    tes3mp.SetSkillBase(targetPid, skillId, value)
                    tes3mp.SendSkills(targetPid)

                    local message = targetName .. '\'s ' .. tes3mp.GetSkillName(skillId) ..
                        ' is now ' .. value .. '\n'
                    tes3mp.SendMessage(pid, message, true)
                    local skillName = tes3mp.GetSkillName(skillId)
                    Players[targetPid].data.skills[skillName].base = value
                end
            end
        end
    elseif cmd[1] == 'setmomentum' and moderator then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local xValue = tonumber(cmd[3])
            local yValue = tonumber(cmd[4])
            local zValue = tonumber(cmd[5])

            if type(xValue) == 'number' and type(yValue) == 'number' and
                type(zValue) == 'number' then
                tes3mp.SetMomentum(targetPid, xValue, yValue, zValue)
                tes3mp.SendMomentum(targetPid)
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setmomentum <pid> <x> <y> <z>\n', false)
            end
        end
    elseif cmd[1] == 'setext' and admin then
        tes3mp.SetExterior(pid, cmd[2], cmd[3])
    elseif cmd[1] == 'getpos' and moderator then
        logicHandler.PrintPlayerPosition(pid, cmd[2])
    elseif (cmd[1] == 'setdifficulty' or cmd[1] == 'setdiff') and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local difficulty = cmd[3]

            if type(tonumber(difficulty)) == 'number' then
                difficulty = tonumber(difficulty)
            end

            if difficulty == 'default' or type(difficulty) == 'number' then
                Players[targetPid]:SetDifficulty(difficulty)
                Players[targetPid]:LoadSettings()
                tes3mp.SendMessage(pid, 'Difficulty for ' .. Players[targetPid].name .. ' is now ' ..
                    difficulty .. '\n', true)
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setdifficulty <pid> <value>\n', false)
                return false
            end
        end
    elseif cmd[1] == 'setconsole' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local state = ''

            if cmd[3] == 'on' then
                Players[targetPid]:SetConsoleAllowed(true)
                state = ' enabled.\n'
            elseif cmd[3] == 'off' then
                Players[targetPid]:SetConsoleAllowed(false)
                state = ' disabled.\n'
            elseif cmd[3] == 'default' then
                Players[targetPid]:SetConsoleAllowed('default')
                state = ' reset to default.\n'
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setconsole <pid> on/off/default\n', false)
                return false
            end

            Players[targetPid]:LoadSettings()
            tes3mp.SendMessage(pid, 'Console for ' .. Players[targetPid].name .. state, false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Console' .. state, false)
            end
        end
    elseif cmd[1] == 'setbedrest' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local state = ''

            if cmd[3] == 'on' then
                Players[targetPid]:SetBedRestAllowed(true)
                state = ' enabled.\n'
            elseif cmd[3] == 'off' then
                Players[targetPid]:SetBedRestAllowed(false)
                state = ' disabled.\n'
            elseif cmd[3] == 'default' then
                Players[targetPid]:SetBedRestAllowed('default')
                state = ' reset to default.\n'
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setbedrest <pid> on/off/default\n', false)
                return false
            end

            Players[targetPid]:LoadSettings()
            tes3mp.SendMessage(pid, 'Bed resting for ' .. Players[targetPid].name .. state, false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Bed resting' .. state, false)
            end
        end
    elseif (cmd[1] == 'setwildernessrest' or cmd[1] == 'setwildrest') and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local state = ''

            if cmd[3] == 'on' then
                Players[targetPid]:SetWildernessRestAllowed(true)
                state = ' enabled.\n'
            elseif cmd[3] == 'off' then
                Players[targetPid]:SetWildernessRestAllowed(false)
                state = ' disabled.\n'
            elseif cmd[3] == 'default' then
                Players[targetPid]:SetWildernessRestAllowed('default')
                state = ' reset to default.\n'
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwildrest <pid> on/off/default\n', false)
                return false
            end

            Players[targetPid]:LoadSettings()
            tes3mp.SendMessage(pid, 'Wilderness resting for ' .. Players[targetPid].name .. state, false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Wilderness resting' .. state, false)
            end
        end
    elseif cmd[1] == 'setwait' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local state = ''

            if cmd[3] == 'on' then
                Players[targetPid]:SetWaitAllowed(true)
                state = ' enabled.\n'
            elseif cmd[3] == 'off' then
                Players[targetPid]:SetWaitAllowed(false)
                state = ' disabled.\n'
            elseif cmd[3] == 'default' then
                Players[targetPid]:SetWaitAllowed('default')
                state = ' reset to default.\n'
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwait <pid> on/off/default\n', false)
                return false
            end

            Players[targetPid]:LoadSettings()
            tes3mp.SendMessage(pid, 'Waiting for ' .. Players[targetPid].name .. state, false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Waiting' .. state, false)
            end
        end
    elseif (cmd[1] == 'setphysicsfps' or cmd[1] == 'setphysicsframerate') and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local physicsFramerate = cmd[3]

            if type(tonumber(physicsFramerate)) == 'number' then
                physicsFramerate = tonumber(physicsFramerate)
            end

            if physicsFramerate == 'default' or type(physicsFramerate) == 'number' then
                Players[targetPid]:SetPhysicsFramerate(physicsFramerate)
                Players[targetPid]:LoadSettings()
                tes3mp.SendMessage(pid, 'Physics framerate for ' .. Players[targetPid].name
                    .. ' is now ' .. physicsFramerate .. '\n', true)
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setphysicsfps <pid> <value>\n', false)
                return false
            end
        end
    elseif (cmd[1] == 'setloglevel' or cmd[1] == 'setenforcedloglevel') and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local logLevel = cmd[3]

            if type(tonumber(logLevel)) == 'number' then
                logLevel = tonumber(logLevel)
            end

            if logLevel == 'default' or type(logLevel) == 'number' then
                Players[targetPid]:SetEnforcedLogLevel(logLevel)
                Players[targetPid]:LoadSettings()
                tes3mp.SendMessage(pid, 'Enforced log level for ' .. Players[targetPid].name
                    .. ' is now ' .. logLevel .. '\n', true)
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setloglevel <pid> <value>\n', false)
                return false
            end
        end
    elseif cmd[1] == 'setscale' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local scale = cmd[3]

            if type(tonumber(scale)) == 'number' then
                scale = tonumber(scale)
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setscale <pid> <value>.\n', false)
                return false
            end

            Players[targetPid]:SetScale(scale)
            Players[targetPid]:LoadShapeshift()
            tes3mp.SendMessage(pid, 'Scale for ' .. Players[targetPid].name .. ' is now ' .. scale .. '\n', false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Your scale is now ' .. scale .. '\n', false)
            end
        end
    elseif cmd[1] == 'setwerewolf' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local targetName = ''
            local state = ''

            if cmd[3] == 'on' then
                Players[targetPid]:SetWerewolfState(true)
                state = ' enabled.\n'
            elseif cmd[3] == 'off' then
                Players[targetPid]:SetWerewolfState(false)
                state = ' disabled.\n'
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /setwerewolf <pid> on/off.\n', false)
                return false
            end

            Players[targetPid]:LoadShapeshift()
            tes3mp.SendMessage(pid, 'Werewolf state for ' .. Players[targetPid].name .. state, false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'Werewolf state' .. state, false)
            end
        end
    elseif cmd[1] == 'disguise' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local creatureRefId = tableHelper.concatenateFromIndex(cmd, 3)

            Players[targetPid].data.shapeshift.creatureRefId = creatureRefId
            tes3mp.SetCreatureRefId(targetPid, creatureRefId)
            tes3mp.SendShapeshift(targetPid)

            if creatureRefId == '' then
                creatureRefId = 'nothing'
            end

            tes3mp.SendMessage(pid, Players[targetPid].accountName .. ' is now disguised as ' ..
                creatureRefId .. '\n', false)
            if targetPid ~= pid then
                tes3mp.SendMessage(targetPid, 'You are now disguised as ' .. creatureRefId .. '\n', false)
            end
        end
    elseif cmd[1] == 'usecreaturename' and admin then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])
            local nameState

            if cmd[3] == 'on' then
                nameState = true
            elseif cmd[3] == 'off' then
                nameState = false
            else
                tes3mp.SendMessage(pid, 'Not a valid argument. Use /usecreaturename <pid> on/off\n', false)
                return false
            end

            Players[targetPid].data.shapeshift.displayCreatureName = nameState
            tes3mp.SetCreatureNameDisplayState(targetPid, nameState)
            tes3mp.SendShapeshift(targetPid)
        end
    elseif cmd[1] == 'sethour' and moderator then
        local inputValue = tonumber(cmd[2])

        if type(inputValue) == 'number' then
            if inputValue == 24 then
                inputValue = 0
            end

            if inputValue >= 0 and inputValue < 24 then
                WorldInstance.data.time.hour = inputValue
                WorldInstance:QuicksaveToDrive()
                WorldInstance:LoadTime(pid, true)
                HourCounter = inputValue
            else
                tes3mp.SendMessage(pid, 'There aren\'t that many hours in a day.\n', false)
            end
        end
    elseif cmd[1] == 'settimescale' and moderator then
        local inputPeriod = string.lower(tostring(cmd[2]))
        local inputValue = tonumber(cmd[3])

        if tableHelper.containsValue({ 'day', 'night', 'both' }, inputPeriod) and type(inputValue) == 'number' then
            if inputPeriod == 'day' or inputPeriod == 'both' then
                WorldInstance.data.time.dayTimeScale = inputValue
            end

            if inputPeriod == 'night' or inputPeriod == 'both' then
                WorldInstance.data.time.nightTimeScale = inputValue
            end

            WorldInstance:QuicksaveToDrive()
            WorldInstance:UpdateFrametimeMultiplier()
            WorldInstance:LoadTime(pid, true)
        else
            tes3mp.SendMessage(pid, 'Invalid input! Please use /settimescale day/night/both <value>\n', false)
        end
    elseif cmd[1] == 'setcollision' and admin then
        local collisionState

        if cmd[2] ~= nil and cmd[3] == 'on' then
            collisionState = true
        elseif cmd[2] ~= nil and cmd[3] == 'off' then
            collisionState = false
        else
            tes3mp.SendMessage(pid, 'Not a valid argument. Use /setcollision <category> on/off\n', false)
            return false
        end

        local categoryInput = string.upper(cmd[2])
        local categoryValue = enumerations.objectCategories[categoryInput]

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
        else
            tes3mp.SendMessage(pid, categoryInput .. ' is not a valid object category. Valid choices are ' ..
                tableHelper.concatenateTableIndices(enumerations.objectCategories, ', ') .. '\n', false)
            return false
        end

        tes3mp.SendWorldCollisionOverride(pid, true)
        tes3mp.SendMessage(pid, 'Collision for ' .. categoryInput .. ' is now ' .. cmd[3] ..
            ' for all newly loaded cells.\n', false)
    elseif cmd[1] == 'overridecollision' and admin then
        local collisionState
        local refId = cmd[2]

        if refId ~= nil and cmd[3] == 'on' then
            collisionState = true
        elseif refId ~= nil and cmd[3] == 'off' then
            collisionState = false
        else
            Players[pid]:Message('Use /overridecollision <refId> on/off\n')
            return false
        end

        local message = 'A collision-enabling override '

        if tableHelper.containsValue(config.enforcedCollisionRefIds, refId) then
            if collisionState then
                message = message .. 'is already on'
            else
                tableHelper.removeValue(config.enforcedCollisionRefIds, refId)
                message = message .. 'is now off'
            end
        else
            if collisionState then
                table.insert(config.enforcedCollisionRefIds, refId)
                message = message .. 'is now on'
            else
                message = message .. 'is already off'
            end
        end

        logicHandler.SendConfigCollisionOverrides(pid, true)
        Players[pid]:Message(message .. ' for ' .. refId .. ' in newly loaded cells\n')
    elseif cmd[1] == 'load' and admin then
        local scriptName = cmd[2]

        if scriptName == nil then
            Players[pid]:Message('Use /load <scriptName>\n')
        else
            local wasLoaded = false

            if package.loaded[scriptName] then
                if type(package.loaded[scriptName]) ~= 'table' then
                    Players[pid]:Message(scriptName ..
                        ' was already loaded but it is not a valid lua module and thus cannot be properly reloaded.\n')
                    return
                end

                Players[pid]:Message(scriptName .. ' was already loaded, so it is being reloaded.\n')
                wasLoaded = true
            end

            local result

            if wasLoaded then
                -- Local objects that use functions from the script we are reloading
                -- will keep their references to the old versions of those functions if
                -- we do this:
                --
                -- package.loaded[scriptName] = nil
                -- require(scriptName)
                --
                -- To get around that, we load up the script with dofile() instead and
                -- then update the function references in package.loaded[scriptName], which
                -- in turn also changes them in the local objects
                --
                local scriptPath = package.searchpath(scriptName, package.path)
                result = dofile(scriptPath)

                for key, value in pairs(package.loaded[scriptName]) do
                    if result[key] == nil then
                        package.loaded[scriptName][key] = nil
                    end
                end

                for key, value in pairs(result) do
                    package.loaded[scriptName][key] = value
                end
            else
                result = miscUtil.prequire(scriptName)
            end

            if result then
                Players[pid]:Message(scriptName .. ' was successfully loaded.\n')
            else
                Players[pid]:Message(scriptName .. ' could not be found.\n')
            end
        end
    elseif cmd[1] == 'resetkills' and moderator and config.shareKills == true then
        -- Set all currently recorded kills to 0 for connected players
        for refId, killCount in pairs(WorldInstance.data.kills) do
            WorldInstance.data.kills[refId] = 0
        end

        WorldInstance:QuicksaveToDrive()
        WorldInstance:LoadKills(pid, true)
        tes3mp.SendMessage(pid, 'All the kill counts for creatures and NPCs have been reset.\n', true)
    elseif cmd[1] == 'resetkills' and config.shareKills == false then
        if Players[pid].data.kills == nil then
            Players[pid].data.kills = {}
        end
        -- Set all currently recorded kills to 0 for players
        for refId, killCount in pairs(Players[pid].data.kills) do
            Players[pid].data.kills[refId] = 0
        end

        Players[pid]:QuicksaveToDrive()
        Players[pid]:LoadKills(pid, false)
        tes3mp.SendMessage(pid, 'All the kill counts for creatures and NPCs have been reset.\n', false)
    elseif cmd[1] == 'suicide' then
        if config.allowSuicideCommand == true then
            tes3mp.SetHealthCurrent(pid, 0)
            tes3mp.SendStatsDynamic(pid)
        else
            tes3mp.SendMessage(pid, 'That command is disabled on this server.\n', false)
        end
    elseif cmd[1] == 'fixme' then
        if config.allowFixmeCommand == true then
            local currentTime = os.time()

            if not tes3mp.IsInExterior(pid) then
                local message = 'Sorry! You can only use ' .. color.Yellow .. '/fixme' ..
                    color.White .. ' in exteriors.\n'
                tes3mp.SendMessage(pid, message, false)
            elseif Players[pid].data.timestamps.lastFixMe == nil or
                currentTime >= Players[pid].data.timestamps.lastFixMe + config.fixmeInterval then
                logicHandler.RunConsoleCommandOnPlayer(pid, 'fixme')
                Players[pid].data.timestamps.lastFixMe = currentTime
                tes3mp.SendMessage(pid, 'You have fixed your position!\n', false)
            else
                local remainingSeconds = Players[pid].data.timestamps.lastFixMe +
                    config.fixmeInterval - currentTime
                local message = 'Sorry! You can\'t use ' .. color.Yellow .. '/fixme' ..
                    color.White .. ' for another '

                if remainingSeconds > 1 then
                    message = message .. color.Yellow .. remainingSeconds .. color.White .. ' seconds'
                else
                    message = message .. ' second'
                end

                message = message .. '\n'
                tes3mp.SendMessage(pid, message, false)
            end
        else
            tes3mp.SendMessage(pid, 'That command is disabled on this server.\n', false)
        end
    elseif cmd[1] == 'storeconsole' and cmd[2] ~= nil and cmd[3] ~= nil and admin then
        local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
        if not isValid then return end

        Players[targetPid].storedConsoleCommand = tableHelper.concatenateFromIndex(cmd, 3)

        tes3mp.SendMessage(pid, ('That console command is now stored for player %s\n'):format(targetPid), false)
    elseif cmd[1] == 'runconsole' and cmd[2] ~= nil and admin then
        local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
        if not isValid then return end

        if Players[targetPid].storedConsoleCommand == nil then
            tes3mp.SendMessage(pid, 'There is no console command stored for player ' .. targetPid ..
                '. Please run /storeconsole on them first.\n', false)
        else
            local consoleCommand = Players[targetPid].storedConsoleCommand

            local count = tonumber(cmd[3])

            if count ~= nil and count > 1 then
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
                    targetName = Players[targetPid].accountName,
                    consoleCommand = consoleCommand
                }

                tes3mp.StartTimer(timerId)
            end
        end
    elseif (cmd[1] == 'placeat' or cmd[1] == 'spawnat') and cmd[2] and cmd[3] and admin then
        local isValid, targetPid = logicHandler.CheckPlayerValidity(pid, cmd[2])
        if not isValid then return end

        local refId = tableHelper.concatenateFromIndex(cmd, 3)
        local packetType

        if cmd[1] == 'placeat' then
            packetType = 'place'
        elseif cmd[1] == 'spawnat' then
            packetType = 'spawn'
        end

        logicHandler.CreateObjectAtPlayer(targetPid, dataTableBuilder.BuildObjectData(refId), packetType)
    elseif (cmd[1] == 'anim' or cmd[1] == 'a') and cmd[2] ~= nil then
        local isValid = animHelper.PlayAnimation(pid, cmd[2])
        if isValid then return end

        local validList = animHelper.GetValidList(pid)
        tes3mp.SendMessage(
            pid,
            ('That is not a valid animation. Try one of the following:\n%s\n'):format(validList),
            false
        )
    elseif cmd[1] == 'speech' or cmd[1] == 's' then
        local isValid, speechNum = false, tonumber(cmd[3])

        if cmd[2] and cmd[3] and type(speechNum) == 'number' then
            isValid = speechHelper.PlaySpeech(pid, cmd[2], speechNum)
        end

        if isValid then return end

        local validList = speechHelper.GetPrintableValidListForPid(pid)
        tes3mp.SendMessage(
            pid,
            ('That is not a valid speech. Try one of the following:\n%s\n'):format(validList),
            false
        )
    elseif cmd[1] == 'confiscate' and moderator then
        if logicHandler.CheckPlayerValidity(pid, cmd[2]) then
            local targetPid = tonumber(cmd[2])

            if targetPid == pid then
                tes3mp.SendMessage(pid, 'You can\'t confiscate from yourself!\n', false)
            elseif Players[targetPid].data.customVariables.isConfiscationTarget then
                tes3mp.SendMessage(pid, 'Someone is already confiscating from that player\n', false)
            else
                Players[pid].confiscationTargetName = Players[targetPid].accountName

                Players[targetPid]:SetConfiscationState(true)

                tableHelper.cleanNils(Players[targetPid].data.inventory)
                guiHelper.ShowInventoryList(config.customMenuIds.confiscate, pid, targetPid)
            end
        end
    elseif cmd[1] == 'setai' and cmd[2] ~= nil and cmd[3] ~= nil and admin then
        local actionInput = cmd[3]
        local actionNumericalId

        -- Allow both numerical and string input for actions (i.e. 1 or COMBAT), but
        -- convert the latter into the former
        if type(tonumber(actionInput)) == 'number' then
            actionNumericalId = tonumber(actionInput)
        else
            actionNumericalId = enumerations.ai[string.upper(actionInput)]
        end

        if actionNumericalId == nil then
            Players[pid]:Message(actionInput .. ' is not a valid AI action. Valid choices are ' ..
                tableHelper.concatenateTableIndices(enumerations.ai, ', ') .. '\n')
        else
            local uniqueIndex = cmd[2]
            local cell = logicHandler.GetCellContainingActor(uniqueIndex)

            if cell == nil then
                Players[pid]:Message('Could not find actor ' .. uniqueIndex .. ' in any loaded cell\n')
            else
                local actionName = tableHelper.getIndexByValue(enumerations.ai, actionNumericalId)
                local messageAction = enumerations.aiPrintableAction[actionName]
                local message = uniqueIndex .. ' is now ' .. messageAction

                if actionNumericalId == enumerations.ai.CANCEL then
                    logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId)
                    Players[pid]:Message(message .. '\n')
                elseif actionNumericalId == enumerations.ai.TRAVEL then
                    local posX, posY, posZ = tonumber(cmd[4]), tonumber(cmd[5]), tonumber(cmd[6])

                    if type(posX) == 'number' and type(posY) == 'number' and type(posZ) == 'number' then
                        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, nil, nil, posX, posY, posZ)
                        Players[pid]:Message(message .. ' ' .. posX .. ' ' .. posY .. ' ' .. posZ .. '\n')
                    else
                        Players[pid]:Message('Invalid travel coordinates! ' ..
                            'Use /setai <uniqueIndex> travel <x> <y> <z>\n')
                    end
                elseif actionNumericalId == enumerations.ai.WANDER then
                    local distance, duration = tonumber(cmd[4]), tonumber(cmd[5])

                    if type(distance) == 'number' and type(duration) == 'number' then
                        if cmd[6] == 'true' then
                            shouldRepeat = true
                        else
                            shouldRepeat = false
                        end

                        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, nil, nil, nil, nil, nil,
                            distance, duration, shouldRepeat)
                        Players[pid]:Message(message .. ' a distance of ' .. distance .. ' for a duration of ' ..
                            duration .. '\n')
                    else
                        Players[pid]:Message('Invalid wander parameters! ' ..
                            'Use /setai <uniqueIndex> wander <distance> <duration> true/false\n')
                    end
                elseif cmd[4] ~= nil then
                    local target = cmd[4]
                    local hasPlayerTarget = false

                    if type(tonumber(target)) == 'number' and logicHandler.CheckPlayerValidity(pid, target) then
                        target = tonumber(target)
                        hasPlayerTarget = true
                    end

                    if hasPlayerTarget then
                        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, target)
                        message = message .. ' player ' .. Players[target].name
                    else
                        logicHandler.SetAIForActor(cell, uniqueIndex, actionNumericalId, nil, target)
                        message = message .. ' object ' .. target
                    end

                    Players[pid]:Message(message .. '\n')
                else
                    Players[pid]:Message('Invalid AI action!\n')
                end
            end
        end
    elseif cmd[1] == 'help' then
        -- Check 'scripts/menu/help.lua' if you want to change the contents of the help menus
        Players[pid].currentCustomMenu = 'help player'
        menuHelper.DisplayMenu(pid, Players[pid].currentCustomMenu)
    elseif cmd[1] == 'craft' then
        -- Check 'scripts/menu/defaultCrafting.lua' if you want to change the example craft menu
        Players[pid].currentCustomMenu = 'default crafting origin'
        menuHelper.DisplayMenu(pid, Players[pid].currentCustomMenu)
    elseif (cmd[1] == 'advancedexample' or cmd[1] == 'advex') and moderator then
        -- Check 'scripts/menu/advancedExample.lua' if you want to change the advanced menu example
        Players[pid].currentCustomMenu = 'advanced example origin'
        menuHelper.DisplayMenu(pid, Players[pid].currentCustomMenu)
    end
end

return commandHandler
