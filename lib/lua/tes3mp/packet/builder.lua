local enumerations = require 'tes3mp.enumerations'
-- local logicHandler = require 'tes3mp.logicHandler'
local dUtil = require 'dUtil.init'

---@class PacketBuilder
local packetBuilder = {}

---@param pid PlayerId
---@param item Item
function packetBuilder.AddPlayerInventoryItemChange(pid, item)
    -- Use default values when necessary
    if not item.charge or item.charge < -1 then item.charge = -1 end
    if not item.enchantmentCharge or item.enchantmentCharge < -1 then item.enchantmentCharge = -1 end
    if not item.soul then item.soul = "" end

    tes3mp.AddItemChange(pid, item.refId, item.count, item.charge, item.enchantmentCharge, item.soul)
end

function packetBuilder.AddPlayerSpellsActive(pid, spellsActive, action)
    tes3mp.ClearSpellsActiveChanges(pid)
    tes3mp.SetSpellsActiveChangesAction(pid, action)

    for spellId, spellInstances in pairs(spellsActive) do
        for spellInstanceIndex, spellInstanceValues in pairs(spellInstances) do
            if action == enumerations.spellbook.SET or action == enumerations.spellbook.ADD then
                for effectIndex, effectTable in pairs(spellInstanceValues.effects) do
                    if effectTable.timeLeft > 0 then
                        tes3mp.AddSpellActiveEffect(pid, effectTable.id, effectTable.magnitude,
                            effectTable.duration, effectTable.timeLeft, effectTable.arg)
                    end
                end
            end

            tes3mp.AddSpellActive(pid, spellId, spellInstanceValues.displayName,
                spellInstanceValues.stackingState)
        end
    end
end

function packetBuilder.AddObjectDelete(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.AddObject()
end

function packetBuilder.AddObjectPlace(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    tes3mp.SetObjectRefId(objectData.refId)

    local count = objectData.count
    local charge = objectData.charge
    local enchantmentCharge = objectData.enchantmentCharge
    local soul = objectData.soul
    local goldValue = objectData.goldValue
    local droppedByPlayer = objectData.droppedByPlayer

    -- Use default values when necessary
    if count == nil then count = 1 end
    if charge == nil then charge = -1 end
    if enchantmentCharge == nil then enchantmentCharge = -1 end
    if soul == nil then soul = "" end
    if goldValue == nil then goldValue = 1 end
    if droppedByPlayer == nil then droppedByPlayer = false end

    tes3mp.SetObjectCount(count)
    tes3mp.SetObjectCharge(charge)
    tes3mp.SetObjectEnchantmentCharge(enchantmentCharge)
    tes3mp.SetObjectSoul(soul)
    tes3mp.SetObjectGoldValue(goldValue)
    tes3mp.SetObjectDroppedByPlayerState(droppedByPlayer)

    local location = objectData.location
    tes3mp.SetObjectPosition(location.posX, location.posY, location.posZ)
    tes3mp.SetObjectRotation(location.rotX, location.rotY, location.rotZ)

    tes3mp.AddObject()
end

function packetBuilder.AddObjectSpawn(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    tes3mp.SetObjectRefId(objectData.refId)

    if objectData.summon ~= nil then
        tes3mp.SetObjectSummonState(true)
        tes3mp.SetObjectSummonEffectId(objectData.summon.effectId)
        tes3mp.SetObjectSummonSpellId(objectData.summon.spellId)

        local currentTime = os.time()
        local finishTime = objectData.summon.startTime + objectData.summon.duration
        tes3mp.SetObjectSummonDuration(finishTime - currentTime)

        if objectData.summon.summoner.playerName then
            local player = logicHandler.GetPlayerByName(objectData.summon.summoner.playerName)
            tes3mp.SetObjectSummonerPid(player.pid)
        else
            local summonerSplitIndex = objectData.summon.summoner.uniqueIndex:split("-")
            tes3mp.SetObjectSummonerRefNum(summonerSplitIndex[1])
            tes3mp.SetObjectSummonerMpNum(summonerSplitIndex[2])
        end
    end

    local location = objectData.location
    tes3mp.SetObjectPosition(location.posX, location.posY, location.posZ)
    tes3mp.SetObjectRotation(location.rotX, location.rotY, location.rotZ)

    tes3mp.AddObject()
end

function packetBuilder.AddObjectLock(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectLockLevel(objectData.lockLevel)
    tes3mp.AddObject()
end

function packetBuilder.AddObjectMiscellaneous(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectGoldPool(objectData.goldPool)
    tes3mp.SetObjectLastGoldRestockHour(objectData.lastGoldRestockHour)
    tes3mp.SetObjectLastGoldRestockDay(objectData.lastGoldRestockDay)
    tes3mp.AddObject()
end

function packetBuilder.AddObjectTrap(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectDisarmState(true)
    tes3mp.AddObject()
end

function packetBuilder.AddObjectScale(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectScale(objectData.scale)
    tes3mp.AddObject()
end

function packetBuilder.AddObjectState(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectState(objectData.state)
    tes3mp.AddObject()
end

function packetBuilder.AddDoorState(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end
    tes3mp.SetObjectDoorState(objectData.doorState)
    tes3mp.AddObject()
end

function packetBuilder.AddClientScriptLocal(uniqueIndex, objectData)
    local splitIndex = uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    if objectData.refId ~= nil then tes3mp.SetObjectRefId(objectData.refId) end

    local variableCount = 0

    for variableType, variableTable in pairs(objectData.variables) do
        if type(variableTable) == "table" then
            for internalIndex, value in pairs(variableTable) do
                if variableType == enumerations.variableType.SHORT then
                    tes3mp.AddClientLocalInteger(tonumber(internalIndex), value, enumerations.variableType.SHORT)
                elseif variableType == enumerations.variableType.LONG then
                    tes3mp.AddClientLocalInteger(tonumber(internalIndex), value, enumerations.variableType.LONG)
                elseif variableType == enumerations.variableType.FLOAT then
                    tes3mp.AddClientLocalFloat(tonumber(internalIndex), value)
                end

                variableCount = variableCount + 1
            end
        end
    end

    if variableCount > 0 then
        tes3mp.AddObject()
    end
end

function packetBuilder.AddAIActor(actorUniqueIndex, targetPid, aiData)
    local splitIndex = actorUniqueIndex:split("-")
    tes3mp.SetActorRefNum(splitIndex[1])
    tes3mp.SetActorMpNum(splitIndex[2])

    tes3mp.SetActorAIAction(aiData.action)

    if targetPid ~= nil then
        tes3mp.SetActorAITargetToPlayer(targetPid)
    elseif aiData.targetUniqueIndex ~= nil then
        local targetSplitIndex = aiData.targetUniqueIndex:split("-")

        if targetSplitIndex[2] ~= nil then
            tes3mp.SetActorAITargetToObject(targetSplitIndex[1], targetSplitIndex[2])
        end
    elseif aiData.posX ~= nil and aiData.posY ~= nil and aiData.posZ ~= nil then
        tes3mp.SetActorAICoordinates(aiData.posX, aiData.posY, aiData.posZ)
    elseif aiData.distance ~= nil then
        tes3mp.SetActorAIDistance(aiData.distance)
    elseif aiData.duration ~= nil then
        tes3mp.SetActorAIDuration(aiData.duration)
    end

    tes3mp.SetActorAIRepetition(aiData.shouldRepeat)

    tes3mp.AddActor()
end

function packetBuilder.AddActorSpellsActive(actorUniqueIndex, spellsActive, action)
    local splitIndex = actorUniqueIndex:split("-")
    tes3mp.SetActorRefNum(splitIndex[1])
    tes3mp.SetActorMpNum(splitIndex[2])
    tes3mp.SetActorSpellsActiveAction(action)

    for spellId, spellInstances in pairs(spellsActive) do
        for spellInstanceIndex, spellInstanceValues in pairs(spellInstances) do
            if action == enumerations.spellbook.SET or action == enumerations.spellbook.ADD then
                for effectIndex, effectTable in pairs(spellInstanceValues.effects) do
                    if effectTable.timeLeft > 0 then
                        tes3mp.AddActorSpellActiveEffect(effectTable.id, effectTable.magnitude,
                            effectTable.duration, effectTable.timeLeft, effectTable.arg)
                    end
                end
            end

            tes3mp.AddActorSpellActive(spellId, spellInstanceValues.displayName,
                spellInstanceValues.stackingState)
        end
    end

    tes3mp.AddActor()
end

function packetBuilder.AddEffectToRecord(effect)
    tes3mp.SetRecordEffectId(effect.id)
    if effect.attribute ~= nil then tes3mp.SetRecordEffectAttribute(effect.attribute) end
    if effect.skill ~= nil then tes3mp.SetRecordEffectSkill(effect.skill) end
    if effect.rangeType ~= nil then tes3mp.SetRecordEffectRangeType(effect.rangeType) end
    if effect.area ~= nil then tes3mp.SetRecordEffectArea(effect.area) end
    if effect.duration ~= nil then tes3mp.SetRecordEffectDuration(effect.duration) end
    if effect.magnitudeMin ~= nil then tes3mp.SetRecordEffectMagnitudeMin(effect.magnitudeMin) end
    if effect.magnitudeMax ~= nil then tes3mp.SetRecordEffectMagnitudeMax(effect.magnitudeMax) end

    tes3mp.AddRecordEffect()
end

function packetBuilder.AddBodyPartToRecord(part)
    tes3mp.SetRecordBodyPartType(part.partType)
    if part.malePart ~= nil then tes3mp.SetRecordBodyPartIdForMale(part.malePart) end
    if part.femalePart ~= nil then tes3mp.SetRecordBodyPartIdForFemale(part.femalePart) end

    tes3mp.AddRecordBodyPart()
end

function packetBuilder.AddInventoryItemToRecord(item)
    tes3mp.SetRecordInventoryItemId(item.id)
    if item.count ~= nil then tes3mp.SetRecordInventoryItemCount(item.count) end

    tes3mp.AddRecordInventoryItem()
end

function packetBuilder.AddRecordByType(id, record, storeType)
    local stype = {
        ["activator"] = packetBuilder.AddActivatorRecord,
        ["apparatus"] = packetBuilder.AddApparatusRecord,
        ["armor"] = packetBuilder.AddArmorRecord,
        ["bodypart"] = packetBuilder.AddBodyPartRecord,
        ["book"] = packetBuilder.AddBookRecord,
        ["cell"] = packetBuilder.AddCellRecord,
        ["clothing"] = packetBuilder.AddClothingRecord,
        ["container"] = packetBuilder.AddContainerRecord,
        ["creature"] = packetBuilder.AddCreatureRecord,
        ["door"] = packetBuilder.AddDoorRecord,
        ["enchantment"] = packetBuilder.AddEnchantmentRecord,
        ["gamesetting"] = packetBuilder.AddGameSettingRecord,
        ["ingredient"] = packetBuilder.AddIngredientRecord,
        ["light"] = packetBuilder.AddLightRecord,
        ["lockpick"] = packetBuilder.AddLockpickRecord,
        ["miscellaneous"] = packetBuilder.AddMiscellaneousRecord,
        ["npc"] = packetBuilder.AddNpcRecord,
        ["potion"] = packetBuilder.AddPotionRecord,
        ["probe"] = packetBuilder.AddProbeRecord,
        ["repair"] = packetBuilder.AddRepairRecord,
        ["script"] = packetBuilder.AddScriptRecord,
        ["sound"] = packetBuilder.AddSoundRecord,
        ["spell"] = packetBuilder.AddSpellRecord,
        ["static"] = packetBuilder.AddStaticRecord,
        ["weapon"] = packetBuilder.AddWeaponRecord,
    }

    if stype[storeType] then
        stype[storeType](id, record)
    end
end

function packetBuilder.AddActivatorRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddApparatusRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.quality then tes3mp.SetRecordQuality(record.quality) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddArmorRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.health then tes3mp.SetRecordHealth(record.health) end
    if record.armorRating then tes3mp.SetRecordArmorRating(record.armorRating) end
    if record.enchantmentId then tes3mp.SetRecordEnchantmentId(record.enchantmentId) end
    if record.enchantmentCharge then tes3mp.SetRecordEnchantmentCharge(record.enchantmentCharge) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.parts) == "table" then
        for _, part in pairs(record.parts) do
            packetBuilder.AddBodyPartToRecord(part)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddBodyPartRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.part then tes3mp.SetRecordBodyPartType(record.part) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.race then tes3mp.SetRecordRace(record.race) end
    if record.vampireState then tes3mp.SetRecordVampireState(record.vampireState) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end

    tes3mp.AddRecord()
end

function packetBuilder.AddBookRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.text then tes3mp.SetRecordText(record.text) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.scrollState then tes3mp.SetRecordScrollState(record.scrollState) end
    if record.skillId then tes3mp.SetRecordSkillId(record.skillId) end
    if record.enchantmentId then tes3mp.SetRecordEnchantmentId(record.enchantmentId) end
    if record.enchantmentCharge then tes3mp.SetRecordEnchantmentCharge(record.enchantmentCharge) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddCellRecord(id, record)
    tes3mp.SetRecordName(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end

    tes3mp.AddRecord()
end

function packetBuilder.AddClothingRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.enchantmentId then tes3mp.SetRecordEnchantmentId(record.enchantmentId) end
    if record.enchantmentCharge then tes3mp.SetRecordEnchantmentCharge(record.enchantmentCharge) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.parts) == "table" then
        for _, part in pairs(record.parts) do
            packetBuilder.AddBodyPartToRecord(part)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddContainerRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.items) == "table" then
        for _, item in pairs(record.items) do
            packetBuilder.AddInventoryItemToRecord(item)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddCreatureRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.scale then tes3mp.SetRecordScale(record.scale) end
    if record.bloodType then tes3mp.SetRecordBloodType(record.bloodType) end
    if record.level then tes3mp.SetRecordLevel(record.level) end
    if record.health then tes3mp.SetRecordHealth(record.health) end
    if record.magicka then tes3mp.SetRecordMagicka(record.magicka) end
    if record.fatigue then tes3mp.SetRecordFatigue(record.fatigue) end
    if record.soulValue then tes3mp.SetRecordSoulValue(record.soulValue) end
    if record.damageChop then tes3mp.SetRecordDamageChop(record.damageChop.min, record.damageChop.max) end
    if record.damageSlash then tes3mp.SetRecordDamageSlash(record.damageSlash.min, record.damageSlash.max) end
    if record.damageThrust then tes3mp.SetRecordDamageThrust(record.damageThrust.min, record.damageThrust.max) end
    if record.aiFight then tes3mp.SetRecordAIFight(record.aiFight) end
    if record.aiServices then tes3mp.SetRecordAIServices(record.aiServices) end
    if record.aiFlee then tes3mp.SetRecordAIFlee(record.aiFlee) end
    if record.aiAlarm then tes3mp.SetRecordAIAlarm(record.aiAlarm) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.items) == "table" then
        for _, item in pairs(record.items) do
            packetBuilder.AddInventoryItemToRecord(item)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddDoorRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.openSound then tes3mp.SetRecordOpenSound(record.openSound) end
    if record.closeSound then tes3mp.SetRecordCloseSound(record.closeSound) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddEnchantmentRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.cost then tes3mp.SetRecordCost(record.cost) end
    if record.charge then tes3mp.SetRecordCharge(record.charge) end

    if record.flags then
        tes3mp.SetRecordFlags(record.flags)
        -- Keep this for compatibility with older data which used autoCalc
    elseif record.autoCalc ~= nil then
        tes3mp.SetRecordFlags(record.autoCalc)
    end

    if type(record.effects) == "table" then
        for _, effect in pairs(record.effects) do
            packetBuilder.AddEffectToRecord(effect)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddGameSettingRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end

    if record.intVar then
        tes3mp.SetRecordIntegerVariable(record.intVar)
    elseif record.floatVar then
        tes3mp.SetRecordFloatVariable(record.floatVar)
    elseif record.stringVar then
        tes3mp.SetRecordStringVariable(tostring(record.stringVar))
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddIngredientRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.effects) == "table" then
        for effectIndex = 1, 4 do
            local effect = record.effects[effectIndex]

            if effect == nil then
                effect = { id = -1 }
            end

            packetBuilder.AddEffectToRecord(effect)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddLightRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.sound then tes3mp.SetRecordSound(record.sound) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.time then tes3mp.SetRecordTime(record.time) end
    if record.radius then tes3mp.SetRecordRadius(record.radius) end
    if record.color then tes3mp.SetRecordColor(record.color.red, record.color.green, record.color.blue) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddLockpickRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.quality then tes3mp.SetRecordQuality(record.quality) end
    if record.uses then tes3mp.SetRecordUses(record.uses) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddMiscellaneousRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.keyState then tes3mp.SetRecordKeyState(record.keyState) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddNpcRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.inventoryBaseId then tes3mp.SetRecordInventoryBaseId(record.inventoryBaseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.gender then tes3mp.SetRecordGender(record.gender) end
    if record.race then tes3mp.SetRecordRace(record.race) end
    if record.hair then tes3mp.SetRecordHair(record.hair) end
    if record.head then tes3mp.SetRecordHead(record.head) end
    if record.class then tes3mp.SetRecordClass(record.class) end
    if record.level then tes3mp.SetRecordLevel(record.level) end
    if record.health then tes3mp.SetRecordHealth(record.health) end
    if record.magicka then tes3mp.SetRecordMagicka(record.magicka) end
    if record.fatigue then tes3mp.SetRecordFatigue(record.fatigue) end
    if record.aiFight then tes3mp.SetRecordAIFight(record.aiFight) end
    if record.aiFlee then tes3mp.SetRecordAIFlee(record.aiFlee) end
    if record.aiAlarm then tes3mp.SetRecordAIAlarm(record.aiAlarm) end
    if record.aiServices then tes3mp.SetRecordAIServices(record.aiServices) end
    if record.autoCalc then tes3mp.SetRecordAutoCalc(record.autoCalc) end
    if record.faction then tes3mp.SetRecordFaction(record.faction) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.items) == "table" then
        for _, item in pairs(record.items) do
            packetBuilder.AddInventoryItemToRecord(item)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddPotionRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.autoCalc then tes3mp.SetRecordAutoCalc(record.autoCalc) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    if type(record.effects) == "table" then
        for _, effect in pairs(record.effects) do
            packetBuilder.AddEffectToRecord(effect)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddProbeRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.quality then tes3mp.SetRecordQuality(record.quality) end
    if record.uses then tes3mp.SetRecordUses(record.uses) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddRepairRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.quality then tes3mp.SetRecordQuality(record.quality) end
    if record.uses then tes3mp.SetRecordUses(record.uses) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

function packetBuilder.AddScriptRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.scriptText then tes3mp.SetRecordScriptText(record.scriptText) end

    tes3mp.AddRecord()
end

function packetBuilder.AddSoundRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.sound then tes3mp.SetRecordSound(record.sound) end
    if record.volume then tes3mp.SetRecordVolume(record.volume) end
    if record.minRange then tes3mp.SetRecordMinRange(record.minRange) end
    if record.maxRange then tes3mp.SetRecordMaxRange(record.maxRange) end

    tes3mp.AddRecord()
end

function packetBuilder.AddSpellRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.cost then tes3mp.SetRecordCost(record.cost) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end

    if type(record.effects) == "table" then
        for _, effect in pairs(record.effects) do
            packetBuilder.AddEffectToRecord(effect)
        end
    end

    tes3mp.AddRecord()
end

function packetBuilder.AddStaticRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.model then tes3mp.SetRecordModel(record.model) end

    tes3mp.AddRecord()
end

function packetBuilder.AddWeaponRecord(id, record)
    tes3mp.SetRecordId(id)
    if record.baseId then tes3mp.SetRecordBaseId(record.baseId) end
    if record.name then tes3mp.SetRecordName(record.name) end
    if record.model then tes3mp.SetRecordModel(record.model) end
    if record.icon then tes3mp.SetRecordIcon(record.icon) end
    if record.subtype then tes3mp.SetRecordSubtype(record.subtype) end
    if record.weight then tes3mp.SetRecordWeight(record.weight) end
    if record.value then tes3mp.SetRecordValue(record.value) end
    if record.health then tes3mp.SetRecordHealth(record.health) end
    if record.speed then tes3mp.SetRecordSpeed(record.speed) end
    if record.reach then tes3mp.SetRecordReach(record.reach) end
    if record.damageChop then tes3mp.SetRecordDamageChop(record.damageChop.min, record.damageChop.max) end
    if record.damageSlash then tes3mp.SetRecordDamageSlash(record.damageSlash.min, record.damageSlash.max) end
    if record.damageThrust then tes3mp.SetRecordDamageThrust(record.damageThrust.min, record.damageThrust.max) end
    if record.flags then tes3mp.SetRecordFlags(record.flags) end
    if record.enchantmentId then tes3mp.SetRecordEnchantmentId(record.enchantmentId) end
    if record.enchantmentCharge then tes3mp.SetRecordEnchantmentCharge(record.enchantmentCharge) end
    if record.script then tes3mp.SetRecordScript(record.script) end

    tes3mp.AddRecord()
end

return packetBuilder
