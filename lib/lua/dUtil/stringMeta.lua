---@class stringlib
---@field split fun(self: string, separator: string): string[] Splits a string by a separator and returns an array of matching substrings
---@field trim fun(self: string): string Removes whitespace from the beginning and end of a string
---@field capitalizeFirstLetter fun(self: string): string
---@field ciEqual fun(self: string, otherString: string): boolean case-insensitive equality comparison

local StringMeta = getmetatable('').__index

function StringMeta:trim()
  return (self:gsub("^%s*(.-)%s*$", "%1"))
end

function StringMeta:split(sep)
  sep = sep or ':'
  local fields, pattern = {}, ('([^%s]+)'):format(sep)
  self:gsub(pattern, function(c) fields[#fields + 1] = c end)
  return fields
end

function StringMeta:capitalizeFirstLetter()
  return (self:gsub("^%l", string.upper))
end

function StringMeta:ciEqual(otherString)
  if type(otherString) ~= "string" then return false end

  return self:lower() == otherString:lower()
end
