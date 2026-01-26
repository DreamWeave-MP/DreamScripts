local ffi = require 'ffi'

ffi.cdef [[
typedef struct CellAmbient {
  vector3 ambientColor;
  vector3 fogColor;
  vector3 sunlightColor;
  float fogDensity;
} CellAmbient;
]]

---@type ffi.ctype*(pos: Vector3, rot: Vector3, scale: number?): CellAmbient
local constructor = ffi.typeof('CellAmbient')

---@type CellAmbientConstructor
return function(ambientColor, fogColor, sunlightColor, fogDensity)
  assert(
    ambientColor and ffi.istype('vector3', ambientColor),
    'Invalid ambient color vector provided to CellAmbient constructor!'
  )

  assert(
    fogColor and ffi.istype('vector3', fogColor),
    'Invalid fog color vector provided to CellAmbient constructor!'
  )

  assert(
    sunlightColor and ffi.istype('vector3', sunlightColor),
    'Invalid sunlight color vector provided to CellAmbient constructor!'
  )

  assert(
    type(fogDensity) == 'number',
    'Invalid scale provided to CellAmbient constructor!'
  )

  return constructor(ambientColor, fogColor, sunlightColor, fogDensity)
end
