local config = require 'config'
local enumerations = require 'tes3mp.enumerations'
local logicHandler = require 'tes3mp.logicHandler'
local packetBuilder = require 'tes3mp.packet.builder'
local tableHelper = require 'tes3mp.util.table'

-- The record type settings whose input should be converted to booleans when using /storerecord
local booleanRecordSettings = {
  scrollState = true,
  keyState = true,
  vampireState = true,
}

--- The record type settings whose input should be converted to tables with a min and a max numerical value
local minMaxRecordSettings = {
  damageChop = true,
  damageSlash = true,
  damageThrust = true,
}

--- The record type settings that are mutually exclusive with each other and remove each other when one of
--- them is set
local mutuallyExclusiveRecordSettings = {
  gamesetting = { intVar = true, floatVar = true, stringVar = true, }
}

-- The record type settings whose input should be converted to numerical values when using /storerecord
local numericalRecordSettings = {
  subtype = true,
  charge = true,
  cost = true,
  value = true,
  weight = true,
  quality = true,
  uses = true,
  time = true,
  radius = true,
  health = true,
  armorRating = true,
  speed = true,
  reach = true,
  scale = true,
  part = true,
  bloodType = true,
  level = true,
  magicka = true,
  fatigue = true,
  soulValue = true,
  aiFight = true,
  aiFlee = true,
  aiAlarm = true,
  aiServices = true,
  autoCalc = true,
  gender = true,
  flags = true,
  enchantmentCharge = true,
  intVar = true,
  floatVar = true,
}

--- The record type settings whose input should be converted to tables with 3 color values
local rgbRecordSettings = {
  color = true,
}

--- The settings which need to be provided when creating a new record that isn't based at all
--- on an existing one, i.e. a new record that is missing a baseId
local requiredRecordSettings = {
  activator = { "name", "model" },
  apparatus = { "name", "model" },
  armor = { "name", "model" },
  bodypart = { "subtype", "part", "model" },
  book = { "name", "model" },
  cell = { "id" },
  clothing = { "name", "model" },
  container = { "name", "model" },
  creature = { "name", "model" },
  door = { "name", "model" },
  enchantment = {},
  gamesetting = { "id" },
  ingredient = { "name", "model" },
  light = { "model" },
  lockpick = { "name", "model" },
  miscellaneous = { "name", "model" },
  npc = { "name", "race", "class" },
  potion = { "name", "model" },
  probe = { "name", "model" },
  repair = { "name", "model" },
  script = { "id" },
  spell = { "name" },
  static = { "model" },
  weapon = { "name", "model" },
  sound = { "sound" }
}

--- The types of records that cannot be placed in the world and should not display a message
--- about how to place them
local unplaceableRecordTypes = { 'spell', 'cell', 'script', 'gamesetting' }

--- The settings which are accepted as input for different record types when using /storerecord
local validRecordSettings = require 'tes3mp.util.validRecordSettings'

local recordHandlers = {
  activator = packetBuilder.AddActivatorRecord,
  apparatus = packetBuilder.AddActivatorRecord,
  armor = packetBuilder.AddArmorRecord,
  book = packetBuilder.AddBookRecord,
  bodypart = packetBuilder.AddBodyPartRecord,
  cell = packetBuilder.AddCellRecord,
  clothing = packetBuilder.AddClothingRecord,
  container = packetBuilder.AddContainerRecord,
  creature = packetBuilder.AddCreatureRecord,
  door = packetBuilder.AddDoorRecord,
  enchantment = packetBuilder.AddEnchantmentRecord,
  gamesetting = packetBuilder.AddGameSettingRecord,
  ingredient = packetBuilder.AddIngredientRecord,
  light = packetBuilder.AddLightRecord,
  lockpick = packetBuilder.AddLockpickRecord,
  miscellaneous = packetBuilder.AddMiscellaneousRecord,
  npc = packetBuilder.AddNpcRecord,
  potion = packetBuilder.AddPotionRecord,
  probe = packetBuilder.AddProbeRecord,
  repair = packetBuilder.AddRepairRecord,
  script = packetBuilder.AddScriptRecord,
  spell = packetBuilder.AddSpellRecord,
  static = packetBuilder.AddStaticRecord,
  weapon = packetBuilder.AddWeaponRecord,
}

local typesWithEffects = {
  enchantment = true,
  ingredient = true,
  potion = true,
  spell = true,
}

local typesWithEnchantments = {
  armor = true,
  book = true,
  clothing = true,
  weapon = true,
}

local typesWithInventories = {
  container = true,
  creature = true,
  npc = true,
}

local typesWithParts = {
  armor = true,
  clothing = true,
}

local storeRecordHandlers = {
  add = function(pid, cmd, inputType, _)
    local player, inputAdditionType = Players[pid], cmd[4]

    if not inputAdditionType or not cmd[5] then
      return player:Message('Please provide the minimum number of arguments required.\n')
    end

    local storedTable = player.data.customVariables.storedRecords[inputType]

    local inputConcatenation = tableHelper.concatenateFromIndex(cmd, 5, ',')
    local inputValues = tableHelper.getTableFromCommaSplit(inputConcatenation)

    if inputAdditionType == 'effect' and typesWithEffects[inputType] then
      if inputType == 'ingredient' and type(storedTable.effects) == 'table' and #storedTable.effects == 4 then
        return player:Message('You have already reached the cap of 4 effects on an ingredient record.\n')
      end

      storedTable.effects = storedTable.effects or {}

      local inputEffectId = tonumber(inputValues[1])

      if type(inputEffectId) ~= 'number' then
        return player:Message('Please use a numerical value for the effect ID.\n')
      end

      storedTable.effects[#storedTable.effects + 1] = {
        id = inputEffectId,
        rangeType = tonumber(inputValues[2]),
        duration = tonumber(inputValues[3]),
        area = tonumber(inputValues[4]),
        magnitudeMin = tonumber(inputValues[5]),
        magnitudeMax = tonumber(inputValues[6]),
        attribute = tonumber(inputValues[7]),
        skill = tonumber(inputValues[8])
      }

      player:Message(('Added effect %s\n'):format(inputConcatenation))
    elseif inputAdditionType == 'part' and typesWithParts[inputType] then
      storedTable.parts = storedTable.parts or {}

      local inputPartType = tonumber(inputValues[1])

      if type(inputPartType) ~= 'number' then
        return player:Message('Please use a numerical value for the part type.\n')
      end

      storedTable.parts[#storedTable.parts + 1] = {
        partType = tonumber(inputPartType),
        malePart = inputValues[2],
        femalePart = inputValues[3]
      }

      player:Message(
        ('Added part %s\n'):format(inputConcatenation)
      )
    elseif inputAdditionType == 'item' and typesWithInventories[inputType] then
      storedTable.items = storedTable.items or {}

      local inputItemId, inputItemCount = inputValues[1], tonumber(inputValues[2])

      if type(inputItemCount) ~= 'number' then
        inputItemCount = 1
      end

      storedTable.items[#storedTable.items + 1] = { id = inputItemId, count = inputItemCount }
      player:Message(
        ('Added item %s with count %s\n'):format(inputItemId, inputItemCount)
      )
    else
      player:Message(tostring(inputAdditionType) .. ' is not a valid addition type for ' ..
        inputType .. ' records.\n')
    end
  end,
  clear = function(pid, _, inputType, _)
    local player = Players[pid]

    player.data.customVariables.storedRecords[inputType] = {}

    player:Message(
      ('Clearing stored %s data\n'):format(inputType)
    )
  end,
  print = function(pid, _, inputType, _)
    local player = Players[pid]
    local storedTable = player.data.customVariables.storedRecords[inputType]

    local text = ('for a record of type %s'):format(inputType)

    if next(storedTable) == nil then
      text = ('You have no values stored %s.'):format(text)
    else
      text = ('You have the current values stored %s:\n\n'):format(text)

      for index, value in pairs(storedTable) do
        local outValue

        if type(value) == 'table' then
          outValue = tableHelper.getSimplePrintableTable(value)
        else
          outValue = value
        end

        text = ('%s%s: %s\n'):format(text, index, outValue)
      end
    end

    tes3mp.CustomMessageBox(pid, config.customMenuIds.recordPrint, text, 'Ok')
  end,
}

---@param value any
---@return boolean isRGB
local function isRGBValue(value)
  return type(value) == 'number'
      and value > -1 and value < 256
end

---@class RecordHelper
local recordHelper = {}

---@param pid PlayerId
---@param cmd CommandTokens
function recordHelper.storeRecord(pid, cmd)
  local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
  if not isValid or not targetPid then return end

  local player = Players[targetPid]
  player.data.customVariables = player.data.customVariables or {}
  player.data.customVariables.storedRecords = player.data.customVariables.storedRecords or {}

  local inputType = cmd[2]:lower()

  if not validRecordSettings[inputType] then
    return player:Message(
      ('Record type %s is invalid. Please use one of the following valid types instead: %s\n')
      :format(inputType, tableHelper.concatenateTableIndices(validRecordSettings, ', '))
    )
  end

  player.data.customVariables.storedRecords[inputType] = player.data.customVariables.storedRecords[inputType] or {}
  local storedTable = player.data.customVariables.storedRecords[inputType]
  local inputSetting = cmd[3]

  local storeHandler = storeRecordHandlers[inputSetting]
  if storeHandler then return storeHandler(targetPid, cmd, inputType, inputSetting) end

  local validSettingsArray = validRecordSettings[inputType]
  if not tableHelper.containsValue(validSettingsArray, inputSetting) then
    return player:Message(
      ('%s is not a valid setting for %s records. Try one of these:\n%s\n')
      :format(inputSetting, inputType, tableHelper.concatenateArrayValues(validSettingsArray, 1, ', '))
    )
  end

  ---@type string|number|nil
  local inputValue = tableHelper.concatenateFromIndex(cmd, 4)

  -- Although numerical values are accepted for gender, allow 'male' and 'female' input
  -- as well
  if inputSetting == 'gender' and type(tonumber(inputValue)) ~= 'number' then
    local gender

    if inputValue == 'male' then
      gender = 1
    elseif inputValue == 'female' then
      gender = 0
    end

    if type(gender) ~= 'number' then
      return player:Message('Please use either 0/1 or female/male as the gender input.\n')
    end

    storedTable.gender = gender
  elseif numericalRecordSettings[inputSetting] then
    inputValue = tonumber(inputValue)

    if type(inputValue) ~= 'number' then
      return player:Message(('Please use a valid numerical value as the input for %s\n'):format(inputSetting))
    end

    storedTable[inputSetting] = inputValue
  elseif minMaxRecordSettings[inputSetting] then
    local minValue = tonumber(cmd[4])
    local maxValue = tonumber(cmd[5])

    if type(minValue) ~= 'number' or type(maxValue) ~= 'number' then
      return player:Message(
        ('Please use two valid numerical values as the input for %s\n'):format(inputSetting)
      )
    end

    storedTable[inputSetting] = { min = minValue, max = maxValue }
  elseif rgbRecordSettings[inputSetting] then
    local redValue = tonumber(cmd[4])
    local greenValue = tonumber(cmd[5])
    local blueValue = tonumber(cmd[6])

    for _, value in ipairs { redValue, greenValue, blueValue } do
      if not isRGBValue(value) then
        return player:Message(
          ('Please use three valid numerical values between 0 and 255 as the input for %s\n')
          :format(inputSetting)
        )
      end
    end

    storedTable[inputSetting] = { red = redValue, green = greenValue, blue = blueValue }
  elseif booleanRecordSettings[inputSetting] then
    if inputValue == 'true' or inputValue == 'on' or tonumber(inputValue) == 1 then
      storedTable[inputSetting] = true
    elseif inputValue == 'false' or inputValue == 'off' or tonumber(inputValue) == 0 then
      storedTable[inputSetting] = false
    else
      return player:Message(
        ('Please use a valid boolean as the input for %s\n'):format(inputSetting)
      )
    end
  else
    storedTable[inputSetting] = inputValue
  end

  -- Remove any stored settings that are mutually exclusive with the one we've added
  if mutuallyExclusiveRecordSettings[inputType] and mutuallyExclusiveRecordSettings[inputType][inputSetting] then
    for _, excludedSetting in pairs(mutuallyExclusiveRecordSettings[inputType]) do
      if excludedSetting ~= inputSetting then
        storedTable[excludedSetting] = nil
      end
    end
  end

  player:Message(
    ('Storing %s %s with value %s\n'):format(inputType, inputSetting, inputValue)
  )
end

---@param pid PlayerId
---@param cmd CommandTokens
function recordHelper.createRecord(pid, cmd)
  local isValid, targetPid = logicHandler.CheckPlayerValidity(nil, pid)
  if not isValid or not targetPid then return end

  local player = Players[targetPid]
  player.data.customVariables = player.data.customVariables or {}
  player.data.customVariables.storedRecords = player.data.customVariables.storedRecords or {}

  if tableHelper.getCount(cmd) > 2 then
    return player:Message('This command does not take more than 1 argument. Did you mean to use /storerecord instead?\n')
  end

  local inputType = cmd[2]:lower()

  if not validRecordSettings[inputType] then
    return player:Message(
      ('Record type %s is invalid. Please use one of the following valid types instead: %s\n')
      :format(inputType, tableHelper.concatenateTableIndices(validRecordSettings, ', '))
    )
  end

  player.data.customVariables.storedRecords[inputType] = player.data.customVariables.storedRecords[inputType] or {}
  local storedTable = player.data.customVariables.storedRecords[inputType]

  if not storedTable.baseId then
    if inputType == 'creature' then
      return player:Message(
        'As of now, you cannot create creatures from scratch because of how many different settings need to be implemented for them. Please use a baseId for your creature instead.\n'
      )
    end

    local missingSettings = {}

    for _, requiredSetting in ipairs(requiredRecordSettings[inputType]) do
      if not storedTable[requiredSetting] then
        table.insert(missingSettings, requiredSetting)
      end
    end

    if next(missingSettings) ~= nil then
      return player:Message(
        ('You cannot create a record of type %s because it is missing the following required settings: %s\n')
        :format(inputType, tableHelper.concatenateArrayValues(missingSettings, 1, ', '))
      )
    end
  end

  if inputType == 'enchantment' and (not storedTable.effects or next(storedTable.effects) == nil) then
    return player:Message(
      ('Records of type %s require at least 1 effect.\n')
      :format(inputType)
    )
  end

  local id = storedTable.id
  local isGenerated = id == nil or logicHandler.IsGeneratedRecord(id)

  local enchantmentStore
  local hasGeneratedEnchantment = typesWithEnchantments[inputType] ~= nil and
      storedTable.enchantmentId ~= nil and logicHandler.IsGeneratedRecord(storedTable.enchantmentId)

  if hasGeneratedEnchantment then
    -- Ensure the generated enchantment used by this record actually exists
    if isGenerated then
      enchantmentStore = RecordStores['enchantment']

      if not enchantmentStore.data.generatedRecords[storedTable.enchantmentId] then
        return player:Message(
          ('The generated enchantment record (%s) you are trying to use for this %s record does not exist.\n')
          :format(storedTable.enchantmentId, inputType)
        )
      end
      -- Permanent records should only use other permanent records as enchantments, so
      -- go no further if that is not the case
    else
      return player:Message(
        ('You cannot use a generated enchantment record (%s) with a permanent record (%s).\n')
        :format(storedTable.enchantmentId, id)
      )
    end
  end

  local recordStore = RecordStores[inputType]

  if not id then
    id = recordStore:GenerateRecordId()
    isGenerated = true
  end

  -- We don't want to insert a direct reference to the storedTable in our record data,
  -- so create a copy of the storedTable and insert that instead
  local savedTable = tableHelper.deepCopy(storedTable)

  -- The id and the savedTable will form a key-value pair, so there's no need to keep
  -- the id in the savedTable as well
  savedTable.id = nil

  -- Use an autoCalc of 1 by default for entirely new NPCs to avoid spawning them
  -- without any stats
  if inputType == 'npc' and not savedTable.baseId and not savedTable.autoCalc then
    savedTable.autoCalc = 1
    player:Message('autoCalc is defaulting to 1 for this record.\n')
  end

  -- Use a skillId of -1 by default for entirely new books to avoid having them
  -- increase a skill
  if inputType == 'book' and not savedTable.skillId then
    savedTable.skillId = -1
    player:Message('skillId is defaulting to -1 for this record.\n')
  end

  local message

  if isGenerated then
    message = 'Your record has now been saved as a generated record that will be deleted when no longer used.\n'
    recordStore.data.generatedRecords[id] = savedTable

    -- This record will be sent to everyone on the server below, so track it
    -- as having already been received by players
    for _, receivingPlayer in pairs(Players) do
      if not tableHelper.containsValue(receivingPlayer.generatedRecordsReceived, id) then
        table.insert(receivingPlayer.generatedRecordsReceived, id)
      end
    end

    -- Is this an enchantable record using an enchantment from a generated record?
    -- If so, add a link to this record for that enchantment record
    if hasGeneratedEnchantment then
      enchantmentStore:AddLinkToRecord(savedTable.enchantmentId, id, inputType)
      enchantmentStore:QuicksaveToDrive()
    end
  else
    message =
    'Your record has now been saved as a permanent record that you\'ll have to remove manually when you no longer need it.\n'
    recordStore.data.permanentRecords[id] = savedTable
  end

  recordStore:QuicksaveToDrive()

  tes3mp.ClearRecords()
  tes3mp.SetRecordType(enumerations.recordType[inputType:upper()])

  local handlerFunction = recordHandlers[inputType]
  if handlerFunction then
    handlerFunction(id, savedTable)
  else
    error(('Invalid record input type: %s'):format(inputType))
  end

  tes3mp.SendRecordDynamic(pid, true, false)

  if not tableHelper.containsValue(unplaceableRecordTypes, inputType) then
    if inputType == 'enchantment' then
      message = ('%sTo use it, create an armor, book, clothing or weapon record with an enchantmentId of %s\n')
          :format(message)
    elseif inputType == 'creature' or inputType == 'npc' then
      message = ('%sYou can spawn an instance of it using /spawnat <pid> %s\n'):format(message)
    else
      message = ('%sYou can place an instance of it using /placeat <pid> %s\n'):format(message)
    end
  end

  player:Message(message)
end

return recordHelper
