local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'
local fileHelper = require 'fileHelper'

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
    hash.reset = assert(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.ACTIVATE
  end,
  AiEscortPackage = function(package)
    local hash = tds.Hash()

    hash.cell = assert(lowercase(package.cell))
    hash.duration = assert(package.duration)
    hash.reset = assert(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.ESCORT

    local location = transform(package.location)
    if location then hash.location = location end

    return hash
  end,
  AiFollowPackage = function(package)
    local hash = tds.Hash()

    hash.cell = assert(lowercase(package.cell))
    hash.duration = assert(package.duration)
    hash.reset = assert(package.reset)
    hash.target = assert(package.target)
    hash.type = enumerations.ai.FOLLOW

    local location = transform(package.location)
    if location then hash.location = location end

    return hash
  end,
  AiTravelPackage = function(package)
    local hash = tds.Hash()

    hash.location = assert(transform(package.location))
    hash.reset = assert(package.reset)
    hash.type = enumerations.ai.TRAVEL

    return hash
  end,
  AiWanderPackage = function(package)
    local hash    = tds.hash()

    hash.distance = assert(package.distance)
    hash.duration = assert(package.duration)
    hash.gameHour = assert(package.game_hour)
    hash.idle2    = assert(package.idle2)
    hash.idle3    = assert(package.idle3)
    hash.idle4    = assert(package.idle4)
    hash.idle5    = assert(package.idle5)
    hash.idle6    = assert(package.idle6)
    hash.idle7    = assert(package.idle7)
    hash.idle8    = assert(package.idle8)
    hash.idle9    = assert(package.idle9)
    hash.reset    = assert(package.reset)
    hash.type     = enumerations.ai.WANDER

    return hash
  end,
}

local Handlers = {
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

      hashBipedObject.bipedObjectType = assert(Enums.BipedObjectType[bipedObject.biped_object_type])
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
      hash.maxMagnitude = numberField(effect.max_magnitude)
      hash.minMagnitude = numberField(effect.min_magnitude)
      hash.skill = numberField(Enums.SkillId[effect.skill])

      --- Convert these to int representation
      hash.magicEffect = assert(effect.magic_effect)
      hash.range = assert(effect.range)

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
      newSpells[i] = assert(OptionalRecordId(spellId))
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
      destination.cell = assert(OptionalRecordId(travelDestination.cell))
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
    local spells = tds.Vec()

    spells:resize(#record.spells)
    for i, spellId in ipairs(record.spells) do
      spells[i] = lowercase(spellId)
    end

    return tds.Hash {
      description = record.description,
      id = recordId,
      name = record.name,
      objectFlags = record.flags,
      spells = spells,
      texture = record.texture:normalize(),
    }
  end,
  Bodypart = function(record, recordId)
    return tds.Hash {
      bodypartFlags = record.data.flags,
      bodypartType = assert(Enums.BodypartType[record.data.bodypart_type]),
      id = recordId,
      isVampire = record.data.vampire,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
      part = assert(Enums.BodypartId[record.data.part]),
      race = lowercase(record.race),
    }
  end,
  Book = function(record, recordId)
    return tds.Hash {
      bookType = assert(Enums.BookType[record.data.book_type]),
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      script = lowercase(record.script),
      skill = assert(Enums.SkillId[record.data.skill]),
      text = record.text,
      value = record.data.value,
      weight = record.data.weight,
    }
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
    local creatureHash = tds.Hash {
      AIData = tds.Hash {
        alarm = record.ai_data.alarm,
        fight = record.ai_data.fight,
        flee = record.ai_data.flee,
        hello = record.ai_data.hello,
        services = record.ai_data.services,
      },
      agility = record.data.agility,
      attack1Min = record.data.attack1[1],
      attack1Max = record.data.attack1[2],
      attack2Min = record.data.attack2[1],
      attack2Max = record.data.attack2[2],
      attack3Min = record.data.attack3[1],
      attack3Max = record.data.attack3[2],
      baseGold = record.data.gold,
      bloodType = record.blood_type,
      creatureFlags = record.creature_flags,
      creatureType = record.data.creature_type,
      endurance = record.data.endurance,
      fatigue = record.data.fatigue,
      health = record.data.health,
      id = recordId,
      intelligence = record.data.intelligence,
      level = record.data.level,
      luck = record.data.luck,
      magicAbility = record.data.magic,
      magicka = record.data.magicka,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
      personality = record.data.personality,
      soulValue = record.data.soul,
      speed = record.data.speed,
      stealthAbility = record.data.stealth,
      strength = record.data.strength,
      willpower = record.data.willpower,
    }

    local creatureScale = tonumber(record.scale)
    if creatureScale and creatureScale ~= 1 then creatureHash.scale = creatureScale end

    local mwScript = OptionalRecordId(record.script)
    if mwScript then creatureHash.script = mwScript end

    local sound = OptionalRecordId(record.sound)
    if sound then creatureHash.sound = sound end

    local destinations = Handlers.TravelDestination(record.travel_destinations)
    if destinations then creatureHash.travelDestinations = destinations end

    local inventory = Handlers.Inventory(record.inventory)
    if inventory then creatureHash.inventory = inventory end

    local aiPackages, spells = Handlers.AIPackages(record.ai_packages), Handlers.Spells(record.spells)

    if aiPackages then creatureHash.AIPackages = aiPackages end
    if spells then creatureHash.spells = spells end

    return creatureHash
  end,

  Static = function(record, recordId)
    local hash = tds.Hash()

    hash.id = recordId
    hash.model = path(record.mesh)
    hash.objectFlags = numberField(record.flags)

    return hash
  end,
}

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

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
          print(storeType, '\n', recordId, '\n', recordData)
          break
        end
      end
    end
  }
}
