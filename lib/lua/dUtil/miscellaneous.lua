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

return MiscUtil
