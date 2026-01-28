---@type DefaultInterfaces
local I = require 'interfaces'

local enumerations = require 'packages.networkEnums'
local inventoryHelper = require 'packages.inventoryHelper'
local logicHandler = require 'packages.logicHandler'

local GoldItemRef = { refId = 'gold_001', count = 0, charge = -1, enchantmentcharge = -1, soul = '' }
local PartialFeeMessage =
'%sWARNING:%sYou were unable to pay your last resurrection fee. You will not be resurrected again if you cannot afford the fee. You paid a partial fee of %s%s%s credits.\n'
local RezFeeMessage = 'You have paid %s%s%s credits to be revived in the nearest medical bay.\n'

--- Class used to handle respawning players upon their death.
--- If a player cannot afford their resurrection fee, the first one is given to them, and as much of the
--- fee as they can afford is taken.
--- Otherwise, after the first free/partial resurrection, the script falls back
--- to whatever the default behavior for the server is.
--- Only operates in specific cells defined by the config file.
---@class SafeRespawn
local safeRespawn = {}

---@param pid PlayerId
function safeRespawn.canAffordRez(pid)
  local PlayerInventory = Players[pid].data.inventory

  local goldIndex = inventoryHelper.getItemIndex(PlayerInventory, "gold_001", -1)

  if not goldIndex then return false end

  return PlayerInventory[goldIndex].count >= safeRespawn.calcRezFee(pid)
end

---@param pid PlayerId
function safeRespawn.calcRezFee(pid)
  local PlayerLevel = Players[pid].data.stats.level

  return 100 * (5 * PlayerLevel)
end

local function rezFeeMessage(fee)
  return RezFeeMessage:format(I.Color.Green, fee, I.Color.White)
end

local function partialFeeMessage(fee)
  return PartialFeeMessage:format(I.Color.Red, I.Color.White, I.Color.Green, fee, I.Color.White)
end

---@param pid PlayerId
function safeRespawn.PayRezFee(pid)
  local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
  if not isValid or not targetPid then return end

  local goldCount, player = 0, Players[targetPid]

  local PlayerInventory, PlayerVars = player.data.inventory, player.data.customVariables

  local goldIndex = inventoryHelper.getItemIndex(PlayerInventory, 'gold_001', -1)

  local rezFee = safeRespawn.calcRezFee(pid)

  if goldIndex then goldCount = PlayerInventory[goldIndex].count end

  if safeRespawn.canAffordRez(pid) then
    PlayerInventory[goldIndex].count = goldCount - rezFee

    PlayerVars.paidLastRez = true

    tes3mp.SendMessage(pid, rezFeeMessage(rezFee))
  else
    if goldIndex then PlayerInventory[goldIndex] = nil end

    PlayerVars.paidLastRez = false

    tes3mp.SendMessage(pid, partialFeeMessage(goldCount))
  end

  player:QuicksaveToDrive()

  GoldItemRef.count = rezFee

  player:LoadItemChanges({ GoldItemRef }, enumerations.inventory.REMOVE)
end

return safeRespawn
