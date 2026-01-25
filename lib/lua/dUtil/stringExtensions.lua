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

--- Title case a string (capitalize first letter of each word)
function StringMeta:titleCase()
  if self == '' then return '' end

  -- Split by spaces, including multiple spaces
  local words = {}
  for word in self:gmatch('%S+') do
    table.insert(words, word)
  end

  -- Capitalize each word
  for i, word in ipairs(words) do
    if #word > 0 then
      words[i] = word:sub(1, 1):upper() .. word:sub(2):lower()
    end
  end

  -- Reconstruct with single spaces
  return table.concat(words, ' ')
end

function StringMeta:ciEqual(otherString)
  if type(otherString) ~= "string" then return false end

  return self:lower() == otherString:lower()
end

function StringMeta:prefixZeroes(desiredLength)
  local length, newString = self:len(), self

  while length < desiredLength do
    newString = "0" .. newString
    length = length + 1
  end

  return newString
end

function StringMeta:normalize()
  return self:lower():gsub('\\', '/')
end

function StringMeta:scriptPath()
  return self:gsub('[\\/]+', '.'):gsub('^%.', ''):gsub('%.$', ''):gsub('%.%.+', '.')
end

function StringMeta:splitUniqueIndex()
  local splitIndex = self:split('-')
  return math.floor(assert(tonumber(splitIndex[1]))), math.floor(assert(tonumber(splitIndex[2])))
end

do
  local hasResty, result = pcall(require, 'table.isempty')
  if hasResty then
    table.isempty = result
    table.isarray = require 'table.isarray'
    table.nkeys = require 'table.nkeys'
    table.clone = require 'table.clone'
  end

  table.new = require 'table.new'
end
