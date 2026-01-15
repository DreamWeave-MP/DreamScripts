local RollDep

RollDep = Roll or require('roll')

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
local testIterations = 10

(function()
    local rand = math.random
    local format = string.format
  for dice, faces in pairs(testPairs) do
    local thisRoll = format('%sd%s+%s', dice, faces, rand(-100, 100))
    for _ = 1, testIterations do
      local rollObject = RollDep(thisRoll)
      rollObject:resolve()
      print(rollObject, rollObject:resolve())
    end
  end
end)()
