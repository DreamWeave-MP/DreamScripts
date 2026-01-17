require 'doc.dUtilDocs'

local enumerations = require 'tes3mp.enumerations'
local jsonInterface = require 'jsonInterface'
local tableHelper = require 'tes3mp.util.table'

local hasTDS, tds = pcall(require, 'tds.init')
local hasTES3, tes3 = pcall(require, 'tes3_lua')

---@param filename string
---@param log boolean? Whether or not to write initialization logs
---@return DataFileRequirements
local function loadDataFileList(filename, log)
  local dataFileList = {}
  if log then
    tes3mp.LogMessage(
      enumerations.log.INFO,
      ('Reading data files from: %s'):format(filename)
    )
  end

  local jsonDataFileList = jsonInterface.load(filename)

  if not jsonDataFileList then
    tes3mp.LogMessage(
      enumerations.log.ERROR,
      ('Data file list at %s cannot be read!'):format(filename)
    )
    tes3mp.StopServer(2)
  end

  ---@cast jsonDataFileList DataFileRequirements
  -- Fix numerical keys to print plugins in the correct order
  tableHelper.fixNumericalKeys(jsonDataFileList, true)

  for listIndex, pluginEntry in ipairs(jsonDataFileList) do
    for entryIndex, checksumStringArray in pairs(pluginEntry) do
      dataFileList[listIndex] = {}
      dataFileList[listIndex].name = entryIndex

      local checksums = {}
      local debugMessage
      if log then
        debugMessage = ('- %d: \"%s\": ['):format(listIndex, entryIndex)
      end

      for _, checksumString in ipairs(checksumStringArray) do
        if log then
          debugMessage = debugMessage .. ('%X, '):format(tonumber(checksumString, 16))
        end

        table.insert(checksums, tonumber(checksumString, 16))
      end

      dataFileList[listIndex].checksums = checksums
      table.insert(dataFileList[listIndex], '')

      if log then
        debugMessage = debugMessage .. '\b\b]'
        tes3mp.LogAppend(enumerations.log.WARN, debugMessage)
      end
    end
  end

  return dataFileList
end

---@enum TableType
local TableType = {
  HASH = 0,
  VEC = 1,
}

--- Fancy table constructor using either TDS or OpenResty functions
--- To construct optimized data structures
---@param tableType TableType
---@param elementCount integer
---@return table
local function tableConstructor(tableType, elementCount, ...)
  assert(hasTDS, 'This function mostly depends on TDS and OpenResty LuaJIT. Sorry!')
  assert(
    table.isarray ~= nil and table.isempty ~= nil,
    'This function depends on TDS and OpenResty LuaJIT. Sorry!'
  )

  local firstArg = select(1, ...)

  if tableType == TableType.HASH then
    if not firstArg then
      return tds.Hash()
    elseif
        type(firstArg) == 'table'
        and not table.isarray(firstArg)
        and not table.isempty(firstArg)
    then
      return tds.Hash(firstArg)
    else
      return tds.Hash()
    end
  elseif tableType == TableType.VEC then
    if not firstArg then
      local result = tds.Vec()

      if elementCount then result:resize(elementCount) end

      return result
    elseif
        type(firstArg) == 'table'
        and table.isarray(firstArg)
    then
      return tds.Vec(firstArg)
    else
      return tds.Vec { ... }
    end
  elseif not tableType then
    local result = {}

    if elementCount then
      for i = 1, elementCount do
        result[i] = 0
      end
    end

    return result
  end

  error(('Invalid tableType: %s'):format(tableType))
end

---@type DUtilModule
local Module = {
  ---@return DataFileRequirements
  getRequiredDataFiles = function()
    return loadDataFileList('requiredDataFiles.json', false)
  end,
  ---@param writeLog boolean? This should only EVER be called with true, once, when the server is initialized. Not heeding this warning or modifying its primary call site in any way will cause very bad things to happen. This function is safe to call with the first parameter as `false` at any point in time.
  ---@return DataFileRequirements
  loadRequiredDataFiles = function(writeLog)
    local dataFileList = loadDataFileList('requiredDataFiles.json', writeLog)

    local clientDataFiles = {}

    for _, entry in ipairs(dataFileList) do
      local name = entry.name
      table.insert(clientDataFiles, name)

      -- Bit of an awkward hack, but we don't necessarily always want to call the C++ functions for this.
      -- It should be safe to call this just the once to initialize ClientDataFiles, without mutating globally
      if writeLog then
        if tableHelper.isEmpty(entry.checksums) then
          tes3mp.AddDataFileRequirement(name, '')
        else
          for _, checksum in ipairs(entry.checksums) do
            tes3mp.AddDataFileRequirement(name, checksum)
          end
        end
      end
    end

    return clientDataFiles
  end,
  ---@type DUtilIO
  io = require 'dUtil.io',
  ---@type DUtilMisc
  misc = require 'dUtil.miscellaneous',
  table = hasTDS and tableConstructor or nil,
  tableType = hasTDS and TableType or nil,
  tds = hasTDS and tds or nil,
  tes3 = hasTES3 and tes3 or nil,
  ---@type Vector3Constructor
  vector3 = require 'dUtil.vector3',
}

return Module
