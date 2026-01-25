local config = require 'config'
local enumerations = require 'packages.networkEnums'
local logicHandler = require 'packages.logicHandler'
local tableHelper = require 'packages.tableHelper'

local sendKills = {}

---@type TES3MPScriptRegistration
return {
  eventHandlers = {
    -- Upon receiving an actor death:
    -- 1) Add 1 to the kill count for its ID and send it to players
    -- 2) Add it to the cell's currently unusable containers
    -- 3) Request its container
    -- Note: points 2 and 3 are temporary and will be handled better when
    --       servers load up .esm data by default.
    OnActorDeath = function(_, pid, cellDescription, actors)
      local cell = LoadedCells[cellDescription]

      tes3mp.ClearKillChanges()

      if config.shareKills then
        for uniqueIndex, actor in pairs(actors) do
          if WorldInstance.data.kills[actor.refId] == nil then
            WorldInstance.data.kills[actor.refId] = 0
          end

          WorldInstance.data.kills[actor.refId] = WorldInstance.data.kills[actor.refId] + 1
          WorldInstance:QuicksaveToDrive()
          tes3mp.AddKill(actor.refId, WorldInstance.data.kills[actor.refId])

          table.insert(cell.unusableContainerUniqueIndexes, uniqueIndex)
        end

        tes3mp.SendWorldKillCount(pid, true)
      else
        local player = Players[pid]
        player.data.kills = player.data.kills or {}
        local playerKills = player.data.kills

        for uniqueIndex, actor in pairs(actors) do
          if playerKills[actor.refId] == nil then
            playerKills[actor.refId] = 0
          end

          playerKills[actor.refId] = playerKills[actor.refId] + 1
          player:QuicksaveToDrive()

          sendKills[uniqueIndex] = sendKills[uniqueIndex] or { timestamp = os.time(), playersName = {} }

          tableHelper.insertValueIfMissing(
            sendKills[uniqueIndex].playersName,
            player.accountName:lower()
          )

          tes3mp.AddKill(actor.refId, playerKills[actor.refId])

          for _, alliedName in ipairs(player.data.alliedPlayers) do
            if logicHandler.GetPlayerByName(alliedName) then
              local alliedPlayer = logicHandler.GetPlayerByName(alliedName)
              if not alliedPlayer or not logicHandler.CheckPlayerValidity(nil, alliedPlayer.pid) then goto CONTINUE end

              alliedPlayer.data.kills = alliedPlayer.data.kills or {}
              local alliedKills = alliedPlayer.data.kills

              alliedKills[actor.refId] = alliedKills[actor.refId] or 0
              alliedKills[actor.refId] = alliedKills[actor.refId] + 1

              alliedPlayer:QuicksaveToDrive()
              tableHelper.insertValueIfMissing(
                sendKills[uniqueIndex].playersName,
                alliedPlayer.accountName:lower()
              )
            end

            ::CONTINUE::
          end

          table.insert(cell.unusableContainerUniqueIndexes, uniqueIndex)
        end

        for targetIndex in pairs(actors) do
          for _, targetName in ipairs(sendKills[targetIndex].playersName) do
            local targetPlayer = logicHandler.GetPlayerByName(targetName)
            if not targetPlayer or not logicHandler.CheckPlayerValidity(nil, targetPlayer.pid) then goto CONTINUE end

            tes3mp.SendWorldKillCount(targetPlayer.pid, false)

            ::CONTINUE::
          end

          sendKills[targetIndex] = nil
        end
      end

      cell:RequestContainers(pid, tableHelper.getArrayFromIndices(actors))
    end,
    -- Print object activations and send an ObjectActivate packet back to the player
    OnObjectActivate = function(eventStatus, _, _, objects, targetPlayers)
      if eventStatus.validDefaultHandler == false then return end

      local debugMessage = ''

      for uniqueIndex, object in pairs(objects) do
        debugMessage = ('%s- %s %s has been activated by')
            :format(debugMessage, uniqueIndex, object.refId)

        if object.activatingPid then
          debugMessage = ('%s %s\n')
              :format(debugMessage, logicHandler.GetChatName(object.activatingPid))
        else
          debugMessage = ('%s %s %s\n')
              :format(debugMessage, object.activatingRefId, object.activatingUniqueIndex)
        end

        tes3mp.LogAppend(enumerations.log.INFO, debugMessage)
      end

      for targetPid, targetPlayer in pairs(targetPlayers) do
        debugMessage = ('%s- %s has been activated by')
            :format(debugMessage, logicHandler.GetChatName(targetPid))

        if targetPlayer.activatingPid then
          debugMessage = ('%s %s\n')
              :format(debugMessage, logicHandler.GetChatName(targetPlayer.activatingPid))
        else
          debugMessage = ('%s %s %s\n')
              :format(
                debugMessage,
                targetPlayer.activatingRefId,
                targetPlayer.activatingUniqueIndex
              )
        end

        tes3mp.LogAppend(enumerations.log.INFO, debugMessage)
      end

      tes3mp.CopyReceivedObjectListToStore()
      -- Objects can't be activated clientside without the server's approval, so we send
      -- the packet back to the player who sent it, but we avoid sending it to other
      -- players because OpenMW barely has any code for handling activations not from
      -- the local player
      -- i.e. sendToOtherPlayers is false and skipAttachedPlayer is false
      tes3mp.SendObjectActivate(false, false)
    end,
    -- Print object dialogue choice and send an ObjectDialogueChoice packet back to the player
    OnObjectDialogueChoice = function(eventStatus, _, _, objects)
      if not eventStatus.validDefaultHandler then return end

      for uniqueIndex, object in pairs(objects) do
        tes3mp.LogAppend(
          enumerations.log.INFO,
          ('- Accepting dialogue choice type %s for %s')
          :format(
            tableHelper.getIndexByValue(enumerations.dialogueChoice, object.dialogueChoiceType),
            object.refId,
            uniqueIndex
          )
        )

        if object.dialogueChoiceType == enumerations.dialogueChoice.TOPIC then
          tes3mp.LogAppend(enumerations.log.INFO, ('- topic was %s'):format(object.dialogueTopic))
        end
      end

      tes3mp.CopyReceivedObjectListToStore()
      -- Dialogue choices cannot be triggered clientside without the server's approval,
      -- so we send the packet back to the player who sent it, but we avoid sending it to
      -- other players
      -- i.e. sendToOtherPlayers is false and skipAttachedPlayer is false
      tes3mp.SendObjectDialogueChoice(false, false)
    end,
    -- Print object hits
    OnObjectHit = function(eventStatus, _, _, objects, targetPlayers)
      if not eventStatus.validDefaultHandler then return end

      local debugMessage = ''

      for uniqueIndex, object in pairs(objects) do
        if object.hittingPid then
          debugMessage = ('- %s%s'):format(debugMessage, logicHandler.GetChatName(object.hittingPid))
        else
          debugMessage = ('- %s%s %s'):format(debugMessage, object.hittingRefId, object.hittingUniqueIndex)
        end

        if object.hit.success then
          debugMessage = ('%s has successfully hit'):format(debugMessage)

          if not config.shareKills and object.hittingPid then
            if sendKills[uniqueIndex] == nil then
              sendKills[uniqueIndex] = { timestamp = os.time(), playersName = {} }
            else
              if os.time() - sendKills[uniqueIndex].timestamp >= 600 then
                sendKills[uniqueIndex] = { timestamp = os.time(), playersName = {} }
              else
                sendKills[uniqueIndex].timestamp = os.time()
              end
            end

            tableHelper.insertValueIfMissing(
              sendKills[uniqueIndex].playersName,
              Players[object.hittingPid].accountName:lower()
            )
          end
        else
          debugMessage = ('%s has missed hitting'):format(debugMessage)
        end

        debugMessage = ('%s%s %s'):format(debugMessage, object.refId, uniqueIndex)

        tes3mp.LogAppend(enumerations.log.INFO, debugMessage)
      end

      for targetPid, targetPlayer in pairs(targetPlayers) do
        if targetPlayer.hittingPid then
          debugMessage = ('- %s%s'):format(debugMessage, logicHandler.GetChatName(targetPlayer.hittingPid))
        else
          debugMessage = ('- %s%s %s'):format(debugMessage, targetPlayer.hittingRefId, targetPlayer.hittingUniqueIndex)
        end

        if targetPlayer.hit.success then
          debugMessage = ('%s has successfully hit '):format(debugMessage)
        else
          debugMessage = ('%s has missed hitting '):format(debugMessage)
        end

        debugMessage = ('%s%s'):format(debugMessage, logicHandler.GetChatName(targetPid))

        tes3mp.LogAppend(enumerations.log.VERBOSE, debugMessage)
      end
    end,
    -- Upon accepting an object placement, request its container if it has one
    OnObjectPlace = function(_, pid, cellDescription, objects)
      local containerUniqueIndexesRequested = {}
      local cell = LoadedCells[cellDescription]

      for uniqueIndex, object in pairs(objects) do
        if object.hasContainer then
          table.insert(containerUniqueIndexesRequested, uniqueIndex)
        end
      end

      if not tableHelper.isEmpty(containerUniqueIndexesRequested) then
        cell:RequestContainers(pid, containerUniqueIndexesRequested)
      end
    end,
    -- Print object restocking and send an ObjectRestock packet back to the player
    OnObjectRestock = function(eventStatus, _, _, objects)
      if not eventStatus.validDefaultHandler then return end

      for uniqueIndex, object in pairs(objects) do
        tes3mp.LogAppend(
          enumerations.log.INFO,
          ('- Accepting restock request for %s %s'):format(object.refId, uniqueIndex)
        )
      end

      tes3mp.CopyReceivedObjectListToStore()
      -- Objects can't be restocked clientside without the server's approval, so we send
      -- the packet back to the player who sent it, but we avoid sending it to other
      -- players because the Container packet resulting from the restocking will get
      -- sent to them instead
      -- i.e. sendToOtherPlayers is false and skipAttachedPlayer is false
      tes3mp.SendObjectRestock(false, false)
    end,
    -- Print object sounds and send an ObjectSound packet to other players
    OnObjectSound = function(eventStatus, _, _, objects, targetPlayers)
      if not eventStatus.validDefaultHandler then return end

      for uniqueIndex, object in pairs(objects) do
        tes3mp.LogAppend(enumerations.log.INFO, ('- %s played sound %s'):format(uniqueIndex, object.soundId))
      end

      for targetPid, targetPlayer in pairs(targetPlayers) do
        tes3mp.LogAppend(
          enumerations.log.INFO,
          ('- %s played sound %s'):format(logicHandler.GetChatName(targetPid), targetPlayer.soundId)
        )
      end

      tes3mp.CopyReceivedObjectListToStore()
      -- Sounds are played unilaterally clientside before being sent to the server, so we
      -- send the packet to other players, but we avoid sending it to the original player
      -- i.e. sendToOtherPlayers is true and skipAttachedPlayer is true
      tes3mp.SendObjectSound(true, true)
    end,
    -- Upon accepting an object spawn, request its container
    OnObjectSpawn = function(_, pid, cellDescription, objects)
      local cell = LoadedCells[cellDescription]
      cell:RequestContainers(pid, tableHelper.getArrayFromIndices(objects))
    end,
    -- Don't allow state spam from clients
    OnObjectState = function(_, pid, cellDescription, objects)
      for uniqueIndex, object in pairs(objects) do
        if object.state == false then
          local player = Players[pid]

          if not player.stateSpam then player.stateSpam = {} end

          -- Track the number of ObjectState packets received from this player that have attempted to disable this object
          if not player.stateSpam[uniqueIndex] then
            player.stateSpam[uniqueIndex] = 0
          else
            player.stateSpam[uniqueIndex] = player.stateSpam[uniqueIndex] + 1

            -- Kick a player that continues the spam
            if player.stateSpam[uniqueIndex] >= 25 then
              player:Kick()
              tes3mp.LogAppend(
                enumerations.log.INFO,
                ('- Kicked player %s for continuing state spam'):format(logicHandler.GetChatName(pid))
              )
              -- If the player has sent 5 false object states for the same uniqueIndex, delete the object
            elseif player.stateSpam[uniqueIndex] >= 5 then
              logicHandler.DeleteObjectForPlayer(pid, cellDescription, uniqueIndex)
              tes3mp.LogAppend(enumerations.log.INFO, '- Deleting state spam object')
            end
          end
        end
      end
    end,
  }
}
