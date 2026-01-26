local ffi = require 'ffi'

ffi.cdef [[
typedef struct Transform {
  vector3 position;
  vector3 rotation;
  float scale;
} Transform;
]]

---@type ffi.ctype*(pos: Vector3, rot: Vector3, scale: numebr?): Transform
local constructor = ffi.typeof('Transform')

---@type TransformConstructor
return function(pos, rot, scale)
  assert(pos and ffi.istype('vector3', pos), 'Invalid position vector provided to Transform constructor!')
  assert(rot and ffi.istype('vector3', rot), 'Invalid rotation vector provided to Transform constructor!')
  if scale then assert(type(scale) == 'number', 'Invalid scale provided to transform constructor!') end

  return constructor(pos, rot, scale or 1)
end
