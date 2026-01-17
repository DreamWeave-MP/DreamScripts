local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'

local I = require 'interfaces'

local tds = I.tds
local tes3 = I.tes3

if not tds or not tes3 then
  tes3mp.LogAppend(
    enumerations.log.ERROR,
    'Either TDS or TES3_lua was missing.'
  )
  return {}
end

---@param string string
---@return string? lowercased
local function lowercase(string)
  if string then return string:lower() end
end

local RequiredDataFiles = dUtil.getRequiredDataFiles()

local loadOrder = tds.Vec()
loadOrder:resize(#RequiredDataFiles)

for i, loadOrderData in ipairs(RequiredDataFiles) do
  loadOrder[i] = loadOrderData.name
end

---@type RecordStores
local RecordStores = tds.Hash {
  Alchemy = tds.Hash(),
  Armor = tds.Hash(),
  Apparatus = tds.Hash(),
  Activator = tds.Hash(),
  Birthsign = tds.Hash(),
  Bodypart = tds.Hash(),
  Book = tds.Hash(),
  Class = tds.Hash(),
  Clothing = tds.Hash(),
  Container = tds.Hash(),
  Static = tds.Hash(),
}

local TypeHandlers = {
  Activator = function(activatorRecord, recordId)
    return tds.Hash {
      objectFlags = activatorRecord.flags,
      id = recordId,
      model = activatorRecord.mesh:normalize(),
      name = activatorRecord.name,
      script = lowercase(activatorRecord.script),
    }
  end,
  Apparatus = function(appaRecord, recordId)
    return tds.Hash {
      apparatusType = appaRecord.data.apparatus_type,
      icon = appaRecord.icon:normalize(),
      id = recordId,
      model = appaRecord.mesh:normalize(),
      name = appaRecord.name,
      objectFlags = appaRecord.flags,
      quality = appaRecord.data.quality,
      script = lowercase(appaRecord.script),
      weight = appaRecord.data.weight,
      value = appaRecord.data.value,
    }
  end,
  Armor = function(armorRecord, recordId)
    local bipedObjects = tds.Vec()
    bipedObjects:resize(#armorRecord.biped_objects)

    for i, bipedObject in ipairs(armorRecord.biped_objects) do
      bipedObjects[i] = tds.Hash {
        bipedObjectType = bipedObject.biped_object_type,
        malePart = lowercase(bipedObject.male_bodypart),
        femalePart = lowercase(bipedObject.female_bodypart),
      }
    end

    return tds.Hash {
      armorRating = armorRecord.data.armor_rating,
      armorType = armorRecord.data.armor_type,
      durability = armorRecord.data.health,
      enchantment = lowercase(armorRecord.enchanting),
      enchantmentValue = armorRecord.data.enchantment,
      icon = armorRecord.icon:normalize(),
      id = recordId,
      model = armorRecord.mesh:normalize(),
      name = armorRecord.name,
      objectFlags = armorRecord.flags,
      parts = bipedObjects,
      script = lowercase(armorRecord.script),
      weight = armorRecord.data.weight,
      value = armorRecord.data.value,
    }
  end,
  Alchemy = function(potionRecord, recordId)
    local effects = tds.Vec()
    effects:resize(#potionRecord.effects)

    for i, effect in ipairs(potionRecord.effects) do
      effects[i] = tds.Hash {
        magicEffect = effect.magic_effect,
        skill = effect.skill,
        attribute = effect.attribute,
        range = effect.range,
        area = effect.area,
        duration = effect.duration,
        maxMagnitude = effect.max_magnitude,
        minMagnitude = effect.min_magnitude,
      }
    end

    return tds.Hash {
      effects = effects,
      objectFlags = potionRecord.flags,
      icon = potionRecord.icon:normalize(),
      id = recordId,
      model = potionRecord.mesh:normalize(),
      name = potionRecord.name,
      potionFlags = potionRecord.data.flags,
      script = lowercase(potionRecord.script),
      value = potionRecord.data.value,
      weight = potionRecord.data.weight,
    }
  end,
  Birthsign = function(record, recordId)
    local spells = tds.Vec()

    spells:resize(#record.spells)

    for i, spellId in ipairs(record.spells) do
      spells[i] = tostring(spellId):lower()
    end

    return tds.Hash {
      description = record.description,
      id = recordId,
      name = record.name,
      objectFlags = record.flags,
      spells = spells,
      texture = record.texture:normalize(),
    }
  end,
  Bodypart = function(record, recordId)
    return tds.Hash {
      bodypartFlags = record.data.flags,
      bodypartType = record.data.bodypart_type,
      id = recordId,
      isVampire = record.data.vampire,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
      part = record.data.part,
      race = lowercase(record.race),
    }
  end,
  Book = function(record, recordId)
    return tds.Hash {
      bookType = record.data.book_type,
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      script = lowercase(record.script),
      text = record.text,
      value = record.data.value,
      weight = record.data.weight,
    }
  end,
  Class = function(record, recordId)
    return tds.Hash {
      attribute1 = record.attribute1,
      attribute2 = record.attribute2,
      id = recordId,
      major1 = record.major1,
      minor1 = record.minor1,
      major2 = record.major2,
      minor2 = record.minor2,
      major3 = record.major3,
      minor3 = record.minor3,
      major4 = record.major4,
      minor4 = record.minor4,
      major5 = record.major5,
      minor5 = record.minor5,
      objectFlags = record.flags,
      services = record.services,
    }
  end,
  Clothing = function(record, recordId)
    local bipedObjects = tds.Vec()
    bipedObjects:resize(#record.biped_objects)

    for i, bipedObject in ipairs(record.biped_objects) do
      bipedObjects[i] = tds.Hash {
        bipedObjectType = bipedObject.biped_object_type,
        malePart = lowercase(bipedObject.male_bodypart),
        femalePart = lowercase(bipedObject.female_bodypart),
      }
    end

    return tds.Hash {
      clothingType = record.data.clothing_type,
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      parts = bipedObjects,
      script = lowercase(record.script),
      weight = record.data.weight,
      value = record.data.value,
    }
  end,
  Container = function(record, recordId)
    local inventory = tds.Vec()
    inventory:resize(#record.inventory)

    -- for i, item in ipairs(record.inventory) do
    --   inventory[i] = tds.Hash { [item[2]] = item[1] }
    -- end

    return tds.Hash {
      capacity = record.encumbrance,
      containerFlags = record.container_flags,
      id = recordId,
      inventory = inventory,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      script = lowercase(record.script),
    }
  end,
  Static = function(record, recordId)
    return tds.Hash {
      id = recordId,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
    }
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

---@return integer numRecords
local function createRecordStores()
  local loadedRecords = 0
  for _, pluginName in ipairs(loadOrder) do
    local pluginPath = PluginPathFormatter:format(pluginName)

    if not dUtil.io.fileExists(pluginPath) then
      error(
        ('Requested to parse a plugin that doesn\'t actually exist: %s!\nThe server will now terminate. Remove %s from the list of plugins to load or place it at %s')
        :format(pluginPath, pluginName, pluginPath)
      )
    end

    for _, object in ipairs(tes3.load_plugin(pluginPath).objects) do
      local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]
      if object.type == "Npc" then
        for _, item in ipairs(object.inventory) do
          print(item.type)
          break
        end
        break
      end

      if recordStore and typeHandler then
        local recordId = object.id:lower()
        recordStore[recordId] = typeHandler(object, recordId)
        loadedRecords = loadedRecords + 1
      end
    end
  end

  return loadedRecords
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'recordStores',
  ---@class RecordInterface
  interface = {
    records = RecordStores,
  },
  eventValidators = {
    OnServerPostInit = function()
      local startClock = os.clock()

      tes3mp.LogAppend(
        enumerations.log.INFO,
        ('Successfully loaded %d records in %.3f seconds.'):format(createRecordStores(), os.clock() - startClock)
      )

      for k, v in pairs(I.recordStores.records) do
        print(('RecordStore type %s contains %s records'):format(k, #v))
      end

      for storeType, recordStore in pairs(RecordStores) do
        for recordId, recordData in pairs(recordStore) do
          print(storeType, '\n', recordId, '\n', recordData)
          break
        end
      end
    end
  }
}
