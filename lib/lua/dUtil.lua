local ffi = require 'ffi'

ffi.cdef [[
typedef struct vector3 {
    float x, y, z;
} vector3;
]]

local vector3_mt = {
  __add = function(a, b)
    return vector3(a.x + b.x, a.y + b.y, a.z + b.z)
  end,

  __mul = function(a, scalar)
    if type(scalar) == 'number' then
      return vector3(a.x * scalar, a.y * scalar, a.z * scalar)
    end
    error("vector3 can only be multiplied by scalar")
  end,

  __tostring = function(v)
    return ("vector3(%.2f, %.2f, %.2f)"):format(v.x, v.y, v.z)
  end,

  __len = function(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  end,

  normalize = function(v)
    local len = #v
    if len > 0 then
      return vector3(v.x / len, v.y / len, v.z / len)
    end
    return vector3(0, 0, 0)
  end
}

local vector3 = ffi.metatype("vector3", vector3_mt)

local v1 = vector3(1, 2, 3)
local v2 = vector3(4, 5, 6)

print(v1, v2, #v1, #v2)
print(v1.x, v1.y, v1.z)

return {
  vector3 = vector3,
}
