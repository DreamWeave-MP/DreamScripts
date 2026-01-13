local speechCollections = require 'tes3mp.util.speechCollections'
local miscUtil = require 'tes3mp.util.misc'
local tableHelper = require 'tes3mp.util.table'

---@class SpeechHelper
local speechHelper = {}

---@enum SpeechPrefixes
local speechTypesToFilePrefixes = {
    attack = 'Atk',
    flee = 'Fle',
    follower = 'Flw',
    hello = 'Hlo',
    hit = 'Hit',
    idle = 'Idl',
    intruder = 'int',
    oppose = 'OP',
    service = 'Srv',
    thief = 'Thf',
    uniform = 'uni'
}

function speechHelper.GetSpeechPathFromCollection(speechCollectionTable, speechType, speechIndex, gender)
    if not speechCollectionTable or not speechTypesToFilePrefixes[speechType] then return end

    local genderTableName

    if gender == 0 then
        genderTableName = 'femaleFiles'
    else
        genderTableName = 'maleFiles'
    end

    local speechTypeTable = speechCollectionTable[genderTableName][speechType]

    if not speechTypeTable then
        return
    end

    if speechIndex > speechTypeTable.count then
        return
    elseif speechTypeTable.skip and tableHelper.containsValue(speechTypeTable.skip, speechIndex) then
        return
    end

    local speechPath = 'Vo\\' .. speechCollectionTable.folderPath .. '\\'

    -- Assume there are only going to be subfolders for different genders if there are actually
    -- speech files for both genders
    if speechCollectionTable.maleFiles and speechCollectionTable.femaleFiles then
        if gender == 0 then
            speechPath = speechPath .. 'f\\'
        else
            speechPath = speechPath .. 'm\\'
        end
    end

    local filePrefix

    if speechTypeTable.filePrefixOverride then
        filePrefix = speechTypeTable.filePrefixOverride
    else
        filePrefix = speechTypesToFilePrefixes[speechType]
    end

    local indexPrefix

    if speechTypeTable.indexPrefixOverride then
        indexPrefix = speechTypeTable.indexPrefixOverride
    elseif gender == 0 then
        indexPrefix = speechCollectionTable.femalePrefix
    else
        indexPrefix = speechCollectionTable.malePrefix
    end

    speechPath = speechPath .. filePrefix .. '_' .. indexPrefix .. miscUtil.prefixZeroes(speechIndex, 3) .. '.mp3'

    return speechPath
end

---@param pid PlayerId
---@param speechInput string
---@param speechIndex integer
function speechHelper.GetSpeechPath(pid, speechInput, speechIndex)
    local speechCollectionKey
    local speechType

    -- Is there a specific folder at the start of the speechInput? If so,
    -- get the speechCollectionKey from it
    local underscoreIndex = speechInput:find('_')

    if underscoreIndex ~= nil and underscoreIndex > 1 then
        speechCollectionKey = speechInput:sub(1, underscoreIndex - 1)
        speechType = speechInput:sub(underscoreIndex + 1)
    else
        speechCollectionKey = 'default'
        speechType = speechInput
    end

    local race = Players[pid].data.character.race:lower()
    local speechCollectionTable = speechCollections[race][speechCollectionKey]

    if not speechCollectionTable then return end

    local gender = Players[pid].data.character.gender

    return speechHelper.GetSpeechPathFromCollection(speechCollectionTable, speechType, speechIndex, gender)
end

function speechHelper.GetPrintableValidListForSpeechCollection(speechCollectionTable, gender, collectionPrefix)
    local validList = {}
    local genderTableName

    if gender == 0 then
        genderTableName = 'femaleFiles'
    else
        genderTableName = 'maleFiles'
    end

    if speechCollectionTable[genderTableName] ~= nil then
        for speechType, typeDetails in pairs(speechCollectionTable[genderTableName]) do
            local validInput = ''

            if collectionPrefix then
                validInput = collectionPrefix
            end

            validInput = validInput .. speechType .. ' 1-' .. typeDetails.count

            if typeDetails.skip ~= nil then
                validInput = validInput .. ' (except '
                validInput = validInput .. tableHelper.concatenateFromIndex(typeDetails.skip, 1, ', ') .. ')'
            end

            table.insert(validList, validInput)
        end
    end

    return validList
end

---@param pid PlayerId
function speechHelper.GetPrintableValidListForPid(pid)
    local validList = {}

    local race = Players[pid].data.character.race:lower()
    local gender = Players[pid].data.character.gender

    -- Print the default speech options first
    if speechCollections[race].default ~= nil then
        validList = speechHelper.GetPrintableValidListForSpeechCollection(speechCollections[race].default, gender)
    end

    for speechCollectionKey, speechCollectionTable in pairs(speechCollections[race]) do
        if speechCollectionKey ~= 'default' then
            tableHelper.insertValues(validList,
                speechHelper.GetPrintableValidListForSpeechCollection(speechCollectionTable, gender,
                    speechCollectionKey .. '_'))
        end
    end

    return tableHelper.concatenateFromIndex(validList, 1, ', ')
end

---@param pid PlayerId
---@param speechInput string
---@param speechIndex integer
function speechHelper.PlaySpeech(pid, speechInput, speechIndex)
    local speechPath = speechHelper.GetSpeechPath(pid, speechInput, speechIndex)

    if not speechPath then return false end

    tes3mp.PlaySpeech(pid, speechPath)
    return true
end

return speechHelper
