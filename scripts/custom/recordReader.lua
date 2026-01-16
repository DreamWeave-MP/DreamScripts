local enumerations = require 'tes3mp.enumerations'

local hasTDS, tds = pcall(require, 'tds')
local hasTES3, tes3 = pcall(require, 'tes3_lua')

if not hasTDS or not hasTES3 then
  tes3mp.LogAppend(
    enumerations.log.ERROR,
    'Either TDS or TES3_lua was missing.'
  )
  -- return {}
end

local loadOrder = {
  'Morrowind.esm',
  -- 'Tribunal.esm',
  -- 'Bloodmoon.esm',
  -- 'Starwind-TSI.omwaddon',
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

for _, pluginName in ipairs(loadOrder) do
  local pluginPath = PluginPathFormatter:format(pluginName)
  local plugin = tes3.load_plugin(pluginPath)
  tes3mp.LogAppend(enumerations.log.WARN, 'Records defined by ' .. pluginPath)

  for _, object in ipairs(plugin.objects) do
    tes3mp.LogAppend(enumerations.log.WARN, object.id .. ' ' .. object.type)
  end
end
