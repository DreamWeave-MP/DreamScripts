local dkjson = require("dkjson")
local cjson
local cjsonExists = doesModuleExist("cjson")
local ffi = require 'ffi'

if cjsonExists then
    cjson = require("cjson")
    cjson.encode_sparse_array(true)
    cjson.encode_invalid_numbers("null")
    cjson.encode_empty_table_as_object(false)
    cjson.decode_null_as_lightuserdata(false)
else
    tes3mp.LogMessage(enumerations.log.ERROR,
        "Could not find Lua CJSON! The decoding and encoding of JSON files will always use dkjson and be slower as a result.")
end

local jsonInterface = {}

jsonInterface.libraryMissingMessage = "No input/output library selected for JSON interface!"

function jsonInterface.setLibrary(ioLibrary)
    jsonInterface.ioLibrary = ioLibrary
end

-- Remove all text from before the actual JSON content starts
function jsonInterface.removeHeader(content)
    local closestBracketIndex

    local bracketIndex1 = content:find("\n%[")
    local bracketIndex2 = content:find("\n{")

    if bracketIndex1 and bracketIndex2 then
        closestBracketIndex = math.min(bracketIndex1, bracketIndex2)
    else
        closestBracketIndex = bracketIndex1 or bracketIndex2
    end

    return content:sub(closestBracketIndex)
end

function jsonInterface.load(fileName)
    if jsonInterface.ioLibrary == nil then
        tes3mp.LogMessage(enumerations.log.ERROR, jsonInterface.libraryMissingMessage)
        return nil
    end

    local home = config.dataPath .. "/"
    local file = jsonInterface.ioLibrary.open(home .. fileName, 'r')

    if file ~= nil then
        local content = file:read("*all")
        file:close()

        if cjsonExists then
            -- Lua CJSON does not support comments before the JSON data, so remove them if
            -- they are present
            if content:sub(1, 2) == "//" then
                content = jsonInterface.removeHeader(content)
            end

            local decodedContent
            local status, result = pcall(function() decodedContent = cjson.decode(content) end)

            if status then
                return decodedContent
            else
                tes3mp.LogMessage(enumerations.log.ERROR, "Could not load " .. fileName .. " using Lua CJSON " ..
                    "due to improperly formatted JSON! Error:\n" .. result .. "\n" .. fileName .. " is being read " ..
                    "via the slower dkjson instead.")
            end
        end

        return dkjson.decode(content)
    else
        return nil
    end
end

if tes3mp.GetOperatingSystemType() == "Windows" then
    --- This isn't the most robust thing in the world, but we mostly don't care
    --- about hidden files or anything with weird attributes, so scream test!
    ffi.cdef [[
    typedef unsigned long DWORD;
    DWORD GetFileAttributesA(const char* lpFileName);
    BOOL CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
]]

    local FILE_DIRECTORY = 0x00000010
    local FILE_NORMAL = 0x00000080

    --- Windows-specific test to determine if a specific file exists
    --- Intentionally omits entries with special or weird perms, including directories
    ---@param fileName string
    ---@return boolean result Whether or not the provided path is a FILE that exists, without special perms
    function jsonInterface.fileExists(fileName)
        if type(fileName) ~= 'string' or fileName == '' then
            error('Invalid parameter passed to jsonInterface.fileExists: ' .. tostring(fileName))
        end

        return ffi.C.GetFileAttributesA(fileName) == FILE_NORMAL
    end

    --- Checks if a given entry is a directory.
    --- Distinct from the linux version, because `fileExists` explicitly checks if an entry IS a file,
    --- So directories will be omitted.
    ---@param path string
    ---@return boolean result Whether or not the provided path is a directory that exists
    function jsonInterface.isDir(path)
        if type(path) ~= 'string' or path == '' then
            error('Invalid parameter passed to jsonInterface.isDir: ' .. tostring(path))
        end

        if jsonInterface.fileExists(path) then return false end

        return ffi.C.GetFileAttributesA(path) == FILE_DIRECTORY
    end

    --- Given a path to a directory, attempt to create it.
    --- If the path already exists, return whether or not it's a directory.
    --- If the path does not exist, attempt to create it, and return whether or not the attempt succeeded
    ---@param path string
    ---@return boolean result Whether or not the directory exists after the function has ran
    function jsonInterface.mkdir(path)
        if type(path) ~= 'string' or path == '' then
            error('Invalid parameter passed to jsonInterface.mkdir: ' .. tostring(path))
        end

        if jsonInterface.fileExists(path) then
            return false
        elseif jsonInterface.isDir(path) then
            return true
        end

        return ffi.C.CreateDirectoryA(path, nil) ~= 0
    end
else
    ffi.cdef [[
    int mkdir(const char *pathname, unsigned int mode);
]]

    local F_OK = 0x00000000
    local DEFAULT_PERMS = 448 -- 0755

    --- Simple linux API test to determine if a path is a file that exists
    ---@param fileName string
    ---@return boolean result Whether or not the provided path is a FILE entry that exists, directories included
    function jsonInterface.fileExists(fileName)
        if type(fileName) ~= 'string' or fileName == '' then
            error('Invalid parameter passed to jsonInterface.fileExists: ' .. tostring(fileName))
        end

        return os.execute(('test -f %s'):format(fileName)) == F_OK
    end

    --- Linux shell test to check if an entry is an existing directory
    --- Fails if the requested entry exists and is a file
    function jsonInterface.isDir(path)
        if type(path) ~= 'string' or path == '' then
            error('Invalid parameter passed to jsonInterface.isDir: ' .. tostring(path))
        end

        if jsonInterface.fileExists(path) then return false end

        return os.execute(('test -d %s'):format(path)) == F_OK
    end

    --- Given a path to a directory, attempt to create it.
    --- If the path already exists, return whether or not it's a directory.
    --- If the path does not exist, attempt to create it, and return whether or not the attempt succeeded
    function jsonInterface.mkdir(path)
        if type(path) ~= 'string' or path == '' then
            error('Invalid parameter passed to jsonInterface.mkdir: ' .. tostring(path))
        end

        if jsonInterface.fileExists(path) then
            return false
        elseif jsonInterface.isDir(path) then
            return true
        end

        return ffi.C.mkdir(path, DEFAULT_PERMS) == F_OK
    end
end

function jsonInterface.writeToFile(fileName, content)
    if jsonInterface.ioLibrary == nil then
        tes3mp.LogMessage(enumerations.log.ERROR, jsonInterface.libraryMissingMessage)
        return false
    end

    local filePath = string.format("%s/%s", config.dataPath, fileName)

    local dir = filePath:match("(.*[/\\])")
    if dir and not jsonInterface.isDir(dir) then
        print('Checking if %s needs to be created . . .')
        if jsonInterface.fileExists(dir) then
            error('Cannot create the directory ' .. dir .. ' since it\'s already a file!')
        end
        jsonInterface.mkdir(dir)
        -- local currentPath = ""
        -- for segment in dir:gmatch("[^/\\]+") do
        --     currentPath = string.format("%s%s/", currentPath, segment)
        --
        --     if currentPath == './' or currentPath == '../' then goto CONTINUE end
        --
        --     if jsonInterface.fileExists(currentPath) then
        --         tes3mp.LogMessage(enumerations.log.ERROR,
        --             'Cannot create directory ' .. currentPath .. ' as it is already a file that exists!')
        --         return false
        --     elseif not jsonInterface.isDir(currentPath) then
        --         local result = jsonInterface.mkdir(currentPath)
        --         if not result then
        --             tes3mp.LogMessage(enumerations.log.ERROR,
        --                 "Failed to create directory: " .. currentPath .. ' result: ' .. tostring(result))
        --             return false
        --         end
        --     end
        --
        --     ::CONTINUE::
        -- end
    end

    local file = assert(jsonInterface.ioLibrary.open(filePath, 'w+b'))

    if file ~= nil then
        file:write(content)
        file:close()
        return true
    else
        return false
    end
end

-- Save data to JSON in a slower but human-readable way, with identation and a specific order
-- to the keys, provided via dkjson
function jsonInterface.save(fileName, data, keyOrderArray)
    local content = dkjson.encode(data, { indent = true, keyorder = keyOrderArray })

    return jsonInterface.writeToFile(fileName, content)
end

-- Save data to JSON in a fast but minimized way, provided via Lua CJSON, ideal for large files
-- that need to be saved over and over
function jsonInterface.quicksave(fileName, data)
    if cjsonExists then
        local content = cjson.encode(data)
        return jsonInterface.writeToFile(fileName, content)
    else
        return jsonInterface.save(fileName, data)
    end
end

return jsonInterface
