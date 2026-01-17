local dUtil = require 'dUtil.init'
local enumerations = require 'tes3mp.enumerations'

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

local AIPackageHandlers = {
  AiActivatePackage = function(package)
    return tds.Hash {
      reset = package.reset,
      target = package.target,
    }
  end,
  AiEscortPackage = function(package)
    return tds.Hash {
      cell = package.cell,
      duration = package.duration,
      locX = tonumber(package.location[1]),
      locY = tonumber(package.location[2]),
      locZ = tonumber(package.location[3]),
      reset = package.reset,
      target = package.target,
    }
  end,
  AiFollowPackage = function(package)
    return tds.Hash {
      cell = package.cell,
      duration = package.duration,
      locX = tonumber(package.location[1]),
      locY = tonumber(package.location[2]),
      locZ = tonumber(package.location[3]),
      reset = package.reset,
      target = package.target,
    }
  end,
  AiTravelPackage = function(package)
    return tds.Hash {
      locX = tonumber(package.location[1]),
      locY = tonumber(package.location[2]),
      locZ = tonumber(package.location[3]),
      reset = package.reset,
    }
  end,
  AiWanderPackage = function(package)
    return tds.Hash {
      distance = package.distance,
      duration = package.duration,
      gameHour = package.game_hour,
      idle2    = package.idle2,
      idle3    = package.idle3,
      idle4    = package.idle4,
      idle5    = package.idle5,
      idle6    = package.idle6,
      idle7    = package.idle7,
      idle8    = package.idle8,
      idle9    = package.idle9,
      reset    = package.reset,
    }
  end,
}

---@param string string
---@return string? lowercased
local function lowercase(string)
  if string then return tostring(string):lower() end
end

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
    return tds.Hash {
      objectFlags = record.flags,
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      script = lowercase(record.script),
    }
  end,
  Apparatus = function(record, recordId)
    return tds.Hash {
      apparatusType = record.data.apparatus_type,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      quality = record.data.quality,
      script = lowercase(record.script),
      weight = record.data.weight,
      value = record.data.value,
    }
  end,
  Armor = function(record, recordId)
    local bipedObjects = tds.Vec()
    bipedObjects:resize(#record.biped_objects)

    for i, bipedObject in ipairs(record.biped_objects) do
      bipedObjects[i] = tds.Hash {
        bipedObjectType = bipedObject.biped_object_type,
        malePart = lowercase(bipedObject.male_bodypart),
        femalePart = lowercase(bipedObject.female_bodypart),
      }
    end

    return tds.Hash {
      armorRating = record.data.armor_rating,
      armorType = record.data.armor_type,
      durability = record.data.health,
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      parts = bipedObjects,
      script = lowercase(record.script),
      weight = record.data.weight,
      value = record.data.value,
    }
  end,
  Alchemy = function(record, recordId)
    local effects = tds.Vec()
    effects:resize(#record.effects)

    for i, effect in ipairs(record.effects) do
      effects[i] = tds.Hash {
        magicEffect = effect.magic_effect,
        skill = effect.skill,
        attribute = effect.attribute,
        range = effect.range,
        area = effect.area,
        duration = effect.duration,
        maxMagnitude = effect.max_magnitude,
        minMagnitude = effect.min_magnitude,
      }
    end

    return tds.Hash {
      effects = effects,
      objectFlags = record.flags,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      potionFlags = record.data.flags,
      script = lowercase(record.script),
      value = record.data.value,
      weight = record.data.weight,
    }
  end,
  Birthsign = function(record, recordId)
    local spells = tds.Vec()

    spells:resize(#record.spells)
    for i, spellId in ipairs(record.spells) do
      spells[i] = tostring(spellId):lower()
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
      bodypartType = record.data.bodypart_type,
      id = recordId,
      isVampire = record.data.vampire,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
      part = record.data.part,
      race = lowercase(record.race),
    }
  end,
  Book = function(record, recordId)
    return tds.Hash {
      bookType = record.data.book_type,
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      script = lowercase(record.script),
      text = record.text,
      value = record.data.value,
      weight = record.data.weight,
    }
  end,
  Class = function(record, recordId)
    return tds.Hash {
      attribute1 = record.attribute1,
      attribute2 = record.attribute2,
      id = recordId,
      major1 = record.major1,
      minor1 = record.minor1,
      major2 = record.major2,
      minor2 = record.minor2,
      major3 = record.major3,
      minor3 = record.minor3,
      major4 = record.major4,
      minor4 = record.minor4,
      major5 = record.major5,
      minor5 = record.minor5,
      objectFlags = record.flags,
      services = record.services,
    }
  end,
  Clothing = function(record, recordId)
    local bipedObjects = tds.Vec()
    bipedObjects:resize(#record.biped_objects)

    for i, bipedObject in ipairs(record.biped_objects) do
      bipedObjects[i] = tds.Hash {
        bipedObjectType = bipedObject.biped_object_type,
        malePart = lowercase(bipedObject.male_bodypart),
        femalePart = lowercase(bipedObject.female_bodypart),
      }
    end

    return tds.Hash {
      clothingType = record.data.clothing_type,
      enchantment = lowercase(record.enchanting),
      enchantmentValue = record.data.enchantment,
      icon = record.icon:normalize(),
      id = recordId,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      parts = bipedObjects,
      script = lowercase(record.script),
      weight = record.data.weight,
      value = record.data.value,
    }
  end,
  Container = function(record, recordId)
    local inventory = tds.Vec()
    inventory:resize(#record.inventory)

    for i, item in ipairs(record.inventory) do
      inventory[i] = tds.Hash { [item[2]] = item[1] }
    end

    return tds.Hash {
      capacity = record.encumbrance,
      containerFlags = record.container_flags,
      id = recordId,
      inventory = inventory,
      model = record.mesh:normalize(),
      name = record.name,
      objectFlags = record.flags,
      script = lowercase(record.script),
    }
  end,
  Creature = function(record, recordId)
    local aiPackages, destinations, inventory, spells = tds.Vec(), tds.Vec(), tds.Vec(), tds.Vec()

    aiPackages:resize(#record.ai_packages)
    for i, aiPackage in ipairs(record.ai_packages) do
      assert(AIPackageHandlers[aiPackage.type])
      aiPackages[i] = AIPackageHandlers[aiPackage.type](aiPackage)
    end

    inventory:resize(#record.inventory)
    for i, item in ipairs(record.inventory) do
      inventory[i] = tds.Hash { [item[2]] = item[1] }
    end

    spells:resize(#record.spells)
    for i, spellId in ipairs(record.spells) do
      spells[i] = lowercase(spellId)
    end

    destinations:resize(#record.travel_destinations)
    for i, travelDestination in ipairs(record.travel_destinations) do
      destinations[i] = tds.Hash {
        cell = lowercase(travelDestination.cell),
        posX = travelDestination.position[1],
        posY = travelDestination.position[2],
        posZ = travelDestination.position[3],
        rotX = travelDestination.rotation[1],
        rotY = travelDestination.rotation[2],
        rotZ = travelDestination.rotation[3],
      }
    end

    return tds.Hash {
      AIData = tds.Hash {
        alarm = record.ai_data.alarm,
        fight = record.ai_data.fight,
        flee = record.ai_data.flee,
        hello = record.ai_data.hello,
        services = record.ai_data.services,
      },
      AIPackages = aiPackages,
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
      inventory = inventory,
      level = record.data.level,
      luck = record.data.luck,
      magicAbility = record.data.magic,
      magicka = record.data.magicka,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
      personality = record.data.personality,
      scale = tonumber(record.scale) or 1,
      script = lowercase(record.script),
      soulValue = record.data.soul,
      sound = lowercase(record.sound),
      speed = record.data.speed,
      spells = spells,
      stealthAbility = record.data.stealth,
      strength = record.data.strength,
      travelDestinations = destinations,
      willpower = record.data.willpower,
    }
  end,
  Static = function(record, recordId)
    return tds.Hash {
      id = recordId,
      model = record.mesh:normalize(),
      objectFlags = record.flags,
    }
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
