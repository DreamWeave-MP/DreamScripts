local config = require 'config'
local tinyYaml = require 'l10n.tinyyaml'

---@type LFSFFIModule
local lfs = require 'lfs'

local OperatingSystem = tes3mp.GetOperatingSystemType()

-- Lua's default io library for input/output can't open Unicode filenames on Windows,
-- which is why on Windows it's replaced by TES3MP's io2 (https://github.com/TES3MP/Lua-io2)
local IoLibrary = OperatingSystem == "Windows" and require 'io2' or io
local PathSeparator = OperatingSystem == 'Windows' and '\\' or '/'

---@param fileName string Path of a filename to open, relative to the server's configured data path.
---@return table<string, any>
return function(fileName)
    local path = ('%s%s%s'):format(config.dataPath, PathSeparator, fileName)
    local result = lfs.attributes(path)

    if not result or result.mode ~= 'file' then
        error(
            ('Could not load the yaml file at path %s because it does not exist, or is not a file!')
            :format(path)
        )
    end

    local file, err = IoLibrary.open(path, 'r')

    if not file then error(('Failed opening the file %s due to error %s'):format(path, err)) end

    local content = file:read("*all")
    file:close()

    local ok, yamlResult = pcall(tinyYaml.parse, content)

    if ok then return yamlResult end

    error(
        ('Failed parsing the yaml file at %s: %s'):format(path, yamlResult)
    )
end
