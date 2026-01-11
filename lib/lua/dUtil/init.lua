require 'doc.dUtilDocs'

---@type DUtilModule
local Module = {
  ---@type DUtilIO
  io = require 'dUtil.io',
  ---@type DUtilMisc
  misc = require 'dUtil.miscellaneous',
  ---@type DScriptLoader
  scriptLoader = require 'dUtil.scriptLoader',
  ---@type Vector3Module
  vector3 = require 'dUtil.vector3',
}

return Module
