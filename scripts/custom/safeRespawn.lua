local enumerations = require 'packages.networkEnums'
local inventoryHelper = require 'packages.inventoryHelper'
local logicHandler = require 'packages.logicHandler'
local yamlInterface = require 'packages.yamlInterface'

---@class ReviveStatInfo
---@field fatigue number|'preserve' Percentage of fatigue when revived as a percentage, or optionally, just leave fatigue intact
---@field health number health when revived as a percentage
---@field magicka number|'preserve' Percentage of magicka when revived as a percentage, or optionally, just leave magicka intact

---@class PositionTable
---@field x number
---@field y number
---@field z number

---@class CellReviveInfo
---@field cell CellDescription
---@field pos PositionTable

---@class SafeRespawnData
---@field SafeCells table<CellDescription, CellReviveInfo>
---@field StatsOnRevive ReviveStatInfo
local SafeRespawnData = yamlInterface('custom/safeRespawn/config.yml')

---@type DefaultInterfaces
local I = require 'interfaces'

---@class SafeRespawn
local safeRespawn = {}
local EPS = 0.001

local ceil, floor = math.ceil, math.floor
---@param input number
local function round(input)
	return input >= 0 and floor(input + 0.5) or ceil(input - 0.5)
end

---@param input number
---@param high number
---@param low number
local function clamp(input, low, high)
	return input < low and low or (input > high and high or input)
end

---@param target number?
---@param base number
local function statValue(target, base)
	if not target then return base end

	if target <= 1.0 and target >= EPS then
		return round(target * base)
	end

	return base
end

---@param pid PlayerId
---@return number, number, number
local function CalculateRevivedPlayerStats(pid)
	local baseHealth = tes3mp.GetHealthBase(pid)
	local currentFatigue, baseFatigue = tes3mp.GetFatigueCurrent(pid), tes3mp.GetFatigueBase(pid)
	local currentMagicka, baseMagicka = tes3mp.GetMagickaCurrent(pid), tes3mp.GetMagickaBase(pid)

	local newHealth, newMagicka, newFatigue

	local targetHealth, targetMagicka, targetFatigue =
			assert(tonumber(SafeRespawnData.StatsOnRevive.health)), tonumber(SafeRespawnData.StatsOnRevive.magicka),
			tonumber(SafeRespawnData.StatsOnRevive.fatigue)

	newHealth = clamp(statValue(targetHealth, baseHealth), 1, baseHealth)

	newMagicka = clamp(
		SafeRespawnData.StatsOnRevive.magicka == 'preserve' and currentMagicka or statValue(targetMagicka, baseMagicka),
		0,
		baseMagicka
	)

	newFatigue = clamp(
		SafeRespawnData.StatsOnRevive.fatigue == 'preserve' and currentFatigue or statValue(targetFatigue, baseFatigue),
		0,
		baseFatigue
	)

	return newHealth, newMagicka, newFatigue
end

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

local PositionCellFormatter = 'player->positioncell %s %s %s 0 %s'

---@param eventStatus EventStatusTable
---@param pid PlayerId
---@return EventStatusTable
function safeRespawn.checkSafeRespawn(eventStatus, pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return eventStatus end

	local player = Players[targetPid]

	local cellDescription = player.data.location.cell

	local safeCell = SafeRespawnData.SafeCells[cellDescription]

	if not safeCell
			or (player.data.customVariables.paidLastRez == false and not safeRespawn.canAffordRez(targetPid)) then
		return
				eventStatus
	end

	local safeCellDestination = PositionCellFormatter:format(
		safeCell.pos.x,
		safeCell.pos.y,
		safeCell.pos.z,
		safeCell.cell
	)

	logicHandler.RunConsoleCommandOnPlayer(targetPid, safeCellDestination, false)

	local newHealth, newMagicka, newFatigue = CalculateRevivedPlayerStats(targetPid)

	tes3mp.Resurrect(targetPid, 0)
	tes3mp.SetHealthCurrent(targetPid, newHealth)
	tes3mp.SetMagickaCurrent(targetPid, newMagicka)
	tes3mp.SetFatigueCurrent(targetPid, newFatigue)
	tes3mp.SendStatsDynamic(targetPid)

	safeRespawn.PayRezFee(targetPid)

	eventStatus.validCustomHandlers = false
	eventStatus.validDefaultHandler = false

	return eventStatus
end

local GoldItemRef = { refId = 'gold_001', count = 0, charge = -1, enchantmentcharge = -1, soul = '' }

local RezFeeMessage = 'You have paid %s%s%s credits to be revived in the nearest medical bay.\n'
local function rezFeeMessage(fee)
	return RezFeeMessage:format(I.Color.Green, fee, I.Color.White)
end

local PartialFeeMessage =
'%sWARNING:%sYou were unable to pay your last resurrection fee. You will not be resurrected again if you cannot afford the fee. You paid a partial fee of %s%s%s credits.\n'
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

---@type TES3MPScriptRegistration
return {
	eventValidators = {
		OnPlayerDeath = safeRespawn.checkSafeRespawn,
	},
}
