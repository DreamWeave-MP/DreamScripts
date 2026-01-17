--[[
All customScripts utilized by this loader will return values in the following format:
return {
  chatCommands = {},
  eventHandlers = {},
  eventValidators = {},
  interface = '',
  interfaceName = {},
  menus = {},
}

All fields are, in and of themselves, optional, however, an interfaceName is required when attempting to define an interface for a script
]]

local config = require 'tes3mp.config'
local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'
local jsonInterface = require 'jsonInterface'
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

local hasTDS, tds = pcall(require, 'tds.init')
local hasTES3, tes3 = pcall(require, 'tes3_lua')
local saveDataTable = BufferedDiskPaths
---@return DefaultInterfaces
function DScriptLoader.originalInterfaces()
  ---@type DefaultInterfaces
  return {
    ---@type StorageModule
    storage = dUtil.misc.makeReadOnly {
      ---@param data SaveSubscriptionData
      ---@return table? resultData Returns the loaded file's contents if it exists, or, the initial data table which was subscribed to, or an empty table.
      loadWithSubscription = function(data)
        local traceback = debug.traceback()
        assert(data and type(data) == 'table', traceback)
        assert(data.filePath and type(data.filePath) == 'string', traceback)
        assert(data.lastCheckedTime == nil, traceback)

        if not data.data or type(data.data) ~= 'table' then
          return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Provided an invalid data table to load subscription handler. Refusing to subscribe: %s\n%s')
            :format(data, traceback)
          )
        end

        local existingData = saveDataTable[data.filePath]
        if existingData then
          if not jsonInterface.quicksave(data.filePath, existingData) then
            return tes3mp.LogAppend(
              enumerations.log.WARN,
              ('Attempted to overwrite %s in the global saved data table, but failed somehow. You must wait for its original reference to be removed!\n%s')
              :format(data.filePath, traceback)
            )
          end
        end

        local result = jsonInterface.load(data.filePath)
        if result then
          if type(result) == 'table' then
            data.data = result
          elseif not result then
            result = {}
          else
            return tes3mp.LogAppend(
              enumerations.log.WARN,
              ('A data path provided to load subscription handler returned a non-table value %s. Refusing to subscribe: %s\n%s')
              :format(result, data, traceback)
            )
          end
        else
          result = data.data
        end

        saveDataTable[data.filePath] = data

        return result
      end,
      subscribeToSave = function(data)
        local traceback = debug.traceback()
        assert(data and type(data) == 'table', traceback)
        assert(data.filePath and type(data.filePath) == 'string', traceback)
        assert(data.lastCheckedTime == nil, traceback)

        if not data.data or type(data.data) ~= 'table' then
          return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Provided an invalid data table to save subscription handler. Refusing to subscribe: %s'):format(data)
          )
        end

        if saveDataTable[data.filePath] then
          if not jsonInterface.quicksave(data.filePath, saveDataTable[data.filePath]) then
            return tes3mp.LogAppend(
              enumerations.log.WARN,
              ('Attempted to overwrite %s in the global saved data table, but failed somehow. You must wait for its original reference to be removed!')
              :format(data.filePath)
            )
          end
        end

        saveDataTable[data.filePath] = data
      end,
    },
    ---@class DScriptLoaderHidden
    ---@field loadScript function(scriptPath: string, callerPid: PlayerId?)
    ---@field loadAllScripts function()
    scriptLoader = dUtil.misc.makeReadOnly {
      loadScript = DScriptLoader.loadScript,
      loadAllScripts = DScriptLoader.loadAllScripts,
    },
    tds = hasTDS and tds or nil,
    tes3 = hasTES3 and tes3 or nil,
  }
end

---@type DefaultInterfaces
local Interfaces = DScriptLoader.originalInterfaces()

---@class ReadOnlyInterfaces: DefaultInterfaces The same as the default interfaces table, but, will throw and kill the server if you try to write to it. Uses a metatable to return a local reference to the current definition of Interfaces, so is never stale.
DScriptLoader.Interfaces = setmetatable({},
  {
    __index = function(_, key)
      return Interfaces[key]
    end,
    __newindex = function()
      error(debug.traceback(('The global interfaces table is not writable!'), 3))
    end,
    __tostring = function()
      return ([[Global Interfaces {
  %s
}]]):format(tableHelper.concatenateTableIndices(Interfaces))
    end,
  }
)

local bit, ffi = require 'bit', require 'ffi'
local hasCJSON, cjson = pcall(require, 'cjson')
function DScriptLoader.defaultModuleCache()
  return {
    bit = bit,
    cjson = hasCJSON and cjson or nil,
    dutil = dUtil,
    ['dutil.vector3'] = dUtil.vector3,
    ffi = ffi,
    interfaces = DScriptLoader.Interfaces,
  }
end

local PathSeparator = tes3mp.GetOperatingSystemType() == 'Windows' and '\\' or '/'
local ModuleCache, ScriptDirectories =
    DScriptLoader.defaultModuleCache(),
    { 'scripts/', 'lib/', 'lib/lua/', }

--- Small shim for overriding require statements in curated script environment
---@param scriptName string
---@return any result, string? error
function DScriptLoader.requireShim(scriptName)
  assert(scriptName and type(scriptName) == 'string')

  scriptName = scriptName:gsub('[\\/]+', '.'):gsub('^%.', ''):gsub('%.$', ''):gsub('%.%.+', '.')

  local lowerName = scriptName:lower()
  if ModuleCache[lowerName] then
    return ModuleCache[lowerName]
  end

  local ok, chunk, err, result = false, nil, nil, nil

  for _, prefix in ipairs(ScriptDirectories) do
    local checkPath = ('server/%s%s.lua'):format(prefix, scriptName:gsub('%.', PathSeparator))

    chunk, err = loadfile(checkPath)

    if chunk then
      ok = true
      break
    end
  end

  if not ok or not chunk then
    error(
      ('Failed to load script %s due to error %s. Aborting!'):format(scriptName, err)
    )
  end

  setfenv(chunk, DScriptLoader.getScriptEnv())

  ok, result = pcall(chunk)
  if not ok then
    error(
      ('Tried to call `require` on the script at %s, but it threw an exception: %s. This script cannot be loaded!')
      :format(scriptName, result)
    )
  end

  ModuleCache[lowerName] = result

  return result
end

--- Returns a fresh copy of the script environment for each loaded script, so it may not be mutated
---@return DreamWeaveScriptEnv
function DScriptLoader.getScriptEnv()
  --- Curated environment passed to DreamWeave scripts
  --- Each instance is mutable, although it is unique, so that scripts are completely sandboxed in every instance
  ---@class DreamWeaveScriptEnv
  local ScriptEnv = {
    assert = assert,
    coroutine = coroutine,
    debug = { traceback = debug.traceback, },
    error = error,
    -- getfenv = getfenv,
    getmetatable = getmetatable,
    ipairs = ipairs,
    math = tableHelper.deepCopy(math),
    next = next,
    os = { clock = os.clock, date = os.date, time = os.time },
    require = DScriptLoader.requireShim,
    pairs = pairs,
    pcall = pcall,
    print = print,
    rawget = rawget,
    rawset = rawset,
    select = select,
    -- setfenv = setfenv,
    setmetatable = setmetatable,
    string = tableHelper.deepCopy(string),
    table = tableHelper.deepCopy(table),
    tes3mp = tes3mp,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    xpcall = xpcall,
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
    error(
      ('%s defined an interface which was not a table! The interface field of all scripts must be a table, if it is defined.')
      :format(scriptPath)
    )
  end

  if not scriptResult.interfaceName then
    error(
      ('%s defined an interface, but no name to reference it by! Add an `interfaceName` field to the return table of your script.')
      :format(scriptPath)
    )
  elseif type(scriptResult.interfaceName) ~= 'string' then
    error(
      ('%s defined an interfaceName, but it was not a string! It was: %s')
      :format(scriptPath, scriptResult.interfaceName)
    )
  end

  Interfaces[scriptResult.interfaceName] = dUtil.misc.makeReadOnly(scriptResult.interface)
end

--- Given a loaded script and its path, insert chat commands
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptCommands(scriptPath, scriptRegistration)
  if not scriptRegistration.chatCommands or type(scriptRegistration.chatCommands) ~= 'table' then return end

  local customCommandHooks = Interfaces.customCommandHooks
  if not customCommandHooks then
    return tes3mp.LogAppend(
      enumerations.log.ERROR,
      ('%s attempted to define chat commands, but the customCommandHooks interface has not been loaded yet!\nFix your load order!')
      :format(scriptPath)
    )
  end

  customCommandHooks.clearCommandsFromScript(scriptPath)

  for commandName, commandRegistration in pairs(scriptRegistration.chatCommands) do
    if type(commandName) ~= 'string' or commandName == '' or type(commandRegistration.callback) ~= 'function' then
      error(
        ('Invalid inputs from script %s for chat command! Command Name: %s, command callback: %s')
        :format(scriptPath, commandName, commandRegistration.callback)
      )
    end

    customCommandHooks.registerCommand(commandName, {
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
    error(
      ('Failed to load the script %s as it attempt to define menus which were not a table: %s')
      :format(scriptPath, scriptMenus)
    )
  elseif not DScriptLoader.Interfaces.menuHelper then
    error(
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
    error(
      ('Script %s defined eventHandlers which were not a table: %s\nTerminating server. Oops!'):format(scriptPath,
        scriptRegistration.eventHandlers)
    )
  elseif scriptRegistration.eventValidators and type(scriptRegistration.eventValidators) ~= 'table' then
    error(
      ('Script %s defined eventValidators which were not a table: %s\nTerminating server. Oops!'):format(scriptPath,
        scriptRegistration.eventValidators)
    )
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

local AllowedFields, Loaders = {
  chatCommands = true,
  eventHandlers = true,
  eventValidators = true,
  interface = true,
  interfaceName = true,
  menus = true,
}, {
  'loadScriptInterface',
  'loadScriptCommands',
  'loadScriptMenus',
  'loadScriptHandlers',
}

local ScriptFailedMessage = 'Attempted to load the script at %s, but failed, because it doesn\'t exist.'

--- Given a script name, attempt to load it into the tes3mp environment like an OpenMW Lua script.
--- Can be called from the chat window by passing the second optional parameter, callerPid.
---@param scriptName string name of a script, relative to server/scripts/custom, to attempt to load
---@param callerPid PlayerId? optional PlayerId
---@return true? didLoad Whether or not script loading was successful
function DScriptLoader.loadScript(scriptName, callerPid)
  if not scriptName or type(scriptName) ~= 'string' then
    error(
      ('Invalid script path provided to DScriptLoader.loadScript: %s'):format(scriptName)
    )
  end

  local scriptPath = DScriptLoader.sanitizePath(ScriptPathFormatter:format(scriptName))

  if not dUtil.io.fileExists(scriptPath) then
    if callerPid then
      return Players[callerPid]:Message(ScriptFailedMessage:format(scriptPath))
    else
      error(ScriptFailedMessage:format(scriptPath))
    end
  end

  if Interfaces.customEventHooks then
    Interfaces.customEventHooks.clearEventsFromScript(scriptPath)
  end

  if Interfaces.customCommandHooks then
    Interfaces.customCommandHooks.clearCommandsFromScript(scriptPath)
  end

  --- If this function was called from chat, then, we don't
  --- Get the guarantee that loadAllScripts will have refreshed our module cache
  --- So, we reset it here, just before initializing the file
  if callerPid then
    ModuleCache = DScriptLoader.defaultModuleCache()
  end

  tes3mp.LogAppend(enumerations.log.INFO, ('Attempting to load custom script from path: %s'):format(scriptPath))
  local ok, result = pcall(function() return assert(loadfile(scriptPath)) end)

  if not ok then
    if callerPid then
      if not logicHandler.CheckPlayerValidity(nil, callerPid) then
        error(
          ('An invalid PlayerId: %s was provided to DScriptLoader.loadScript. This should never happen!')
          :format(callerPid)
        )
      end

      return tes3mp.SendMessage(callerPid, ('Failed to load script: %s, error: %s'):format(scriptPath, result))
    else
      error(('Failed to load %s, error: %s. Aborting startup!'):format(scriptPath, result))
    end
  end

  setfenv(result, DScriptLoader.getScriptEnv())
  ok, result = pcall(result)

  if not ok then
    error(
      ('Tried to load the script at %s, but it threw an exception: %s. This script cannot be loaded!')
      :format(scriptPath, result)
    )
  elseif type(result) ~= 'table' then
    error(
      ('Successfully loaded the script at %s, but its return value was not a table. This script cannot be loaded!')
      :format(scriptPath)
    )
  end

  for elementName in pairs(result) do
    if not AllowedFields[elementName] then
      error(
        ('Failed to load script %s as it returned an invalid field: %s. The server will now terminate!')
        :format(scriptPath, elementName)
      )
    end
  end

  if config.debugScriptRegistrations then
    tableHelper.print(result)
  end

  for _, loader in ipairs(Loaders) do
    DScriptLoader[loader](scriptPath, result)
  end

  collectgarbage()
  return true
end

--- Load all scripts defined by config.customScripts
--- Upon failure, for any reason, the server will be terminated.
--- This function should only be called upon initializing the server, OR when attempting to reload all running lua scripts.
function DScriptLoader.loadAllScripts()
  --- Reinitialize all interfaces when reloading all scripts
  Interfaces = DScriptLoader.originalInterfaces()

  --- When reloading all scripts, reinitialize the module cache
  ModuleCache = DScriptLoader.defaultModuleCache()

  local startTime = os.clock()

  for _, scriptName in ipairs(config.customScripts) do
    if not DScriptLoader.loadScript(scriptName) then
      error('Script loading has failed! Check your server log for more details.')
    end
  end

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('Successfully completed script initialization in %.6f milliseconds.'):format((os.clock() - startTime) * 1000)
  )
end

return DScriptLoader
