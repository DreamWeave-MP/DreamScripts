---@class MatchPatterns
local Patterns = {
  --- characters not allowed in filenames
  invalidFileCharacters = '[<>:"/\\|*?\r\n]',
  --- strings separated by commas, with spaces immediately after the commas ignored
  commaSplit = "%s*([^,]+)",
  --- as in commaSplit, but with periods
  periodSplit = "%s*([^%.]+)",
  --- Strings separated by quotation marks
  quoteSplit = '".-"',
  --- X coordinate, Y coordinate
  exteriorCell = "(%-?%d+), ?(%-?%d+)$",
  --- RefId, count, charge
  item = "(.+), (%d+), (%-?%d+)$",
  --- X coordinate, Y coordinate, Z coordinate
  coordinates = "(%-?%d+%.?%d*), (%-?%d+%.?%d*), (%-?%d+%.?%d*)$",
}

return Patterns
