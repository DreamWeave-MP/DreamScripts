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

-- Check for case-insensitive equality
function StringMeta:ciEqual(otherString)
  if type(otherString) ~= "string" then return false end

  return self:lower() == otherString:lower()
end
