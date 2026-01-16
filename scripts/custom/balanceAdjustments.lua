local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'
local logicHandler = require 'tes3mp.logicHandler'

---@type DefaultInterfaces
local I = require 'interfaces'

---@param eventStatus EventStatusTable
---@param pid integer
---@param _ string
---@param objects table
---@return EventStatusTable
local function disableTradersTrainers(eventStatus, pid, _, objects)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return eventStatus end

    local ObjectIndex, ObjectRefid, ObjectDialogue

    for _, object in pairs(objects) do
        ObjectIndex = object.uniqueIndex
        ObjectRefid = object.refId
        ObjectDialogue = object.dialogueChoiceType
    end

    if not (ObjectIndex and ObjectRefid) then return eventStatus end
    if ObjectDialogue == enumerations.dialogueChoice.TRAINING or ObjectDialogue == enumerations.dialogueChoice.BARTER then
        eventStatus.validDefaultHandler = false
        eventStatus.validCustomHandlers = false
    end

    return eventStatus
end

---@param eventStatus EventStatusTable
---@param playerPacket table
---@return boolean didChange
local function checkForSpellStackingChanges(eventStatus, playerPacket)
    local didChange = false

    if not eventStatus.validCustomHandlers then return false end

    for spellId, spellInstances in pairs(playerPacket.spellsActive) do
        for key, spellInstance in ipairs(spellInstances) do
            if spellInstance.stackingState then
                playerPacket.spellsActive[spellId][key].stackingState = false
                didChange = true
            end
        end
    end

    return didChange
end

---@param eventStatus EventStatusTable
---@param pid integer
---@param playerPacket table
---@return EventStatusTable
local function disableDuplicateMagicEffects(eventStatus, pid, playerPacket)
    local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
    if not isValid or not targetPid then return eventStatus end

    local didChange = checkForSpellStackingChanges(eventStatus, playerPacket)
    if not didChange then return eventStatus end

    local player = Players[pid]
    player:SaveSpellsActive(playerPacket)
    player:LoadSpellsActive()

    return dUtil.misc.makeEventStatus(false, false)
end

---@type CommandHandler
local function playerCoordsCommand(pid, _)
    local posX, posY, posZ = tes3mp.GetPosX(pid), tes3mp.GetPosY(pid), tes3mp.GetPosZ(pid)
    local player, positionVector = Players[pid], dUtil.vector3(posX, posY, posZ)

    player:Message(
        ('%s%s: %s%s%s\n')
        :format(
            I.Color.Aquamarine,
            player.data.location.cell,
            I.Color.Gold,
            tostring(positionVector),
            I.Color.White
        )
    )
end

---@type TES3MPScriptRegistration
return {
    chatCommands = {
        coords = { callback = playerCoordsCommand, },
    },
    eventValidators = {
        OnObjectDialogueChoice = disableTradersTrainers,
        OnPlayerSpellsActive = disableDuplicateMagicEffects,
    },
}
