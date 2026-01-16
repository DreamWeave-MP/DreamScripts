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

local loadOrder = {
  'Morrowind.esm',
  -- 'Tribunal.esm',
  -- 'Bloodmoon.esm',
  -- 'Starwind-TSI.omwaddon',
}

local SkipTypes = {
  Dialogue = true,
  DialogueInfo = true,
}

local RecordStores = {
  Static = tds.Hash()
}

local TypeHandlers = {
  Static = function(recordStore, staticRecord)
    tes3mp.LogAppend(
      enumerations.log.WARN,
      staticRecord
    )

    local objectId = staticRecord.id:lower()
    local objectHashTable = tds.Hash {
      id = objectId,
      model = staticRecord.model:lower(),
    }

    recordStore[objectId] = objectHashTable
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

for _, pluginName in ipairs(loadOrder) do
  local pluginPath = PluginPathFormatter:format(pluginName)
  local plugin = tes3.load_plugin(pluginPath)
  tes3mp.LogAppend(enumerations.log.WARN, 'Records defined by ' .. pluginPath)

  for i = 1, #plugin.objects do
    local object = plugin.objects[i]
    if RecordStores[object.type] and TypeHandlers[object.type] then
      TypeHandlers[object.type](RecordStores[object.type], object)
      -- tes3mp.LogAppend(enumerations.log.WARN, tostring(object.id))
      -- tes3mp.LogAppend(enumerations.log.WARN, tostring(object))
    end
    -- tes3mp.LogAppend(enumerations.log.WARN, tostring(object))
  end
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'RecordStores',
  interface = RecordStores,
}
