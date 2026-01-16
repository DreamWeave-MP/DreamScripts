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

local loadOrder = {
  'Morrowind.esm',
  'Tribunal.esm',
  'Bloodmoon.esm',
  'Starwind-TSI.omwaddon',
}

---@type RecordStores
local RecordStores = tds.Hash {
  Alchemy = tds.Hash(),
  Armor = tds.Hash(),
  Activator = tds.Hash(),
  Static = tds.Hash(),
}

local TypeHandlers = {
  Activator = function(recordStore, activatorRecord, recordId)
    recordStore[recordId] = tds.Hash {
      objectFlags = activatorRecord.flags,
      id = recordId,
      model = activatorRecord.mesh:normalize(),
      name = activatorRecord.name,
      script = lowercase(activatorRecord.script),
    }
  end,
  Armor = function(recordStore, armorRecord, recordId)
    local bipedObjects = tds.Vec(#armorRecord.biped_objects)

    for i, bipedObject in ipairs(armorRecord.biped_objects) do
      bipedObjects[i] = tds.Hash {
        bipedObjectType = bipedObject.biped_object_type,
        malePart = lowercase(bipedObject.male_bodypart),
        femalePart = lowercase(bipedObject.female_bodypart),
      }
    end

    recordStore[recordId] = tds.Hash {
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
  Alchemy = function(recordStore, potionRecord, recordId)
    local effects = tds.Vec(#potionRecord.effects)

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

    recordStore[recordId] = tds.Hash {
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
  Static = function(recordStore, staticRecord, recordId)
    recordStore[recordId] = tds.Hash {
      objectFlags = staticRecord.flags,
      id = recordId,
      model = staticRecord.mesh:normalize(),
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

  local plugin = tes3.load_plugin(pluginPath)

  for _, object in ipairs(plugin.objects) do
    local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

    if recordStore and typeHandler then
      typeHandler(recordStore, object, object.id:lower())
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
          print(storeType, recordId, recordData)
          break
        end
      end
    end
  }
}
