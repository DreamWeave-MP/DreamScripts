local bit = require 'bit'
local dUtil = require 'dUtil'
local enumerations = require 'packages.networkEnums'
local ffi = require 'ffi'
local lfs = require 'lfs'

local LogSkippedRecords = false
local LoadedRecords, PluginLoadIndex = 0, 0

local PluginPathFormatter = tes3mp.GetDataPath() .. '/custom/recordParser/%s'

---@type DefaultInterfaces
local I = require 'interfaces'

local tds = assert(I.tds)
local tes3 = assert(I.tes3)

---@class CellLoadConfig
---@field Exterior boolean
---@field Interior boolean
local LoadCellTypes = tds.hash { Exterior = true, Interior = true, }

local Enums = require 'packages.MWEnums'

local RequiredDataFiles = dUtil.getRequiredDataFiles()

local loadOrder = table.new(#RequiredDataFiles, 0)

local foundPlugins = table.new(0, #RequiredDataFiles)

for i, loadOrderData in ipairs(RequiredDataFiles) do
  local pluginName = loadOrderData.name
  local lowerPluginName = pluginName:lower()

  assert(
    not foundPlugins[lowerPluginName],
    ('%s was already loaded and cannot be loaded a second time.')
    :format(pluginName)
  )

  loadOrder[i] = pluginName

  foundPlugins[lowerPluginName] = true
end

---@param value any
---@return string? lowercased
local function lowercase(value)
  if not value then return end

  if type(value) == 'string' then
    if value == '' then return end

    return value:lower()
  end

  local result = tostring(value)
  if not result or result == '' then return end

  return result:lower()
end

local function numberField(value)
  if type(value) == 'number' then return value end

  return assert(tonumber(value))
end

---@param value any
---@return NormalizedPath? lowercased
local function path(value)
  if not value then return end

  if type(value) == 'string' then
    if value == '' then return end

    return value:normalize()
  end

  local stringForm = assert(tostring(value))

  if stringForm == '' then return end

  return stringForm:normalize()
end

---@param value any
---@return RecordId?
local function OptionalRecordId(value)
  local id = lowercase(value)
  if id then return id end
end

---@param value any
---@return RecordId
local function MandatoryRecordId(value)
  local id = lowercase(value)
  if not id then error('Invalid recordId: ' .. tostring(value), 2) end

  return id
end

---@param value any
---@return string? forSure
local function RealString(value)
  if type(value) == 'string' then
    if value == '' then return end

    return value
  end

  local converted = tostring(value)
  if converted ~= '' then return converted end
end

---@param trans number[] array with three numeric values
local function transform(trans)
  assert(trans and #trans == 3, tostring(trans))
  return { numberField(tostring(trans[1])), numberField(tostring(trans[2])), numberField(tostring(trans[3])) }
end

---@param flags integer
---@param checkFlags integer
---@return boolean
local function hasFlag(flags, checkFlags)
  return bit.band(flags, checkFlags) ~= 0
end

---@param record table<string, any>
---@return boolean? wasDeleted, boolean? wasModified
local function objectFlags(record)
  assert(type(record.flags) == 'number')

  local flags = record.flags
  if flags == 0 then return end

  return hasFlag(record.flags, Enums.Flags.Record.DELETED), hasFlag(record.flags, Enums.Flags.Record.MODIFIED)
end

local NumMandatoryFields = {
  Activator = 2,
  Alchemy = 5,
  Apparatus = 7,
  Armor = 9,
  Birthsign = 4,
  Bodypart = 4,
  Book = 7,
  Class = 6,
  Clothing = 7,
  Container = 3,
  Creature = 21,
  Door = 2,
  Enchanting = 4,
  Faction = 4,
  Ingredient = 8,
  LeveledCreature = 2,
  LeveledItem = 2,
  Light = 9,
  Lockpick = 7,
  MiscItem = 7,
  Npc = 11,
  Probe = 7,
  Race = 12,
  Region = 12,
  RepairItem = 7,
  Script = 2,
  Skill = 5,
  Sound = 4,
  SoundGen = 3,
  Spell = 2,
  StartScript = 2,
  Static = 2,
  Weapon = 13,
}

local AIPackageHandlers = {
  AiActivatePackage = function(package)
    return {
      reset = numberField(package.reset),
      target = assert(package.target),
      type = enumerations.ai.ACTIVATE,
    }
  end,
  AiEscortPackage = function(package)
    local cell = OptionalRecordId(package.cell)

    local numFields = 5 + (cell and 1 or 0)
    local object = table.new(0, numFields)

    object.duration = numberField(package.duration)
    object.reset = numberField(package.reset)
    object.target = assert(package.target)
    object.type = enumerations.ai.ESCORT
    object.location = transform(package.location)

    if cell then object.cell = cell end

    return object
  end,
  AiFollowPackage = function(package)
    local cell = OptionalRecordId(package.cell)

    local numFields = 5 + (cell and 1 or 0)
    local object = table.new(0, numFields)

    object.duration = numberField(package.duration)
    object.location = transform(package.location)
    object.reset = numberField(package.reset)
    object.target = assert(package.target)
    object.type = enumerations.ai.FOLLOW

    if cell then object.cell = cell end

    return object
  end,
  AiTravelPackage = function(package)
    return {
      location = assert(transform(package.location)),
      reset = numberField(package.reset),
      type = enumerations.ai.TRAVEL,
    }
  end,
  AiWanderPackage = function(package)
    return {
      distance = numberField(package.distance),
      duration = numberField(package.duration),
      gameHour = numberField(package.game_hour),
      idle2    = numberField(package.idle2),
      idle3    = numberField(package.idle3),
      idle4    = numberField(package.idle4),
      idle5    = numberField(package.idle5),
      idle6    = numberField(package.idle6),
      idle7    = numberField(package.idle7),
      idle8    = numberField(package.idle8),
      idle9    = numberField(package.idle9),
      reset    = numberField(package.reset),
      type     = enumerations.ai.WANDER,
    }
  end,
}

local Handlers = {
  AIData = function(aiData)
    return {
      alarm = numberField(aiData.alarm),
      fight = numberField(aiData.fight),
      flee = numberField(aiData.flee),
      hello = numberField(aiData.hello),
      services = numberField(aiData.services),
    }
  end,
  AIPackages = function(aiPackages)
    if not aiPackages then return end

    local numPackages = #aiPackages
    if numPackages <= 0 then return end

    local newPackages = table.new(numPackages, 0)

    for i, aiPackage in ipairs(aiPackages) do
      newPackages[i] = assert(AIPackageHandlers[aiPackage.type](aiPackage))
    end

    return newPackages
  end,
  BipedObjects = function(biped_objects)
    local numObjects, bipedObjects = #biped_objects, nil

    if numObjects <= 0 then return end

    bipedObjects = table.new(numObjects, 0)

    for i, bipedObject in ipairs(biped_objects) do
      local malePart = OptionalRecordId(bipedObject.male_bodypart)
      local femalePart = OptionalRecordId(bipedObject.female_bodypart)

      local numFields = 1 + (malePart and 1 or 0) + (femalePart and 1 or 0)
      local hashBipedObject = table.new(0, numFields)

      hashBipedObject.bipedObjectType = numberField(Enums.BipedObjectType[bipedObject.biped_object_type])
      if malePart then hashBipedObject.malePart = malePart end
      if femalePart then hashBipedObject.femalePart = femalePart end

      bipedObjects[i] = hashBipedObject
    end
  end,
  ---@param originalEffects MagicEffect[]?
  Effects = function(originalEffects)
    if not originalEffects then return end

    local numItems = #originalEffects
    if numItems <= 0 then return end

    local newEffects = table.new(numItems, 0)

    for i, effect in ipairs(originalEffects) do
      newEffects[i] = {
        area = numberField(effect.area),
        attribute = numberField(Enums.AttributeId[effect.attribute]),
        duration = numberField(effect.duration),
        magicEffect = numberField(Enums.MagicEffectId[effect.magic_effect]),
        magnitude = {
          numberField(effect.max_magnitude),
          numberField(effect.min_magnitude)
        },
        range = numberField(Enums.EffectRange[effect.range]),
        skill = numberField(Enums.SkillId[effect.skill]),
      }
    end

    return newEffects
  end,
  ---@param originalInventory InventoryItem[]?
  ---@return InventoryItem[]? hashInventory If the original inventory exists and has items in it, returns it converted to a TDS hashmap
  Inventory = function(originalInventory)
    if not originalInventory then return end

    local numItems = #originalInventory
    if numItems <= 0 then return end

    local inventory = table.new(numItems, 0)

    for i, item in ipairs(originalInventory) do
      inventory[i] = { [MandatoryRecordId(item[2])] = item[1] }
    end

    return inventory
  end,
  ---@param originalItems LeveledItemRef[]?
  ---@return LeveledItemRef[]? hashItems If the original inventory exists and has items in it, returns it converted to a TDS hashmap
  LeveledEntry = function(originalItems)
    if not originalItems then return end

    local numItems = #originalItems
    if numItems <= 0 then return end

    local list = table.new(numItems, 0)

    for i, item in ipairs(originalItems) do
      list[i] = { [MandatoryRecordId(item[1])] = item[2] }
    end

    return list
  end,
  Spells = function(spells)
    if not spells then return end

    local numSpells = #spells
    if numSpells <= 0 then return end

    local newSpells = table.new(numSpells, 0)

    for i, spellId in ipairs(spells) do
      newSpells[i] = MandatoryRecordId(spellId)
    end

    return newSpells
  end,
  TravelDestination = function(destinations)
    if not destinations then return end

    local numDestinations = #destinations
    if numDestinations <= 0 then return end

    local newDestinations = table.new(numDestinations, 0)

    for i, travelDestination in ipairs(destinations) do
      local cell = OptionalRecordId(travelDestination.cell)
      local destRot = travelDestination.rotation
      local destPos = travelDestination.position

      local numFields = (cell and 1 or 0) + (destPos and 1 or 0) + (destRot and 1 or 0)
      if numFields == 0 then error() end

      local destination = table.new(0, numFields)

      if cell then destination.cell = cell end
      if destPos then destination.position = transform(destPos) end
      if destRot then destination.rotation = transform(destRot) end

      newDestinations[i] = destination
    end

    return newDestinations
  end
}

---@type RecordStores
local RecordStores = {
  Activator = {},
  Alchemy = {},
  Apparatus = {},
  Armor = {},
  Birthsign = {},
  Bodypart = {},
  Book = {},
  -- Cell = tds.Hash { Interior = tds.Hash(), Exterior = tds.Hash(), },
  Class = {},
  Clothing = {},
  Container = {},
  Creature = {},
  Door = {},
  Enchanting = {},
  Faction = {},
  GameSetting = {},
  GlobalVariable = {},
  Header = {},
  Ingredient = {},
  LeveledCreature = {},
  LeveledItem = {},
  Light = {},
  Lockpick = {},
  MiscItem = {},
  Npc = {},
  Probe = {},
  Race = {},
  Region = {},
  RepairItem = {},
  Script = {},
  Skill = {},
  Sound = {},
  SoundGen = {},
  Spell = {},
  StartScript = {},
  Static = {},
  Weapon = {},
}

local TypeHandlers = {

  Activator = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Activator
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.model = path(record.mesh)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Alchemy = function(record, recordId)
    local effects = Handlers.Effects(record.effects)
    local isAutoCalc = hasFlag(record.data.flags, Enums.Flags.Potion.AUTO_CALC)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Alchemy
        + (effects and 1 or 0)
        + (isAutoCalc and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if effects then object.effects = effects end
    if isAutoCalc then object.isAutoCalc = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Apparatus = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Apparatus
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.apparatusType = numberField(Enums.ApparatusType[record.data.apparatus_type])
    object.quality = numberField(record.data.quality)
    object.weight = numberField(record.data.weight)
    object.value = numberField(record.data.value)
    object.icon = path(record.icon)
    object.model = path(record.mesh)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Armor = function(record, recordId)
    local bipedObjects = Handlers.BipedObjects(record.biped_objects)
    local enchantment = OptionalRecordId(record.enchanting)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Armor
        + (bipedObjects and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (enchantment and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.armorRating = numberField(record.data.armor_rating)
    object.armorType = numberField(Enums.ArmorType[record.data.armor_type])
    object.durability = numberField(record.data.health)
    object.enchantmentValue = numberField(record.data.enchantment)
    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.weight = numberField(record.data.weight)
    object.value = numberField(record.data.value)

    if bipedObjects then object.bipedObjects = bipedObjects end
    if enchantment then object.enchantment = enchantment end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Birthsign = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local spells = Handlers.Spells(record.spells)

    local numFields = NumMandatoryFields.Birthsign
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (spells and 1 or 0)

    local object = table.new(0, numFields)

    object.description = assert(RealString(record.description))
    object.id = recordId
    object.name = assert(RealString(record.name))
    object.texture = path(record.texture)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if spells then object.spells = spells end

    return object
  end,

  Bodypart = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local isFemale = hasFlag(record.data.flags, Enums.Flags.BodyPart.FEMALE)
    local isVampire = record.data.vampire == true
    local isUnplayable = hasFlag(record.data.flags, Enums.Flags.BodyPart.NOT_PLAYABLE)
    local race = OptionalRecordId(record.race)

    local numFields = NumMandatoryFields.Bodypart
        + (isDeleted and 1 or 0)
        + (isFemale and 1 or 0)
        + (isModified and 1 or 0)
        + (isVampire and 1 or 0)
        + (isUnplayable and 1 or 0)
        + (race and 1 or 0)

    local object = table.new(0, numFields)

    object.bodypartType = numberField(Enums.BodypartType[record.data.bodypart_type])
    object.id = MandatoryRecordId(recordId)
    object.model = path(record.mesh)
    object.part = numberField(Enums.BodypartId[record.data.part])

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isFemale then object.isFemale = true end
    if isVampire then object.isVampire = true end
    if isUnplayable then object.isUnplayable = true end
    if race then object.race = race end

    return object
  end,

  Book = function(record, recordId)
    local enchantment = OptionalRecordId(record.enchanting)
    local isDeleted, isModified = objectFlags(record)
    local isScroll = Enums.BookType[record.data.book_type] == Enums.BookType.Book
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)
    local text = RealString(record.text)

    local numFields = NumMandatoryFields.Book
        + (enchantment and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isScroll and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)
        + (text and 1 or 0)

    local object = table.new(0, numFields)

    object.enchantmentValue = numberField(record.data.enchantment)
    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.skill = numberField(Enums.SkillId[record.data.skill])
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if enchantment then object.enchantment = enchantment end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isScroll then object.isBook = true end
    if name then object.name = name end
    if script then object.script = script end
    if text then object.text = text end

    return object
  end,

  Cell = function(record, _, currentPluginName)
    local isInterior = hasFlag(record.data.flags, Enums.Flags.Cell.IS_INTERIOR)
    local gridX, gridY = numberField(record.data.grid[1]), numberField(record.data.grid[2])

    local cellId, cellType
    if isInterior and LoadCellTypes.Interior then
      cellId = MandatoryRecordId(record.name)

      cellType = 'Interior'
    elseif not isInterior and LoadCellTypes.Exterior then
      cellId = ('%d, %d'):format(gridX, gridY)

      cellType = 'Exterior'
    else
      return
    end

    local existingCell = RecordStores.Cell[cellType][cellId]
    if not existingCell then LoadedRecords = LoadedRecords + 1 end

    local cell = existingCell or tds.Hash()
    cell.id = cell.id or cellId

    if isInterior then
      cell.isInterior = true
    else
      cell.gridX, cell.gridY = gridX, gridY
    end

    local cellName = RealString(record.name)
    if cellName then cell.name = cellName end

    if record.atmosphere_data then
      local atmo = record.atmosphere_data
      cell.fogDensity = atmo.fog_density

      cell.ambientColor = tds.Vec(
        numberField(tostring(atmo.ambient_color[1])),
        numberField(tostring(atmo.ambient_color[2])),
        numberField(tostring(atmo.ambient_color[3])),
        numberField(tostring(atmo.ambient_color[4]))
      )

      cell.fogColor = tds.Vec(
        numberField(tostring(atmo.fog_color[1])),
        numberField(tostring(atmo.fog_color[2])),
        numberField(tostring(atmo.fog_color[3])),
        numberField(tostring(atmo.fog_color[4]))
      )

      cell.sunlightColor = tds.Vec(
        numberField(tostring(atmo.sunlight_color[1])),
        numberField(tostring(atmo.sunlight_color[2])),
        numberField(tostring(atmo.sunlight_color[3])),
        numberField(tostring(atmo.sunlight_color[4]))
      )
    end

    local maybeRegion = OptionalRecordId(record.region)
    if maybeRegion then cell.region = maybeRegion end

    if record.water_height then
      cell.waterHeight = numberField(tostring(record.water_height))
    end

    --- One plugin might change certain cell flags, so,
    --- unfortunately to account for this possibility some parameters
    --- of the cell type are not optional
    cell.hasWater = hasFlag(record.data.flags, Enums.Flags.Cell.HAS_WATER)
    cell.isFakeExterior = hasFlag(record.data.flags, Enums.Flags.Cell.BEHAVES_LIKE_EXTERIOR)
    cell.restingIsIllegal = hasFlag(record.data.flags, Enums.Flags.Cell.RESTING_IS_ILLEGAL)

    objectFlags(record, cell)

    local references = record.references
    cell.references = cell.references or tds.Hash()

    for _, referenceData in ipairs(references) do
      -- print(i, referenceData)
      local masterIndex, referenceIndex =
          numberField(tostring(referenceData.mast_index)), numberField(tostring(referenceData.refr_index))

      local LiveRefIndex = PluginLoadIndex

      local referenceKey = ('%d-%d'):format(LiveRefIndex, referenceIndex)

      if masterIndex == 0 then
        local hashRef = tds.Hash()

        hashRef.id = referenceKey
        hashRef.recordId = MandatoryRecordId(referenceData.id)

        hashRef.transform = tds.Hash()
        hashRef.transform.position = tds.Vec(
          numberField(tostring(referenceData.translation[1])),
          numberField(tostring(referenceData.translation[2])),
          numberField(tostring(referenceData.translation[3]))
        )
        hashRef.transform.rotation = tds.Vec(
          numberField(tostring(referenceData.rotation[1])),
          numberField(tostring(referenceData.rotation[2])),
          numberField(tostring(referenceData.rotation[3]))
        )

        cell.references[referenceKey] = hashRef
      end
    end

    -- print(cell)
    RecordStores.Cell[cellType][cellId] = cell
  end,

  Class = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local isPlayable = hasFlag(record.data.flags, Enums.Flags.Class.PLAYABLE)

    local numFields = NumMandatoryFields.Class
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isPlayable and 1 or 0)

    local object = table.new(0, numFields)

    object.attribute = {
      numberField(Enums.AttributeId[record.data.attribute1]),
      numberField(Enums.AttributeId[record.data.attribute2])
    }

    object.id = recordId
    object.major = {
      numberField(Enums.SkillId[record.data.major1]),
      numberField(Enums.SkillId[record.data.major2]),
      numberField(Enums.SkillId[record.data.major3]),
      numberField(Enums.SkillId[record.data.major4]),
      numberField(Enums.SkillId[record.data.major5])
    }

    object.minor = {
      numberField(Enums.SkillId[record.data.minor1]),
      numberField(Enums.SkillId[record.data.minor2]),
      numberField(Enums.SkillId[record.data.minor3]),
      numberField(Enums.SkillId[record.data.minor4]),
      numberField(Enums.SkillId[record.data.minor5])
    }

    object.services = numberField(record.data.services)
    object.specialization = numberField(Enums.Specialization[record.data.specialization])

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isPlayable then object.isPlayable = true end

    return object
  end,

  Clothing = function(record, recordId)
    local bipedObjects = Handlers.BipedObjects(record.biped_objects)
    local enchantment = OptionalRecordId(record.enchanting)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Clothing
        + (bipedObjects and 1 or 0)
        + (enchantment and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.clothingType = numberField(Enums.ClothingType[record.data.clothing_type])
    object.enchantmentValue = numberField(record.data.enchantment)
    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.weight = numberField(record.data.weight)
    object.value = numberField(record.data.value)

    if bipedObjects then object.parts = bipedObjects end
    if enchantment then object.enchantment = enchantment end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if script then object.script = script end
    if name then object.name = name end

    return object
  end,

  Container = function(record, recordId)
    local inventory = Handlers.Inventory(record.inventory)
    local isDeleted, isModified = objectFlags(record)
    local isOrganic = hasFlag(record.container_flags, Enums.Flags.Container.ORGANIC)
    local isRespawning = hasFlag(record.container_flags, Enums.Flags.Container.RESPAWNS)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Container
        + (inventory and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isOrganic and 1 or 0)
        + (isRespawning and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.capacity = numberField(record.encumbrance)
    object.id = recordId
    object.model = path(record.mesh)

    if inventory then object.inventory = inventory end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isOrganic then object.isOrganic = true end
    if isRespawning then object.isRespawning = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Creature = function(record, recordId)
    local aiPackages = Handlers.AIPackages(record.ai_packages)
    local baseGold = numberField(record.data.gold)
    local canFly = hasFlag(record.creature_flags, Enums.Flags.Creature.FLIES)
    local canSwim = hasFlag(record.creature_flags, Enums.Flags.Creature.SWIMS)
    local canWalk = hasFlag(record.creature_flags, Enums.Flags.Creature.WALKS)
    local creatureScale = tonumber(record.scale)
    local destinations = Handlers.TravelDestination(record.travel_destinations)
    local inventory = Handlers.Inventory(record.inventory)
    local isBiped = hasFlag(record.creature_flags, Enums.Flags.Creature.BIPED)
    local isDeleted, isModified = objectFlags(record)
    local isEssential = hasFlag(record.creature_flags, Enums.Flags.Creature.ESSENTIAL)
    local isRespawning = hasFlag(record.creature_flags, Enums.Flags.Creature.RESPAWN)
    local mwScript = OptionalRecordId(record.script)
    local name = RealString(record.name)
    local sound = OptionalRecordId(record.sound)
    local spells = Handlers.Spells(record.spells)
    local usesWeapons = hasFlag(record.creature_flags, Enums.Flags.Creature.WEAPON_AND_SHIELD)

    local numFields = NumMandatoryFields.Creature
        + (aiPackages and 1 or 0)
        + (baseGold > 0 and 1 or 0)
        + (canFly and 1 or 0)
        + (canSwim and 1 or 0)
        + (canWalk and 1 or 0)
        + (creatureScale and creatureScale ~= 1 and 1 or 0)
        + (destinations and 1 or 0)
        + (inventory and 1 or 0)
        + (isBiped and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isEssential and 1 or 0)
        + (isRespawning and 1 or 0)
        + (mwScript and 1 or 0)
        + (name and 1 or 0)
        + (sound and 1 or 0)
        + (spells and 1 or 0)
        + (usesWeapons and 1 or 0)

    local object = table.new(0, numFields)

    object.AIData = Handlers.AIData(record.ai_data)
    object.agility = numberField(record.data.agility)
    object.attack = {
      numberField(record.data.attack1[1]),
      numberField(record.data.attack1[2]),
      numberField(record.data.attack2[1]),
      numberField(record.data.attack2[2]),
      numberField(record.data.attack3[1]),
      numberField(record.data.attack3[2]),
    }
    object.bloodType = numberField(record.blood_type)
    object.creatureType = numberField(Enums.CreatureType[record.data.creature_type])
    object.endurance = numberField(record.data.endurance)
    object.fatigue = numberField(record.data.fatigue)
    object.health = numberField(record.data.health)
    object.id = MandatoryRecordId(recordId)
    object.intelligence = numberField(record.data.intelligence)
    object.level = numberField(record.data.level)
    object.luck = numberField(record.data.luck)
    object.magicAbility = numberField(record.data.magic)
    object.magicka = numberField(record.data.magicka)
    object.model = path(record.mesh)
    object.personality = numberField(record.data.personality)
    object.soulValue = numberField(record.data.soul)
    object.speed = numberField(record.data.speed)
    object.stealthAbility = numberField(record.data.stealth)
    object.strength = numberField(record.data.strength)
    object.willpower = numberField(record.data.willpower)

    if aiPackages then object.AIPackages = aiPackages end
    if baseGold > 0 then object.baseGold = baseGold end
    if canFly then object.canFly = true end
    if canSwim then object.canSwim = true end
    if canWalk then object.canWalk = true end
    if creatureScale and creatureScale ~= 1 then object.scale = creatureScale end
    if destinations then object.travelDestinations = destinations end
    if inventory then object.inventory = inventory end
    if isBiped then object.isBiped = true end
    if isDeleted then object.isDeleted = true end
    if isEssential then object.isEssential = true end
    if isModified then object.isModified = true end
    if isRespawning then object.isRespawning = true end
    if mwScript then object.script = mwScript end
    if name then object.name = name end
    if sound then object.sound = sound end
    if spells then object.spells = spells end
    if usesWeapons then object.usesWeapons = true end

    return object
  end,

  Door = function(record, recordId)
    local closeSound = OptionalRecordId(record.close_sound)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local openSound = OptionalRecordId(record.open_sound)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Door
        + (closeSound and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (openSound and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.model = path(record.mesh)

    if closeSound then object.closeSound = closeSound end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if openSound then object.openSound = openSound end
    if script then object.script = script end

    return object
  end,

  Enchanting = function(record, recordId)
    local effects = Handlers.Effects(record.effects)
    local isAutoCalc = hasFlag(record.data.flags, Enums.Flags.Enchant.AUTO_CALC)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.Enchanting
        + (effects and 1 or 0)
        + (isAutoCalc and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.cost = numberField(record.data.cost)
    object.enchantType = numberField(Enums.EnchantType[record.data.enchant_type])
    object.id = recordId
    object.maxCharge = numberField(record.data.max_charge)

    --- Surely this has some implication for parsing the effect array?
    if isAutoCalc then object.isAutoCalc = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if effects then object.effects = effects end

    return object
  end,

  Faction = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local isHidden = hasFlag(record.data.flags, Enums.Flags.Faction.HIDDEN_FROM_PC)
    local name = RealString(record.name)

    local numRanks, rankNames = #record.rank_names, nil
    if numRanks > 0 then
      rankNames = table.new(numRanks, 0)

      for i, rankName in ipairs(record.rank_names) do
        rankNames[i] = assert(RealString(rankName))
      end
    end

    local numReactions, reactions = #record.reactions, nil
    if numReactions > 0 then
      reactions = table.new(numReactions, 0)

      for i, reactionData in ipairs(record.reactions) do
        reactions[i] = { [MandatoryRecordId(reactionData.faction)] = numberField(reactionData.reaction) }
      end
    end

    local numFields = NumMandatoryFields.Faction
        + (isDeleted and 1 or 0)
        + (isHidden and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (rankNames and 1 or 0)
        + (reactions and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.favoredAttributes = {
      numberField(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[1]):titleCase()]),
      numberField(Enums.AttributeId[MandatoryRecordId(record.data.favored_attributes[2]):titleCase()])
    }
    object.favoredSkills = {
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[1]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[2]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[3]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[4]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[5]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[6]):titleCase()]),
      numberField(Enums.SkillId[MandatoryRecordId(record.data.favored_skills[7]):titleCase()])
    }

    local numReqs = #record.data.requirements
    assert(numReqs == 10)

    object.requirements = table.new(10, 0)
    for i, requirement in ipairs(record.data.requirements) do
      local attributes, numAttributes = nil, #requirement.attributes
      if numAttributes > 0 then
        attributes = table.new(numAttributes, 0)

        for j, attribute in ipairs(requirement.attributes) do
          attributes[j] = numberField(tostring(attribute))
        end
      end

      local numReqFields = 3 + (attributes and 1 or 0)
      local objectRequirement = table.new(numReqFields, 0)

      objectRequirement.favoredSkill = numberField(requirement.favored_skill)
      objectRequirement.primarySkill = numberField(requirement.primary_skill)
      objectRequirement.reputation = numberField(requirement.reputation)
      if attributes then objectRequirement.attributes = attributes end

      object.requirements[i] = objectRequirement
    end

    if isDeleted then object.isDeleted = true end
    if isHidden then object.isHidden = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if rankNames then object.rankNames = rankNames end
    if reactions then object.reactions = reactions end

    return object
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

  Header = function(record, _, currentPluginName)
    local masters = record.masters
    local masterLength = #masters
    if masterLength == 0 then return end

    local masterList = table.new(masterLength, 0)

    for i, masterInfo in ipairs(masters) do
      masterList[i] = assert(masterInfo[1]:lower())
    end

    RecordStores.Header[currentPluginName] = masterList
  end,

  Ingredient = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Ingredient
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)
    object.effects = {
      numberField(Enums.MagicEffectId[RealString(record.data.effects[1])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[2])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[3])]),
      numberField(Enums.MagicEffectId[RealString(record.data.effects[4])])
    }
    object.skills = {
      numberField(Enums.SkillId[RealString(record.data.skills[1])]),
      numberField(Enums.SkillId[RealString(record.data.skills[2])]),
      numberField(Enums.SkillId[RealString(record.data.skills[3])]),
      numberField(Enums.SkillId[RealString(record.data.skills[4])])
    }
    object.attributes = {
      numberField(Enums.AttributeId[RealString(record.data.attributes[1])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[2])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[3])]),
      numberField(Enums.AttributeId[RealString(record.data.attributes[4])])
    }

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  LeveledCreature = function(record, recordId)
    local calculateFromAllLevels = hasFlag(
      record.leveled_creature_flags,
      Enums.Flags.LeveledCreature.CALCULATE_FROM_ALL_LEVELS
    )
    local creatures = Handlers.LeveledEntry(record.creatures)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.LeveledCreature
        + (calculateFromAllLevels and 1 or 0)
        + (creatures and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.chanceNone = numberField(record.chance_none)
    object.id = recordId

    if calculateFromAllLevels then object.calculateFromAllLevels = true end
    if creatures then object.creatures = creatures end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  LeveledItem = function(record, recordId)
    local calculateForEachItem = hasFlag(record.leveled_item_flags, Enums.Flags.LeveledItem.CALCULATE_FOR_EACH_ITEM)
    local calculateFromAllLevels = hasFlag(record.leveled_item_flags, Enums.Flags.LeveledItem.CALCULATE_FROM_ALL_LEVELS)
    local isDeleted, isModified = objectFlags(record)
    local items = Handlers.LeveledEntry(record.items)

    local numFields = NumMandatoryFields.LeveledItem
        + (calculateForEachItem and 1 or 0)
        + (calculateFromAllLevels and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (items and 1 or 0)

    local object = table.new(0, numFields)

    object.chanceNone = numberField(record.chance_none)
    object.id = recordId

    if calculateForEachItem then object.calculateForEachItem = true end
    if calculateFromAllLevels then object.calculateFromAllLevels = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if items then object.items = items end

    return object
  end,

  Light = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)
    local sound = OptionalRecordId(record.sound)

    local numFields = NumMandatoryFields.Lockpick
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)
        + (sound and 1 or 0)

    local object = table.new(0, numFields)

    object.color = {
      numberField(tostring(record.data.color[1])),
      numberField(tostring(record.data.color[2])),
      numberField(tostring(record.data.color[3]))
    }
    object.icon = path(record.icon)
    object.id = recordId
    object.lightFlags = numberField(record.data.flags)
    object.model = path(record.mesh)
    object.radius = numberField(record.data.radius)
    object.time = numberField(record.data.value)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end
    if sound then object.sound = sound end

    return object
  end,

  Lockpick = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local script, name = OptionalRecordId(record.script), RealString(record.name)

    local numFields = NumMandatoryFields.Lockpick
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.quality = numberField(record.data.quality)
    object.uses = numberField(record.data.uses)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if script then object.script = script end
    if name then object.name = name end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  MiscItem = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.MiscItem
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = recordId
    object.isKey = hasFlag(record.data.flags, Enums.Flags.Misc.KEY)
    object.miscFlags = numberField(record.data.flags)
    object.model = path(record.mesh)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if script then object.script = script end

    return object
  end,

  Npc = function(record, recordId)
    local aiPackages = Handlers.AIPackages(record.ai_packages)
    local baseGold = numberField(record.data.gold)
    local destinations = Handlers.TravelDestination(record.travel_destinations)
    local faction = OptionalRecordId(record.faction)
    local hair = OptionalRecordId(record.hair)
    local inventory = Handlers.Inventory(record.inventory)
    local isAutoCalc = hasFlag(record.npc_flags, Enums.Flags.NPC.AUTO_CALCULATE)
    local isDeleted, isModified = objectFlags(record)
    local isEssential = hasFlag(record.npc_flags, Enums.Flags.NPC.ESSENTIAL)
    local isFemale = hasFlag(record.npc_flags, Enums.Flags.NPC.FEMALE)
    local isRespawning = hasFlag(record.npc_flags, Enums.Flags.NPC.RESPAWN)
    local mwScript = OptionalRecordId(record.script)
    local name = RealString(record.name)
    local spells = Handlers.Spells(record.spells)

    local stats
    if isAutoCalc and record.data.stats then
      assert(#record.data.stats.attributes == 8)
      assert(#record.data.stats.skills == 27)

      stats = {
        attributes = {
          numberField(tostring(record.data.stats.attributes[1])),
          numberField(tostring(record.data.stats.attributes[2])),
          numberField(tostring(record.data.stats.attributes[3])),
          numberField(tostring(record.data.stats.attributes[4])),
          numberField(tostring(record.data.stats.attributes[5])),
          numberField(tostring(record.data.stats.attributes[6])),
          numberField(tostring(record.data.stats.attributes[7])),
          numberField(tostring(record.data.stats.attributes[8]))
        },
        fatigue = record.data.stats.fatigue,
        health = record.data.stats.health,
        magicka = record.data.stats.magicka,
        skills = {
          numberField(tostring(record.data.stats.skills[1])),
          numberField(tostring(record.data.stats.skills[2])),
          numberField(tostring(record.data.stats.skills[3])),
          numberField(tostring(record.data.stats.skills[4])),
          numberField(tostring(record.data.stats.skills[5])),
          numberField(tostring(record.data.stats.skills[6])),
          numberField(tostring(record.data.stats.skills[7])),
          numberField(tostring(record.data.stats.skills[8])),
          numberField(tostring(record.data.stats.skills[9])),
          numberField(tostring(record.data.stats.skills[10])),
          numberField(tostring(record.data.stats.skills[11])),
          numberField(tostring(record.data.stats.skills[12])),
          numberField(tostring(record.data.stats.skills[13])),
          numberField(tostring(record.data.stats.skills[14])),
          numberField(tostring(record.data.stats.skills[15])),
          numberField(tostring(record.data.stats.skills[16])),
          numberField(tostring(record.data.stats.skills[17])),
          numberField(tostring(record.data.stats.skills[18])),
          numberField(tostring(record.data.stats.skills[19])),
          numberField(tostring(record.data.stats.skills[20])),
          numberField(tostring(record.data.stats.skills[21])),
          numberField(tostring(record.data.stats.skills[22])),
          numberField(tostring(record.data.stats.skills[23])),
          numberField(tostring(record.data.stats.skills[24])),
          numberField(tostring(record.data.stats.skills[25])),
          numberField(tostring(record.data.stats.skills[26])),
          numberField(tostring(record.data.stats.skills[27]))
        },
      }
    end

    local numFields = NumMandatoryFields.Npc
        + (aiPackages and 1 or 0)
        + (baseGold > 0 and 1 or 0)
        + (destinations and 1 or 0)
        + (faction and 1 or 0)
        + (hair and 1 or 0)
        + (inventory and 1 or 0)
        + (isAutoCalc and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isEssential and 1 or 0)
        + (isFemale and 1 or 0)
        + (isModified and 1 or 0)
        + (isRespawning and 1 or 0)
        + (mwScript and 1 or 0)
        + (name and 1 or 0)
        + (spells and 1 or 0)
        + (stats and 1 or 0)

    local object = table.new(0, numFields)

    object.AIData = Handlers.AIData(record.ai_data)
    object.bloodType = numberField(record.blood_type)
    object.class = MandatoryRecordId(record.class)
    object.disposition = numberField(record.data.disposition)
    object.head = MandatoryRecordId(record.head)
    object.id = recordId
    object.level = numberField(record.data.level)
    object.model = path(record.mesh)
    object.race = MandatoryRecordId(record.race)
    object.rank = numberField(record.data.rank)
    object.reputation = numberField(record.data.reputation)

    if aiPackages then object.AIPackages = aiPackages end
    if baseGold > 0 then object.baseGold = baseGold end
    if destinations then object.travelDestinations = destinations end
    if faction then object.faction = faction end
    if hair then object.hair = hair end
    if inventory then object.inventory = inventory end
    if isAutoCalc then object.isAutoCalc = true end
    if isDeleted then object.isDeleted = true end
    if isEssential then object.isEssential = true end
    if isFemale then object.isFemale = true end
    if isModified then object.isModified = true end
    if isRespawning then object.isRespawning = true end
    if mwScript then object.script = mwScript end
    if name then object.name = name end
    if spells then object.spells = spells end
    if stats then object.stats = stats end

    return object
  end,

  Probe = function(record, recordId)
    local script, name = OptionalRecordId(record.script), RealString(record.name)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.Probe
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.quality = numberField(record.data.quality)
    object.uses = numberField(record.data.uses)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if script then object.script = script end
    if name then object.name = name end

    return object
  end,

  Race = function(record, recordId)
    local description = RealString(record.description)
    local isBeast = hasFlag(record.data.flags, Enums.Flags.Race.BEAST_RACE)
    local isDeleted, isModified = objectFlags(record)
    local isPlayable = hasFlag(record.data.flags, Enums.Flags.Race.PLAYABLE)
    local name = RealString(record.name)
    local spells = Handlers.Spells(record.spells)

    local numFields = NumMandatoryFields.Race
        + (description and 1 or 0)
        + (isBeast and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isPlayable and 1 or 0)
        + (name and 1 or 0)
        + (spells and 1 or 0)

    local object = table.new(0, numFields)

    object.agility = {
      numberField(tostring(record.data.agility[1])),
      numberField(tostring(record.data.agility[2]))
    }

    object.endurance = {
      numberField(tostring(record.data.endurance[1])),
      numberField(tostring(record.data.endurance[2]))
    }

    object.height = {
      numberField(tostring(record.data.height[1])),
      numberField(tostring(record.data.height[2]))
    }

    object.id = recordId

    object.intelligence = {
      numberField(tostring(record.data.intelligence[1])),
      numberField(tostring(record.data.intelligence[2]))
    }

    object.luck = {
      numberField(tostring(record.data.luck[1])),
      numberField(tostring(record.data.luck[2]))
    }

    object.personality = {
      numberField(tostring(record.data.personality[1])),
      numberField(tostring(record.data.personality[2]))
    }

    object.speed = {
      numberField(tostring(record.data.speed[1])),
      numberField(tostring(record.data.speed[2]))
    }

    object.strength = {
      numberField(tostring(record.data.strength[1])),
      numberField(tostring(record.data.strength[2]))
    }

    object.weight = {
      numberField(tostring(record.data.weight[1])),
      numberField(tostring(record.data.weight[2]))
    }

    object.willpower = {
      numberField(tostring(record.data.willpower[1])),
      numberField(tostring(record.data.willpower[2]))
    }

    object.bonuses = {
      bonus1 = numberField(record.data.skill_bonuses.bonus_0),
      bonus2 = numberField(record.data.skill_bonuses.bonus_1),
      bonus3 = numberField(record.data.skill_bonuses.bonus_2),
      bonus4 = numberField(record.data.skill_bonuses.bonus_3),
      bonus5 = numberField(record.data.skill_bonuses.bonus_4),
      bonus6 = numberField(record.data.skill_bonuses.bonus_5),
      bonus7 = numberField(record.data.skill_bonuses.bonus_6),
      skill1 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_0]),
      skill2 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_1]),
      skill3 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_2]),
      skill4 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_3]),
      skill5 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_4]),
      skill6 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_5]),
      skill7 = numberField(Enums.SkillId[record.data.skill_bonuses.skill_6]),
    }

    if description then object.description = description end
    if isBeast then object.isBeastRace = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isPlayable then object.isPlayable = true end
    if name then object.name = name end
    if spells then object.spells = spells end

    return object
  end,

  Region = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local name                  = RealString(record.name)
    local sleepCreature         = OptionalRecordId(record.sleep_creature)
    local numSounds, sounds     = #record.sounds, nil
    if numSounds > 0 then
      sounds = table.new(numSounds, 0)

      for i, soundData in ipairs(record.sounds) do
        sounds[i] = { [MandatoryRecordId(soundData[1])] = numberField(soundData[2]) }
      end
    end

    local numFields       = NumMandatoryFields.Region
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (sleepCreature and 1 or 0)
        + (sounds and 1 or 0)

    local object          = table.new(0, numFields)
    local chances         = record.weather_chances

    object.ashChance      = numberField(chances.ash)
    object.blightChance   = numberField(chances.blight)
    object.blizzardChance = numberField(chances.blizzard)
    object.clearChance    = numberField(chances.clear)
    object.cloudyChance   = numberField(chances.cloudy)
    object.foggyChance    = numberField(chances.foggy)
    object.id             = recordId

    object.mapColor       = table.new(4, 0)
    for i = 1, 4 do
      object.mapColor[i] = numberField(tostring(record.map_color[i]))
    end

    object.overcastChance = numberField(chances.overcast)
    object.rainChance     = numberField(chances.rain)
    object.snowChance     = numberField(chances.snow)
    object.thunderChance  = numberField(chances.thunder)

    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if name then object.name = name end
    if sleepCreature then object.sleepCreature = sleepCreature end
    if sounds then object.sounds = sounds end

    return object
  end,

  RepairItem = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.RepairItem
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.icon = path(record.icon)
    object.id = MandatoryRecordId(recordId)
    object.model = path(record.mesh)
    object.uses = numberField(record.data.uses)
    object.value = numberField(record.data.value)
    object.weight = numberField(record.data.weight)
    object.quality = numberField(record.data.quality)

    if name then object.name = name end
    if script then object.script = script end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Script = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.Script
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.text = assert(record.text:lower())
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Skill = function(record, _)
    local isDeleted, isModified = objectFlags(record)

    local description = RealString(record.description)

    local numFields = NumMandatoryFields.Skill
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (description and 1 or 0)

    local object = table.new(0, numFields)

    object.actions = table.new(4, 0)

    for i = 1, 4 do
      object.actions[i] = numberField(tostring(record.data.actions[i]))
    end

    object.governingAttribute = numberField(record.data.governing_attribute)
    object.id = MandatoryRecordId(record.skill_id)
    object.specialization = numberField(record.data.specialization)

    object.skillId = numberField(Enums.SkillId[RealString(record.skill_id)])
    if description then object.description = description end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Sound = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.Sound
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.path = path(record.sound_path)
    object.range = {
      assert(tostring(record.data.range[1])),
      assert(tostring(record.data.range[2])),
    }
    object.volume = numberField(record.data.volume)
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  SoundGen = function(record, recordId)
    assert(recordId and recordId ~= '')

    local isDeleted, isModified = objectFlags(record)
    local creature = OptionalRecordId(record.creature)

    local numFields = NumMandatoryFields.SoundGen
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (creature and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.sound = MandatoryRecordId(record.sound)
    object.soundGenType = numberField(Enums.SoundGenType[RealString(record.sound_gen_type)])

    if creature then object.creature = creature end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Spell = function(record, recordId)
    local alwaysSucceeds = hasFlag(record.data.flags, Enums.Flags.Spell.ALWAYS_SUCCEEDS)
    local effects = Handlers.Effects(record.effects)
    local isAutoCalc = hasFlag(record.data.flags, Enums.Flags.Spell.AUTO_CALCULATE)
    local isDeleted, isModified = objectFlags(record)
    local isStartSpell = hasFlag(record.data.flags, Enums.Flags.Spell.PC_START_SPELL)
    local name = RealString(record.name)

    local numFields = NumMandatoryFields.Spell
        + (alwaysSucceeds and 1 or 0)
        + (effects and 1 or 0)
        + (isAutoCalc and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isStartSpell and 1 or 0)
        + (name and 1 or 0)

    local object = table.new(0, numFields)

    object.cost = numberField(record.data.cost)
    object.id = MandatoryRecordId(recordId)

    if alwaysSucceeds then object.alwaysSucceeds = true end
    if effects then object.effects = effects end
    if isAutoCalc then object.isAutoCalc = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isStartSpell then object.isStartSpell = true end
    if name then object.name = name end

    return object
  end,

  StartScript = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.StartScript
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.script = MandatoryRecordId(record.script)
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Static = function(record, recordId)
    local isDeleted, isModified = objectFlags(record)

    local numFields = NumMandatoryFields.Static
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)

    local object = table.new(0, numFields)

    object.id = recordId
    object.model = path(record.mesh)
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end

    return object
  end,

  Weapon = function(record, recordId)
    local enchantment = OptionalRecordId(record.enchanting)
    local ignoresNormalResistance = hasFlag(record.data.flags, Enums.Flags.Weapon.IGNORES_NORMAL_WEAPON_RESISTANCE)
    local isDeleted, isModified = objectFlags(record)
    local isSilver = hasFlag(record.data.flags, Enums.Flags.Weapon.SILVER)
    local name = RealString(record.name)
    local script = OptionalRecordId(record.script)

    local numFields = NumMandatoryFields.Weapon
        + (enchantment and 1 or 0)
        + (ignoresNormalResistance and 1 or 0)
        + (isDeleted and 1 or 0)
        + (isModified and 1 or 0)
        + (isSilver and 1 or 0)
        + (name and 1 or 0)
        + (script and 1 or 0)

    local object = table.new(0, numFields)

    object.chop = { numberField(record.data.chop_min), numberField(record.data.chop_max), }
    object.durability = numberField(record.data.health)
    object.enchantmentValue = numberField(record.data.enchantment)
    object.icon = path(record.icon)
    object.id = recordId
    object.model = path(record.mesh)
    object.reach = numberField(record.data.reach)
    object.slash = { numberField(record.data.slash_min), numberField(record.data.slash_max), }
    object.speed = numberField(record.data.speed)
    object.thrust = { numberField(record.data.thrust_min), numberField(record.data.thrust_max), }
    object.value = numberField(record.data.value)
    object.weaponType = numberField(Enums.WeaponType[RealString(record.data.weapon_type)])
    object.weight = numberField(record.data.weight)

    if ignoresNormalResistance then object.ignoresNormalResistance = true end
    if isDeleted then object.isDeleted = true end
    if isModified then object.isModified = true end
    if isSilver then object.isSilver = true end
    if name then object.name = name end
    if script then object.script = script end
    if enchantment then object.enchantment = enchantment end

    return object
  end,
}

--- Certain record types share a global namespace
--- This is used to check if the id is in the shared namespace or not
local ReferenceableTypes = {
  Activator = true,
  Apparatus = true,
  Alchemy = true,
  Armor = true,
  Birthsign = true,
  Bodypart = true,
  Book = true,
  Clothing = true,
  Container = true,
  Creature = true,
  Door = true,
  Ingredient = true,
  Light = true,
  Lockpick = true,
  MiscItem = true,
  Npc = true,
  Probe = true,
  RepairItem = true,
  Static = true,
  Weapon = true,
  -- These apparently are an exception to the placeable rule
  -- :todd:
  Enchanting = true,
  Spell = true,
}

local FieldsForTypesWithoutIds = {
  Skill = 'skill_id',
}

--- ID Usage rules are slightly more complex than
--- being a simple typed hashmap.
--- Referenceable types are considered to be things that
--- can be placed in the game world -> books, weapons, people, monsters, doors, etc.
--- We don't really know why enchantments and spells share
--- this namespace, but, TESCS will complain about it.
--- Non-referenceable types are just simple hashmaps.
--- However, cells are an exception as N plugins may write to the same
--- number of cell entries, so typical ID usage rules don't apply at all.
--- Sourced from: https://github.com/Greatness7/merge_to_master/blob/main/src/types/plugin.rs#L82
---@param recordId RecordId?
---@param object table<string, any>
local function idIsFree(recordId, object)
  local recordType = object.type

  assert(recordType)

  -- We don't necessarily save everything, so skip object generation for those
  -- Also there are some dumb edge cases where records have ids defined
  -- But they are empty, we're just gonna reject those because they're stupid
  if object.id == '' or not RecordStores[recordType] then return false end

  --- Cells are an exception to this rule
  --- As they must merge, so the id is always considered 'free'
  --- Headers are also unique as they're expected not to be duplicated.
  if recordType == 'Cell' or recordType == 'Header' then
    return true
  end

  if not recordId then
    recordId = OptionalRecordId(object[FieldsForTypesWithoutIds[recordType]]) or error(tostring(object))
  end

  local recordOfSameTypeAndIdExists = RecordStores[recordType][recordId] ~= nil

  if not ReferenceableTypes[recordType] then
    if not recordOfSameTypeAndIdExists then LoadedRecords = LoadedRecords + 1 end
    return not recordOfSameTypeAndIdExists
  end

  if recordOfSameTypeAndIdExists then return false end

  --- For referenceable types, if another record of the same type
  --- And id does not exist, ensure that no other placeable type bears the same id
  for checkedRecordType in pairs(ReferenceableTypes) do
    if RecordStores[checkedRecordType][recordId] ~= nil then return false end
  end

  LoadedRecords = LoadedRecords + 1
  return true
end

---@return integer numRecords
local function createRecordStores()
  LoadedRecords = 0

  local _, numPlugins = nil, #loadOrder
  for i = numPlugins, 1, -1 do
    PluginLoadIndex = i
    local pluginName = loadOrder[i]
    local pluginPath = PluginPathFormatter:format(pluginName)

    if not lfs.attributes(pluginPath) then
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

    local lowerPluginName = pluginName:lower()

    for j, object in ipairs(tes3.load_plugin(pluginPath).objects) do
      local recordId

      if object.id then
        recordId = ffi.string(object.id:lower(), #object.id)
      end

      if idIsFree(recordId, object) then
        local recordStore, typeHandler = RecordStores[object.type], TypeHandlers[object.type]

        if recordStore and typeHandler then
          local resultRecord = typeHandler(object, recordId, lowerPluginName)

          if resultRecord then
            recordStore[recordId or resultRecord.id] = resultRecord
          elseif object.type ~= 'Cell' and LogSkippedRecords then
            tes3mp.LogAppend(
              enumerations.log.WARN,
              ('Skipping record at index %d of plugin %s: %s')
              :format(j, pluginName, recordId or tostring(object))
            )
          end
        end
      end
    end
  end

  return LoadedRecords
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
        local length = 0
        if k ~= 'Cell' then
          length = #v
        else
          length = #v.Exterior + #v.Interior
        end

        logStr = logStr .. ('%s %s Records loaded.\n'):format(length, k)
      end

      tes3mp.LogAppend(enumerations.log.INFO, logStr)
    end
  }
}
