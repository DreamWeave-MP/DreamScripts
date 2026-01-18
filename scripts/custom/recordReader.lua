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
  assert(#trans == 3)
  return vector(tonumber(trans[1]), tonumber(trans[2]), tonumber(trans[3]))
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
      hash.maxMagnitude = numberField(effect.max_magnitude)
      hash.minMagnitude = numberField(effect.min_magnitude)
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

      inventoryItem[lowercase(item[2])] = item[1]

      inventory[i] = inventoryItem
    end

    return inventory
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

    for i, travelDestination in ipairs(newDestinations) do
      local destination = tds.Hash()
      destination.cell = MandatoryRecordId(travelDestination.cell)
      destination.position = transform(travelDestination.position)
      destination.rotation = transform(travelDestination.rotation)

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
  Static = tds.Hash(),
}

local TypeHandlers = {
  Activator = function(record, recordId)
    local hash = tds.Hash()

    hash.objectFlags = numberField(record.flags)
    hash.id = recordId
    hash.model = path(record.mesh)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    return hash
  end,
  Apparatus = function(record, recordId)
    local hash = tds.Hash()
    hash.id = recordId
    hash.apparatusType = numberField(Enums.ApparatusType[record.data.apparatus_type])
    hash.objectFlags = numberField(record.flags)
    hash.quality = numberField(record.data.quality)
    hash.weight = numberField(record.data.weight)
    hash.value = numberField(record.data.value)
    hash.icon = path(record.icon)
    hash.model = path(record.mesh)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    return hash
  end,
  Alchemy = function(record, recordId)
    local hash = tds.Hash()
    hash.objectFlags = numberField(record.flags)
    hash.icon = path(record.icon)
    hash.id = recordId
    hash.model = path(record.mesh)
    hash.potionFlags = numberField(record.data.flags)
    hash.value = numberField(record.data.value)
    hash.weight = numberField(record.data.weight)

    local name = RealString(record.name)
    if name then hash.name = name end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local effects = Handlers.Effects(record.effects)
    if effects then hash.effects = effects end

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
    hash.objectFlags = numberField(record.flags)
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

    return hash
  end,
  Birthsign = function(record, recordId)
    local hash = tds.Hash()

    hash.description = assert(RealString(record.description))
    hash.id = recordId
    hash.name = assert(RealString(record.name))
    hash.objectFlags = numberField(record.flags)
    hash.texture = path(record.texture)

    local spells = Handlers.Spells(record.spells)
    if spells then hash.spells = spells end

    return hash
  end,
  Bodypart = function(record, recordId)
    local hash = tds.Hash()

    hash.bodypartFlags = numberField(record.data.flags)
    hash.bodypartType = numberField(Enums.BodypartType[record.data.bodypart_type])
    hash.id = MandatoryRecordId(recordId)

    -- This one's a bool field so we can't just assert on the value itself
    assert(record.data.vampire ~= nil)
    hash.isVampire = record.data.vampire

    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)
    hash.part = numberField(Enums.BodypartId[record.data.part])

    local race = OptionalRecordId(record.race)
    if race then hash.race = race end

    return hash
  end,
  Book = function(record, recordId)
    local hash = tds.Hash()

    hash.bookType = numberField(Enums.BookType[record.data.book_type])
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

    return hash
  end,
  Class = function(record, recordId)
    local hash = tds.Hash()
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

    hash.objectFlags = numberField(record.flags)
    hash.services = numberField(record.data.services)
    hash.specialization = numberField(Enums.Specialization[record.data.specialization])

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
    hash.objectFlags = numberField(record.flags)
    hash.weight = numberField(record.data.weight)
    hash.value = numberField(record.data.value)

    if bipedObjects then hash.parts = bipedObjects end

    local enchantment = OptionalRecordId(record.enchanting)
    if enchantment then hash.enchantment = enchantment end

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local name = RealString(record.name)
    if name then hash.name = name end

    return hash
  end,
  Container = function(record, recordId)
    local hash = tds.Hash()
    hash.capacity = numberField(record.encumbrance)
    hash.containerFlags = numberField(record.container_flags)
    hash.id = recordId
    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)

    local script = OptionalRecordId(record.script)
    if script then hash.script = script end

    local inventory = Handlers.Inventory(record.inventory)
    if inventory then hash.inventory = inventory end

    local name = RealString(record.name)
    if name then hash.name = name end

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

    hash.baseGold = numberField(record.data.gold)
    hash.bloodType = numberField(record.blood_type)
    hash.creatureFlags = numberField(record.creature_flags)
    hash.creatureType = numberField(Enums.CreatureType[record.data.creature_type])
    hash.endurance = numberField(record.data.endurance)
    hash.fatigue = numberField(record.data.fatigue)
    hash.health = numberField(record.data.health)
    hash.id = MandatoryRecordId(recordId)
    hash.intelligence = numberField(record.data.intelligence)
    hash.level = numberField(record.data.level)
    hash.luck = numberField(record.data.luck)
    hash.magicAbility = numberField(record.data.magic)
    hash.magicka = numberField(record.data.magicka)
    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)
    hash.personality = numberField(record.data.personality)
    hash.soulValue = numberField(record.data.soul)
    hash.speed = numberField(record.data.speed)
    hash.stealthAbility = numberField(record.data.stealth)
    hash.strength = numberField(record.data.strength)
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

    return hash
  end,

  Door = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)

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
    hash.enchantFlags = numberField(record.data.flags)
    hash.id = MandatoryRecordId(recordId)
    hash.maxCharge = numberField(record.data.max_charge)
    hash.objectFlags = numberField(record.flags)

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

    hash.factionFlags = numberField(record.data.flags)
    hash.id = MandatoryRecordId(recordId)
    hash.objectFlags = numberField(record.flags)

    hash.favoredAttributes = tds.Vec(
      assert(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[1]):titleCase()]),
      assert(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[2]):titleCase()])
    )

    hash.favoredSkills = tds.Vec(
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[1]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[2]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[3]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[4]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[5]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[6]):titleCase()]),
      assert(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[7]):titleCase()])
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

  Static = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)

    return hash
  end,
}

---@return integer numRecords
local function createRecordStores()
  local loadedRecords = 0

  for _, pluginName in ipairs(loadOrder) do
    local pluginPath = PluginPathFormatter:format(pluginName)

    if not dUtil.io.fileExists(pluginPath) then
      error(
        ('Requested to parse a plugin that doesn\'t actually exist: %s!\nThe server will now terminate. Remove %s from the list of plugins to load or place it at %s')
        :format(pluginPath, pluginName, pluginPath)
      )
    end

    for _, object in ipairs(tes3.load_plugin(pluginPath).objects) do
      local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

      if recordStore and typeHandler then
        local recordId = object.id:lower()
        recordStore[recordId] = typeHandler(object, recordId)
        loadedRecords = loadedRecords + 1
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

      for storeType, recordStore in pairs(RecordStores) do
        for recordId, recordData in pairs(recordStore) do
          print(storeType, '\n', recordId, '\n', recordData, '\n')
          break
        end
      end
    end
  }
}
