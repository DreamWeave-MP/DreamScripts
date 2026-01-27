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

local config = require 'config'
local dUtil = require 'dUtil.init'
local enumerations = require 'packages.networkEnums'
local jsonInterface = require 'packages.jsonInterface'
local logicHandler = require 'packages.logicHandler'
local tableHelper = require 'packages.tableHelper'
local yamlInterface = require 'packages.yamlInterface'

---@type LFSFFIModule
local lfs = require 'lfs'

local ScriptPathFormatter = 'server.scripts.%s.%s'

local BuiltinScriptPaths = {
  --- NOTE: Only pure interfaces may be defined in this section.

  --- Re-expose the contents of clientVariableScopes through an interface
  'clientVariableScopesInterface',
  --- The menu interface is what used to be menuHelper, and many builtins rely on it
  --- FIXME: menuHelper sucked and menuInterface does too
  'menuInterface',
  --- speechHelper is exposed as a public interface here.
  --- For load order reasons, it should be defined before defaultCommands, as defaultCommands
  --- relies on the interface it defines
  'speechHelper',
  --- customEventHooks is the most important module!
  --- Its load order must never be changed and everything else, even all the chat commands,
  --- depend upon it.
  --- Should it be removed, even the serverCore will crash upon initialization!
  'customEventHooks',
  --- The interface defined by customCommandHooks is required for all scripts to
  --- Define chat commands. Don't remove it or change its order.
  'customCommandHooks',
  --- NOTE: All chat commands should be defined in this section, before event callbacks

  'defaultCommands',
  --- NOTE: Event callbacks in this section

  -- Most core server functionality is implemented in defaultValidators/defaultHandlers
  'defaultValidators',
  'defaultHandlers',
  --- contentFixer is used to adjust corprus state and world variables in certain circumstances
  'contentFixer',
  --- NOTE: Dependencies of builtin interfaces without event callbacks

  -- Built in help menu and example interfaces
  'menu/help',
  'menu/defaultCrafting',
  'menu/advancedExample',
}

--- OpenMW-Style Script loader module for TES3MP.
--- This is a stateful module which should only ever be `require`'d once by serverCore.lua
--- YOU HAVE BEEN WARNED!!!!!!!
---@class DScriptLoader
local DScriptLoader = {}
local IsWindows = tes3mp.GetOperatingSystemType() == 'Windows'
local PathSeparator = IsWindows and '\\' or '/'

--- Takes an input script path relative to server/scripts/custom and returns a sanitized script path to input into dofile
---@param path string name of a script to attempt to load, NOT including the file extension, or any path leading up to server/scripts/custom. Inputs to this function should look identical to require statements.
---@return string sanitizedPath input path with all duplicate and inappropriate path separators, including `.`, replaced and the `.lua` file extension appended. On Windows, lowercases the input path also.
function DScriptLoader.sanitizePath(path)
  assert(type(path) == 'string')

  if IsWindows then path = path:lower() end

  return path:scriptPath():gsub('%.', PathSeparator) .. '.lua'
end

local AllowedFields, Loaders = {
  chatCommands = true,
  eventHandlers = true,
  eventValidators = true,
  interface = true,
  interfaceName = true,
  menus = true,
}, {
  'loadScriptCommands',
  'loadScriptMenus',
  'loadScriptHandlers',
  'loadScriptInterface',
}

---@enum ScriptLoadType
local ScriptPathPrefixes = {
  BUILTIN = 1,
  CUSTOM = 2,
}

local ScriptFailedMessage = 'Attempted to load the script at %s, but failed, because it doesn\'t exist.'

--- Given a script name, attempt to load it into the tes3mp environment like an OpenMW Lua script.
--- Can be called from the chat window by passing the second optional parameter, callerPid.
---@param scriptName string name of a script, relative to server/scripts/custom, to attempt to load
---@param callerPid PlayerId? optional PlayerId
---@param scriptDir ScriptLoadType? Optionally determines whether the script being loaded is a builtin or not. If unspecified, falls back to custom.
---@return true? didLoad Whether or not script loading was successful
function DScriptLoader.loadScript(scriptName, callerPid, scriptDir)
  if not scriptName or type(scriptName) ~= 'string' then
    error(
      ('Invalid script path provided to DScriptLoader.loadScript: %s'):format(scriptName)
    )
  end

  local subDir = scriptDir and scriptDir == ScriptPathPrefixes.BUILTIN and 'builtin' or 'custom'

  local scriptPath = DScriptLoader.sanitizePath(ScriptPathFormatter:format(subDir, scriptName))

  if not lfs.attributes(scriptPath) then
    if callerPid then
      return Players[callerPid]:Message(ScriptFailedMessage:format(scriptPath))
    else
      error(ScriptFailedMessage:format(scriptPath))
    end
  end

  if DScriptLoader.Interfaces.customEventHooks then
    DScriptLoader.Interfaces.customEventHooks.clearEventsFromScript(scriptPath)
  end

  if DScriptLoader.Interfaces.customCommandHooks then
    DScriptLoader.Interfaces.customCommandHooks.clearCommandsFromScript(scriptPath)
  end

  --- If this function was called from chat, then, we don't
  --- Get the guarantee that loadAllScripts will have refreshed our module cache
  --- So, we reset it here, just before initializing the file
  if callerPid then
    ModuleCache = DScriptLoader.defaultModuleCache()
  end

  tes3mp.LogAppend(enumerations.log.INFO, ('Attempting to load %s script from path: %s'):format(subDir, scriptPath))
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

  --- Maybe we only describe custom scripts here?
  --- Or just omit menus, perhaps, and do it in each of the handler functions
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

  --- In case the config file may have changed in some way,
  --- Which descendent scripts will be aware of anyway,
  --- recompile the configuration each time all scripts are reloaded.
  --- This allows us to respond to changes in the actual customScripts list,
  config = DScriptLoader.requireShim('config')

  local startTime = os.clock()

  for scriptType, scriptTable in ipairs { BuiltinScriptPaths, config.customScripts, } do
    for _, scriptName in ipairs(scriptTable) do
      if not DScriptLoader.loadScript(scriptName, nil, scriptType) then
        error('Script loading has failed! Check your server log for more details.')
      end
    end
  end

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('Successfully completed script initialization in %.6f milliseconds.'):format((os.clock() - startTime) * 1000)
  )
end

local hasTES3, tes3 = pcall(require, 'tes3_lua')

---@class DScriptLoaderHidden
---@field loadScript function(scriptPath: string, callerPid: PlayerId?)
---@field loadAllScripts function()
local ScriptLoaderInterface = dUtil.misc.makeReadOnly {
  loadScript = DScriptLoader.loadScript,
  loadAllScripts = DScriptLoader.loadAllScripts,
}

---@type TimedModule
local TimedInterface = dUtil.misc.makeReadOnly(require 'dUtil.timed')

---@return DefaultInterfaces
function DScriptLoader.originalInterfaces()
  local interfaces = {
    scriptLoader = ScriptLoaderInterface,
    timed = TimedInterface,
  }

  if hasTES3 then interfaces.tes3 = tes3 end

  return interfaces
end

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
      local interfaceNames, interfaceStr = {}, ''

      for interfaceName in pairs(Interfaces) do
        interfaceNames[#interfaceNames + 1] = interfaceName
      end

      table.sort(interfaceNames)

      for i, sortedName in ipairs(interfaceNames) do
        interfaceStr = interfaceStr .. sortedName

        if i < #interfaceNames then
          interfaceStr = interfaceStr .. ', '
        end
      end

      return ('Global Interfaces {\n  %s\n}'):format(interfaceStr)
    end,
  }
)

local bit, ffi = require 'bit', require 'ffi'
local hasCJSON, cjson = pcall(require, 'cjson')
function DScriptLoader.defaultModuleCache()
  return {
    bit = bit,
    cjson = hasCJSON and cjson or nil,
    ['dutil'] = dUtil,
    ['dutil.init'] = dUtil,
    ffi = ffi,
    interfaces = DScriptLoader.Interfaces,
    jsoninterface = jsonInterface,
    lfs = lfs,
    ['packages.jsoninterface'] = jsonInterface,
    ['packages.yamlinterface'] = yamlInterface,
  }
end

local ModuleCache = DScriptLoader.defaultModuleCache()

--- Small shim for overriding require statements in curated script environment
---@param scriptName string
---@return any result, string? error
function DScriptLoader.requireShim(scriptName)
  assert(scriptName and type(scriptName) == 'string')

  scriptName = scriptName:scriptPath()

  local lowerName = scriptName:lower()
  if ModuleCache[lowerName] then
    return ModuleCache[lowerName]
  end

  local chunk, err = loadfile(('server/scripts/%s.lua'):format(scriptName:gsub('%.', '/')))

  if not chunk then
    error(('%s: %s!'):format(scriptName, err))
  end

  setfenv(chunk, DScriptLoader.getScriptEnv())

  local ok, result = pcall(chunk)
  if not ok then
    error(('%s: %s!'):format(scriptName, result))
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
    -- io = io,
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
---@param scriptResult TES3MPScriptRegistration resulting table after invoking a script using dofile
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

  local oldInterface = Interfaces[scriptResult.interfaceName]
  if scriptResult.eventValidators and oldInterface then
    local interfaceOverrideHandler = scriptResult.eventValidators.OnInterfaceOverride
    if interfaceOverrideHandler then interfaceOverrideHandler(oldInterface) end
  end

  Interfaces[scriptResult.interfaceName] = dUtil.misc.makeReadOnly(scriptResult.interface)
end

--- Given a loaded script and its path, insert chat commands
---@param scriptPath string sanitized relative script path for error output
---@param scriptRegistration TES3MPScriptRegistration resulting table after invoking a script using dofile
function DScriptLoader.loadScriptCommands(scriptPath, scriptRegistration)
  if not scriptRegistration.chatCommands or type(scriptRegistration.chatCommands) ~= 'table' then return end

  local customCommandHooks = assert(Interfaces.customCommandHooks)

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
  local customEventHooks = assert(Interfaces.customEventHooks)

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

return DScriptLoader
