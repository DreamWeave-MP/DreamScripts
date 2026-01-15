if not Roll then
  Roll = require('custom.dreamDice.roll')
end

local lastRolls = {}

Roll:addSkills {
  lb = 'Longblade',
  sb = 'Shortblade',
}

local Format = string.format
local RegisterCommand = customCommandHooks.registerCommand
local SendSystemMessage = tes3mp.SendMessage
local Traceback = debug.traceback

local Players = Players
local Roll = Roll
local LoadedCells = LoadedCells

local darkMagenta = color.DarkMagenta
local green = color.Green
local red = color.Red
local yellow = color.Yellow

local InvalidRollCommandMessage = Format('%sInvalid roll command.\n%sExample: %s/roll %s2d2-4\n'
                                         , red, darkMagenta, green, yellow)
local NoPreviousRollMessage = 'does not have a previous roll to retry!'
local LoadedCellAssertMessage = 'A player is in this cell, why wouldn\'t it be loaded?'
local NonStringCellDescriptionAssertMessage = 'Cannot send a message to a non-string cell description!'
local UnloggedPlayerRerollAssertMessage = 'Player must be logged in to reroll!'

local function sendMessageToVisitors(cellDescription, message)
  local cell = LoadedCells[cellDescription]
  assert(cell, Format("%s%s", LoadedCellAssertMessage, Traceback(3)))

  local cellVisitors = cell.visitors
  for _, visitorPid in ipairs(cellVisitors) do
    SendSystemMessage(visitorPid, message, false)
  end
end

local function sendMessage(message, sendToAllOrCellDesc, playerId)
  if sendToAllOrCellDesc == true then
    SendSystemMessage(playerId, message, true)
  else
    assert(type(sendToAllOrCellDesc) == 'string', NonStringCellDescriptionAssertMessage)
    sendMessageToVisitors(sendToAllOrCellDesc, message)
  end
end

local function roll(pid, cmd, sendToAll)
  local player = Players[pid]
  local rollAttempt = cmd[2]
  if not player and player:IsLoggedIn() then return end

  local rollMessage = InvalidRollCommandMessage

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
    or Format("%s %s", Players[pid].accountName, NoPreviousRollMessage)

  sendMessage(message, sendToAll or player.data.location.cell, pid)
end

RegisterCommand("roll", function(pid, cmd) roll(pid, cmd, false) end)
RegisterCommand("rollg", function(pid, cmd) roll(pid, cmd, true) end)
RegisterCommand("reroll", function(pid) reroll(pid, false) end)
RegisterCommand("rerollg", function(pid) reroll(pid, true) end)
