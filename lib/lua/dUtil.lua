local ffi = require 'ffi'

---@class Vector3: userdata
---@field x number
---@field y number
---@field z number

---@class Vector3Module
---@field new ffi.ctype*(x: number?, y: number?, z: number?): Vector3

---@class DUtilModule
---@field vector3 Vector3Module
local Module = {
}

ffi.cdef [[
typedef struct vector3 {
    float x, y, z;
} vector3;
]]

local Vec3MT = {}

Vec3MT.__add = function(a, b)
  ---@type Vector3
  local result = ffi.new('vector3')
  result.x, result.y, result.z = a.x + b.x, a.y + b.y, a.z + b.z

  return result
end

Vec3MT.__mul = function(a, scalar)
  if type(scalar) == 'number' then
    ---@type Vector3
    local result = ffi.new('vector3')

    result.x, result.y, result.z = a.x * scalar, a.y * scalar, a.z * scalar
    return result
  end

  error("vector3 can only be multiplied by scalar")
end

Vec3MT.__tostring = function(v)
  return ("vector3(%.2f, %.2f, %.2f)"):format(v.x, v.y, v.z)
end

Vec3MT.__len = function(v)
  return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

Vec3MT.normalize = function(v)
  local len = #v

  ---@type Vector3
  local result = ffi.new('vector3')

  if len > 0 then
    result.x, result.y, result.z = v.x / len, v.y / len, v.z / len
  else
    result.x, result.y, result.z = 0, 0, 0
  end

  return result
end

---@type ffi.ctype*(x?: number, y?: number, z?: number)
local vector3 = ffi.metatype("vector3", Vec3MT)

Module.vector3 = {
  new = vector3,
}

return Module
