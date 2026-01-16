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
  Bodypart = tds.Hash(),
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
  Bodypart = function(record, recordId)
    return tds.Hash {
      objectFlags = record.flags,
      id = recordId,
      race = lowercase(record.race),
      model = record.mesh:normalize(),
      part = record.data.part,
      bodypartFlags = record.data.flags,
      bodypartType = record.data.bodypart_type,
      isVampire = record.data.vampire,
    }
  end,
  Static = function(record, recordId)
    return tds.Hash {
      objectFlags = record.flags,
      id = recordId,
      model = record.mesh:normalize(),
    }
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

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

    if recordStore and typeHandler then
      local recordId = object.id:lower()
      recordStore[recordId] = typeHandler(object, recordId)
    end
  end
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'recordStores',
  ---@class RecordInterface
  interface = {
    records = RecordStores,
  },
  eventHandlers = {
    OnServerPostInit = function()
      for storeType, recordStore in pairs(RecordStores) do
        for recordId, recordData in pairs(recordStore) do
          print(storeType, '\n', recordId, '\n', recordData)
          break
        end
      end
    end
  }
}
