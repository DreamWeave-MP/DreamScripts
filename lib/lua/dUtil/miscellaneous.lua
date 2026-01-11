---@class DUtilMisc
local MiscUtil = {}

--- Given a playerId, return all of their associated server ranks
--- This should probably be sanitized so we take Player throughout corescripts instead of pids which suck.
---@param pid PlayerId
---@return boolean isOwner, boolean isAdmin, boolean isModerator
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

return MiscUtil
