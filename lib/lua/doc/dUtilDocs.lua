---@meta

---@class Vector3: userdata
---@field x number
---@field y number
---@field z number
---@field __add fun(a: Vector3, b: Vector3): Vector3 add another vector onto this one
---@field __sub fun(a: Vector3, b: Vector3): Vector3 subtract another vector from this one
---@field __div fun(a: Vector3, b: Vector3): Vector3 divide this vector element-wise by a single number or another Vector3
---@field __mul fun(a: Vector3, b: Vector3): Vector3 multiply this vector element-wise by a single number or another Vector3
---@field __len fun(): number return the length of the vector
---@field normalize fun(): Vector3 returns the magnitude of the vector from 0.0-1.0
---@field is fun(v: any): boolean returns whether or not the input is also a vector3
---@field add_mut fun(v: Vector3) adds one vector onto this one mutably
---@field sub_mut fun(v: Vector3) subtract another vector from this one mutably

---@class Vector3Module
---@field new fun(x: number?, y: number?, z: number?): Vector3

---@class DUtilModule
---@field io DUtilIO
---@field misc DUtilMisc
---@field vector3 Vector3Module
