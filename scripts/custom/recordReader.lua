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

local RecordStores = tds.Hash {
  Static = tds.Hash(),
}

local StaticRecords = {}
local TypeHandlers = {
  Static = function(recordStore, staticRecord)
    local objectId = staticRecord.id:lower()
    recordStore[objectId] = tds.Hash {
      flags = staticRecord.flags,
      id = objectId,
      model = staticRecord.mesh:normalize(),
    }
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

for _, pluginName in ipairs(loadOrder) do
  local pluginPath = PluginPathFormatter:format(pluginName)
  local plugin = tes3.load_plugin(pluginPath)
  tes3mp.LogAppend(enumerations.log.WARN, 'Records defined by ' .. pluginPath)

  for _, object in ipairs(plugin.objects) do
    local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

    if recordStore and typeHandler then
      typeHandler(recordStore, object)
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
