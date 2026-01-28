local config = require 'config'
local logicHandler = require 'packages.logicHandler'
local tableHelper = require 'packages.tableHelper'

local PositionCellFormatter = 'player->positioncell %s %s %s 0 %s'

---@type DefaultInterfaces
local I = require 'interfaces'

---@alias AnnounceRadius 'none'|'loaded'|'server'

---@class CellReviveInfo
---@field cell CellDescription
---@field pos PositionTable

---@class MarkerConfig
---@field markerModel NormalizedPath
---@field markerRecordId RecordId
---@field useMarkers boolean

---@class PositionTable
---@field x number
---@field y number
---@field z number

---@class ReviveConfig
---@field allowWithPermaDeath boolean
---@field bleedOutTime number
---@field diedAnnounceRadius AnnounceRadius
---@field downedAnnounceRadius AnnounceRadius
---@field reviveAnnounceRadius AnnounceRadius
---@field useBleedOut boolean

---@class ReviveStatInfo
---@field fatigue number|'preserve' Percentage of fatigue when revived as a percentage, or optionally, just leave fatigue intact
---@field health number health when revived as a percentage
---@field magicka number|'preserve' Percentage of magicka when revived as a percentage, or optionally, just leave magicka intact

---@class SafeRespawnData
---@field markerConfig MarkerConfig
---@field reviveConfig ReviveConfig
---@field SafeCells table<CellDescription, CellReviveInfo>
---@field StatsOnRevive ReviveStatInfo
local SafeRespawnData = require 'packages.yamlInterface' 'custom/r3vival/config.yml'
local calculateRevivedPlayerStats = require 'custom.r3vival.calculateRevivedPlayerStats' (SafeRespawnData)

---@type SafeRespawn
local safeRespawn = require 'custom.r3vival.safeRespawn'

---@type L10NSearchFunction
local L = require 'packages.l10n' 'r3vival'

local reviveMarkers = {}
local pidMarkerLookup = {}

---@param cellDescription CellDescription
---@param message string
---@param exceptionPids PlayerId[]?
local function sendMessageToAllWithCellLoaded(cellDescription, message, exceptionPids)
	for pid, player in pairs(Players) do
		if tableHelper.containsValue(player.cellsLoaded, cellDescription) and not tableHelper.containsValue(exceptionPids or {}, pid) then
			tes3mp.SendMessage(pid, message .. "\n")
		end
	end
end

---@param message string
---@param exceptionPids PlayerId[]?
local function sendMessageToAllOnServer(message, exceptionPids)
	for pid in pairs(Players) do
		if not tableHelper.containsValue(exceptionPids or {}, pid) then
			tes3mp.SendMessage(pid, message .. "\n")
		end
	end
end

---@param pid PlayerId
---@return boolean isDowned
local function isPlayerDowned(pid)
	local player = Players[pid]

	if not player then return false end

	return player.data.customVariables.isDowned or false
end

---@param pid PlayerId
---@return boolean canRevive
local function canRevivePlayer(pid)
	local player = Players[pid]

	if not player then return false end

	return not player.data.customVariables.cannotRevive
end

---@param uniqueIndex UniqueIndex
---@param cellDescriptionGiven CellDescription?
local function removeReviveMarker(uniqueIndex, cellDescriptionGiven)
	if uniqueIndex then
		local useTemporaryLoad = false

		local cellDescription
		-- The OnObjectActivate call for this function provides a cell description in case the revive marker is from an old session
		-- Use that if provided, otherwise it's safe to get it from looking up its information
		if not cellDescriptionGiven then
			cellDescription = reviveMarkers[uniqueIndex].cellDescription
		else
			cellDescription = cellDescriptionGiven
		end

		if LoadedCells[cellDescription] == nil then
			logicHandler.LoadCell(cellDescription)
			useTemporaryLoad = true
		end

		logicHandler.DeleteObjectForEveryone(cellDescription, uniqueIndex)
		LoadedCells[cellDescription]:DeleteObjectData(uniqueIndex)

		if useTemporaryLoad then
			logicHandler.UnloadCell(cellDescription)
		end

		if reviveMarkers[uniqueIndex] then
			pidMarkerLookup[reviveMarkers[uniqueIndex].pid] = nil
		end

		reviveMarkers[uniqueIndex] = nil
	end
end

---@param downedPid PlayerId
---@param reviverPid PlayerId
local function onPlayerRevive(downedPid, reviverPid)
	local newHealth, newMagicka, newFatigue = calculateRevivedPlayerStats(downedPid)

	-- Inform players about the revival
	local exemptPids = { downedPid, reviverPid }
	local downedPlayerName = Players[downedPid].name
	local reviverPlayerName = Players[reviverPid].name
	local cell = Players[downedPid].data.location.cell
	local broadcastMessage = L('revivedOtherMessage', { receive = downedPlayerName, give = reviverPlayerName })

	-- ...Inform the player being revived
	tes3mp.SendMessage(downedPid, L('reviveReceivedMessage', { name = reviverPlayerName }) .. '\n')

	-- ...Inform the reviver
	tes3mp.SendMessage(reviverPid, L('reviveGivenMessage', { name = downedPlayerName }) .. '\n')

	-- ...Inform others (if configured)
	if SafeRespawnData.reviveConfig.reviveAnnounceRadius == 'cell' then
		sendMessageToAllWithCellLoaded(cell, broadcastMessage, exemptPids)
	elseif SafeRespawnData.reviveConfig.reviveAnnounceRadius == 'server' then
		sendMessageToAllOnServer(broadcastMessage, exemptPids)
	end

	-- Now finally actually revive the player
	Players[downedPid].data.customVariables.isDowned = false

	-- contentFixer.UnequipDeadlyItems(downedPid)
	tes3mp.Resurrect(downedPid, 0)

	-- Set the players stats...
	tes3mp.SetHealthCurrent(downedPid, newHealth)
	tes3mp.SetMagickaCurrent(downedPid, newMagicka)
	tes3mp.SetFatigueCurrent(downedPid, newFatigue)

	tes3mp.SendStatsDynamic(downedPid)

	-- Cleanup the player's revive marker, if created
	if SafeRespawnData.markerConfig.useMarkers then
		removeReviveMarker(pidMarkerLookup[downedPid])
	end
end

local function onBleedoutExpire(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	local player = Players[pid]; local customVariables = player.data.customVariables
	customVariables.isDowned = false

	-- Inform the player
	if config.playersRespawn then
		tes3mp.SendMessage(pid, L 'bleedoutPlayerMessage' .. '\n')
	else
		tes3mp.SendMessage(pid, L 'defaultPermanentDeath' .. '\n')
	end

	-- Inform others if configured
	local exemptPids = { pid }
	local pname = player.name
	local message = L('bleedoutOtherMessage', { name = pname })
	local cell = player.data.location.cell

	if SafeRespawnData.reviveConfig.diedAnnounceRadius == 'cell' then
		sendMessageToAllWithCellLoaded(cell, message, exemptPids)
	elseif SafeRespawnData.reviveConfig.diedAnnounceRadius == 'server' then
		sendMessageToAllOnServer(message, exemptPids)
	end

	-- Resurrect the player, if permadeath is disabled
	if config.playersRespawn then
		--- It might be worth calling eventValidators/Handlers as the serverCore function does, but, meh
		player:Resurrect()
	else
		-- Set a flag permanently preventing the player from being able to be revived
		customVariables.cannotRevive = true
	end

	-- Cleanup the player's revive marker, if created
	if SafeRespawnData.markerConfig.useMarkers then
		removeReviveMarker(pidMarkerLookup[pid])
	end
end

---@param pid PlayerId
local function bleedoutTick(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	local player = Players[targetPid]

	local cvars = player.data.customVariables
	if cvars.isDowned ~= true then return end

	-- Check if the player is still supposed to be bleeding out
	-- Increment timer
	cvars.bleedoutTicks = (cvars.bleedoutTicks or 0) + 1

	if SafeRespawnData.reviveConfig.useBleedOut
			and cvars.bleedoutTicks >= SafeRespawnData.reviveConfig.bleedOutTime then
		-- Player has exceeded bleedout time!
		onBleedoutExpire(pid)
	else
		-- Queue up another tick countdown
		I.timed.defer(bleedoutTick, 1, pid)
	end
end

local MarkerData = { refId = SafeRespawnData.markerConfig.markerRecordId, count = 1, charge = -1, enchantmentCharge = -1, soul = -1 }

---@param pid PlayerId
local function createReviveMarker(pid)
	local playerName = Players[pid].name
	local cellDescription = Players[pid].data.location.cell

	local location = {
		posX = tes3mp.GetPosX(pid),
		posY = tes3mp.GetPosY(pid),
		posZ = tes3mp.GetPosZ(pid) + 10,
		rotX = 0,
		rotY = 0,
		rotZ = tes3mp.GetRotZ(pid)
	}

	-- Create the marker
	local useTemporaryLoad = false
	if not LoadedCells[cellDescription] then
		logicHandler.LoadCell(cellDescription)
		useTemporaryLoad = true
	end

	local uniqueIndex = logicHandler.CreateObjectAtLocation(cellDescription, location, MarkerData, 'place')

	if useTemporaryLoad then
		logicHandler.UnloadCell(cellDescription)
	end

	reviveMarkers[uniqueIndex] = { playerName = playerName, cellDescription = cellDescription, pid = pid }
	pidMarkerLookup[pid] = uniqueIndex

	-- Delete the marker for the downed player, and anyone who was in the cell
	for localPid in pairs(Players) do
		if tes3mp.GetCell(localPid) == cellDescription then
			logicHandler.DeleteObjectForPlayer(localPid, cellDescription, uniqueIndex)
		end
	end

	-- A little bit extra to maybe ensure that the player whose marker it is doesn't see it
	logicHandler.DeleteObjectForPlayer(pid, cellDescription, uniqueIndex)
end

---@param pid PlayerId
---@param timeRemaining number?
local function setPlayerDowned(pid, timeRemaining)
	local player = Players[pid]; local customVars = player.data.customVariables

	-- Set the variables
	customVars.isDowned = true

	-- If the player logged out while bleeding out, they will have a non-standard number of seconds left
	local secondsLeft
	if not timeRemaining then
		secondsLeft = SafeRespawnData.reviveConfig.bleedOutTime
		customVars.bleedoutTicks = 0
	else
		secondsLeft = timeRemaining
		customVars.bleedoutTicks = SafeRespawnData.reviveConfig.bleedOutTime - secondsLeft
	end

	-- Send the first basic messages
	-- ... To the player
	tes3mp.SendMessage(pid, L 'awaitingReviveMessage' .. '\n')

	-- ... And the others (if configured)
	local downedPlayerName = player.name
	local exemptPids = { pid }
	local cell = player.data.location.cell

	local downBroadcastMessage = L('awaitingReviveOtherMessage', { name = downedPlayerName })

	if SafeRespawnData.reviveConfig.downedAnnounceRadius == 'cell' then
		sendMessageToAllWithCellLoaded(cell, downBroadcastMessage, exemptPids)
	elseif SafeRespawnData.reviveConfig.downedAnnounceRadius == 'server' then
		sendMessageToAllOnServer(downBroadcastMessage, exemptPids)
	end

	-- Do all the bleedout-related things, provided we're configured to do that
	if SafeRespawnData.reviveConfig.useBleedOut then
		-- Tell the player that they're bleeding out, and how many seconds they have left
		tes3mp.SendMessage(pid, L('bleedingOutMessage', { seconds = tostring(secondsLeft) }) .. '\n')
		I.timed.defer(bleedoutTick, 1, pid)
	end

	-- Create a marker, if configured
	if SafeRespawnData.markerConfig.useMarkers then
		createReviveMarker(pid)
	end

	-- Tell the player the command prompt to die
	tes3mp.SendMessage(pid, L 'giveInPrompt' .. '\n')
end

--- We use this to set a player to the downed state when they die, with a special case for if the player has logged back in after being downed (using a flag set during in Methods.OnPlayerLogin to know)
--- And also obviously we only want to set the player downed if they aren't already
---@param pid PlayerId
local function trySetPlayerDowned(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	local player = Players[targetPid]; local customVars = player.data.customVariables

	if customVars.cannotRevive then return end

	if customVars.loggedOutDowned then
		local remaining = SafeRespawnData.reviveConfig.bleedOutTime - customVars.bleedoutTicks

		-- Clear the logout flag
		customVars.loggedOutDowned = nil

		setPlayerDowned(pid, remaining)
	elseif not isPlayerDowned(pid) then
		setPlayerDowned(pid)
	end
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
---@return EventStatusTable
local function handleDownedPlayer(eventStatus, pid)
	-- Here we replicate some of the tesmp default logic that we're blocking
	local message
	if tes3mp.DoesPlayerHavePlayerKiller(pid) and tes3mp.GetPlayerKillerPid(pid) ~= pid then
		local killerPid = tes3mp.GetPlayerKillerPid(pid)
		message = L(
			'defaultKilledByPlayer',
			{
				name = logicHandler.GetChatName(pid),
				killer = logicHandler.GetChatName(killerPid)
			}
		)
	elseif tes3mp.GetPlayerKillerName(pid) ~= '' then
		message = L(
			'defaultKilledByOther',
			{ name = logicHandler.GetChatName(pid), killer = tes3mp.GetPlayerKillerName(pid) }
		)
	else
		message = L('defaultSuicide', { name = logicHandler.GetChatName(pid) })
	end

	tes3mp.SendMessage(pid, message .. '\n', true)

	if config.playersRespawn or SafeRespawnData.reviveConfig.allowWithPermaDeath then
		trySetPlayerDowned(pid)
	else
		tes3mp.SendMessage(pid, L 'defaultPermanentDeath' .. '\n', false)
		eventStatus.validDefaultHandler = false
		eventStatus.validCustomHandlers = true
		return eventStatus
	end

	eventStatus.validDefaultHandler = false
	eventStatus.validCustomHandlers = false
	return eventStatus
end

---@type TES3MPScriptRegistration
return {
	chatCommands = {
		die = {
			callback = function(pid, _)
				if isPlayerDowned(pid) then return onBleedoutExpire(pid) end
			end,
		},
	},
	eventHandlers = {
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@param cellDescription CellDescription
		---@return EventStatusTable
		OnObjectActivate = function(eventStatus, pid, cellDescription, _, _)
			local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
			if not isValid or not targetPid or not LoadedCells[cellDescription] then return eventStatus end

			-- A lot of this code is copied from eventHandler.OnObjectActivate
			tes3mp.ReadReceivedObjectList()

			for index = 0, tes3mp.GetObjectListSize() - 1 do
				local objectPid, activatorPid, objectUniqueIndex, objectRefId

				-- Detect if the object being activated is a player
				if tes3mp.IsObjectPlayer(index) then
					objectPid = tes3mp.GetObjectPid(index)
				else
					objectUniqueIndex = ('%s-%s'):format(tes3mp.GetObjectRefNum(index), tes3mp.GetObjectMpNum(index))
					objectRefId = tes3mp.GetObjectRefId(index)
				end

				-- Detect if the object was activated by a player
				if tes3mp.DoesObjectHavePlayerActivating(index) then
					activatorPid = tes3mp.GetObjectActivatingPid(index)
				end

				-- If a player was activating a player...
				if objectPid and activatorPid then
					-- Check if the target player is currently downed
					if isPlayerDowned(objectPid) then
						-- Revive them!
						onPlayerRevive(objectPid, activatorPid)
					end
				elseif objectRefId:ciEqual(SafeRespawnData.markerConfig.markerRecordId) then
					-- The player activated a revive marker!
					if reviveMarkers[objectUniqueIndex] and isPlayerDowned(reviveMarkers[objectUniqueIndex].pid) then
						onPlayerRevive(reviveMarkers[objectUniqueIndex].pid, activatorPid)
					end

					-- It's possible that markers might be left over from previous sessions, so we'll always make sure to delete one that's activated
					removeReviveMarker(objectUniqueIndex, cellDescription)
				end
			end

			return eventStatus
		end,
		OnPlayerFinishLogin = function(eventStatus, pid)
			local player = Players[pid]; local customVariables = player.data.customVariables
			-- Check if a player logged out while downed
			-- If they did, set the flags up for them to resume bleeding out when their death event triggers
			-- The rest of setting up / resuming is left to the death event
			-- Also double-kill them, to be really sure they're actually dead
			if customVariables.isDowned then
				player:SetHealthCurrent(0)
				customVariables.loggedOutDowned = true
			end

			return eventStatus
		end,
		--- Detect if this script's permanent record has been created on this server yet, and create it if not
		OnServerPostInit = function()
			local recordStore = RecordStores.miscellaneous; local permanentRecords = recordStore.data.permanentRecords
			local markerId = SafeRespawnData.markerConfig.markerRecordId

			if permanentRecords[markerId] then return end

			permanentRecords[markerId] = {
				model = SafeRespawnData.markerConfig.markerModel,
				name = L 'reviveMarkerName',
				script = 'nopickup',
			}

			recordStore:Save()
		end,
	},
	eventValidators = {
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@return EventStatusTable
		OnPlayerDeath = function(eventStatus, pid)
			local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
			if not isValid or not targetPid then return eventStatus end

			local player = Players[targetPid]

			local cellDescription = player.data.location.cell

			local safeCell = SafeRespawnData.SafeCells[cellDescription]

			--- In unsafe cells, OR,
			--- Safe cells, where the player failed to pay their previous respawn fee, down them.
			if not safeCell
					or (player.data.customVariables.paidLastRez == false and not safeRespawn.canAffordRez(targetPid)) then
				return handleDownedPlayer(eventStatus, pid)
			end

			local safeCellDestination = PositionCellFormatter:format(
				safeCell.pos.x,
				safeCell.pos.y,
				safeCell.pos.z,
				safeCell.cell
			)

			logicHandler.RunConsoleCommandOnPlayer(targetPid, safeCellDestination, false)

			local newHealth, newMagicka, newFatigue = calculateRevivedPlayerStats(targetPid)

			tes3mp.Resurrect(targetPid, 0)
			tes3mp.SetHealthCurrent(targetPid, newHealth)
			tes3mp.SetMagickaCurrent(targetPid, newMagicka)
			tes3mp.SetFatigueCurrent(targetPid, newFatigue)
			tes3mp.SendStatsDynamic(targetPid)

			safeRespawn.PayRezFee(targetPid)

			eventStatus.validCustomHandlers = false
			eventStatus.validDefaultHandler = false

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@return EventStatusTable eventStatus
		OnPlayerDisconnect = function(eventStatus, pid)
			-- Remove the revive markers of players who disconnect
			if isPlayerDowned(pid) and SafeRespawnData.markerConfig.useMarkers then
				removeReviveMarker(pidMarkerLookup[pid])
			end

			return eventStatus
		end,
	},
}
