--[[
FIXME: We made this change in DreamScripts, but, is it necessary?
add in function SaveObjectsPlaced under self.data.objectData[uniqueIndex].location = location
self.data.objectData[uniqueIndex].scale = 1
tableHelper.insertValueIfMissing(self.data.packets.scale, uniqueIndex)
---------------------------
]]

---@type DefaultInterfaces
local I = require 'interfaces'

---@type L10NSearchFunction
local L = require('l10n')('decorateHelp')

---@type MenuHelper
local menuHelper = I.menuHelper
local tableHelper = require 'tes3mp.util.table'
MainGUIId, PromptGUIId = menuHelper.getMenuId(), menuHelper.getMenuId()

local cfg = {}

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
	NoOption = L 'NoOption',
	NoSelect = L 'NoSelect',
	North = L 'North',
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

tableHelper.print(Text)

local playerSelectedObject = {}
local playerCurrentMode = {}
local playersTab = {}

function StartDrop(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	DecorateScript.moveObject(targetPid)
end

local function GetName(pid)
	return Players[pid].accountName:lower()
end

local function setSelectedObject(pid, refIndex)
	playerSelectedObject[GetName(pid)] = refIndex
end

local function GetObject(refIndex, cellId)
	if not refIndex then return false end
	local cell = LoadedCells[cellId]

	if not cell:ContainsObject(refIndex) then return end

	return cell.data.objectData[refIndex]
end

local function DeleteObject(pid, cellDescription, uniqueIndex, forEveryone)
	tes3mp.ClearObjectList()
	tes3mp.SetObjectListPid(pid)
	tes3mp.SetObjectListCell(cellDescription)
	local splitIndex = uniqueIndex:split("-")
	tes3mp.SetObjectRefNum(splitIndex[1])
	tes3mp.SetObjectMpNum(splitIndex[2])
	tes3mp.AddObject()
	tes3mp.SendObjectDelete(forEveryone)
end

local function ResendPlace(pid, uniqueIndex, cellDescription, forEveryone)
	DeleteObject(pid, cellDescription, uniqueIndex, forEveryone)

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

local function showPromptGUI(pid)
	local message = "[" .. playerCurrentMode[GetName(pid)] .. trad.prompt
	tes3mp.InputDialog(pid, cfg.PromptId, message, "")
end

local function onEnterPrompt(pid, data)
	local cell = tes3mp.GetCell(pid)
	local pname = GetName(pid)
	local mode = playerCurrentMode[pname]
	local object = GetObject(playerSelectedObject[pname], cell)
	local cellSize = 8192

	if not object then
		return tes3mp.MessageBox(pid, -1, Text.NoSelect)
	end

	data = tonumber(data) or 0
	object.scale = object.scale or 1

	local scaling = object.scale

	if mode == Text.RotX then
		local curDegrees = math.deg(object.location.rotX)
		local newDegrees = (curDegrees + data) % 360
		object.location.rotX = math.rad(newDegrees)
	elseif mode == Text.RotY then
		local curDegrees = math.deg(object.location.rotY)
		local newDegrees = (curDegrees + data) % 360
		object.location.rotY = math.rad(newDegrees)
	elseif mode == Text.RotZ then
		local curDegrees = math.deg(object.location.rotZ)
		local newDegrees = (curDegrees + data) % 360
		object.location.rotZ = math.rad(newDegrees)
	elseif mode == Text.MovN then
		object.location.posY = object.location.posY + data
	elseif mode == Text.MovE then
		object.location.posX = object.location.posX + data
	elseif mode == Text.MovUp then
		object.location.posZ = object.location.posZ + data
	elseif mode == Text.Up then
		object.location.posZ = object.location.posZ + 10
	elseif mode == Text.Down then
		object.location.posZ = object.location.posZ - 10
	elseif mode == Text.East then
		object.location.posX = object.location.posX + 10
	elseif mode == Text.West then
		object.location.posX = object.location.posX - 10
	elseif mode == Text.North then
		object.location.posY = object.location.posY + 10
	elseif mode == Text.South then
		object.location.posY = object.location.posY - 10
	elseif mode == Text.Bigger then
		if object.scale < 2 then
			object.scale = object.scale + 0.1
		else
			tes3mp.MessageBox(pid, -1, Text.NoOption)
		end
	elseif mode == Text.Smaller then
		if scaling ~= nil then
			if scaling > 0.1 then
				object.scale = object.scale - 0.1
			else
				object.scale = object.scale
			end
		else
			tes3mp.MessageBox(pid, -1, Text.NoOption)
		end
	elseif mode == Text.Close then
		object.location.posY = object.location.posY
		return
	end

	if tes3mp.IsInExterior(pid) then
		local correctGridX = math.floor(object.location.posX / cellSize)
		local correctGridY = math.floor(object.location.posY / cellSize)
		if LoadedCells[cell].gridX ~= correctGridX or LoadedCells[cell].gridY ~= correctGridY then
			return tes3mp.MessageBox(pid, -1, Text.WarningCell)
		end
	end

	ResendPlace(pid, playerSelectedObject[pname], cell, true)
end

local DecorateScript = {}

function DecorateScript.SetSelectedObject(pid, refIndex)
	setSelectedObject(pid, refIndex)
end

function DecorateScript.OnObjectPlace(eventStatus, pid, cellDescription)
	tes3mp.ReadReceivedObjectList()
	setSelectedObject(pid, ('%s-%s'):format(tes3mp.GetObjectRefNum(0), tes3mp.GetObjectMpNum(0)))
end

function DecorateScript.OnGUIAction(eventStatus, pid, idGui, data)
	if idGui == cfg.MainId then
		local pname = GetName(pid)
		if tonumber(data) == 0 then --Move North
			playerCurrentMode[pname] = trad.movn
			showPromptGUI(pid)
		elseif tonumber(data) == 1 then --Move East
			playerCurrentMode[pname] = trad.move
			showPromptGUI(pid)
		elseif tonumber(data) == 2 then --Move Up
			playerCurrentMode[pname] = trad.movup
			showPromptGUI(pid)
		elseif tonumber(data) == 3 then --Rotate X
			playerCurrentMode[pname] = trad.rotx
			showPromptGUI(pid)
		elseif tonumber(data) == 4 then --Rotate Y
			playerCurrentMode[pname] = trad.roty
			showPromptGUI(pid)
		elseif tonumber(data) == 5 then --Rotate Z
			playerCurrentMode[pname] = trad.rotz
			showPromptGUI(pid)
		elseif tonumber(data) == 6 then --Monter
			playerCurrentMode[pname] = trad.up
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 7 then --Descendre
			playerCurrentMode[pname] = trad.down
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 8 then --Est
			playerCurrentMode[pname] = trad.east
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 9 then --Ouest
			playerCurrentMode[pname] = trad.west
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 10 then --Nord
			playerCurrentMode[pname] = trad.north
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 11 then --Sud
			playerCurrentMode[pname] = trad.sud
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 12 then --Agrandir
			playerCurrentMode[pname] = trad.bigger
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 13 then --Reduire
			playerCurrentMode[pname] = trad.Lower
			onEnterPrompt(pid, 0)
			DecorateScript.showMainGUI(pid)
		elseif tonumber(data) == 14 then --Attraper
			playersTab[pname] = true
			logicHandler.RunConsoleCommandOnPlayer(pid, "tb", false)
			tes3mp.MessageBox(pid, -1, trad.info)
			local TimerDrop = tes3mp.CreateTimerEx("StartDrop", time.seconds(0.01), "i", pid)
			tes3mp.StartTimer(TimerDrop)
		elseif tonumber(data) == 15 then --Close
		end
	elseif idGui == cfg.PromptId then
		local pname = GetName(pid)
		if data ~= nil and data ~= "" and tonumber(data) then
			onEnterPrompt(pid, data)
		end
		playerCurrentMode[pname] = nil
		DecorateScript.showMainGUI(pid)
	end
end

function DecorateScript.moveObject(pid)
	local cellSize = 8192
	local cell = tes3mp.GetCell(pid)
	local pname = GetName(pid)
	local object = GetObject(playerSelectedObject[pname], cell)
	local drawState = tes3mp.GetDrawState(pid)
	if not object then
		return tes3mp.MessageBox(pid, -1, Text.NoSelect)
	end

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
		local correctGridX = math.floor(PosX / cellSize)
		local correctGridY = math.floor(PosY / cellSize)
		if LoadedCells[cell].gridX ~= correctGridX or LoadedCells[cell].gridY ~= correctGridY then
			PosX = object.location.posX
			PosY = object.location.posY
			PosZ = object.location.posZ
			tes3mp.MessageBox(pid, -1, trad.warningcell)
		end
	end

	if drawState == 1 then
		local curDegrees = math.deg(object.location.rotZ)
		local newDegrees = (curDegrees + 1) % 360
		object.location.rotZ = math.rad(newDegrees)
	elseif drawState == 2 then
		local curDegrees = math.deg(object.location.rotX)
		local newDegrees = (curDegrees + 1) % 360
		object.location.rotX = math.rad(newDegrees)
	end

	object.location.posX = PosX
	object.location.posY = PosY
	object.location.posZ = PosZ

	ResendPlace(pid, playerSelectedObject[pname], cell, false)

	if tes3mp.GetSneakState(pid) then
		tes3mp.MessageBox(pid, -1, trad.placeobjet)
		ResendPlace(pid, playerSelectedObject[pname], cell, true)
		playersTab[GetName(pid)] = nil
		logicHandler.RunConsoleCommandOnPlayer(pid, "tb", false)
	else
		local TimerDrop = tes3mp.CreateTimerEx("StartDrop", time.seconds(0.01), "i", pid)
		tes3mp.StartTimer(TimerDrop)
	end
end

function DecorateScript.OnObjectActivate(eventStatus, pid, cellDescription, objects)
	if playersTab[GetName(pid)] and GetObject(playerSelectedObject[GetName(pid)], cellDescription) then
		return customEventHooks.makeEventStatus(false, false)
	end
end

function DecorateScript.OnPlayerCellChange(eventStatus, pid, playerPacket, previousCellDescription)
	playerSelectedObject[GetName(pid)] = nil
	if playersTab[GetName(pid)] then
		logicHandler.RunConsoleCommandOnPlayer(pid, "tb", false)
		playersTab[GetName(pid)] = nil
	end
end

function DecorateScript.OnPlayerAuthentified(eventStatus, pid)
	if playersTab[GetName(pid)] then
		playersTab[GetName(pid)] = nil
	end
end

function DecorateScript.showMainGUI(pid)
	if not playersTab[GetName(pid)] then
		local currentItem = "Aucun"
		local selected = playerSelectedObject[GetName(pid)]
		local object = GetObject(selected, tes3mp.GetCell(pid))
		if selected and object then
			currentItem = object.refId .. " (" .. selected .. ")"
		end
		local message = trad.opt1 .. currentItem
		tes3mp.CustomMessageBox(pid, cfg.MainId, message, trad.opt2)
	end
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
