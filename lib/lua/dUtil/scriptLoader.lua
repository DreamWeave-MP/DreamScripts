--- All customScripts utilized by this loader will return values in the following format:
-- return {
--   interface = '',
--   interfaceName = {},
--   eventHandlers = {},
--   eventValidators = {},
--   chatCommands = {},
-- }
-- All fields are, in and of themselves, optional, however, an interfaceName is required when attempting to define an interface for a script

local config = require 'tes3mp.config'
local enumerations = require 'tes3mp.enumerations'
local logicHandler = require 'tes3mp.logicHandler'
local tableHelper = require 'tes3mp.util.table'

local ScriptPathFormatter = 'server/scripts/custom/%s'

--- OpenMW-Style Script loader module for TES3MP.
--- This is a stateful module which should only ever be `require`'d once by serverCore.lua
--- YOU HAVE BEEN WARNED!!!!!!!
---@class DScriptLoader
local DScriptLoader = {}

--- Takes an input script path relative to server/scripts/custom and returns a sanitized script path to input into dofile
---@param path string name of a script to attempt to load, NOT including the file extension, or any path leading up to server/scripts/custom. Inputs to this function should look identical to require statements.
---@return string sanitizedPath input path with all duplicate and inappropriate path separators, including `.`, replaced and the `.lua` file extension appended. On Windows, lowercases the input path also.
function DScriptLoader.sanitizePath(path)
  if type(path) ~= 'string' then return path end

  -- Remove duplicate slashes (both forward and back)
  path = path:gsub('%.', '/'):gsub('[/\\]+', '/')

  -- On windows, we assume case-insensitive filesystems, so lowercasing file names to ensure conformity is safer
  if tes3mp.GetOperatingSystemType() == 'Windows' then
    path = path:gsub('/', '\\'):lower()
  else
    path = path:gsub('\\', '/')
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
}]]):format(tableHelper.concatenateTableIndices(Interfaces))
    end,
  }
)

---@type table<string, function>
local sandboxLoaded = {}
local PathSeparator = tes3mp.GetOperatingSystemType() == 'Windows' and '\\' or '/'

--- Small shim for overriding require statements in curated script environment
---@param scriptName string
---@return any result, string? error
function DScriptLoader.requireShim(scriptName)
  assert(scriptName and type(scriptName) == 'string')

  scriptName = scriptName:gsub('[\\/]', '.')

  if scriptName == 'interfaces' then
    return DScriptLoader.Interfaces
  elseif sandboxLoaded[scriptName] then
    return sandboxLoaded[scriptName]()
  else
    local ok, chunk, err, result = false, nil, nil, nil

    ok, chunk = pcall(require, scriptName)
    if ok then return chunk end

    for _, prefix in ipairs { 'scripts/', 'lib/', 'lib/lua/', } do
      local checkPath = ('server/%s%s.lua'):format(prefix, scriptName:gsub('%.', PathSeparator))

      chunk, err = loadfile(checkPath)

      if chunk then
        ok = true
        break
      end
    end

    if not ok or not chunk then
      tes3mp.LogAppend(
        enumerations.log.FATAL,
        ('Failed to load script %s due to error %s. Aborting!'):format(scriptName, err)
      )
      return tes3mp.StopServer(18)
    end

    setfenv(chunk, DScriptLoader.getScriptEnv())
    -- setfenv(chunk, getfenv(2))

    ok, result = pcall(chunk)
    if not ok then
      tes3mp.LogAppend(
        enumerations.log.ERROR,
        ('Tried to load the script at %s, but it threw an exception: %s. This script cannot be loaded!')
        :format(scriptName, result)
      )
      tes3mp.StopServer(11)
    end

    sandboxLoaded[scriptName] = chunk

    return result
  end
end

--- Returns a fresh copy of the script environment for each loaded script, so it may not be mutated
---@return DreamWeaveScriptEnv
function DScriptLoader.getScriptEnv()
  --- Curated environment passed to DreamWeave scripts
  --- Each instance is mutable, although it is unique, so that scripts are completely sandboxed in every instance
  ---@class DreamWeaveScriptEnv
  local ScriptEnv = {
    assert = assert,
    debug = debug,
    error = error,
    ipairs = ipairs,
    math = math,
    require = DScriptLoader.requireShim,
    pairs = pairs,
    pcall = pcall,
    print = print,
    rawget = rawget,
    rawset = rawset,
    setmetatable = setmetatable,
    string = string,
    table = table,
    tes3mp = tes3mp,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    xpcall = xpcall,
    ---@class DScriptLoaderHidden
    scriptLoader = {
      loadScript = DScriptLoader.loadScript,
      loadAllScripts = DScriptLoader.loadAllScripts,
    },
    --- TES3MP Globals
    banList = banList,
    HourCounter = HourCounter,
    pidsByIpAddress = pidsByIpAddress,
    updateTimerId = updateTimerId,
    Cell = Cell,
    ClientDataFiles = ClientDataFiles,
    Database = Database,
    LoadedCells = LoadedCells,
    ObjectLoops = ObjectLoops,
    Player = Player,
    Players = Players,
    RecordStores = RecordStores,
    RecordStore = RecordStore,
    World = World,
    WorldInstance = WorldInstance,
  }

  return ScriptEnv
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

--- Given a loaded script and its path, insert chat commands
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptCommands(scriptPath, scriptRegistration)
  if not scriptRegistration.chatCommands or type(scriptRegistration.chatCommands) ~= 'table' then return end

  if not Interfaces.customCommandHooks then
    return tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s attempted to define chat commands, but the customCommandHooks interface has not been loaded yet!\nFix your load order!')
      :format(scriptPath)
    )
  end

  Interfaces.customCommandHooks.clearCommandsFromScript(scriptPath)

  for commandName, commandRegistration in pairs(scriptRegistration.chatCommands) do
    if type(commandName) ~= 'string' or commandName == '' or type(commandRegistration.callback) ~= 'function' then
      tes3mp.LogAppend(
        enumerations.log.ERROR,
        ('Invalid inputs from script %s for chat command! Command Name: %s, command callback: %s')
        :format(scriptPath, commandName, commandRegistration.callback)
      )
    end

    Interfaces.customCommandHooks.registerCommand(commandName, {
      definedBy = scriptPath,
      callback = commandRegistration.callback,
      nameRequirement = commandRegistration.nameRequirement,
      rankRequirement = commandRegistration.rankRequirement,
    })
  end
end

--- Given a loaded script and its path, insert relevant interfaces
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptMenus(scriptPath, scriptRegistration)
  local scriptMenus = scriptRegistration.menus
  if not scriptMenus then
    return
  elseif type(scriptMenus) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.FATAL,
      ('Failed to load the script %s as it attempt to define menus which were not a table: %s')
      :format(scriptPath, scriptMenus)
    )
    tes3mp.StopServer(5)
  elseif not DScriptLoader.Interfaces.menuHelper then
    return tes3mp.LogAppend(
      enumerations.log.WARN,
      ('Failed to load the script %s\'s menus as the menuHelper interface has not been defined.'):format(scriptPath)
    )
  end

  for menuName, menuContent in pairs(scriptMenus) do
    DScriptLoader.Interfaces.menuHelper.registerMenu(menuName, menuContent)
  end
end

--- Given a loaded script and its path, load all eventHandlers and validators it defines
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptHandlers(scriptPath, scriptRegistration)
  if not scriptRegistration.eventHandlers and not scriptRegistration.eventValidators then return end
  local customEventHooks = Interfaces.customEventHooks

  if not customEventHooks then
    return tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s tried to define eventHandlers or eventValidators, but was loaded before customEventHooks. Sorry!'):format(
        scriptPath)
    )
  end

  if scriptRegistration.eventHandlers and type(scriptRegistration.eventHandlers) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Script %s defined eventHandlers which were not a table: %s\nTerminating server. Oops!'):format(scriptPath,
        scriptRegistration.eventHandlers)
    )
    tes3mp.StopServer(1)
  elseif scriptRegistration.eventValidators and type(scriptRegistration.eventValidators) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Script %s defined eventValidators which were not a table: %s\nTerminating server. Oops!'):format(scriptPath,
        scriptRegistration.eventValidators)
    )
    tes3mp.StopServer(1)
  end

  ---@cast customEventHooks CustomEventHooks

  for eventName, eventHandler in pairs(scriptRegistration.eventHandlers or {}) do
    assert(type(eventName) == 'string' and type(eventHandler) == 'function')

    customEventHooks.registerHandler(eventName, {
      definedBy = scriptPath,
      callback = eventHandler,
    })
  end

  for eventName, eventValidator in pairs(scriptRegistration.eventValidators or {}) do
    assert(type(eventName) == 'string' and type(eventValidator) == 'function')

    customEventHooks.registerValidator(eventName, {
      definedBy = scriptPath,
      callback = eventValidator,
    })
  end
end

local AllowedFields = {
  chatCommands = true,
  eventHandlers = true,
  eventValidators = true,
  interface = true,
  interfaceName = true,
  menus = true,
}

local dUtil = require 'dUtil.init'
local ScriptFailedMessage = 'Attempted to load the script at %s, but failed, because it doesn\'t exist.'

--- Given a script name, attempt to load it into the tes3mp environment like an OpenMW Lua script.
--- Can be called from the chat window by passing the second optional parameter, callerPid.
---@param scriptName string name of a script, relative to server/scripts/custom, to attempt to load
---@param callerPid PlayerId? optional PlayerId
function DScriptLoader.loadScript(scriptName, callerPid)
  if not scriptName or type(scriptName) ~= 'string' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Invalid script path provided to DScriptLoader.loadScript: %s'):format(scriptName)
    )
  end

  local scriptPath = DScriptLoader.sanitizePath(ScriptPathFormatter:format(scriptName))

  if not dUtil.io.fileExists(scriptPath) then
    if callerPid then
      return Players[callerPid]:Message(ScriptFailedMessage:format(scriptPath))
    else
      tes3mp.LogAppend(enumerations.log.ERROR, ScriptFailedMessage:format(scriptPath))
      tes3mp.StopServer(4)
    end
  end

  if Interfaces.customEventHooks then
    Interfaces.customEventHooks.clearEventsFromScript(scriptPath)
  end

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
  ok, result = pcall(result)

  if not ok then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Tried to load the script at %s, but it threw an exception: %s. This script cannot be loaded!')
      :format(scriptPath, result)
    )
    tes3mp.StopServer(11)
  elseif type(result) ~= 'table' then
    tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('Successfully loaded the script at %s, but its return value was not a table. This script cannot be loaded!')
      :format(scriptPath)
    )
    tes3mp.StopServer(12)
  end

  for elementName in pairs(result) do
    if not AllowedFields[elementName] then
      tes3mp.LogAppend(
        enumerations.log.FATAL,
        ('Failed to load script %s as it returned an invalid field: %s. The server will now terminate!')
        :format(scriptPath, elementName)
      )
      tes3mp.StopServer(9)
    end
  end

  if config.debugScriptRegistrations then
    tableHelper.print(result)
  end

  DScriptLoader.loadScriptInterface(scriptPath, result)
  DScriptLoader.loadScriptCommands(scriptPath, result)
  DScriptLoader.loadScriptMenus(scriptPath, result)
  DScriptLoader.loadScriptHandlers(scriptPath, result)
end

--- Load all scripts defined by config.customScripts
--- Upon failure, for any reason, the server will be terminated.
--- This function should only be called upon initializing the server, OR when attempting to reload all running lua scripts.
function DScriptLoader.loadAllScripts()
  --- Reinitialize all interfaces when reloading all scripts
  Interfaces = {}

  for _, scriptName in ipairs(config.customScripts) do
    DScriptLoader.loadScript(scriptName)
  end
end

return DScriptLoader
