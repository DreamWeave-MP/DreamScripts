# Dream-Dice

Dream-Dice is a standalone dice roller for TES3MP and Dreamweave. It supports easy and simple usages like you'd expect from a typical virtual tabletop. You roll (or reroll) using chat commands, and the results are broadcast to anyone in the same cell (area) as yourself.

It has two chat commands:

- /roll : makes a new roll based on numbers or stats - Sent to players in the same cell
- /reroll : does whatever your last roll was, but with a fresh result - Sent to players in the same cell
- /rollg : Same as above, but sends result to everyone
- /rerollg : Same as above, but sends result to everyone

# Examples

``` lua
/roll strength
/roll LoNgBlaDe
/roll 1d20
/roll d4
/roll 3d
/roll 6d7-3
/roll 7D9+2
/roll 20
/reroll
```

# Installation
1. Download Dream-Dice from this repository using the download zip button on the GitHub page.
2. In your server's `server/scripts/customScripts.lua` add the following line (anywhere): `require('custom.dreamDice.main')`
3. Roll!

# Roll.lua

You may use the `roll.lua` API to construct new rolls as well in one of two ways.

If you are using Dream-Dice already, then you can access all of `roll.lua`'s functions through the global `Roll`.

Otherwise, assign it to a local in your own require statements: `local Roll = require('custom.myThing.roll')`

1. Simply call `Roll` using any of the above examples: `Roll('1d8-7')` This constructor returns a roll object with the fields:
   - diceCount -> Number of dice for this roll
   - faceCount -> Number of faces on each die for this roll
   - modifier -> Positive or negative stat modifier for this roll
   - rollOne -> helper function to roll a single die with the assigned faceCount. It *must* be called with colon notation:
     ```lua
        local thisRoll = Roll('3d4+1')
        print(thisRoll:rollOne())
     ```
   - resolve -> helper function to get the final result of the current dice roll. It *must* be called with colon notation:
     ```lua
        local thisRoll = Roll('2d8-3')
        print(thisRoll:resolve())
     ```
   - getResultMessage -> This is a helper function used to generate chat messages for rolls. It *must* be called using colon notation:
     ```lua
     local thisRoll = Roll('1d2-8')
     local messageData = {
        --- pid usually provided by some eventHandler, etc
        playerId = pid,
        --- result optional result from calling resolve. If not provided, generates itself
        result = nil,
        --- forStat optional string id of stat or skill rolled for. 
        --- Roll.lua does not provide an API for getting rolls from skills or attributes directly.
        --- See or use dreamDice/main.lua for related code 
        forStat = 'Strength'
     }
     tes3mp.SendMessage(pid, thisRoll:getResultMessage(), false)
     ```
     Naturally, this is the preferred means of interacting with the Roll api.
 2. The functions which the `Roll` constructor uses internally are also public.
    - getModifier
    - getNumDice
    - getNumFaces
    These functions take the same string inputs as above, but don't provide any of the helper stuff or string methods.
    ```lua
    local rollString = '1d8'
    local Roll = require('custom.dreamDice.roll')
    print(Roll.getNumFaces(rollString), Roll.getNumDice(rollString), Roll.getModifier(rollString))
    ```
