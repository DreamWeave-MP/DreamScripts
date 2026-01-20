local config = require 'tes3mp.config'
local dkjson = require 'dkjson'
local enumerations = require 'tes3mp.enumerations'

local cjsonExists, cjson = pcall(require, 'cjson')

local LocalDataPath = tes3mp.GetDataPath()

---@type LFSFFIModule
local lfs = require 'lfs'

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

local PathSeparator = tes3mp.GetOperatingSystemType() == 'Windows' and '\\' or '/'
function jsonInterface.writeToFile(fileName, content)
    if jsonInterface.ioLibrary == nil then
        tes3mp.LogMessage(enumerations.log.ERROR, jsonInterface.libraryMissingMessage)
        return false
    end

    local filePath = string.format("%s/%s", config.dataPath, fileName)

    local dir = fileName:match("(.*[/\\])")
    local attributes = dir and lfs.attributes(dir) or nil

    if dir and not attributes then
        local currentPath = config.dataPath .. PathSeparator

        for segment in dir:gmatch("[^/\\]+") do
            if segment == '.' or segment == '..' then goto CONTINUE end

            currentPath = string.format("%s%s/", currentPath, segment)
            local currentPathAttributes = lfs.attributes(currentPath)

            if currentPathAttributes and currentPathAttributes.mode == 'file' then
                tes3mp.LogMessage(enumerations.log.ERROR,
                    'Cannot create directory ' .. currentPath .. ' as it is already a file that exists!')
                return false
            elseif not currentPathAttributes then
                local result = lfs.mkdir(currentPath)
                if not result then
                    tes3mp.LogMessage(enumerations.log.ERROR,
                        "Failed to create directory: " .. currentPath .. ' result: ' .. tostring(result))
                    return false
                end
            end

            ::CONTINUE::
        end
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

-- Lua's default io library for input/output can't open Unicode filenames on Windows,
-- which is why on Windows it's replaced by TES3MP's io2 (https://github.com/TES3MP/Lua-io2)
if tes3mp.GetOperatingSystemType() == "Windows" then
    jsonInterface.setLibrary(require("io2"))
else
    jsonInterface.setLibrary(io)
end

return jsonInterface
