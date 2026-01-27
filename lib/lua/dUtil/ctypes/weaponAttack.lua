local ffi = require 'ffi'

ffi.cdef [[
typedef struct WeaponAttack {
  uint8_t chopMin;
  uint8_t chopMax;
  uint8_t slashMin;
  uint8_t slashMax;
  uint8_t thrustMin;
  uint8_t thrustMax;
} WeaponAttack;
]]

---@type ffi.ctype*(chopMin: integer, chopMax: integer, slashMin: integer, slashMax: integer, thrustMin: integer, thrustMax: integer): WeaponAttack
local constructor = ffi.typeof('WeaponAttack')

---@param input number?
local function validateDamageInput(input, paramName)
  if not input or type(input) ~= 'number' or input < 0 or input > 255 then
    error(('Invalid %s provided to WeaponAttack constructor!'):format(paramName))
  end
end

---@type WeaponAttackConstructor
return function(chopMin, chopMax, slashMin, slashMax, thrustMin, thrustMax)
  validateDamageInput(chopMin, 'chopMin')
  validateDamageInput(chopMax, 'chopMax')
  validateDamageInput(slashMin, 'slashMin')
  validateDamageInput(slashMin, 'slashMin')
  validateDamageInput(thrustMax, 'thrustMax')
  validateDamageInput(thrustMax, 'thrustMax')

  return constructor(chopMin, chopMax, slashMin, slashMax, thrustMin, thrustMax)
end
