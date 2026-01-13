---@meta

---@class DreamWeaveScriptEnv
---@field print fun(...) Standard lua print
---@field tableHelper table<string, function> tes3mp's built in tableHelper module
---@field tes3mp TES3MPModule global tes3mp namespace functions
---@field I table<string, table<any, any>> Global script interfaces to be accessed by other mods

---@class DUtilModule
---@field getRequiredDataFiles fun(): DataFileRequirements Safer version of below function which doesn't modify global server state
---@field loadRequiredDataFiles fun(writeLog: boolean): DataFileRequirements Loads the required data files, whilst also initializing the server connection requirements. ONLY Call this once!
---@field io DUtilIO
---@field misc DUtilMisc
---@field vector3 Vector3Module

---@class TES3MPCommandRegistration
---@field callback CommandHandler
---@field nameRequirement string[]?
---@field rankRequirement integer?

---@class TES3MPScriptRegistration
---@field interface table<any, any>? Exposed functions and variables for other scripts to access
---@field interfaceName string? Name of the interface for another script to look for. Mandatory if an interface is defined.
---@field eventHandlers table<string, function>? series of eventHandlers for this script to run
---@field eventValidators table<string, function>? series of eventValidators for this script to run
---@field chatCommands table<string, TES3MPCommandRegistration>? chat commands registered by this script
---@field menus table<string, TES3MPMenu>? Menus defined to be consumed by menuHelper

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
