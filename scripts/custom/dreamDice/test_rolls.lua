local enumerations = require 'tes3mp.enumerations'

---@class DiceInterfaceLocal: ReadOnlyInterfaces
---@field dreamDice DiceInterface
local I = require 'interfaces'

local testPairs = {}

local maxElements = math.random(25, 50)
local usedKeys, numKeys = {}, 0

for _ = 1, maxElements do
  local randomKey

  repeat
    randomKey = math.random(1, maxElements + 1)
  until not usedKeys[randomKey]

  usedKeys[randomKey] = true

  testPairs[randomKey] = math.random(20)
  numKeys = numKeys + 1
end

tes3mp.LogAppend(
  enumerations.log.INFO,
  ('Generating %d random dice pairs for dreamDice integration tests . . .'):format(numKeys)
)

usedKeys = nil

local TestIterations = 25

local TimerDelay = 1 / 10
local function testTimer(randomInt)
  print(randomInt)
  I.timed.registerCallbackFunction(testTimer, TimerDelay, math.random())
end

I.timed.registerCallbackFunction(testTimer, TimerDelay, math.random())

return function()
  local startTime = os.clock()

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('DreamDice integration tests running for %d dice, with %d iterations each.'):format(numKeys, TestIterations)
  )

  local testResults = {}
  for dice, faces in pairs(testPairs) do
    for _ = 1, TestIterations do
      local thisRoll = ('%sd%s+%s'):format(dice, faces, math.random(-100, 100))
      local rollObject = I.dreamDice.roll(thisRoll)

      rollObject:resolve()

      testResults[#testResults + 1] = tostring(rollObject)
    end
  end

  I.timed.subscribeToSave {
    filePath = 'custom/dice/diceTestResults.json',
    data = testResults,
    persistent = false,
    delay = math.random(30, 60),
  }

  tes3mp.LogAppend(
    enumerations.log.INFO,
    ('DreamDice integration tests completed %d rolls in %.6f milliseconds')
    :format(
      numKeys * TestIterations,
      (os.clock() - startTime) * 1000
    )
  )
end
