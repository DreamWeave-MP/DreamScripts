---@class CommandHandler
local commandHandler = {}

function commandHandler.ProcessCommand(pid, cmd)
    if cmd[1] == 'setcollision' and admin then
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
    elseif cmd[1] == 'suicide' then
        if config.allowSuicideCommand then
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
    end
end

return commandHandler
