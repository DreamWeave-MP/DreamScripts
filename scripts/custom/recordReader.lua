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
  Static = {}
}

local StaticRecords = {}
local TypeHandlers = {
  Static = function(recordStore, staticRecord)
    local objectId = staticRecord.id:lower()

    tes3mp.LogAppend(
      enumerations.log.WARN,
      type(objectId) .. ' ' .. objectId .. ' ' .. tostring(staticRecord) .. ' ' .. staticRecord.flags
    )

    local objectHashMap = tds.Hash {
      -- flags = staticRecord.flags,
      -- id = objectId,
      -- model = staticRecord.mesh:lower(),
    }
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

for _, pluginName in ipairs(loadOrder) do
  local pluginPath = PluginPathFormatter:format(pluginName)
  local plugin = tes3.load_plugin(pluginPath)
  tes3mp.LogAppend(enumerations.log.WARN, 'Records defined by ' .. pluginPath)

  for i = 1, #plugin.objects do
    local object = plugin.objects[i]
    local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

    if recordStore and typeHandler then
      typeHandler(recordStore, object)
    end
  end
end

-- RecordStores = tds.Hash(RecordStores)

---@type TES3MPScriptRegistration
return {
  interfaceName = 'RecordStores',
  interface = RecordStores,
}
