local color = require 'color'
local Roll = require 'custom.dreamDice.roll'

local lastRolls = {}

Roll:addSkills {
  lb = 'Longblade',
  sb = 'Shortblade',
}

local InvalidRollCommandMessage = ('%sInvalid roll command.\n%sExample: %s/roll %s2d2-4\n')
    :format(color.Red, color.DarkMagenta, color.Green, color.Yellow)
local NoPreviousRollMessage = 'does not have a previous roll to retry!'
local LoadedCellAssertMessage = 'A player is in this cell, why wouldn\'t it be loaded?'
local NonStringCellDescriptionAssertMessage = 'Cannot send a message to a non-string cell description!'
local UnloggedPlayerRerollAssertMessage = 'Player must be logged in to reroll!'

local function sendMessageToVisitors(cellDescription, message)
  local cell = LoadedCells[cellDescription]
  if not cell then
    error(
      ("%s%s"):format(LoadedCellAssertMessage, debug.traceback(nil, 3))
    )
  end

  for _, visitorPid in ipairs(cell.visitors) do
    tes3mp.SendMessage(visitorPid, message, false)
  end
end

local function sendMessage(message, sendToAllOrCellDesc, playerId)
  if sendToAllOrCellDesc == true then
    tes3mp.SendMessage(playerId, message, true)
  else
    assert(type(sendToAllOrCellDesc) == 'string', NonStringCellDescriptionAssertMessage)
    sendMessageToVisitors(sendToAllOrCellDesc, message)
  end
end

local function roll(pid, cmd, sendToAll)
  local player = Players[pid]
  if not player and player:IsLoggedIn() then return end

  local rollAttempt, rollMessage = cmd[2], InvalidRollCommandMessage

  if rollAttempt then
    local statName, statRoll = Roll:fromStatId(pid, rollAttempt)
    local rollInput = statRoll or rollAttempt

    ---@type RollObject
    local currentRoll = Roll(rollInput)

    currentRoll:log(pid)

    lastRolls[pid] = currentRoll

    rollMessage = currentRoll:getResultMessage {
      playerId = pid,
      forStat = statName,
    }
  end

  sendMessage(rollMessage, sendToAll or player.data.location.cell, pid)
end

local function reroll(pid, sendToAll)
  local player = Players[pid]
  assert(player and player:IsLoggedIn(), UnloggedPlayerRerollAssertMessage)

  local message = lastRolls[pid] and lastRolls[pid]:getResultMessage { playerId = pid }
      or ("%s %s"):format(Players[pid].accountName, NoPreviousRollMessage)

  sendMessage(message, sendToAll or player.data.location.cell, pid)
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'dreamDice',
  ---@class DiceInterface
  interface = {
    ---@param rollInput string A formatted string, like 2d6, to generate a roll from
    ---@return RollObject
    roll = function(rollInput)
      assert(rollInput and type(rollInput) == 'string', 'Invalid roll input! No dice for you!')
      return Roll(rollInput)
    end
  },
  eventHandlers = {
    OnServerPostInit = function()
      require 'custom.dreamDice.test_rolls' ()
    end,
  },
  chatCommands = {
    reroll = { callback = function(pid, _) reroll(pid, false) end },
    rerollg = { callback = function(pid, _) reroll(pid, true) end },
    roll = { callback = function(pid, cmd) roll(pid, cmd, false) end },
    rollg = { callback = function(pid, cmd) roll(pid, cmd, true) end },
  }
}
