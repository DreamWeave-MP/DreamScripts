local ffi = require 'ffi'

--- Helper modules built with FFI to improve filesystem experience
--- Paths provided to the DIo module should always be relative to the server/ directory, EG data/requiredDataFiles.json
---@class DUtilIO
local DIo = {}

local OperatingSystem = tes3mp.GetOperatingSystemType()
local UNIX_DEFAULT_PERMS = 448 -- 0755
local WIN_FILE_DIRECTORY = 0x00000010
local WIN_FILE_NORMAL = 0x00000080

if OperatingSystem == "Windows" then
  --- This isn't the most robust thing in the world, but we mostly don't care
  --- about hidden files or anything with weird attributes, so scream test!
  ffi.cdef [[
    typedef unsigned long DWORD;
    DWORD GetFileAttributesA(const char* lpFileName);
    BOOL CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
]]
else
  ffi.cdef [[
    int mkdir(const char *pathname, unsigned int mode);
]]
end

--- Test to determine if a specific file exists
--- Intentionally omits entries with special or weird perms, including directories
---@param fileName string
---@return boolean result Whether or not the provided path is a FILE that exists, without special perms
function DIo.fileExists(fileName)
  if type(fileName) ~= 'string' or fileName == '' then
    error('Invalid parameter passed to jsonInterface.fileExists: ' .. tostring(fileName))
  end

  if OperatingSystem == 'Windows' then
    return ffi.C.GetFileAttributesA(fileName) == WIN_FILE_NORMAL
  else
    return os.execute(('test -f %s'):format(fileName)) == true
  end
end

--- Checks if a given entry is a directory.
--- Distinct from the linux version, because `fileExists` explicitly checks if an entry IS a file,
--- So directories will be omitted.
---@param path string
---@return boolean result Whether or not the provided path is a directory that exists
function DIo.isDir(path)
  if type(path) ~= 'string' or path == '' then
    error('Invalid parameter passed to jsonInterface.isDir: ' .. tostring(path))
  end

  if DIo.fileExists(path) then return false end

  if OperatingSystem == 'Windows' then
    return ffi.C.GetFileAttributesA(path) == WIN_FILE_DIRECTORY
  else
    return os.execute(('test -d %s'):format(path)) == true
  end
end

--- Given a path to a directory, attempt to create it.
--- If the path already exists, return whether or not it's a directory.
--- If the path does not exist, attempt to create it, and return whether or not the attempt succeeded
---@param path string
---@return boolean result Whether or not the directory exists after the function has ran
function DIo.mkdir(path)
  if type(path) ~= 'string' or path == '' then
    error('Invalid parameter passed to jsonInterface.mkdir: ' .. tostring(path))
  end

  if DIo.fileExists(path) then
    return false
  elseif DIo.isDir(path) then
    return true
  end

  if OperatingSystem == 'Windows' then
    return ffi.C.CreateDirectoryA(path, nil) ~= 0
  else
    return ffi.C.mkdir(path, UNIX_DEFAULT_PERMS) == 0
  end
end

return DIo
