local ffi = require 'ffi'

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

Vec3MT.__sub = function(a, b)
  ---@type Vector3
  local result = ffi.new('vector3')
  result.x, result.y, result.z = a.x - b.x, a.y - b.y, a.z - b.z

  return result
end

Vec3MT.__mul = function(a, scalar)
  local isNumber, isVector = type(scalar) == 'number', a.is(scalar)

  if isNumber or isVector then
    ---@type Vector3
    local result = ffi.new('vector3')

    if isNumber then
      result.x, result.y, result.z = a.x * scalar, a.y * scalar, a.z * scalar
    elseif isVector then
      result.x, result.y, result.z = a.x * scalar.x, a.y * scalar.y, a.z * scalar.z
    end

    return result
  end

  error("vector3 can only be multiplied by scalar")
end

Vec3MT.__div = function(a, scalar)
  local isNumber, isVector = type(scalar) == 'number', a.is(scalar)

  if isNumber or isVector then
    ---@type Vector3
    local result = ffi.new('vector3')

    if isNumber then
      result.x, result.y, result.z = a.x / scalar, a.y / scalar, a.z / scalar
    elseif isVector then
      result.x, result.y, result.z = a.x / scalar.x, a.y / scalar.y, a.z / scalar.z
    end

    return result
  end

  error("vector3 can only be divided by scalar")
end

Vec3MT.__tostring = function(v)
  return ("vector3(%.2f, %.2f, %.2f)"):format(v.x, v.y, v.z)
end

Vec3MT.__len = function(v)
  return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

Vec3Methods = {}

Vec3Methods.normalize = function(v)
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

Vec3Methods.is = function(v)
  return ffi.istype('vector3', v)
end

Vec3Methods.add_mut = function(a, b)
  assert(a.is(b), tostring(b) .. ' is not a vector type! Could not add it to ' .. tostring(a))
  a.x, a.y, a.z = a.x + b.x, a.y + b.y, a.z + b.z
end

Vec3MT.__index = Vec3Methods

---@type ffi.ctype*(x?: number, y?: number, z?: number): Vector3
local vector3 = ffi.metatype("vector3", Vec3MT)

---@type Vector3Module
local Vector3 = {
  new = function(...)
    return vector3(...)
  end,
}

return Vector3
