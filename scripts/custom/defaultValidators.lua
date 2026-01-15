local clientVariableScopes = require 'tes3mp.clientVariableScopes'
local config = require 'tes3mp.config'
local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'
local logicHandler = require 'tes3mp.logicHandler'
local tableHelper = require 'tes3mp.util.table'

-- Don't create objects mentioned in config.disallowedCreateRefIds
local function defaultCreationValidator(_, _, _, objects)
  for _, object in pairs(objects) do
    if tableHelper.containsValue(config.disallowedCreateRefIds, object.refId) then
      tes3mp.LogAppend(enumerations.log.INFO, "- Rejected attempt at creating " .. object.refId ..
        " " .. object.uniqueIndex .. " because it is disallowed in the server config")
      return dUtil.misc.makeEventStatus(false, false)
    end
  end
end

---@type TES3MPScriptRegistration
return {
  eventValidators = {
    -- Ignore packets with global variables that are listed under ClientVariableScopes.globals.ignored
    OnClientScriptGlobal = function(_, _, variables)
      for id, _ in pairs(variables) do
        if tableHelper.containsValue(clientVariableScopes.globals.ignored, id) then
          tes3mp.LogAppend(enumerations.log.INFO, "- Ignoring attempt at setting global variable " .. id ..
            " because it is listed as an ignored variable in ClientVariableScopes")
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    -- Don't allow console commands from players who lack the permissions for them and haven't been asked
    -- to run the console commands by the server itself; kick them instead
    OnConsoleCommand = function(_, pid, cellDescription, consoleCommand, _, _)
      print('Number of Players: ', tableHelper.getCount(Players))
      tableHelper.print(Players)
      local hasConsoleCommandQueued = tableHelper.containsValue(Players[pid].consoleCommandsQueued, consoleCommand)

      if not logicHandler.IsPlayerAllowedConsole(pid) and not hasConsoleCommandQueued then
        local debugMessage = "Rejected ConsoleCommand from " .. logicHandler.GetChatName(pid) ..
            " about " .. cellDescription .. " and kicked them due to them not being allowed to" ..
            " use the console"
        debugMessage = debugMessage .. "\n- consoleCommand: " .. consoleCommand
        tes3mp.LogMessage(enumerations.log.INFO, debugMessage)
        tes3mp.Kick(pid)
        return dUtil.misc.makeEventStatus(false, false)
      end
    end,
    -- Don't change door states for objects mentioned in config.disallowedDoorStateRefIds
    OnDoorState = function(_, _, _, objects, _)
      for _, object in pairs(objects) do
        if tableHelper.containsValue(config.disallowedDoorStateRefIds, object.refId) then
          tes3mp.LogAppend(enumerations.log.INFO,
            ('- Rejected attempt at changing door state for %s %s because it is disallowed in the server config')
            :format(object.refId, object.uniqueIndex)
          )

          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    -- Don't activate objects that are supposed to already be deleted according to the
    -- server, preventing item duping
    --
    -- Additionally, don't activate objects mentioned in config.disallowedActivateRefIds
    OnObjectActivate = function(_, _, cellDescription, objects, _)
      for uniqueIndex, object in pairs(objects) do
        local debugMessage = ('- Rejected attempt at activating %s %s because it')
            :format(object.refId,
              object.uniqueIndex)
        local splitIndex = uniqueIndex:split("-")
        local refNum = tonumber(splitIndex[1])
        local mpNum = tonumber(splitIndex[2])

        local cellData = LoadedCells[cellDescription].data

        -- If this is a preexisting object from the data files, make sure it doesn't
        -- have a Delete packet recorded for it
        if refNum ~= 0 and tableHelper.containsValue(cellData.packets.delete, uniqueIndex) then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ('%s is a preexisting object that is already tracked as being deleted')
            :format(debugMessage)
          )
          return dUtil.misc.makeEventStatus(false, false)
        elseif mpNum ~= 0 and cellData.objectData[uniqueIndex] == nil then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ('%s is a server-created object that is no longer supposed to exist')
            :format(debugMessage)
          )
          return dUtil.misc.makeEventStatus(false, false)
        elseif tableHelper.containsValue(config.disallowedActivateRefIds, object.refId) then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ('%s is disallowed in the server config'):format(debugMessage)
          )
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    -- Don't validate object deletions for currently unusable containers (such as
    -- dying actors whose corpses players try to dispose of too early)
    --
    -- Additionally, don't delete objects mentioned in config.disallowedDeleteRefIds
    OnObjectDelete = function(_, _, cellDescription, objects)
      local cell = LoadedCells[cellDescription]
      local unusableContainerUniqueIndexes = cell.unusableContainerUniqueIndexes

      for uniqueIndex, object in pairs(objects) do
        if tableHelper.containsValue(unusableContainerUniqueIndexes, uniqueIndex) then
          return dUtil.misc.makeEventStatus(false, false)
        elseif tableHelper.containsValue(config.disallowedDeleteRefIds, object.refId) then
          tes3mp.LogAppend(enumerations.log.INFO, "- Rejected attempt at deleting " .. object.refId ..
            " " .. object.uniqueIndex .. " because it is disallowed in the server config")
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    -- Don't change lock levels for objects mentioned in config.disallowedLockRefIds
    OnObjectLock = function(_, _, _, objects, _)
      for _, object in pairs(objects) do
        if tableHelper.containsValue(config.disallowedLockRefIds, object.refId) then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ('- Rejected attempt at changing lock for %s %s because it is disallowed in the server config')
            :format(object.refId, object.uniqueIndex)
          )
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    OnObjectPlace = defaultCreationValidator,
    -- Don't validate scales larger than the maximum set in the config
    OnObjectScale = function(_, _, _, objects)
      for _, object in pairs(objects) do
        if object.scale >= config.maximumObjectScale then
          tes3mp.LogAppend(enumerations.log.INFO,
            ('- Rejected attempt at setting scale of %s %s to %s because it exceeds the server\'s maximum of %d')
            :format(object.refId, object.uniqueIndex, object.scale, config.maximumObjectScale)
          )
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    OnObjectSpawn = defaultCreationValidator,
    -- Don't change states for objects mentioned in config.disallowedStateRefIds
    OnObjectState = function(_, _, _, objects, _)
      for _, object in pairs(objects) do
        if tableHelper.containsValue(config.disallowedStateRefIds, object.refId) then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ("- Rejected attempt at changing state for %s %s because it is disallowed in the server config")
            :format(object.refId, object.uniqueIndex)
          )
          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
    -- Don't change traps for objects mentioned in config.disallowedTrapRefIds
    OnObjectTrap = function(_, _, _, objects, _)
      for _, object in pairs(objects) do
        if tableHelper.containsValue(config.disallowedTrapRefIds, object.refId) then
          tes3mp.LogAppend(
            enumerations.log.INFO,
            ('- Rejected attempt at changing trap for %s %s because it is disallowed in the server config')
            :format(object.refId, object.uniqueIndex)
          )

          return dUtil.misc.makeEventStatus(false, false)
        end
      end
    end,
  }
}
