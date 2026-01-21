local enumerations = require 'tes3mp.enumerations'
local jsonInterface = require 'jsonInterface'

assert(
  BufferedDiskPaths and Callbacks,
  'This module may not be imported directly inside the script sandbox. Use I.timed instead!'
)

---@class TimedModule
local TimedModule = {}

--- Provide a callback function, the amount of time before
--- It should be called, and any arbitrary number of arguments
---@param callbackFunction function
---@param callbackDelay number
---@param ... any
function TimedModule.registerCallbackFunction(callbackFunction, callbackDelay, ...)
  assert(callbackFunction and type(callbackFunction) == 'function', 'Invalid callback function registered!')
  assert(callbackDelay and type(callbackDelay) == 'number' and callbackDelay > 0., 'Invalid callback delay!')

  Callbacks[#Callbacks + 1] = {
    callback = callbackFunction,
    triggerAt = os.clock() + callbackDelay,
    arguments = { ... }
  }
end

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
