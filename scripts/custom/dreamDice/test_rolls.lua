local enumerations = require 'tes3mp.enumerations'

local I = require 'interfaces'

local testPairs = {}

local maxElements = math.random(100) * math.random(100)
local usedKeys, numKeys = {}, 0

for _ = 1, maxElements do
  local randomKey

  repeat
    randomKey = math.random(1, maxElements + 1)
  until not usedKeys[randomKey] -- Check if key already used

  usedKeys[randomKey] = true

  testPairs[randomKey] = math.random(20)
  numKeys = numKeys + 1
end

tes3mp.LogAppend(
  enumerations.log.INFO,
  ('Generating %d random dice pairs for dreamDice integration tests . . .'):format(numKeys)
)

usedKeys = nil

local DefaultTestIterations = 1000
---@param testIterations integer?
return function(testIterations)
  if not testIterations or type(testIterations) ~= 'number' then
    testIterations = DefaultTestIterations
  end

  local startTime = os.clock()

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('DreamDice integration tests running for %d dice, with %d iterations each.'):format(numKeys, testIterations)
  )

  for dice, faces in pairs(testPairs) do
    for _ = 1, testIterations do
      local thisRoll = ('%sd%s+%s'):format(dice, faces, math.random(-100, 100))
      local rollObject = I.dreamDice.roll(thisRoll)
      rollObject:resolve()
    end
  end

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('DreamDice integration tests completed %d rolls in %.6f milliseconds')
    :format(
      numKeys * testIterations,
      (os.clock() - startTime) * 1000
    )
  )
end
