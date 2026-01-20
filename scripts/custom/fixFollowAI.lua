local enumerations = require 'tes3mp.enumerations'
local logicHandler = require 'tes3mp.logicHandler'

---@param pid PlayerId
---@param cellDescription CellDescription
---@param uniqueIndex string
---@param state boolean
local function localSendObjectState(pid, cellDescription, uniqueIndex, state)
    local splitIndex = uniqueIndex:split("-")
    local refNum, mpNum = math.floor(assert(tonumber(splitIndex[1]))), math.floor(assert(tonumber(splitIndex[2])))

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(cellDescription)
    tes3mp.SetObjectRefNum(refNum)
    tes3mp.SetObjectMpNum(mpNum)
    tes3mp.SetObjectState(state)
    tes3mp.AddObject()
    tes3mp.SendObjectState(false)
end

---@param _ EventStatusTable
---@param pid PlayerId
---@param playerPacket table
local function toggleFollowerActorStates(_, pid, playerPacket, _)
    local cellDescription = playerPacket.location.cell

    local playerName = tes3mp.GetName(pid):lower()

    local cellData = LoadedCells[cellDescription].data
    local objectData = cellData.objectData
    for _, uniqueIndex in ipairs(cellData.packets.ai) do
        local AI = objectData[uniqueIndex]

        if AI.action and AI.action == enumerations.ai.FOLLOW and AI.targetPlayer:lower() == playerName then
            localSendObjectState(pid, cellDescription, uniqueIndex, false)
            localSendObjectState(pid, cellDescription, uniqueIndex, true)
        end
    end
end

local function reapplyFollowAI(playerId, actorIndex, cellDescription)
    local uniqueIndex = tes3mp.GetActorRefNum(actorIndex) .. "-" .. tes3mp.GetActorMpNum(actorIndex)
    local newCellDescription = tes3mp.GetActorCell(actorIndex)

    if not uniqueIndex or uniqueIndex == "0-0" or cellDescription == newCellDescription then return end

    local loadTemporarily = false

    if not LoadedCells[newCellDescription] then
        logicHandler.LoadCell(newCellDescription)
        loadTemporarily = true
    end

    local newCell = LoadedCells[newCellDescription]

    if not newCell.isExterior then
        newCell:SetAuthority(playerId)
        logicHandler.SetAIForActor(newCell, uniqueIndex, enumerations.ai.FOLLOW, playerId)
    end

    if loadTemporarily == true then
        logicHandler.UnloadCell(newCellDescription)
    end
end

---@param _ EventStatusTable
---@param pid PlayerId
---@param cellDescription CellDescription
local function reapplyFollowAIToAllActors(_, pid, cellDescription)
    tes3mp.ReadReceivedActorList()
    for actorIndex = 0, tes3mp.GetActorListSize() - 1 do
        reapplyFollowAI(pid, actorIndex, cellDescription)
    end
end

---@type TES3MPScriptRegistration
return {
    eventHandlers = {
        OnActorCellChange = reapplyFollowAIToAllActors,
        OnPlayerCellChange = toggleFollowerActorStates,
    }
}
