local config = require 'tes3mp.config'
local enumerations = require 'tes3mp.enumerations'
local tinyYaml = require 'l10n.tinyyaml'

---@type LFSFFIModule
local lfs = require 'lfs'

local OperatingSystem = tes3mp.GetOperatingSystemType()

-- Lua's default io library for input/output can't open Unicode filenames on Windows,
-- which is why on Windows it's replaced by TES3MP's io2 (https://github.com/TES3MP/Lua-io2)
local IoLibrary = OperatingSystem == "Windows" and require 'io2' or io
local PathSeparator = OperatingSystem == 'Windows' and '\\' or '/'

---@param fileName string Path of a filename to open, relative to the server's configured data path.
---@return table<string, any>?
return function(fileName)
    local path = ('%s%s%s'):format(config.dataPath, PathSeparator, fileName)
    local result = lfs.attributes(path)

    if not result or result.mode ~= 'file' then
        return tes3mp.LogMessage(
            enumerations.log.ERROR,
            ('Could not load the yaml file at path %s because it does not exist, or is not a file!')
            :format(path)
        )
    end

    local file = IoLibrary.open(path, 'r')

    if not file then return end

    local content = file:read("*all")
    file:close()

    local ok, yamlResult = pcall(tinyYaml.parse, content)

    if ok then return yamlResult end

    tes3mp.LogAppend(
        enumerations.log.ERROR,
        ('Failed parsing the yaml file at %s: %s'):format(path, yamlResult)
    )
end
