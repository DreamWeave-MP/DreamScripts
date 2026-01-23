local enumerations = require 'tes3mp.enumerations'
local jsonInterface = require 'jsonInterface'

local hasChronos, chronos = pcall(require, 'chronos')
local timeFunction = hasChronos and chronos.nanotime or os.time

assert(
  BufferedDiskPaths and Callbacks,
  'This module may not be imported directly inside the script sandbox. Use I.timed instead!'
)

---@class TimedModule
local TimedModule = {}

--- Provide a callback function, the amount of time before
--- It should be called, and any arbitrary number of arguments may be supplied
--- Which are passed to the callback when it runs.
---@param callbackFunction function
---@param callbackDelay number
---@param ... any
function TimedModule.registerCallbackFunction(callbackFunction, callbackDelay, ...)
  assert(callbackFunction and type(callbackFunction) == 'function', 'Invalid callback function registered!')
  assert(callbackDelay and type(callbackDelay) == 'number' and callbackDelay > 0., 'Invalid callback delay!')

  local numCallbacks = #Callbacks

  Callbacks[#numCallbacks + 1] = {
    callback = callbackFunction,
    triggerAt = timeFunction() + callbackDelay,
    arguments = { ... }
  }

  if numCallbacks == 0 then StartTimedCallbackHandler() end
end

--- Given some initial data, provide a path and details for subscription,
--- And return whatever the saved content is or will be.
--- If neither a data field is provided in the subscription handler, nor an existing file was found,
--- An empty table will be returned which is used for serialization.
--- Don't lose track of it!
--- For example, this function can be used to provide a default configuration
--- And keep the configuration file saving consistently every thirty seconds or what-have.
---@param data SaveSubscriptionData
---@return table? resultData Returns the loaded file's contents if it exists, or, the initial data table which was subscribed to, or an empty table.
function TimedModule.loadWithSubscription(data)
  local traceback = debug.traceback()
  assert(data and type(data) == 'table', traceback)
  assert(data.filePath and type(data.filePath) == 'string', traceback)
  assert(data.lastCheckedTime == nil, traceback)

  if data.data and type(data.data) ~= 'table' then
    return tes3mp.LogAppend(
      enumerations.log.WARN,
      ('Provided an invalid data table to load subscription handler. Refusing to subscribe: %s\n%s')
      :format(data, traceback)
    )
  end

  local existingData = BufferedDiskPaths[data.filePath]
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
    else
      return tes3mp.LogAppend(
        enumerations.log.WARN,
        ('A data path provided to load subscription handler returned a non-table value %s. Refusing to subscribe: %s\n%s')
        :format(result, data, traceback)
      )
    end
  else
    result = data.data or {}
  end

  BufferedDiskPaths[data.filePath] = data

  return result
end

--- Given some initial data, provide a path and details for subscription,
--- The provided table will be auto-saved according to the parameters you set, once or continuously,
--- On whatever delay you wish, or upon each server tick (which is a configurable timed delay up to the behest of the server administrator)
--- No data is returned, and it is expected that references to the table you provide live as long as the subscription itself does.
--- So, if you want to have a table be continuously saved for the entire runtime of the server, do not ever replace it entirely.
function TimedModule.subscribeToSave(data)
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

  if BufferedDiskPaths[data.filePath] then
    if not jsonInterface.quicksave(data.filePath, BufferedDiskPaths[data.filePath]) then
      return tes3mp.LogAppend(
        enumerations.log.WARN,
        ('Attempted to overwrite %s in the global saved data table, but failed somehow. You must wait for its original reference to be removed!')
        :format(data.filePath)
      )
    end
  end

  BufferedDiskPaths[data.filePath] = data
end

return TimedModule
