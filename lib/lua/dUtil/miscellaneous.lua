local enumerations = require 'tes3mp.enumerations'

---@class DUtilMisc
local MiscUtil = {}

--- Given a playerId, return all of their associated server ranks
--- This should probably be sanitized so we take Player throughout corescripts instead of pids which suck.
---@param pid PlayerId
---@return boolean isModerator, boolean isAdmin, boolean isOwner
function MiscUtil.getRanks(pid)
  local serverOwner, admin, moderator = false, false, false
  local player = Players[pid]

  if player:IsServerOwner() then
    serverOwner = true
    admin = true
    moderator = true
  elseif player:IsAdmin() then
    admin = true
    moderator = true
  elseif player:IsModerator() then
    moderator = true
  end

  return moderator, admin, serverOwner
end

--- Given any value, returns whether it's a proper IP address string representation.
--- Decimal only!
---@param ip any
---@return boolean isValidIP
function MiscUtil.isValidIP(ip)
  if type(ip) ~= "string" then return false end

  local chunks = { ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
  if #chunks ~= 4 then return false end

  for _, chunk in ipairs(chunks) do
    local num = tonumber(chunk)
    if not num or num < 0 or num > 255 then
      return false
    end
  end

  return true
end

--- Get the Player object of either an online player or an offline one
---@param targetName string
---@return Player?
function MiscUtil.GetPlayerByName(targetName)
  local lowerTargetName = targetName:lower()

  assert(Players ~= nil, 'Failed to find the global Players table! This should never happen!')

  -- Check if the player is online
  for _, player in pairs(Players) do
    if lowerTargetName == player.accountName:lower() then
      return player
    end
  end

  -- If they're offline, try to load their account file
  local targetPlayer = Player(nil, targetName)

  if not targetPlayer:HasAccount() then return end

  targetPlayer:LoadFromDrive()
  return targetPlayer
end

--- Returns an EventStatusTable used to determine whether or not certain behaviors should run.
--- This function is used as a return value from events, or, from simulating such.
--- It will assume `true` for nil values provided to either parameter, so it may be called with no arguments to get true values of both.
---@param validDefaultHandler boolean? Whether or not default behaviors should run after a validator.
---@param validCustomHandlers boolean? Whether or not to run custom handlers for certain behaviors. This must be checked explicitly, it is ignored by CustomEventHooks.
---@return EventStatusTable
function MiscUtil.makeEventStatus(validDefaultHandler, validCustomHandlers)
  if validDefaultHandler == nil then
    validDefaultHandler = true
  end

  if validCustomHandlers == nil then
    validCustomHandlers = true
  end

  return {
    validDefaultHandler = validDefaultHandler,
    validCustomHandlers = validCustomHandlers
  }
end

--- Takes a table as input and returns a read-only one.
--- Commits seppuku if the input is not a table, so do be careful
---@param inTable table<any, any>
---@return table<any, any>
function MiscUtil.makeReadOnly(inTable)
  if type(inTable) ~= 'table' then error(('Input value to makeReadOnly %s was not a table!'):format(inTable)) end

  return setmetatable({}, {
    __index = inTable,
    __newindex = function()
      error(debug.traceback(('Write attempt to read-only table %s'):format(inTable), 3))
    end,
    __metatable = false,
  })
end

--- Safe function wrapper used by the `timed` module and customEventHooks exposed for reuse to help prevent crashes
---@param fn function
---@param ... any
function MiscUtil.safeCall(fn, ...)
  local function wrapped(...)
    return fn(...)
  end

  local success, result = xpcall(
    wrapped,
    function(err)
      tes3mp.LogAppend(
        enumerations.log.WARN,
        ('%s\n%s'):format(err, debug.traceback('', 1))
      )
    end,
    ...
  )

  return success, result
end

return MiscUtil
