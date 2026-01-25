--[[
FIXME: We made this change in DreamScripts, but, is it necessary?
add in function SaveObjectsPlaced under self.data.objectData[uniqueIndex].location = location
self.data.objectData[uniqueIndex].scale = 1
tableHelper.insertValueIfMissing(self.data.packets.scale, uniqueIndex)
---------------------------
]]
local logicHandler = require 'packages.logicHandler'

---@type DefaultInterfaces
local I = require 'interfaces'

---@type L10NSearchFunction
local L = require 'l10n' 'decorateHelp'

---@type MenuHelper
local menuHelper = I.menuHelper
local MainGUIId, PromptGUIId = menuHelper.getMenuId(), menuHelper.getMenuId()

---@class DecorateHelp
local DecorateScript = {}

local CellSize = 8192

local Text = {
	Bigger = L 'Bigger',
	Close = L 'Close',
	Down = L 'Down',
	Drop = L 'Drop',
	East = L 'East',
	Info = L 'Info',
	MovE = L('MovE', { East = L 'East', }),
	MovN = L('MovN', { North = L 'North', }),
	MovUp = L('MovUp', { Height = L 'Height', }),
	None = L 'None',
	North = L 'North',
	NoOption = L 'NoOption',
	NoSelect = L 'NoSelect',
	Opt1 = L 'Option1',
	Opt2 = L(
		'Option2',
		{
			Adjust = L 'Adjust',
			Bigger = L 'Bigger',
			Close = L 'Close',
			Drop = L 'Drop',
			Down = L 'Down',
			East = L 'East',
			Height = L 'Height',
			North = L 'North',
			Smaller = L 'Smaller',
			South = L 'South',
			Turn = L 'Turn',
			Up = L 'Up',
			West = L 'West',
		}
	),
	PlaceObject = L 'PlaceObject',
	Prompt = L 'Prompt',
	RotX = L('RotX', { Turn = L 'Turn', }),
	RotY = L('RotY', { Turn = L 'Turn', }),
	RotZ = L('RotZ', { Turn = L 'Turn', }),
	Smaller = L 'Smaller',
	South = L 'South',
	Up = L 'Up',
	WarningCell = L 'WarningCell',
	West = L 'West',
}

local playerSelectedObject = {}
local playerCurrentMode = {}
local playersTab = {}

---@param pid PlayerId
function DecorateScript.startDrop(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	DecorateScript.moveObject(targetPid)
end

---@param pid PlayerId
---@return table? player
local function getPlayer(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	return Players[targetPid]
end

--- Returns the player's lowercase account name for use as a table key
--- If they're not logged in or otherwise invalid returns nil
---@param pid PlayerId
---@return string? playerName
local function getName(pid)
	local player = getPlayer(pid)
	if player then return player.accountName:lower() end
end

--- Returns the player's lowercase account name for use as a table key
--- If they're not logged in or otherwise invalid, murders the server
---@param pid PlayerId
---@return string playerName
local function getNameAngry(pid)
	return assert(getName(pid))
end

---@param pid PlayerId
---@param refIndex string
local function setSelectedObject(pid, refIndex)
	local name = getNameAngry(pid)
	playerSelectedObject[name] = refIndex
end

---@param refIndex string
---@param cellId CellDescription
local function GetObject(refIndex, cellId)
	if not refIndex then return end

	local cell = LoadedCells[cellId]

	if not cell:ContainsObject(refIndex) then return end

	return cell.data.objectData[refIndex]
end

---@param pid PlayerId
---@param uniqueIndex UniqueIndex unique index string
---@param cellDescription CellDescription
---@param forEveryone boolean?
local function ResendPlace(pid, uniqueIndex, cellDescription, forEveryone)
	forEveryone = forEveryone or false

	logicHandler.DeleteObject(pid, cellDescription, uniqueIndex, forEveryone)

	tes3mp.ClearObjectList()
	tes3mp.SetObjectListPid(pid)
	tes3mp.SetObjectListCell(cellDescription)

	local cell = LoadedCells[cellDescription]
	local object = cell.data.objectData[uniqueIndex]

	if not object then return end

	local inventory = object.inventory

	if object and object.location and object.refId then
		local refNum, mpNum = uniqueIndex:splitUniqueIndex()
		tes3mp.SetObjectRefNum(refNum)
		tes3mp.SetObjectMpNum(mpNum)
		tes3mp.SetObjectRefId(object.refId)
		tes3mp.SetObjectCharge(object.charge or -1)
		tes3mp.SetObjectEnchantmentCharge(object.enchantmentCharge or -1)
		tes3mp.SetObjectPosition(object.location.posX, object.location.posY, object.location.posZ)
		tes3mp.SetObjectRotation(object.location.rotX, object.location.rotY, object.location.rotZ)
		tes3mp.SetObjectScale(object.scale or 1)

		if inventory then
			for _, item in pairs(inventory) do
				tes3mp.SetContainerItemRefId(item.refId)
				tes3mp.SetContainerItemCount(item.count)
				tes3mp.SetContainerItemCharge(item.charge)
				tes3mp.AddContainerItem()
			end
		end

		tes3mp.AddObject()
	end

	tes3mp.SendObjectPlace(forEveryone)
	tes3mp.SendObjectScale(forEveryone)

	if inventory then
		tes3mp.SendContainer(forEveryone)
	end
end

---@param pid PlayerId
local function showPromptGUI(pid)
	local message = '[' .. playerCurrentMode[getNameAngry(pid)] .. Text.Prompt
	tes3mp.InputDialog(pid, PromptGUIId, message, '')
end

---@param start number
---@param add number
---@return number added
local function convertAddedDegrees(start, add)
	return math.rad((math.deg(start) + add) % 360)
end

---@param coord number
---@return integer gridCoord Exterior position flattened to a cell grid coordinate
local function grid(coord)
	return math.floor(coord / CellSize)
end

---@param pid PlayerId
---@param data integer
local function onEnterPrompt(pid, data)
	local cell, name = tes3mp.GetCell(pid), getNameAngry(pid)
	local object = GetObject(playerSelectedObject[name], cell)

	if not object then
		return tes3mp.MessageBox(pid, -1, Text.NoSelect)
	end

	local mode = playerCurrentMode[name]

	data = assert(tonumber(data))
	object.scale = object.scale or 1

	local location, scaling = object.location, object.scale

	if mode == Text.RotX then
		location.rotX = convertAddedDegrees(location.rotX, data)
	elseif mode == Text.RotY then
		location.rotY = convertAddedDegrees(location.rotY, data)
	elseif mode == Text.RotZ then
		location.rotZ = convertAddedDegrees(location.rotZ, data)
	elseif mode == Text.MovN then
		location.posY = location.posY + data
	elseif mode == Text.MovE then
		location.posX = location.posX + data
	elseif mode == Text.MovUp then
		location.posZ = location.posZ + data
	elseif mode == Text.Up then
		location.posZ = location.posZ + 10
	elseif mode == Text.Down then
		location.posZ = location.posZ - 10
	elseif mode == Text.East then
		location.posX = location.posX + 10
	elseif mode == Text.West then
		location.posX = location.posX - 10
	elseif mode == Text.North then
		location.posY = location.posY + 10
	elseif mode == Text.South then
		location.posY = location.posY - 10
	elseif mode == Text.Bigger then
		if object.scale < 2 then
			object.scale = object.scale + 0.1
		else
			tes3mp.MessageBox(pid, -1, Text.NoOption)
		end
	elseif mode == Text.Smaller then
		if scaling > 0.1 then
			object.scale = object.scale - 0.1
		else
			tes3mp.MessageBox(pid, -1, Text.NoOption)
		end
	elseif mode == Text.Close then
		location.posY = location.posY
		return
	end

	if tes3mp.IsInExterior(pid) then
		local loadedCell = LoadedCells[cell]

		if loadedCell.gridX ~= grid(location.posX) or loadedCell.gridY ~= grid(location.posY) then
			return tes3mp.MessageBox(pid, -1, Text.WarningCell)
		end
	end

	ResendPlace(pid, playerSelectedObject[name], cell, true)
end

---@param pid PlayerId
---@param refIndex UniqueIndex Generated uniqueIndex string
function DecorateScript.SetSelectedObject(pid, refIndex)
	setSelectedObject(pid, refIndex)
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
function DecorateScript.OnObjectPlace(eventStatus, pid, _)
	tes3mp.ReadReceivedObjectList()

	setSelectedObject(
		pid,
		('%s-%s'):format(tes3mp.GetObjectRefNum(0), tes3mp.GetObjectMpNum(0))
	)

	return eventStatus
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
---@param idGui GUIID
---@param data integer The selected option in the given menu
function DecorateScript.OnGUIAction(eventStatus, pid, idGui, data)
	data = assert(tonumber(data))

	local name = getNameAngry(pid)

	if idGui == MainGUIId then
		-- Closed
		if data >= 15 or data < 0 then return end

		if data == 0 then
			playerCurrentMode[name] = Text.MovN
			showPromptGUI(pid)
		elseif data == 1 then
			playerCurrentMode[name] = Text.MovE
			showPromptGUI(pid)
		elseif data == 2 then
			playerCurrentMode[name] = Text.MovUp
			showPromptGUI(pid)
		elseif data == 3 then
			playerCurrentMode[name] = Text.RotX
			showPromptGUI(pid)
		elseif data == 4 then
			playerCurrentMode[name] = Text.RotY
			showPromptGUI(pid)
		elseif data == 5 then
			playerCurrentMode[name] = Text.RotZ
			showPromptGUI(pid)
		elseif data == 6 then
			playerCurrentMode[name] = Text.Up
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 7 then
			playerCurrentMode[name] = Text.Down
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 8 then
			playerCurrentMode[name] = Text.East
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 9 then
			playerCurrentMode[name] = Text.West
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 10 then
			playerCurrentMode[name] = Text.North
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 11 then
			playerCurrentMode[name] = Text.South
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 12 then
			playerCurrentMode[name] = Text.Bigger
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 13 then
			playerCurrentMode[name] = Text.Smaller
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif data == 14 then
			playersTab[name] = true

			logicHandler.RunConsoleCommandOnPlayer(pid, 'tb', false)
			tes3mp.MessageBox(pid, -1, Text.Info)

			I.timed.defer(DecorateScript.startDrop, 0.01, pid)
		end
	elseif idGui == PromptGUIId then
		onEnterPrompt(pid, data)
		playerCurrentMode[name] = nil
		DecorateScript.showMainGUI(pid)
	end

	return eventStatus
end

---@param pid PlayerId
function DecorateScript.moveObject(pid)
	local cell, name = tes3mp.GetCell(pid), getNameAngry(pid)

	local object = GetObject(playerSelectedObject[name], cell)

	if not object then
		return tes3mp.MessageBox(pid, -1, Text.NoSelect)
	end

	local drawState = tes3mp.GetDrawState(pid)

	local playerAngleZ = tes3mp.GetRotZ(pid)

	if playerAngleZ > 3.0 then
		playerAngleZ = 3.0
	elseif playerAngleZ < -3.0 then
		playerAngleZ = -3.0
	end

	local playerAngleX = tes3mp.GetRotX(pid)

	if playerAngleX > 1.5 then
		playerAngleX = 1.5
	elseif playerAngleX < -1.5 then
		playerAngleX = -1.5
	end

	local PosX = (200 * math.sin(playerAngleZ) + tes3mp.GetPosX(pid))
	local PosY = (200 * math.cos(playerAngleZ) + tes3mp.GetPosY(pid))
	local PosZ = (200 * math.sin(-playerAngleX) + (tes3mp.GetPosZ(pid) + 100))

	if PosZ < tes3mp.GetPosZ(pid) then PosZ = tes3mp.GetPosZ(pid) end

	if tes3mp.IsInExterior(pid) then
		local loadedCell = LoadedCells[cell]

		if loadedCell.gridX ~= grid(PosX) or loadedCell.gridY ~= grid(PosY) then
			PosX, PosY, PosZ = object.location.posX, object.location.posY, object.location.posZ
			tes3mp.MessageBox(pid, -1, Text.WarningCell)
		end
	end

	if drawState == 1 then
		object.location.rotZ = convertAddedDegrees(object.location.rotZ, 1)
	elseif drawState == 2 then
		object.location.rotZ = convertAddedDegrees(object.location.rotX, 1)
	end

	object.location.posX = PosX
	object.location.posY = PosY
	object.location.posZ = PosZ

	ResendPlace(pid, playerSelectedObject[name], cell, false)

	if tes3mp.GetSneakState(pid) then
		tes3mp.MessageBox(pid, -1, Text.PlaceObject)

		ResendPlace(pid, playerSelectedObject[name], cell, true)
		playersTab[name] = nil

		logicHandler.RunConsoleCommandOnPlayer(pid, 'tb', false)
	else
		I.timed.defer(DecorateScript.startDrop, 0.01, pid)
	end
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
---@param cellDescription CellDescription
---@return EventStatusTable?
function DecorateScript.OnObjectActivate(eventStatus, pid, cellDescription, _)
	local name = getNameAngry(pid)

	if playersTab[name] and GetObject(playerSelectedObject[name], cellDescription) then
		eventStatus.validCustomHandlers = false
		eventStatus.validDefaultHandler = false
	end

	return eventStatus
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
function DecorateScript.OnPlayerCellChange(eventStatus, pid, _, _)
	local name = getNameAngry(pid)

	playerSelectedObject[name] = nil

	if playersTab[name] then
		logicHandler.RunConsoleCommandOnPlayer(pid, 'tb', false)
		playersTab[name] = nil
	end

	return eventStatus
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
function DecorateScript.OnPlayerAuthentified(eventStatus, pid)
	local name = getNameAngry(pid)

	if playersTab[name] then playersTab[name] = nil end

	return eventStatus
end

---@param pid PlayerId
function DecorateScript.showMainGUI(pid)
	local name = getNameAngry(pid)

	if playersTab[name] then return end

	local currentItem = Text.None

	local selected = playerSelectedObject[name]
	local object = GetObject(selected, tes3mp.GetCell(pid))

	if selected and object then
		currentItem = ('%s (%s)'):format(object.refId, selected)
	end

	tes3mp.CustomMessageBox(pid, MainGUIId, Text.Opt1 .. currentItem, Text.Opt2)
end

---@type TES3MPScriptRegistration
return {
	chatCommands = {
		dh = { callback = DecorateScript.showMainGUI, },
	},
	eventHandlers = {
		OnGUIAction = DecorateScript.OnGUIAction,
		OnObjectPlace = DecorateScript.OnObjectPlace,
		OnPlayerCellChange = DecorateScript.OnPlayerCellChange,
		OnPlayerAuthentified = DecorateScript.OnPlayerAuthentified,
	},
	eventValidators = {
		OnObjectActivate = DecorateScript.OnObjectActivate,
	},
}
