---@alias RollString string dice roll such as '1d4', '1d8+12', '1d6-1'
---@alias RollModifier integer positive or negative number denoting roll bonus. Can be zero
---@alias RollNum integer positive number of dice to roll. Minimum of 1, but any positive bounds
---@alias RollFaces integer positive number of faces to roll for each die. Minimum of 1, but any positive bounds

math.randomseed(os.time())
local abs = math.abs
local find = string.find
local floor = math.floor
local format = string.format
local HUGE = math.huge
local lower = string.lower
local match = string.match
local rand = math.random
local sub = string.sub

local Players = Players

local blueViolet
local defaultColor
local green
local lightBlue
local yellow

if color then
    blueViolet = color.BlueViolet
    defaultColor = color.Default
    green = color.Green
    lightBlue = color.LightBlue
    yellow = color.Yellow
end

local DICE_MIN_FACES = 3
local DICE_TYPES = {4, 6, 8, 10, 12, 20, 100}
local ITERATIONS_PER_DICE = 25
local MAX_FACES_OR_DICE = 10000

local LogLoggedPlayerError = 'Must be used with both playerId on a logged player, and called with colon notation!'
local RollOneNoFacesError = 'Faces arg must be provided when calling rollOne!'
local RollFormatStr = '[ ROLL ]: %s: %s'
local RollForStatFormatString = '%s for %s'
local RollFromNumberNoModifierString = '%dd%d'
local RollFromNumberHasModifierString = RollFromNumberNoModifierString .. '+%d'
local RollModifierMatchString = '([+-])()'
local RollNewIndexError = 'Cannot modify field %s of immutable Roll!'
local RollNumDiceMatchString = '^(.-)d'
local RollNumFacesMatchString = '[+-]'
local RollResultMessageFormatString = '%s%s%s rolled %s%s %s%s-sided %s with a modifier of %s%s for a total of %s%s%s%s.\n%s'
local RollToStringString = 'Roll( Modifier: %s, Dice: %s, Faces: %s )'

---@alias Attribute
---| 'Strength'
---| 'Willpower'
---| 'Agility'
---| 'Intelligence'
---| 'Speed'
---| 'Endurance'
---| 'Personality'
---| 'Luck'

---@alias Skill
---| 'Block'
---| 'Armorer'
---| 'HeavyArmor'
---| 'Blunt'
---| 'Longblade'
---| 'Axe'
---| 'Spear'
---| 'Athletics'
---| 'Enchant'
---| 'Destruction'
---| 'Alteration'
---| 'Illusion'
---| 'Conjuration'
---| 'Mysticism'
---| 'Restoration'
---| 'Alchemy'
---| 'Unarmored'
---| 'Security'
---| 'Sneak'
---| 'Acrobatics'
---| 'Lightarmor'
---| 'Shortblade'
---| 'Marksman'
---| 'Mercantile'
---| 'Speechcraft'
---| 'Handtohand'
---| 'Mediumarmor'

---@class Roll
local Roll = {
    ---@type table <string, Attribute>
    Attributes = {
        strength = 'Strength',
        willpower = 'Willpower',
        intelligence = 'Intelligence',
        agility = 'Agility',
        speed = 'Speed',
        endurance = 'Endurance',
        personality = 'Personality',
        luck = 'Luck',
    },
    ---@type table <string, Skill>
    Skills = {
        block = 'Block',
        armorer = 'Armorer',
        mediumarmor = 'Mediumarmor',
        heavyarmor = 'HeavyArmor',
        blunt = 'Blunt',
        longblade = 'Longblade',
        axe = 'Axe',
        spear = 'Spear',
        athletics = 'Athletics',
        enchant = 'Enchant',
        destruction = 'Destruction',
        alteration = 'Alteration',
        illusion = 'Illusion',
        conjuration = 'Conjuration',
        mysticism = 'Mysticism',
        restoration = 'Restoration',
        alchemy = 'Alchemy',
        unarmored = 'Unarmored',
        security = 'Security',
        sneak = 'Sneak',
        acrobatics = 'Acrobatics',
        lightarmor = 'Lightarmor',
        shortblade = 'Shortblade',
        marksman = 'Marksman',
        mercantile = 'Mercantile',
        speechcraft = 'Speechcraft',
        handtohand = 'Handtohand',
    },
}

---@class RollResultData
---@field playerId PlayerId
---@field result? integer roll result from calling resolve
---@field forStat? string attribute or skill being rolled for

---@param rollData RollResultData
---@return string|nil formatted string for a chatbox message
local function getResultMessage(self, rollData)
    local player = Players[rollData.playerId]
    if not player or not player:IsLoggedIn() then return end

    local forStat = (rollData.forStat and string.format(RollForStatFormatString, green, rollData.forStat)) or ''
    local rollResult = rollData.result or self:resolve()

    local diceNum = self.diceCount
    local dieOrDice = 'dice'
    if diceNum == 1 then dieOrDice = 'die' end

    return string.format(RollResultMessageFormatString,
                          lightBlue,
                          player.accountName,
                          blueViolet,
                          green,
                          diceNum,
                          blueViolet,
                          self.faceCount,
                          dieOrDice,
                          green,
                          self.modifier,
                          yellow,
                          rollResult,
                          forStat,
                          blueViolet,
                          defaultColor)
end

---@param input string
---@return boolean whether input actually is a string with something in it
local function isValidString(input)
    return input ~= nil and type(input) == 'string' and string ~= ''
end

---@return integer roll result for a single die
local function rollOne(faces)
    assert(faces, RollOneNoFacesError)
    for i = 1, ITERATIONS_PER_DICE do
        local sideRoll = rand(1, faces)
        if i == ITERATIONS_PER_DICE then return sideRoll end
        ---@diagnostic disable-next-line: missing-return
    end
end

---@return integer final result of a roll for the given set of dice
local function resolve(self)
    local sum = 0

    local numFaces = self.faceCount
    for _ = 1, self.diceCount do
        sum = sum + rollOne(numFaces)
    end

    return sum + self.modifier
end

local function log(self, playerId)
    local player = Players[playerId]
    assert(self and player and player:IsLoggedIn(), LogLoggedPlayerError)
    print(format(RollFormatStr, Players[playerId].accountName, self))
end

---@class RollObject
---@field modifier RollModifier
---@field diceCount RollNum
---@field faceCount RollFaces
---@field getResultMessage function
---@field log function
---@field resolve function
---@field rollOne function

---@param rollString RollString
---@return RollObject
function Roll:__call(rollString)
    ---@type RollObject
    local private = {
        diceCount = self.getNumDice(rollString),
        faceCount = self.getNumFaces(rollString),
        modifier = self.getModifier(rollString),
        getResultMessage = getResultMessage,
        resolve = resolve,
        rollOne = rollOne,
        log = log,
    }

    return setmetatable({}, {
        __index = private,
        __newindex = function(_, key, _)
            error(format(RollNewIndexError, key), 2)
        end,
        __tostring = function(roll)
            return string.format(RollToStringString
                                 , roll.modifier, roll.diceCount, roll.faceCount)
        end
    })
end

---@param input RollString
---@return RollModifier
function Roll.getModifier(input)
    if not isValidString(input) then return 0 end

    local sign, pos = match(input, RollModifierMatchString)

    if not sign then return 0 end

    local number_str = sub(input, pos)

    local number = tonumber(number_str)

    if not number then return 0 end

    if sign == '-' then number = -number end

    return number
end

---@param input RollString
---@return RollNum
function Roll.getNumDice(input)
    if not isValidString(input) then return 1 end

    local before_d = match(input, RollNumDiceMatchString)
    if not before_d or before_d == '' then return 1 end

    local number = tonumber(before_d)

    if not number or number <= 0 then return 1
    elseif MAX_FACES_OR_DICE <= number then return MAX_FACES_OR_DICE end

    return number
end

---@param input RollString
---@return RollFaces
function Roll.getNumFaces(input)
    if not isValidString(input) then return DICE_MIN_FACES end

    local start_pos = find(lower(input), 'd')
    if not start_pos then
        local numFaces = tonumber(input)
        if numFaces then return numFaces end
        return DICE_MIN_FACES
    end

    local substring = sub(input, start_pos + 1)

    local end_pos = find(substring, RollNumFacesMatchString)
    if end_pos then
        substring = sub(substring, 1, end_pos - 1)
    end

    local number = tonumber(substring)

    if not number or number <= DICE_MIN_FACES then return DICE_MIN_FACES
    elseif MAX_FACES_OR_DICE <= number then return MAX_FACES_OR_DICE end

    return number
end

---@param targetValue integer number to generate a roll string for
---@return string roll string that can be used in a Roll constructor
function Roll.fromNumber(targetValue)
    local bestRoll = {dice = 1, sides = targetValue, modifier = 0}
    local bestDifference = HUGE

    for _, sides in ipairs(DICE_TYPES) do
        local dice = floor(targetValue / sides)
        if dice > 0 then
            local remainder = targetValue % sides
            local difference = abs(targetValue - (dice * sides))

            if difference < bestDifference then
                bestRoll = {dice = dice, sides = sides, modifier = remainder}
                bestDifference = difference
            end
        end
    end

    if bestRoll.modifier > 0 then
        return format(RollFromNumberHasModifierString, bestRoll.dice, bestRoll.sides, bestRoll.modifier)
    end

    return format(RollFromNumberNoModifierString, bestRoll.dice, bestRoll.sides)
end

---@param playerId integer
---@param attrOrSkill string present in either Skills or Attributes tables
function Roll:fromStatId(playerId, attrOrSkill)
    local player = Players[playerId]
    if not isValidString(attrOrSkill) or not player or not player:IsLoggedIn() then return end

    attrOrSkill = attrOrSkill:lower()
    local attributeName = self.Attributes[attrOrSkill]
    local skillName = self.Skills[attrOrSkill]

    local resultStat

    local playerData = player.data

    if attributeName then
        resultStat = playerData.attributes[attributeName]
    elseif skillName then
        resultStat = playerData.skills[skillName]
    end

    if resultStat then
        return attributeName or skillName, self.fromNumber(resultStat.base - resultStat.damage)
    end
end

---@param attributeTable table <string, Attribute>
function Roll:addAttributes(attributeTable)
    local Attributes = self.Attributes
    for k, v in pairs(attributeTable) do
        if not rawget(Attributes, k) then rawset(Attributes, k, v) end
    end
end

---@param skillTable table <string, Skill>
function Roll:addSkills(skillTable)
    local Skills = self.Skills
    for k, v in pairs(skillTable) do
        if not rawget(Skills, k) then rawset(Skills, k, v) end
    end
end

return setmetatable(Roll, Roll)
