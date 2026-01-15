local Roll = require 'custom.dreamDice.roll'

---Only meant to be ran for performance reasons under luaJIT.
---Do not deploy this under tes3mp directly!
local testPairs = {
  [3] = 4,
  [1] = 7,
  [2] = 3,
  [5] = 6,
  [4] = 8,
  [7] = 6,
}
local DefaultTestIterations = 1000

---@param testIterations integer?
return function(testIterations)
  if not testIterations or type(testIterations) ~= 'number' then
    testIterations = DefaultTestIterations
  end

  for dice, faces in pairs(testPairs) do
    local thisRoll = ('%sd%s+%s'):format(dice, faces, math.random(-100, 100))
    for _ = 1, testIterations do
      local rollObject = Roll(thisRoll)
      rollObject:resolve()
      error()
      -- print(rollObject, rollObject:resolve())
    end
  end
end
