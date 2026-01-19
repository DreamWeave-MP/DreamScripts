local bit = require 'bit'
local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

---@type DefaultInterfaces
local I = require 'interfaces'

local tds = I.tds
local tes3 = I.tes3

if not tds or not tes3 then
  tes3mp.LogAppend(
    enumerations.log.ERROR,
    'Either TDS or TES3_lua was missing.'
  )
  return {}
end

local Enums = require 'dUtil.enums'

---@param value any
---@return string? lowercased
local function lowercase(value)
  if value then return tostring(value):lower() end
end

local function numberField(value)
  return assert(tonumber(value))
end

---@param value any
---@return NormalizedPath? lowercased
local function path(value)
  if value then return assert(tostring(value):normalize()) end
end

---@param value any
---@return RecordId?
local function OptionalRecordId(value)
  local id = lowercase(value)
  if id and id ~= '' then return id end
end

---@param value any
---@return RecordId?
local function MandatoryRecordId(value)
  local id = lowercase(value)
  assert(id and id ~= '')
  return id
end

---@param value any
---@return string? forSure
local function RealString(value)
  local result = tostring(value)
  if result and result ~= '' then return result end
end

---@param ... any
---@return any[]
local function vector(...)
  return tds.Vec(...)
end

---@param trans number[] array with three numeric values
local function transform(trans)
  assert(trans and #trans == 3, tostring(trans))
  return vector(tonumber(trans[1]), tonumber(trans[2]), tonumber(trans[3]))
end

---@param flags integer
---@param checkFlags integer
---@return boolean
local function hasFlag(flags, checkFlags)
  return bit.band(flags, checkFlags) ~= 0
end

---@param record table<string, any>
---@param hash table<string, any>
local function objectFlags(record, hash)
  local flags = numberField(record.flags)
  if flags == 0 then return end

  if hasFlag(record.flags, Enums.Flags.Record.DELETED) then
    hash.isDeleted = true
  end

  if hasFlag(record.flags, Enums.Flags.Record.MODIFIED) then
    hash.isModified = true
  end
end

local AIPackageHandlers = {
  AiActivatePackage = function(package)
    local hash = tds.Hash()
    hash.reset = numberField(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.ACTIVATE
  end,
  AiEscortPackage = function(package)
    local hash = tds.Hash()

    hash.duration = numberField(package.duration)
    hash.reset = numberField(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.ESCORT

    local location = transform(package.location)
    if location then hash.location = location end

    local cell = OptionalRecordId(package.cell)
    if cell then hash.cell = cell end

    return hash
  end,
  AiFollowPackage = function(package)
    local hash = tds.Hash()

    hash.duration = numberField(package.duration)
    hash.reset = numberField(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.FOLLOW

    local location = transform(package.location)
    if location then hash.location = location end

    local cell = OptionalRecordId(package.cell)
    if cell then hash.cell = cell end

    return hash
  end,
  AiTravelPackage = function(package)
    local hash = tds.Hash()

    hash.location = assert(transform(package.location))
    hash.reset = numberField(package.reset)
    hash.type = enumerations.ai.TRAVEL

    return hash
  end,
  AiWanderPackage = function(package)
    local hash    = tds.hash()

    hash.distance = numberField(package.distance)
    hash.duration = numberField(package.duration)
    hash.gameHour = numberField(package.game_hour)
    hash.idle2    = numberField(package.idle2)
    hash.idle3    = numberField(package.idle3)
    hash.idle4    = numberField(package.idle4)
    hash.idle5    = numberField(package.idle5)
    hash.idle6    = numberField(package.idle6)
    hash.idle7    = numberField(package.idle7)
    hash.idle8    = numberField(package.idle8)
    hash.idle9    = numberField(package.idle9)
    hash.reset    = numberField(package.reset)
    hash.type     = enumerations.ai.WANDER

    return hash
  end,
}

local Handlers = {
  AIData = function(aiData)
    local hash = tds.Hash()

    hash.alarm = numberField(aiData.alarm)
    hash.fight = numberField(aiData.fight)
    hash.flee = numberField(aiData.flee)
    hash.hello = numberField(aiData.hello)
    hash.services = numberField(aiData.services)

    return hash
  end,
  AIPackages = function(aiPackages)
    if not aiPackages then return end

    local numPackages = #aiPackages
    if numPackages <= 0 then return end

    local newPackages = tds.Vec()

    newPackages:resize(numPackages)
    for i, aiPackage in ipairs(aiPackages) do
      newPackages[i] = assert(AIPackageHandlers[aiPackage.type](aiPackage))
    end

    return newPackages
  end,
  BipedObjects = function(biped_objects)
    local numObjects, bipedObjects = #biped_objects, nil

    if numObjects <= 0 then return end

    bipedObjects = tds.Vec()
    bipedObjects:resize(numObjects)

    for i, bipedObject in ipairs(biped_objects) do
      local hashBipedObject = tds.Hash()

      hashBipedObject.bipedObjectType = numberField(Enums.BipedObjectType[bipedObject.biped_object_type])
      local malePart = OptionalRecordId(bipedObject.male_bodypart)
      local femalePart = OptionalRecordId(bipedObject.female_bodypart)

      if malePart then
        hashBipedObject.malePart = malePart
      end

      if femalePart then
        hashBipedObject.femalePart = femalePart
      end

      bipedObjects[i] = hashBipedObject
    end
  end,
  ---@param originalEffects MagicEffect[]?
  Effects = function(originalEffects)
    if not originalEffects then return end

    local numItems = #originalEffects
    if numItems <= 0 then return end

    local newEffects = tds.Vec()
    newEffects:resize(numItems)

    for i, effect in ipairs(originalEffects) do
      local hash = tds.Hash()
      hash.area = numberField(effect.area)
      hash.attribute = numberField(Enums.AttributeId[effect.attribute])
      hash.duration = numberField(effect.duration)
      hash.magicEffect = numberField(Enums.MagicEffectId[effect.magic_effect])
      hash.magnitude = tds.Vec(
        numberField(effect.max_magnitude),
        numberField(effect.min_magnitude)
      )
      hash.range = numberField(Enums.EffectRange[effect.range])
      hash.skill = numberField(Enums.SkillId[effect.skill])

      newEffects[i] = hash
    end

    return newEffects
  end,
  ---@param originalInventory InventoryItem[]?
  ---@return InventoryItem[]? hashInventory If the original inventory exists and has items in it, returns it converted to a TDS hashmap
  Inventory = function(originalInventory)
    if not originalInventory then return end

    local numItems = #originalInventory
    if numItems <= 0 then return end

    local inventory = tds.Vec()
    inventory:resize(numItems)

    for i, item in ipairs(originalInventory) do
      local inventoryItem = tds.Hash()

      inventoryItem[MandatoryRecordId(item[2])] = item[1]

      inventory[i] = inventoryItem
    end

    return inventory
  end,
  ---@param originalItems LeveledItemRef[]?
  ---@return LeveledItemRef[]? hashItems If the original inventory exists and has items in it, returns it converted to a TDS hashmap
  LeveledEntry = function(originalItems)
    if not originalItems then return end

    local numItems = #originalItems
    if numItems <= 0 then return end

    local list = tds.Vec()
    list:resize(numItems)

    for i, item in ipairs(originalItems) do
      local listItem = tds.Hash()

      listItem[MandatoryRecordId(item[1])] = item[2]

      list[i] = listItem
    end

    return list
  end,
  Spells = function(spells)
    if not spells then return end

    local numSpells = #spells
    if numSpells <= 0 then return end

    local newSpells = tds.Vec()
    newSpells:resize(numSpells)

    for i, spellId in ipairs(spells) do
      newSpells[i] = MandatoryRecordId(spellId)
    end

    return newSpells
  end,
  TravelDestination = function(destinations)
    if not destinations then return end

    local numDestinations = #destinations
    if numDestinations <= 0 then return end

    local newDestinations = tds.Vec()
    newDestinations:resize(#destinations)

    for i, travelDestination in ipairs(destinations) do
      local destination = tds.Hash()

      local cell = OptionalRecordId(travelDestination.cell)
      if cell then destination.cell = cell end

      if travelDestination.position then
        destination.position = transform(travelDestination.position)
      end

      if travelDestination.rotation then
        destination.rotation = transform(travelDestination.rotation)
      end

      newDestinations[i] = destination
    end

    return newDestinations
  end
}

local RequiredDataFiles = dUtil.getRequiredDataFiles()

local loadOrder = tds.Vec()
loadOrder:resize(#RequiredDataFiles)

for i, loadOrderData in ipairs(RequiredDataFiles) do
  loadOrder[i] = loadOrderData.name
end

---@type RecordStores
local RecordStores = tds.Hash {
  Alchemy = tds.Hash(),
  Armor = tds.Hash(),
  Apparatus = tds.Hash(),
  Activator = tds.Hash(),
  Birthsign = tds.Hash(),
  Bodypart = tds.Hash(),
  Book = tds.Hash(),
  Class = tds.Hash(),
  Clothing = tds.Hash(),
  Container = tds.Hash(),
  Creature = tds.Hash(),
  Door = tds.Hash(),
  Enchanting = tds.Hash(),
  Faction = tds.Hash(),
  GameSetting = tds.Hash(),
  GlobalVariable = tds.Hash(),
  Ingredient = tds.Hash(),
  LeveledCreature = tds.Hash(),
  LeveledItem = tds.Hash(),
  Light = tds.Hash(),
  Lockpick = tds.Hash(),
  MiscItem = tds.Hash(),
  Npc = tds.Hash(),
  Probe = tds.Hash(),
  Race = tds.Hash(),
  Region = tds.Hash(),
  RepairItem = tds.Hash(),
  Script = tds.Hash(),
  Skill = tds.Hash(),
  Sound = tds.Hash(),
  SoundGen = tds.Hash(),
  Spell = tds.Hash(),
  StartScript = tds.Hash(),
  Static = tds.Hash(),
  Weapon = tds.Hash(),
}

local TypeHandlers = {
  Activator = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    objectFlags(record, hash)
    return hash
  end,
  Apparatus = function(record, recordId)
    local hash = tds.Hash()
    hash.id = recordId
    hash.apparatusType = numberField(Enums.ApparatusType[record.data.apparatus_type])
    hash.quality = numberField(record.data.quality)
    hash.weight = numberField(record.data.weight)
    hash.value = numberField(record.data.value)
    hash.icon = path(record.icon)
    hash.model = path(record.mesh)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    objectFlags(record, hash)
    return hash
  end,
  Alchemy = function(record, recordId)
    local hash = tds.Hash()
    hash.icon = path(record.icon)
    hash.id = recordId
    hash.model = path(record.mesh)
    if hasFlag(record.data.flags, Enums.Flags.Potion.AUTO_CALC) then hash.isAutoCalc = true end
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local effects = Handlers.Effects(record.effects)
    if effects then hash.effects = effects end

    objectFlags(record, hash)
    return hash
  end,
  Armor = function(record, recordId)
    local hash = tds.Hash()

    hash.armorRating = numberField(record.data.armor_rating)
    hash.armorType = numberField(Enums.ArmorType[record.data.armor_type])
    hash.durability = numberField(record.data.health)
    hash.enchantmentValue = numberField(record.data.enchantment)
    hash.icon = path(record.icon)
    hash.id = recordId
    hash.model = path(record.mesh)
    hash.weight = numberField(record.data.weight)
    hash.value = numberField(record.data.value)

    local bipedObjects = Handlers.BipedObjects(record.biped_objects)
    if bipedObjects then hash.bipedObjects = bipedObjects end

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local enchantment = OptionalRecordId(record.enchanting)
    if enchantment then hash.enchantment = enchantment end

    objectFlags(record, hash)
    return hash
  end,
  Birthsign = function(record, recordId)
    local hash = tds.Hash()

    hash.description = assert(RealString(record.description))
    hash.id = recordId
    hash.name = assert(RealString(record.name))
    hash.texture = path(record.texture)

    local spells = Handlers.Spells(record.spells)
    if spells then hash.spells = spells end

    objectFlags(record, hash)
    return hash
  end,
  Bodypart = function(record, recordId)
    local hash = tds.Hash()

    hash.bodypartType = numberField(Enums.BodypartType[record.data.bodypart_type])
    hash.id = MandatoryRecordId(recordId)

    -- This one's a bool field so we can't just assert on the value itself
    assert(record.data.vampire ~= nil and type(record.data.vampire) == 'boolean')
    if record.data.vampire then hash.isVampire = true end

    if hasFlag(record.data.flags, Enums.Flags.BodyPart.FEMALE) then hash.isFemale = true end
    if hasFlag(record.data.flags, Enums.Flags.BodyPart.NOT_PLAYABLE) then hash.isUnplayable = true end

    hash.model = path(record.mesh)
    hash.part = numberField(Enums.BodypartId[record.data.part])

    local race = OptionalRecordId(record.race)
    if race then hash.race = race end

    objectFlags(record, hash)
    return hash
  end,
  Book = function(record, recordId)
    local hash = tds.Hash()

    if Enums.BookType[record.data.book_type] == Enums.BookType.Book then
      hash.isBook = true
    end

    hash.enchantmentValue = numberField(record.data.enchantment)
    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    hash.model = path(record.mesh)
    hash.skill = numberField(Enums.SkillId[record.data.skill])
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local enchantment = OptionalRecordId(record.enchanting)
    if enchantment then hash.enchantment = enchantment end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local text = RealString(record.text)
    if text then hash.text = text end

    objectFlags(record, hash)
    return hash
  end,
  Class = function(record, recordId)
    local hash = tds.Hash()

    if hasFlag(record.data.flags, Enums.Flags.Class.PLAYABLE) then hash.isPlayable = true end

    hash.attribute = tds.Vec(
      numberField(Enums.AttributeId[record.data.attribute1]),
      numberField(Enums.AttributeId[record.data.attribute2])
    )

    hash.id = recordId
    hash.major = tds.Vec(
      numberField(Enums.SkillId[record.data.major1]),
      numberField(Enums.SkillId[record.data.major2]),
      numberField(Enums.SkillId[record.data.major3]),
      numberField(Enums.SkillId[record.data.major4]),
      numberField(Enums.SkillId[record.data.major5])
    )

    hash.minor = tds.Vec(
      numberField(Enums.SkillId[record.data.minor1]),
      numberField(Enums.SkillId[record.data.minor2]),
      numberField(Enums.SkillId[record.data.minor3]),
      numberField(Enums.SkillId[record.data.minor4]),
      numberField(Enums.SkillId[record.data.minor5])
    )

    hash.services = numberField(record.data.services)
    hash.specialization = numberField(Enums.Specialization[record.data.specialization])

    objectFlags(record, hash)
    return hash
  end,
  Clothing = function(record, recordId)
    local bipedObjects = Handlers.BipedObjects(record.biped_objects)

    local hash = tds.Hash()
    hash.clothingType = numberField(Enums.ClothingType[record.data.clothing_type])
    hash.enchantmentValue = numberField(record.data.enchantment)
    hash.icon = path(record.icon)
    hash.id = recordId
    hash.model = path(record.mesh)
    hash.weight = numberField(record.data.weight)
    hash.value = numberField(record.data.value)

    if bipedObjects then hash.parts = bipedObjects end

    local enchantment = OptionalRecordId(record.enchanting)
    if enchantment then hash.enchantment = enchantment end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local name = RealString(record.name)
    if name then hash.name = name end

    objectFlags(record, hash)
    return hash
  end,
  Container = function(record, recordId)
    local hash = tds.Hash()
    hash.capacity = numberField(record.encumbrance)
    hash.id = recordId
    if hasFlag(record.container_flags, Enums.Flags.Container.ORGANIC) then hash.isOrganic = true end
    if hasFlag(record.container_flags, Enums.Flags.Container.RESPAWNS) then hash.isRespawning = true end
    hash.model = path(record.mesh)

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local inventory = Handlers.Inventory(record.inventory)
    if inventory then hash.inventory = inventory end

    local name = RealString(record.name)
    if name then hash.name = name end

    objectFlags(record, hash)
    return hash
  end,
  Creature = function(record, recordId)
    local hash = tds.Hash()

    hash.agility = numberField(record.data.agility)

    hash.attack = tds.Vec(
      record.data.attack1[1],
      record.data.attack1[2],
      record.data.attack2[1],
      record.data.attack2[2],
      record.data.attack3[1],
      record.data.attack3[2]
    )

    local baseGold = numberField(record.data.gold)
    if baseGold > 0 then hash.baseGold = baseGold end

    hash.bloodType = numberField(record.blood_type)
    if hasFlag(record.creature_flags, Enums.Flags.Creature.FLIES) then hash.canFly = true end
    if hasFlag(record.creature_flags, Enums.Flags.Creature.SWIMS) then hash.canSwim = true end
    if hasFlag(record.creature_flags, Enums.Flags.Creature.WALKS) then hash.canWalk = true end
    hash.creatureType = numberField(Enums.CreatureType[record.data.creature_type])
    hash.endurance = numberField(record.data.endurance)
    hash.fatigue = numberField(record.data.fatigue)
    hash.health = numberField(record.data.health)
    hash.id = MandatoryRecordId(recordId)
    hash.intelligence = numberField(record.data.intelligence)
    if hasFlag(record.creature_flags, Enums.Flags.Creature.BIPED) then hash.isBiped = true end
    if hasFlag(record.creature_flags, Enums.Flags.Creature.ESSENTIAL) then hash.isEssential = true end
    if hasFlag(record.creature_flags, Enums.Flags.Creature.RESPAWN) then hash.isRespawning = true end
    hash.level = numberField(record.data.level)
    hash.luck = numberField(record.data.luck)
    hash.magicAbility = numberField(record.data.magic)
    hash.magicka = numberField(record.data.magicka)
    hash.model = path(record.mesh)
    objectFlags(record, hash)
    hash.personality = numberField(record.data.personality)
    hash.soulValue = numberField(record.data.soul)
    hash.speed = numberField(record.data.speed)
    hash.stealthAbility = numberField(record.data.stealth)
    hash.strength = numberField(record.data.strength)
    if hasFlag(record.creature_flags, Enums.Flags.Creature.WEAPON_AND_SHIELD) then hash.usesWeapons = true end
    hash.willpower = numberField(record.data.willpower)


    hash.AIData = Handlers.AIData(record.ai_data)

    local creatureScale = tonumber(record.scale)
    if creatureScale and creatureScale ~= 1 then hash.scale = creatureScale end

    local mwScript = OptionalRecordId(record.script)
    if mwScript then hash.script = mwScript end

    local sound = OptionalRecordId(record.sound)
    if sound then hash.sound = sound end

    local destinations = Handlers.TravelDestination(record.travel_destinations)
    if destinations then hash.travelDestinations = destinations end

    local inventory = Handlers.Inventory(record.inventory)
    if inventory then hash.inventory = inventory end

    local aiPackages, spells = Handlers.AIPackages(record.ai_packages), Handlers.Spells(record.spells)

    if aiPackages then hash.AIPackages = aiPackages end
    if spells then hash.spells = spells end

    local name = RealString(record.name)
    if name then hash.name = name end

    return hash
  end,

  Door = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)
    objectFlags(record, hash)

    local name = RealString(record.name)
    if name then hash.name = name end

    local openSound, closeSound = OptionalRecordId(record.open_sound), OptionalRecordId(record.close_sound)

    if openSound then hash.openSound = openSound end
    if closeSound then hash.closeSound = closeSound end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    return hash
  end,

  Enchanting = function(record, recordId)
    local hash = tds.Hash()

    hash.cost = numberField(record.data.cost)
    hash.enchantType = numberField(Enums.EnchantType[record.data.enchant_type])
    hash.id = MandatoryRecordId(recordId)
    --- Surely this has some implication for parsing the effect array?
    if hasFlag(record.data.flags, Enums.Flags.Enchant.AUTO_CALC) then hash.isAutoCalc = true end
    hash.maxCharge = numberField(record.data.max_charge)
    objectFlags(record, hash)

    local effects = Handlers.Effects(record.effects)
    if effects then hash.effects = effects end

    return hash
  end,

  Faction = function(record, recordId)
    local hash = tds.Hash()

    local numRanks, rankNames = #record.rank_names, nil

    if numRanks > 0 then
      rankNames = tds.Vec()
      rankNames:resize(numRanks)

      for i, rankName in ipairs(record.rank_names) do
        rankNames[i] = assert(RealString(rankName))
      end
    end

    local numReactions, reactions = #record.reactions, nil
    if numReactions > 0 then
      reactions = tds.Vec()
      reactions:resize(numReactions)

      for i, reactionData in ipairs(record.reactions) do
        local reaction = tds.Hash()

        reaction[MandatoryRecordId(reactionData.faction)] = numberField(reactionData.reaction)

        reactions[i] = reaction
      end
    end

    if hasFlag(record.data.flags, Enums.Flags.Faction.HIDDEN_FROM_PC) then hash.isHidden = true end

    hash.id = MandatoryRecordId(recordId)
    objectFlags(record, hash)

    hash.favoredAttributes = tds.Vec(
      numberField(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[1]):titleCase()]),
      numberField(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[2]):titleCase()])
    )

    hash.favoredSkills = tds.Vec(
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[1]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[2]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[3]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[4]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[5]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[6]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[7]):titleCase()])
    )

    local requirements = record.data.requirements

    local numReqs = #requirements
    assert(numReqs == 10)

    local hashRequirements = tds.Vec()
    hashRequirements:resize(10)

    for i, requirement in ipairs(requirements) do
      local hashRequirement = tds.Hash()
      hashRequirement.favoredSkill = numberField(requirement.favored_skill)
      hashRequirement.primarySkill = numberField(requirement.primary_skill)
      hashRequirement.reputation = numberField(requirement.reputation)

      local attributes, numAttributes = nil, #requirement.attributes

      if numAttributes > 0 then
        attributes = tds.Vec()
        attributes:resize(numAttributes)

        for j, attribute in ipairs(requirement.attributes) do
          attributes[j] = numberField(tostring(attribute))
        end
      end

      if attributes then hashRequirement.attributes = attributes end

      hashRequirements[i] = hashRequirement
    end

    hash.requirements = hashRequirements

    local name = RealString(record.name)
    if name then hash.name = name end

    if rankNames then hash.rankNames = rankNames end

    return hash
  end,

  GameSetting = function(record, _)
    if record.value.type == 'String' then
      return assert(tostring(record.value))
    else
      return numberField(tostring(record.value))
    end
  end,

  GlobalVariable = function(record, _)
    return numberField(tostring(record.value))
  end,

  Ingredient = function(record, recordId)
    local hash = tds.Hash()

    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    objectFlags(record, hash)
    hash.model = path(record.mesh)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    hash.effects = tds.Vec(
      numberField(Enums.MagicEffectId[RealString(record.data.effects[1])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[2])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[3])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[4])])
    )

    hash.skills = tds.Vec(
      numberField(Enums.SkillId[RealString(record.data.skills[1])]),
      numberField(Enums.SkillId[RealString(record.data.skills[2])]),
      numberField(Enums.SkillId[RealString(record.data.skills[3])]),
      numberField(Enums.SkillId[RealString(record.data.skills[4])])
    )

    hash.attributes = tds.Vec(
      numberField(Enums.AttributeId[RealString(record.data.attributes[1])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[2])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[3])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[4])])
    )

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    return hash
  end,

  LeveledCreature = function(record, recordId)
    local hash = tds.Hash()

    hash.chanceNone = numberField(record.chance_none)
    hash.id = recordId

    if hasFlag(
          record.leveled_creature_flags,
          Enums.Flags.LeveledCreature.CALCULATE_FROM_ALL_LEVELS
        ) then
      hash.calculateFromAllLevels = true
    end

    local creatures = Handlers.LeveledEntry(record.creatures)
    if creatures then hash.creatures = creatures end

    objectFlags(record, hash)
    return hash
  end,

  LeveledItem = function(record, recordId)
    local hash = tds.Hash()

    if hasFlag(
          record.leveled_item_flags,
          Enums.Flags.LeveledItem.CALCULATE_FOR_EACH_ITEM
        ) then
      hash.calculateForEachItem = true
    end

    if hasFlag(
          record.leveled_item_flags,
          Enums.Flags.LeveledItem.CALCULATE_FROM_ALL_LEVELS
        ) then
      hash.calculateFromAllLevels = true
    end

    hash.chanceNone = numberField(record.chance_none)
    hash.id = recordId

    local items = Handlers.LeveledEntry(record.items)
    if items then hash.items = items end

    objectFlags(record, hash)
    return hash
  end,

  Light = function(record, recordId)
    local hash = tds.Hash()

    hash.color = tds.Vec(
      numberField(tostring(record.data.color[1])),
      numberField(tostring(record.data.color[2])),
      numberField(tostring(record.data.color[3]))
    )
    hash.icon = path(record.icon)
    hash.id = recordId
    hash.lightFlags = numberField(record.data.flags)
    hash.model = path(record.mesh)

    hash.radius = numberField(record.data.radius)
    hash.time = numberField(record.data.value)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local sound = OptionalRecordId(record.sound)
    if sound then hash.sound = sound end

    objectFlags(record, hash)
    return hash
  end,

  Lockpick = function(record, recordId)
    local hash = tds.Hash()

    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    hash.model = path(record.mesh)

    hash.quality = numberField(record.data.quality)
    hash.uses = numberField(record.data.uses)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local script, name = OptionalRecordId(record.script), RealString(record.name)
    if script then hash.script = script end
    if name then hash.name = name end

    objectFlags(record, hash)
    return hash
  end,

  MiscItem = function(record, recordId)
    local hash = tds.Hash()

    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    hash.isKey = numberField(record.data.flags) == 1
    hash.miscFlags = numberField(record.data.flags)
    hash.model = path(record.mesh)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    objectFlags(record, hash)
    return hash
  end,

  Npc = function(record, recordId)
    local hash = tds.Hash()

    local baseGold = numberField(record.data.gold)
    if baseGold > 0 then hash.baseGold = baseGold end

    hash.bloodType = numberField(record.blood_type)
    hash.class = MandatoryRecordId(record.class)
    hash.disposition = numberField(record.data.disposition)
    hash.head = MandatoryRecordId(record.head)
    hash.id = MandatoryRecordId(recordId)
    hash.level = numberField(record.data.level)
    hash.model = path(record.mesh)

    if hasFlag(record.npc_flags, Enums.Flags.NPC.AUTO_CALCULATE) then hash.isAutoCalc = true end
    if hasFlag(record.npc_flags, Enums.Flags.NPC.ESSENTIAL) then hash.isEssential = true end
    if hasFlag(record.npc_flags, Enums.Flags.NPC.FEMALE) then hash.isFemale = true end
    if hasFlag(record.npc_flags, Enums.Flags.NPC.RESPAWN) then hash.isRespawning = true end

    hash.race = MandatoryRecordId(record.race)
    hash.rank = numberField(record.data.rank)
    hash.reputation = numberField(record.data.reputation)

    if hash.isAutoCalc and record.data.stats then
      local stats = record.data.stats
      assert(#stats.attributes == 8)
      assert(#stats.skills == 27)

      local statHash = tds.Hash()

      statHash.health = stats.health
      statHash.magicka = stats.magicka
      statHash.fatigue = stats.fatigue

      statHash.attributes = tds.Vec(
        numberField(tostring(stats.attributes[1])),
        numberField(tostring(stats.attributes[2])),
        numberField(tostring(stats.attributes[3])),
        numberField(tostring(stats.attributes[4])),
        numberField(tostring(stats.attributes[5])),
        numberField(tostring(stats.attributes[6])),
        numberField(tostring(stats.attributes[7])),
        numberField(tostring(stats.attributes[8]))
      )

      statHash.skills = tds.Vec(
        numberField(tostring(stats.skills[1])),
        numberField(tostring(stats.skills[2])),
        numberField(tostring(stats.skills[3])),
        numberField(tostring(stats.skills[4])),
        numberField(tostring(stats.skills[5])),
        numberField(tostring(stats.skills[6])),
        numberField(tostring(stats.skills[7])),
        numberField(tostring(stats.skills[8])),
        numberField(tostring(stats.skills[9])),
        numberField(tostring(stats.skills[10])),
        numberField(tostring(stats.skills[11])),
        numberField(tostring(stats.skills[12])),
        numberField(tostring(stats.skills[13])),
        numberField(tostring(stats.skills[14])),
        numberField(tostring(stats.skills[15])),
        numberField(tostring(stats.skills[16])),
        numberField(tostring(stats.skills[17])),
        numberField(tostring(stats.skills[18])),
        numberField(tostring(stats.skills[19])),
        numberField(tostring(stats.skills[20])),
        numberField(tostring(stats.skills[21])),
        numberField(tostring(stats.skills[22])),
        numberField(tostring(stats.skills[23])),
        numberField(tostring(stats.skills[24])),
        numberField(tostring(stats.skills[25])),
        numberField(tostring(stats.skills[26])),
        numberField(tostring(stats.skills[27]))
      )

      hash.stats = statHash
      stats = nil
    end

    hash.AIData = Handlers.AIData(record.ai_data)

    local hair = OptionalRecordId(record.hair)
    if hair then hash.hair = hair end

    local faction = OptionalRecordId(record.faction)
    if faction then hash.faction = faction end

    local mwScript = OptionalRecordId(record.script)
    if mwScript then hash.script = mwScript end

    local destinations = Handlers.TravelDestination(record.travel_destinations)
    if destinations then hash.travelDestinations = destinations end

    local inventory = Handlers.Inventory(record.inventory)
    if inventory then hash.inventory = inventory end

    local aiPackages, spells = Handlers.AIPackages(record.ai_packages), Handlers.Spells(record.spells)

    if aiPackages then hash.AIPackages = aiPackages end
    if spells then hash.spells = spells end

    local name = RealString(record.name)
    if name then hash.name = name end

    objectFlags(record, hash)
    return hash
  end,

  Probe = function(record, recordId)
    local hash = tds.Hash()

    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    hash.model = path(record.mesh)
    hash.quality = numberField(record.data.quality)
    hash.uses = numberField(record.data.uses)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local script, name = OptionalRecordId(record.script), RealString(record.name)
    if script then hash.script = script end
    if name then hash.name = name end

    objectFlags(record, hash)
    return hash
  end,

  Race = function(record, recordId)
    local hash = tds.Hash()

    hash.id = MandatoryRecordId(recordId)

    if hasFlag(record.data.flags, Enums.Flags.Race.BEAST_RACE) then
      hash.isBeastRace = true
    end

    if hasFlag(record.data.flags, Enums.Flags.Race.PLAYABLE) then
      hash.isPlayable = true
    end

    local name = RealString(record.name)
    if name then hash.name = name end

    local spells = Handlers.Spells(record.spells)
    if spells then hash.spells = spells end

    hash.agility = tds.Vec(
      numberField(tostring(record.data.agility[1])),
      numberField(tostring(record.data.agility[2]))
    )

    hash.endurance = tds.Vec(
      numberField(tostring(record.data.endurance[1])),
      numberField(tostring(record.data.endurance[2]))
    )

    hash.height = tds.Vec(
      numberField(tostring(record.data.height[1])),
      numberField(tostring(record.data.height[2]))
    )

    hash.intelligence = tds.Vec(
      numberField(tostring(record.data.intelligence[1])),
      numberField(tostring(record.data.intelligence[2]))
    )

    hash.luck = tds.Vec(
      numberField(tostring(record.data.luck[1])),
      numberField(tostring(record.data.luck[2]))
    )

    hash.personality = tds.Vec(
      numberField(tostring(record.data.personality[1])),
      numberField(tostring(record.data.personality[2]))
    )

    hash.speed = tds.Vec(
      numberField(tostring(record.data.speed[1])),
      numberField(tostring(record.data.speed[2]))
    )

    hash.strength = tds.Vec(
      numberField(tostring(record.data.strength[1])),
      numberField(tostring(record.data.strength[2]))
    )

    hash.weight = tds.Vec(
      numberField(tostring(record.data.weight[1])),
      numberField(tostring(record.data.weight[2]))
    )

    hash.willpower = tds.Vec(
      numberField(tostring(record.data.willpower[1])),
      numberField(tostring(record.data.willpower[2]))
    )

    local description = RealString(record.description)
    if description then hash.description = description end

    local bonuses = tds.Hash()
    bonuses.skill1 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_0])
    bonuses.bonus1 = numberField(record.data.skill_bonuses.bonus_0)
    bonuses.skill2 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_1])
    bonuses.bonus2 = numberField(record.data.skill_bonuses.bonus_1)
    bonuses.skill3 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_2])
    bonuses.bonus3 = numberField(record.data.skill_bonuses.bonus_2)
    bonuses.skill4 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_3])
    bonuses.bonus4 = numberField(record.data.skill_bonuses.bonus_3)
    bonuses.skill5 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_4])
    bonuses.bonus5 = numberField(record.data.skill_bonuses.bonus_4)
    bonuses.skill6 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_5])
    bonuses.bonus6 = numberField(record.data.skill_bonuses.bonus_5)
    bonuses.skill7 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_6])
    bonuses.bonus7 = numberField(record.data.skill_bonuses.bonus_6)
    hash.bonuses = bonuses

    objectFlags(record, hash)
    return hash
  end,

  Region = function(record, recordId)
    local chances       = record.weather_chances
    local hash          = tds.Hash()

    hash.ashChance      = numberField(chances.ash)
    hash.blightChance   = numberField(chances.blight)
    hash.blizzardChance = numberField(chances.blizzard)
    hash.clearChance    = numberField(chances.clear)
    hash.cloudyChance   = numberField(chances.cloudy)
    hash.foggyChance    = numberField(chances.foggy)
    hash.id             = MandatoryRecordId(recordId)
    hash.mapColor       = tds.Vec(
      numberField(tostring(record.map_color[1])),
      numberField(tostring(record.map_color[2])),
      numberField(tostring(record.map_color[3])),
      numberField(tostring(record.map_color[4]))
    )
    hash.overcastChance = numberField(chances.overcast)
    hash.rainChance     = numberField(chances.rain)
    hash.snowChance     = numberField(chances.snow)
    hash.thunderChance  = numberField(chances.thunder)

    local name          = RealString(record.name)
    if name then hash.name = name end

    local sleepCreature = OptionalRecordId(record.sleep_creature)
    if sleepCreature then hash.sleepCreature = sleepCreature end

    local numSounds, sounds = #record.sounds, nil
    if numSounds > 0 then
      sounds = tds.Vec()
      sounds:resize(numSounds)

      for i, soundData in ipairs(record.sounds) do
        local soundHash = tds.Hash()

        soundHash[MandatoryRecordId(soundData[1])] = numberField(soundData[2])

        sounds[i] = soundHash
      end

      hash.sounds = sounds
    end

    objectFlags(record, hash)
    return hash
  end,

  RepairItem = function(record, recordId)
    local hash = tds.Hash()

    hash.icon = path(record.icon)
    hash.id = MandatoryRecordId(recordId)
    hash.model = path(record.mesh)
    hash.uses = numberField(record.data.uses)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)
    hash.quality = numberField(record.data.quality)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    objectFlags(record, hash)
    return hash
  end,

  Script = function(record, recordId)
    local hash = tds.Hash()

    hash.id = MandatoryRecordId(recordId)
    hash.text = MandatoryRecordId(record.text)

    objectFlags(record, hash)
    return hash
  end,

  Skill = function(record, _)
    local hash = tds.Hash()

    hash.actions = tds.Vec(
      numberField(tostring(record.data.actions[1])),
      numberField(tostring(record.data.actions[2])),
      numberField(tostring(record.data.actions[3])),
      numberField(tostring(record.data.actions[4]))
    )
    hash.governingAttribute = numberField(record.data.governing_attribute)
    hash.id = MandatoryRecordId(tostring(record.skill_id))
    hash.skillId = numberField(Enums.SkillId[tostring(record.skill_id)])
    hash.specialization = numberField(record.data.specialization)

    local description = RealString(record.description)
    if description then hash.description = description end

    objectFlags(record, hash)
    return hash
  end,

  Sound = function(record, recordId)
    local hash = tds.Hash()

    hash.id = MandatoryRecordId(recordId)
    hash.path = path(record.sound_path)
    hash.range = tds.Vec(
      numberField(tostring(record.data.range[1])),
      numberField(tostring(record.data.range[2]))
    )
    hash.volume = numberField(record.data.volume)

    objectFlags(record, hash)
    return hash
  end,

  SoundGen = function(record, recordId)
    local creature = OptionalRecordId(record.creature)
    local thisId = recordId or creature

    if not thisId then return end

    local hash = tds.Hash()

    if creature then hash.creature = creature end
    hash.id = thisId

    hash.sound = MandatoryRecordId(record.sound)
    hash.soundGenType = numberField(Enums.SoundGenType[tostring(record.sound_gen_type)])

    objectFlags(record, hash)
    return hash
  end,

  Spell = function(record, recordId)
    local hash = tds.Hash()

    if hasFlag(record.data.flags, Enums.Flags.Spell.ALWAYS_SUCCEEDS) then hash.alwaysSucceeds = true end
    hash.cost = numberField(record.data.cost)
    hash.id = MandatoryRecordId(recordId)
    if hasFlag(record.data.flags, Enums.Flags.Spell.AUTO_CALCULATE) then hash.isAutoCalc = true end
    if hasFlag(record.data.flags, Enums.Flags.Spell.PC_START_SPELL) then hash.isStartSpell = true end

    local name = RealString(record.name)
    if name then hash.name = name end

    local effects = Handlers.Effects(record.effects)
    if effects then hash.effects = effects end

    objectFlags(record, hash)
    return hash
  end,

  StartScript = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.script = MandatoryRecordId(record.script)
    objectFlags(record, hash)

    return hash
  end,

  Static = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)

    objectFlags(record, hash)
    return hash
  end,

  Weapon = function(record, recordId)
    local hash = tds.Hash()

    hash.chop = tds.Vec(numberField(record.data.chop_min), numberField(record.data.chop_max))
    hash.durability = numberField(record.data.health)
    hash.enchantmentValue = numberField(record.data.enchantment)
    hash.icon = path(record.icon)
    hash.id = recordId
    if hasFlag(record.data.flags, Enums.Flags.Weapon.IGNORES_NORMAL_WEAPON_RESISTANCE) then hash.ignoresNormalResistance = true end
    if hasFlag(record.data.flags, Enums.Flags.Weapon.SILVER) then hash.isSilver = true end
    hash.model = path(record.mesh)
    hash.reach = numberField(record.data.reach)
    hash.slash = tds.Vec(numberField(record.data.slash_min), numberField(record.data.slash_max))
    hash.speed = numberField(record.data.speed)
    hash.thrust = tds.Vec(numberField(record.data.thrust_min), numberField(record.data.thrust_max))
    hash.value = numberField(record.data.value)
    hash.weaponType = numberField(Enums.WeaponType[tostring(record.data.weapon_type)])
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local enchantment = OptionalRecordId(record.enchanting)
    if enchantment then hash.enchantment = enchantment end

    objectFlags(record, hash)
    return hash
  end,
}

---@return integer numRecords
local function createRecordStores()
  local loadedRecords = 0

  local _, numPlugins = nil, #loadOrder
  for i = numPlugins, 1, -1 do
    local pluginName = loadOrder[i]
    local pluginPath = PluginPathFormatter:format(pluginName)

    if not dUtil.io.fileExists(pluginPath) then
      error(
        ('Requested to parse a plugin that doesn\'t actually exist: %s!\nThe server will now terminate. Remove %s from the list of plugins to load or place it at %s')
        :format(pluginPath, pluginName, pluginPath)
      )
    else
      tes3mp.LogAppend(
        enumerations.log.INFO,
        ('Parsing record data from: %s'):format(pluginName)
      )
    end

    for j, object in ipairs(tes3.load_plugin(pluginPath).objects) do
      local recordId = OptionalRecordId(object.id)
      local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

      if recordStore and typeHandler then
        --- Since we iterate in reverse, skip records in
        --- this store which have already been defined
        --- Technically this isn't good enough as we should do a placeable check as well
        if not recordId or not recordStore[recordId] then
          local resultRecord = typeHandler(object, recordId)
          local inputId = recordId or resultRecord.id

          if inputId and resultRecord then
            recordStore[inputId] = resultRecord
            loadedRecords = loadedRecords + 1
          else
            tes3mp.LogAppend(
              enumerations.log.WARN,
              ('Skipping record at index %d of plugin %s')
              :format(j, pluginName)
            )
          end
        end
      end
    end
  end

  return loadedRecords
end

---@type TES3MPScriptRegistration
return {
  interfaceName = 'recordStores',
  ---@class RecordInterface
  interface = {
    records = RecordStores,
  },
  eventValidators = {
    OnServerPostInit = function()
      local startClock = os.clock()

      local logStr = ('Successfully loaded %d records in %.3f seconds.\n')
          :format(createRecordStores(), os.clock() - startClock)

      for k, v in pairs(I.recordStores.records) do
        logStr = logStr .. ('%s %s Records loaded.\n'):format(#v, k)
      end

      tes3mp.LogAppend(enumerations.log.INFO, logStr)
    end
  }
}
