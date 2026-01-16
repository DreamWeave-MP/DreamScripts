local enumerations = require 'tes3mp.enumerations'
local tableHelper = require 'tes3mp.util.table'

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

local loadOrder = {
  'Morrowind.esm',
  'Tribunal.esm',
  'Bloodmoon.esm',
  'Starwind-TSI.omwaddon',
}

local RecordStores = tds.Hash {
  Alchemy = tds.Hash(),
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
      script = activatorRecord.script,
    }
  end,
  Alchemy = function(recordStore, potionRecord, recordId)
    local effects = {}

    for _, effect in ipairs(potionRecord.effects) do
      effects[#effects + 1] = tds.Hash {
        magic_effect = effect.magic_effect,
        skill = effect.skill,
        attribute = effect.attribute,
        range = effect.range,
        area = effect.area,
        duration = effect.duration,
        max_magnitude = effect.max_magnitude,
        min_magnitude = effect.min_magnitude,
      }
    end

    recordStore[recordId] = tds.Hash {
      area = potionRecord.area,
      duration = potionRecord.duration,
      effects = effects,
      objectFlags = potionRecord.flags,
      icon = potionRecord.icon:normalize(),
      id = recordId,
      model = potionRecord.mesh:normalize(),
      name = potionRecord.name,
      potionFlags = potionRecord.data.flags,
      script = potionRecord.script,
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
  local plugin = tes3.load_plugin(pluginPath)
  tes3mp.LogAppend(
    enumerations.log.WARN,
    ('Records defined by %s'):format(pluginPath)
  )

  for _, object in ipairs(plugin.objects) do
    local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

    if recordStore and typeHandler then
      typeHandler(recordStore, object, object.id:lower())
    end
  end
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'RecordStores',
  interface = {
    records = RecordStores,
  },
}
