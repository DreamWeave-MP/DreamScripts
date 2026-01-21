local enumerations = require 'tes3mp.enumerations'
local inventoryHelper = require 'tes3mp.util.inventory'
local logicHandler = require 'tes3mp.logicHandler'
local yamlInterface = require 'yamlInterface'

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

---@param pid PlayerId
---@return number, number, number
local function CalculateRevivedPlayerStats(pid)
	local healthBase = tes3mp.GetHealthBase(pid)
	local fatigueCurrent, fatigueBase = tes3mp.GetFatigueCurrent(pid), tes3mp.GetFatigueBase(pid)
	local magickaCurrent, magickaBase = tes3mp.GetMagickaCurrent(pid), tes3mp.GetMagickaBase(pid)

	local newHealth, newMagicka, newFatigue

	local targetHealth, targetMagicka, targetFatigue =
			assert(tonumber(SafeRespawnData.StatsOnRevive.health)), tonumber(SafeRespawnData.StatsOnRevive.magicka),
			tonumber(SafeRespawnData.StatsOnRevive.fatigue)

	if targetHealth < 1.0 then
		newHealth = math.floor((healthBase * SafeRespawnData.StatsOnRevive.health) + 0.5)
	else
		newHealth = SafeRespawnData.StatsOnRevive.health
	end

	if not targetMagicka and SafeRespawnData.StatsOnRevive.magicka == 'preserve' then
		newMagicka = magickaCurrent
	elseif targetMagicka and targetMagicka < 1.0 then
		newMagicka = math.floor((magickaBase * SafeRespawnData.StatsOnRevive.magicka) + 0.5)
	else
		newMagicka = targetMagicka or magickaBase
	end

	if not targetFatigue and SafeRespawnData.StatsOnRevive.fatigue == 'preserve' then
		newFatigue = fatigueCurrent
	elseif targetFatigue and targetFatigue < 1.0 then
		newFatigue = math.floor((fatigueBase * SafeRespawnData.StatsOnRevive.fatigue) + 0.5)
	else
		newFatigue = targetFatigue or fatigueBase
	end

	newHealth = math.max(math.min(newHealth, healthBase), 1)
	newMagicka = math.max(math.min(newMagicka, magickaBase), 0)
	newFatigue = math.max(math.min(newFatigue, fatigueBase), 0)
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
