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

return MiscUtil
