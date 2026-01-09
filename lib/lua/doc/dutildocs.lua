---@meta

---@class Vector3: userdata
---@field x number
---@field y number
---@field z number
---@field normalize fun(): Vector3 returns the magnitude of the vector from 0.0-1.0
---@field is fun(v: any): boolean returns whether or not the input is also a vector3
---@field add_mut fun(v: Vector3) adds one vector onto this one mutably

---@class Vector3Module
---@field new fun(x: number?, y: number?, z: number?): Vector3

---@class DUtilModule
---@field vector3 Vector3Module
