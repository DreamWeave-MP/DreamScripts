local enumerations = require 'packages.networkEnums'
local logicHandler = require 'packages.logicHandler'
local tableHelper = require 'packages.tableHelper'

local QuickKeyUsed = 9
local BagName = 'Survival Pack'

---@class TES3MPNetworkObject
---@field uniqueIndex UniqueIndex
---@field refId RecordId

---@class TES3MPWorldObject
---@field scale number
---@field location TES3MPWorldTransform

---@class TES3MPWorldTransform
---@field posX number
---@field posY number
---@field posZ number
---@field rotX number
---@field rotY number
---@field rotZ number

---@param pid PlayerId
---@param cellDescription CellDescription
---@param uniqueIndex UniqueIndex
---@param object TES3MPWorldObject
local function sendPacketBag(pid, cellDescription, uniqueIndex, object)
	-- Clear Objects Stored on the server
	tes3mp.ClearObjectList()

	-- The object list now belongs to the player at pid
	tes3mp.SetObjectListPid(pid)

	-- The temporary object list is now attached to this cell
	tes3mp.SetObjectListCell(cellDescription)

	-- Get the index ready for later functions
	local refNum, mpNum = uniqueIndex:splitUniqueIndex()

	-- This should more or less always be zero, because it's spawned by the server.
	-- But, if it's loaded from an esm/p, then it will have a unique and important value
	tes3mp.SetObjectRefNum(refNum)

	-- The `unique` portion of the `uniqueindex` in the server context
	tes3mp.SetObjectMpNum(mpNum)

	-- Sets the temp object's refId and other needed attributes
	tes3mp.SetObjectRefId('bag_container')
	tes3mp.SetObjectPosition(object.location.posX, object.location.posY, object.location.posZ)
	tes3mp.SetObjectRotation(object.location.rotX, object.location.rotY, object.location.rotZ)
	tes3mp.SetObjectScale(object.scale)

	-- Add the temp object to permanent objects and clear the temp one
	tes3mp.AddObject()

	-- Place and scale the object, only for the relevant player
	tes3mp.SendObjectPlace(false)
	tes3mp.SendObjectScale(false)
end

---@param pid PlayerId
local function closeMenu(pid)
	for _ = 1, 2 do
		-- Clear Objects Stored on the server
		tes3mp.ClearObjectList()

		-- The object list now belongs to the player at pid
		tes3mp.SetObjectListPid(pid)

		-- The temporary object list is now attached to this cell
		tes3mp.SetObjectListCell(Players[pid].data.location.cell)

		-- Disables menus for all objects in the object list
		tes3mp.SetObjectListConsoleCommand('TM')

		-- Sets the player as an object
		tes3mp.SetPlayerAsObject(pid)

		-- Add the temp object to permanent objects and clear the temp one
		tes3mp.AddObject()

		-- Queues the command and sends the packet
		table.insert(Players[pid].consoleCommandsQueued, 'TM')
		tes3mp.SendConsoleCommand(false)
	end
end

---@param pid PlayerId
local function addBag(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end
	local player = Players[targetPid]

	tes3mp.ClearObjectList()

	tes3mp.SetObjectListPid(pid)

	tes3mp.SetObjectListCell(player.data.location.cell)

	tes3mp.SetObjectListConsoleCommand('player->additem bag_book 1')

	tes3mp.SetPlayerAsObject(pid)

	tes3mp.AddObject()

	table.insert(player.consoleCommandsQueued, 'player->additem bag_book 1')

	tes3mp.SendConsoleCommand(false)
end

---@param pid PlayerId
---@param objectCellDescription CellDescription
---@param objectUniqueIndex UniqueIndex
local function activateBag(pid, objectCellDescription, objectUniqueIndex)
	tes3mp.ClearObjectList()

	tes3mp.SetObjectListPid(pid)

	tes3mp.SetObjectListCell(objectCellDescription)

	local refNum, mpNum = objectUniqueIndex:splitUniqueIndex()

	tes3mp.SetObjectRefNum(refNum)

	tes3mp.SetObjectMpNum(mpNum)

	tes3mp.SetObjectActivatingPid(pid)

	tes3mp.AddObject()

	tes3mp.SendObjectActivate()
end

---@param pid PlayerId
local function updateBag(pid)
	local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
	if not isValid or not targetPid then return end

	local player = Players[targetPid]; local bagVars = player.data.customVariables.Bag

	local targetEquipment, targetCellDescription, targetUniqueIndex =
			bagVars.inventory, bagVars.cellDescription, bagVars.uniqueIndex

	tes3mp.ClearObjectList()

	tes3mp.SetObjectListPid(pid)

	tes3mp.SetObjectListCell(targetCellDescription)

	local refNum, mpNum = targetUniqueIndex:splitUniqueIndex()

	tes3mp.SetObjectRefNum(refNum)

	tes3mp.SetObjectMpNum(mpNum)

	tes3mp.SetObjectRefId('bag_container')

	--- Is this an array?
	for _, item in pairs(targetEquipment) do
		--- Are either of these checks necessary??
		if item.refId and item.refId ~= '' then
			tes3mp.SetContainerItemRefId(item.refId)

			tes3mp.SetContainerItemCount(item.count or 1)

			tes3mp.SetContainerItemCharge(item.charge or -1)

			tes3mp.SetContainerItemEnchantmentCharge(item.enchantmentCharge or -1)

			tes3mp.SetContainerItemSoul(item.soul or '')

			tes3mp.AddContainerItem()
		end
	end

	tes3mp.AddObject()

	tes3mp.SetObjectListAction(enumerations.container.SET)

	tes3mp.SendContainer(false, false)
end

---@param cellDescription CellDescription
---@param location TES3MPWorldTransform
---@param refId RecordId
local function createBag(cellDescription, location, refId)
	local mpNum = WorldInstance:GetCurrentMpNum() + 1

	local uniqueIndex = ('0-%s'):format(mpNum)
	local cell = LoadedCells[cellDescription]; local cellObjects, cellPackets = cell.data.objectData, cell.data.packets

	cell:InitializeObjectData(uniqueIndex, refId)

	local targetObject = cellObjects[uniqueIndex]

	if targetObject then
		targetObject.location = location

		targetObject.scale = 0.0001

		targetObject.inventory = {}

		table.insert(cellPackets.place, uniqueIndex)

		table.insert(cellPackets.scale, uniqueIndex)

		table.insert(cellPackets.container, uniqueIndex)
	end

	WorldInstance:SetCurrentMpNum(mpNum)

	tes3mp.SetCurrentMpNum(mpNum)

	return uniqueIndex
end

---@param pid PlayerId
local function deleteBag(pid)
	local bagVars = Players[pid].data.customVariables.Bag

	local cellDescription = bagVars.cellDescription
	local uniqueIndex = bagVars.uniqueIndex

	if not cellDescription or not uniqueIndex or cellDescription == '' or uniqueIndex == 0 then return end

	local loadTemporarily = false

	if not LoadedCells[cellDescription] then
		logicHandler.LoadCellForPlayer(pid, cellDescription)

		loadTemporarily = true
	end

	tes3mp.ClearObjectList()

	tes3mp.SetObjectListPid(pid)

	tes3mp.SetObjectListCell(cellDescription)

	local refNum, mpNum = uniqueIndex:splitUniqueIndex()

	tes3mp.SetObjectRefNum(refNum)

	tes3mp.SetObjectMpNum(mpNum)

	tes3mp.AddObject()

	LoadedCells[cellDescription]:DeleteObjectData(uniqueIndex)

	tes3mp.SendObjectDelete(false)

	if loadTemporarily then
		logicHandler.UnloadCellForPlayer(pid, cellDescription)
	end
end

---@type TES3MPScriptRegistration
return {
	eventHandlers = {
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@param objects TES3MPNetworkObject[]
		---@return EventStatusTable
		OnContainer = function(eventStatus, pid, _, objects)
			local ObjectIndex, ObjectRefId = next(objects)
			local bagVars = Players[pid].data.customVariables.Bag

			if bagVars
					and ObjectIndex
					and ObjectRefId
					and ObjectIndex == bagVars.uniqueIndex
					and tes3mp.GetObjectListContainerSubAction() == enumerations.containerSub.TAKE_ALL
			then
				deleteBag(pid)
			end

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@return EventStatusTable
		OnPlayerAuthentified = function(eventStatus, pid)
			if Players[pid].data.customVariables.Bag == nil then
				Players[pid].data.customVariables.Bag = {
					inventory = {},
					cellDescription = '',
					uniqueIndex = 0
				}
			end

			if not tableHelper.containsValue(Players[pid].data.inventory, 'bag_book', true) then
				addBag(pid)
			end

			Players[pid].data.quickKeys[QuickKeyUsed] = {
				keyType = 0,
				itemId = 'bag_book'
			}

			Players[pid]:LoadQuickKeys()

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@return EventStatusTable
		OnPlayerDisconnect = function(eventStatus, pid)
			local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)

			if isValid and targetPid then
				deleteBag(pid)
			end

			return eventStatus
		end,
	},
	eventValidators = {
		---@param eventStatus EventStatusTable
		---@param objects TES3MPNetworkObject[]
		---@return EventStatusTable
		OnContainer = function(eventStatus, _, _, objects)
			local ObjectIndex, ObjectRefId = next(objects)

			if ObjectIndex and ObjectRefId then
				for containerIndex = 0, tes3mp.GetObjectListSize() - 1 do
					for itemIndex = 0, tes3mp.GetContainerChangesSize(containerIndex) - 1 do
						local grabbedItemId = tes3mp.GetContainerItemRefId(containerIndex, itemIndex)

						if grabbedItemId and grabbedItemId == 'bag_book' then
							eventStatus.validCustomHandlers = false
							eventStatus.validDefaultHandler = false
						end
					end
				end
			end

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param objects TES3MPNetworkObject[]
		---@return EventStatusTable
		OnObjectPlace = function(eventStatus, _, _, objects)
			local ObjectIndex, ObjectRefId

			print(('BagScript.OnObjectPlace received table with %s keys.'):format(table.nkeys(objects)))

			--- Can we replace this with next?
			for _, object in pairs(objects) do
				ObjectIndex, ObjectRefId = object.uniqueIndex, object.refId
			end

			if ObjectIndex and ObjectRefId and ObjectRefId == 'bag_book' then
				eventStatus.validCustomHandlers = false
				eventStatus.validDefaultHandler = false
			end

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@return EventStatusTable
		OnPlayerInventory = function(eventStatus, pid, _)
			local action = tes3mp.GetInventoryChangesAction(pid)

			local itemChangesCount = tes3mp.GetInventoryChangesSize(pid)

			if action == enumerations.inventory.REMOVE then
				for index = 0, itemChangesCount - 1 do
					local ObjectRefId = tes3mp.GetInventoryItemRefId(pid, index)

					if ObjectRefId and ObjectRefId == 'bag_book' then
						Players[pid]:LoadItemChanges(
							{
								{
									refId = ObjectRefId,
									count = tes3mp.GetInventoryItemCount(pid, index),
									charge = tes3mp.GetInventoryItemCharge(pid, index),
									enchantmentCharge = tes3mp.GetInventoryItemEnchantmentCharge(pid, index),
									soul = tes3mp.GetInventoryItemSoul(pid, index)
								},
							},
							enumerations.inventory.ADD
						)

						eventStatus.validDefaultHandler = false
						eventStatus.validCustomHandlers = false
					end
				end
			end

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@param pid PlayerId
		---@param refId RecordId
		---@return EventStatusTable
		OnPlayerItemUse = function(eventStatus, pid, refId)
			if refId:lower() == 'bag_book' then
				deleteBag(pid)

				local cellDescription = tes3mp.GetCell(pid)

				local location = {
					posX = tes3mp.GetPosX(pid),
					posY = tes3mp.GetPosY(pid),
					posZ = -99999,
					rotX = 0,
					rotY = 0,
					rotZ = 0
				}

				local objectData = LoadedCells[cellDescription].data.objectData
				local customVars = Players[pid].data.customVariables

				local bagIndex = createBag(cellDescription, location, 'bag_container')

				customVars.Bag.cellDescription = cellDescription

				customVars.Bag.uniqueIndex = bagIndex

				sendPacketBag(pid, cellDescription, bagIndex, objectData[bagIndex])

				if customVars.Bag.inventory then
					objectData[bagIndex].inventory = customVars.Bag.inventory
					updateBag(pid)
				end

				closeMenu(pid)

				activateBag(pid, cellDescription, bagIndex)

				eventStatus.validCustomHandlers = false
				eventStatus.validDefaultHandler = false
			end

			return eventStatus
		end,
		---@param eventStatus EventStatusTable
		---@return EventStatusTable
		OnServerPostInit = function(eventStatus)
			local recordStoreBook = RecordStores.book

			local recordStoreContainer = RecordStores.container

			recordStoreBook.data.permanentRecords.bag_book = {
				name = BagName,
				icon = 'l/Tx_buglamp_01.tga',
				model = 'l/Light_buglamp_01.NIF',
				value = 0,
				weight = 0
			}
			recordStoreBook:Save()

			recordStoreContainer.data.permanentRecords.bag_container = {
				name = BagName,
				model = 'l/Light_buglamp_01.NIF',
				weight = 125
			}
			recordStoreContainer:Save()

			return eventStatus
		end
	}
}
