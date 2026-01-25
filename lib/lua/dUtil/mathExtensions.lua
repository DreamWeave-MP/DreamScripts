local ceil, floor = math.ceil, math.floor
---@param input number
local function round(input)
  return input >= 0 and floor(input + 0.5) or ceil(input - 0.5)
end
math.round = round

---@param input number
---@param high number
---@param low number
local function clamp(input, low, high)
  return input < low and low or (input > high and high or input)
end
math.clamp = clamp
