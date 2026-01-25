---@alias ExactRefIdSpellList table<RecordId, RecordId[]>
---@alias FuzzyRefIdSpellList table<string, RecordId[]>
---@alias UniqueIndexSpellList table<UniqueIndex, RecordId[]>

---@class TES3MPMagicEffect
---@field id MagicEffectId
---@field magnitude number
---@field duration number
---@field timeLeft number
---@field arg AttributeId|SkillId

---@class CustomSpellRecord
---@field displayName string
---@field stackingState boolean
---@field effects TES3MPMagicEffect[]

---@class AddActorSpellConfig
---@field forAllActors boolean Whether spells added by this script should be added to all actors
---@field forRefIdActors boolean if forAllActors is false, this value can add spells only to actors by specific refIds
---@field forIndexActors boolean if forAllActors and forRefIdActors is false, this can assign spells to actors by unique index
---@field refIdActors ExactRefIdSpellList
---@field fuzzyIdActors FuzzyRefIdSpellList
---@field actorIndexList UniqueIndexSpellList
---@field addedSpells table<RecordId, CustomSpellRecord>
local SpellConfig = require 'yamlInterface' 'custom/addActorSpell/config.yml'

local enumerations = require 'packages.networkEnums'
local enums = require 'dUtil.enums'
local tableHelper = require 'tes3mp.util.table'

--- Lowercases input recordIds
---@param dirtyTable ExactRefIdSpellList|FuzzyRefIdSpellList|UniqueIndexSpellList
---@return ExactRefIdSpellList|FuzzyRefIdSpellList|UniqueIndexSpellList sanitizedTable
local function sanitizeIdTable(dirtyTable)
  local cleanTable = {}

  for actorId, spellArray in pairs(dirtyTable) do
    local lowerSpells = {}

    for _, spellId in ipairs(spellArray) do
      table.insert(lowerSpells, spellId:lower())
    end

    cleanTable[actorId:lower()] = lowerSpells
  end

  return cleanTable
end

for _, list in ipairs { 'actorIndexList', 'fuzzyIdActors', 'refIdActors', } do
  SpellConfig[list] = sanitizeIdTable(SpellConfig[list])
end

--- Convert spell effec string representation in configs back to numeric
--- Or blow up, violently.
for _, spellData in pairs(SpellConfig.addedSpells) do
  for _, effectData in ipairs(spellData.effects) do
    effectData.id = assert(
      enums.MagicEffectId[effectData.id],
      ('Invalid Magic effect id: %s! Please check server/lib/lua/dUtil/enums.lua for valid values.')
      :format(effectData.id)
    )
  end
end

---@param cellDescription CellDescription
---@param uniqueIndex UniqueIndex
---@return boolean
local function CheckValidActor(cellDescription, uniqueIndex)
  local cell = LoadedCells[cellDescription]; if not cell then return false end
  local objectData = cell.data.objectData[uniqueIndex]; if not objectData then return false end

  return not objectData.deathState and not objectData.summon
end

---@param refId RecordId
---@param uniqueIndex UniqueIndex
local function CheckConfigForActor(refId, uniqueIndex)
  if SpellConfig.forAllActors then return true end

  if SpellConfig.forRefIdActors then
    refId = refId:lower()

    if SpellConfig.refIdActors[refId] then return true end

    for match in pairs(SpellConfig.fuzzyIdActors) do
      if refId:find(match) then return true end
    end
  end

  if SpellConfig.forIndexActors and SpellConfig.actorIndexList[uniqueIndex] then return true end

  return false
end

---@param refId RecordId
---@param uniqueIndex UniqueIndex
---@param spellId RecordId
---@return boolean doesGetSpell
local function CheckSpellForActor(refId, uniqueIndex, spellId)
  if SpellConfig.forAllActors then return true end

  if SpellConfig.refIdActors then
    refId = refId:lower()

    local targetActorSpells = SpellConfig.refIdActors[refId]

    if targetActorSpells then
      for _, spell in ipairs(targetActorSpells) do
        if spell == spellId then return true end
      end
    end

    for match, matchSpells in pairs(SpellConfig.fuzzyIdActors) do
      if refId:find(match) then
        for _, spell in ipairs(matchSpells) do
          if spell == spellId then return true end
        end
      end
    end
  end

  if SpellConfig.forIndexActors then
    local targetActorSpells = SpellConfig.actorIndexList[uniqueIndex]

    if not targetActorSpells then return false end

    for _, spell in ipairs(targetActorSpells) do
      if spell == spellId then return true end
    end
  end

  return false
end

---@param pid PlayerId
---@param cellDescription CellDescription
---@param uniqueIndexList UniqueIndex[]
local function SendActorSpellsActive(pid, cellDescription, uniqueIndexList)
  local actorCount = 0
  tes3mp.ClearActorList()
  tes3mp.SetActorListPid(pid)
  tes3mp.SetActorListCell(cellDescription)

  local cell = LoadedCells[cellDescription]

  for _, uniqueIndex in ipairs(uniqueIndexList) do
    local refNum, mpNum = uniqueIndex:splitUniqueIndex()
    tes3mp.SetActorRefNum(refNum)
    tes3mp.SetActorMpNum(mpNum)
    tes3mp.SetActorSpellsActiveAction(enumerations.spellbook.ADD)

    local objectData = cell.data.objectData[uniqueIndex]

    for spellId, spellInstances in pairs(objectData.spellsActive) do
      for _, spellInstanceValues in pairs(spellInstances) do
        for _, effectTable in pairs(spellInstanceValues.effects) do
          tes3mp.AddActorSpellActiveEffect(
            effectTable.id,
            effectTable.magnitude,
            effectTable.duration,
            effectTable.timeLeft,
            effectTable.arg
          )
        end
        tes3mp.AddActorSpellActive(
          spellId,
          spellInstanceValues.displayName,
          spellInstanceValues.stackingState
        )
      end
    end

    tes3mp.AddActor()
    actorCount = actorCount + 1
  end

  if actorCount > 0 then
    tes3mp.SendActorSpellsActiveChanges()
  end
end

---@param pid PlayerId
---@param cellDescription CellDescription
---@param uniqueIndexList UniqueIndex[]
local function AddActorSpellsActive(pid, cellDescription, uniqueIndexList)
  local addSpell, uniqueIndexTable = false, {}

  for _, uniqueIndex in ipairs(uniqueIndexList) do
    if CheckValidActor(cellDescription, uniqueIndex) then
      local cellData = LoadedCells[cellDescription].data
      local objectData = cellData.objectData[uniqueIndex]

      if CheckConfigForActor(objectData.refId, uniqueIndex) then
        for spellId, spellTable in pairs(SpellConfig.addedSpells) do
          if CheckSpellForActor(objectData.refId, uniqueIndex, spellId) then
            objectData.spellsActive = objectData.spellsActive or {}

            if not objectData.spellsActive[spellId] then
              tableHelper.insertValueIfMissing(cellData.packets.spellsActive, uniqueIndex)

              objectData.spellsActive[spellId] = {
                {
                  displayName = spellTable.displayName,
                  stackingState = spellTable.stackingState,
                  effects = tableHelper.deepCopy(spellTable.effects),
                  startTime = os.time()
                }
              }

              addSpell = true
              table.insert(uniqueIndexTable, uniqueIndex)
            end
          end
        end
      end
    end
  end

  if addSpell then
    SendActorSpellsActive(pid, cellDescription, uniqueIndexTable)
  end
end

---@type TES3MPScriptRegistration
return {
  eventHandlers = {
    OnActorCellChange = function(eventStatus, pid, cellDescription)
      if LoadedCells[cellDescription] then
        tes3mp.ReadReceivedActorList()

        for actorIndex = 0, tes3mp.GetActorListSize() - 1 do
          local uniqueIndex = ('%s-%s'):format(tes3mp.GetActorRefNum(actorIndex), tes3mp.GetActorMpNum(actorIndex))
          local newCellDescription = tes3mp.GetActorCell(actorIndex)

          if uniqueIndex and uniqueIndex ~= "0-0" and newCellDescription and LoadedCells[newCellDescription] then
            AddActorSpellsActive(pid, newCellDescription, { uniqueIndex })
          end
        end
      end

      return eventStatus
    end,
    OnActorList = function(eventStatus, pid, cellDescription, _)
      local cell = LoadedCells[cellDescription]

      if cell then
        AddActorSpellsActive(pid, cellDescription, cell.data.packets.actorList)
      end

      return eventStatus
    end,
    OnPlayerCellChange = function(eventStatus, pid, playerPacket, _)
      local cellDescription = playerPacket.location.cell; local cell = LoadedCells[cellDescription]

      if cell then
        AddActorSpellsActive(pid, cellDescription, cell.data.packets.actorList)
      end

      return eventStatus
    end,
  }
}
