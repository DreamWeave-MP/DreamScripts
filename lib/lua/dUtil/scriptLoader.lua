--- All customScripts utilized by this loader will return values in the following format:
-- return {
--   interface = '',
--   interfaceName = {},
--   eventHandlers = {},
--   eventValidators = {},
--   chatCommands = {},
-- }
-- All fields are, in and of themselves, optional, however, an interfaceName is required when attempting to define an interface for a script

local ScriptPathFormatter = 'server/scripts/custom/%s'
local Deps

--- OpenMW-Style Script loader module for TES3MP.
--- This is a stateful module which should only ever be `require`'d once by serverCore.lua
--- YOU HAVE BEEN WARNED!!!!!!!
---@class DScriptLoader
local DScriptLoader = {}

--- Takes an input script path relative to server/scripts/custom and returns a sanitized script path to input into dofile
---@param path string name of a script to attempt to load, NOT including the file extension, or any path leading up to server/scripts/custom. Inputs to this function should look identical to require statements.
---@return string sanitizedPath input path with all duplicate and inappropriate path separators, including `.`, replaced and the `.lua` file extension appended. On Windows, lowercases the input path also.
function DScriptLoader.sanitizePath(path)
  if type(path) ~= "string" then return path end

  -- Remove duplicate slashes (both forward and back)
  path = path:gsub("%.", "/"):gsub("[/\\]+", "/")

  -- On windows, we assume case-insensitive filesystems, so lowercasing file names to ensure conformity is safer
  if tes3mp.GetOperatingSystemType() == 'Windows' then
    path = path:gsub("/", "\\"):lower()
  else
    path = path:gsub("\\", "/")
  end

  return path .. '.lua'
end

--- Takes a table as input and returns a read-only one.
--- Commits seppuku if the input is not a table, so do be careful
---@param inTable table<any, any>
---@return table<any, any>
function DScriptLoader.makeReadOnly(inTable)
  if type(inTable) ~= 'table' then error(('Input value to makeReadOnly %s was not a table!'):format(inTable)) end

  return setmetatable(inTable, {
    __newindex = function()
      print(debug.traceback(('Write attempt to read-only table %s'):format(inTable), 3))
      tes3mp.StopServer(15)
    end,
  })
end

local Interfaces = {}
DScriptLoader.Interfaces = setmetatable({},
  {
    __index = function(_, key)
      return Interfaces[key]
    end,
    __newindex = function()
      print(debug.traceback(('The global interfaces table is not writable!'), 3))
      tes3mp.StopServer(15)
    end,
    __tostring = function()
      return ([[Global Interfaces {
  %s
}]]):format(tableHelper.concatenateTableIndexes(Interfaces))
    end,
  }
)

--- Returns a fresh copy of the script environment for each loaded script, so it may not be mutated
---@return DreamWeaveScriptEnv
function DScriptLoader.getScriptEnv()
  return {
    math = math,
    require = require,
    print = print,
    string = string,
    table = table,
    tableHelper = tableHelper,
    I = DScriptLoader.Interfaces,
  }
end

--- Given a loaded script and its path, insert relevant interfaces
--- Tries to flush old interfaces, but if the interface name has changed this isn't possible,
--- leaving old references dangling.
---@param scriptPath string sanitized relative script path for error output
---@param scriptResult table resulting table after invoking a script using dofile
function DScriptLoader.loadScriptInterface(scriptPath, scriptResult)
  if not scriptResult.interface then
    if scriptResult.interfaceName and Interfaces[scriptResult.interfaceName] then
      Interfaces[scriptResult.interfaceName] = nil
    end

    return
  end

  if type(scriptResult.interface) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s defined an interface which was not a table! The interface field of all scripts must be a table, if it is defined.')
      :format(scriptPath)
    )
    tes3mp.StopServer(13)
  end

  if not scriptResult.interfaceName then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s defined an interface, but no name to reference it by! Add an `interfaceName` field to the return table of your script.')
      :format(scriptPath)
    )
    tes3mp.StopServer(14)
  elseif type(scriptResult.interfaceName) ~= 'string' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s defined an interfaceName, but it was not a string! It was: %s')
      :format(scriptPath, scriptResult.interfaceName)
    )
    tes3mp.StopServer(11)
  end

  Interfaces[scriptResult.interfaceName] = DScriptLoader.makeReadOnly(scriptResult.interface)
end

--- Given a loaded script and its path, insert relevant interfaces
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptCommands(scriptPath, scriptRegistration)
  Deps.customCommandHooks:clearCommandsFromScript(scriptPath)

  for commandName, commandRegistration in pairs(scriptRegistration.chatCommands or {}) do
    if type(commandName ~= string) or commandName == '' or type(commandRegistration.callback) ~= 'function' then
      tes3mp.LogAppend(
        enumerations.log.ERROR,
        ('Invalid inputs from script %s for chat command! Command Name: %s, command callback: %s')
        :format(scriptPath, commandName, commandRegistration.callback)
      )
    end

    Deps.customCommandHooks:registerCommand(commandName, {
      definedBy = scriptPath,
      callback = commandRegistration.callback,
      nameRequirement = commandRegistration.nameRequirement,
      rankRequirement = commandRegistration.rankRequirement,
    })
  end
end

--- Given a script name, attempt to load it into the tes3mp environment like an OpenMW Lua script.
--- Can be called from the chat window by passing the second optional parameter, callerPid.
---@param scriptName string name of a script, relative to server/scripts/custom, to attempt to load
---@param callerPid PlayerId? optional PlayerId
function DScriptLoader.loadScript(scriptName, callerPid)
  local scriptPath = DScriptLoader.sanitizePath(ScriptPathFormatter:format(scriptName))

  tes3mp.LogAppend(enumerations.log.INFO, ('Attempting to load custom script from path: %s'):format(scriptPath))
  local ok, result = pcall(function() return assert(loadfile(scriptPath)) end)

  if not ok then
    if callerPid then
      if not logicHandler.CheckPlayerValidity(nil, callerPid) then
        tes3mp.LogAppend(
          enumerations.log.ERROR,
          ('An invalid PlayerId: %s was provided to DScriptLoader.loadScript. This should never happen!')
          :format(callerPid)
        )
        tes3mp.StopServer(10)
      end

      return tes3mp.SendMessage(callerPid, ('Failed to load script: %s, error: %s'):format(scriptPath, result))
    else
      tes3mp.LogAppend(enumerations.log.FATAL,
        ('Failed to load %s, error: %s. Aborting startup!'):format(scriptPath, result))
      tes3mp.StopServer(16)
    end
  end

  setfenv(result, DScriptLoader.getScriptEnv())
  result = result()

  if type(result) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Successfully loaded the script at %s, but its return value was not a table. This script cannot be loaded!')
      :format(scriptPath)
    )
    tes3mp.StopServer(12)
  end

  tableHelper.print(result)
  DScriptLoader.loadScriptInterface(scriptPath, result)
  DScriptLoader.loadScriptCommands(scriptPath, result)
end

--- Load all scripts defined by config.customScripts
--- Upon failure, for any reason, the server will be terminated.
--- This function should only be called upon initializing the server, OR when attempting to reload all running lua scripts.
function DScriptLoader.loadAllScripts()
  for _, scriptName in ipairs(config.customScripts) do
    DScriptLoader.loadScript(scriptName)
  end
end

---@class DScriptLoaderDeps
---@field customCommandHooks CustomCommandHooks

---@param deps DScriptLoaderDeps
return function(deps)
  assert(deps.customCommandHooks)

  Deps = deps

  return DScriptLoader
end
