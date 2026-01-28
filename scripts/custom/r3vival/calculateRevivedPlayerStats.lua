local SafeRespawnData
local EPS = 0.001

---@param target number?
---@param base number
local function statValue(target, base)
  if not target then return base end

  if target <= 1.0 and target >= EPS then
    return math.round(target * base)
  end

  return base
end

---@param pid PlayerId
---@return number, number, number
local function CalculateRevivedPlayerStats(pid)
  local baseHealth = tes3mp.GetHealthBase(pid)
  local currentFatigue, baseFatigue = tes3mp.GetFatigueCurrent(pid), tes3mp.GetFatigueBase(pid)
  local currentMagicka, baseMagicka = tes3mp.GetMagickaCurrent(pid), tes3mp.GetMagickaBase(pid)

  local newHealth, newMagicka, newFatigue

  local targetHealth, targetMagicka, targetFatigue =
      assert(tonumber(SafeRespawnData.StatsOnRevive.health)), tonumber(SafeRespawnData.StatsOnRevive.magicka),
      tonumber(SafeRespawnData.StatsOnRevive.fatigue)

  newHealth = math.clamp(statValue(targetHealth, baseHealth), 1, baseHealth)

  newMagicka = math.clamp(
    SafeRespawnData.StatsOnRevive.magicka == 'preserve' and currentMagicka or statValue(targetMagicka, baseMagicka),
    0,
    baseMagicka
  )

  newFatigue = math.clamp(
    SafeRespawnData.StatsOnRevive.fatigue == 'preserve' and currentFatigue or statValue(targetFatigue, baseFatigue),
    0,
    baseFatigue
  )

  return newHealth, newMagicka, newFatigue
end

---@param safeRespawnData SafeRespawnData
return function(safeRespawnData)
  assert(safeRespawnData and type(safeRespawnData) == 'table')
  SafeRespawnData = safeRespawnData
  return CalculateRevivedPlayerStats
end
