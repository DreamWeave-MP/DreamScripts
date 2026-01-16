---@meta

---@alias Vector3Constructor fun(x: number, y: number, z: number): Vector3

---@class DefaultInterfaces
---@field Color ColorModule?
---@field contentFixer ContentFixer?
---@field customCommandHooks CustomCommandHooks?
---@field customEventHooks CustomEventHooks?
---@field menuHelper MenuHelper?
---@field scriptLoader DScriptLoaderHidden
---@field speechHelper SpeechHelper?
---@field storage StorageModule
---@field dreamDice DiceInterface?
---@field customMerchantRestock RestockInterface?

---@class DreamWeaveMenuModule
---@field display function(pid: PlayerId, menuName: string)

---@class DreamWeaveScriptEnv
---@field print fun(...) Standard lua print
---@field string stringlib
---@field math mathlib
---@field menu DreamWeaveMenuModule
---@field tes3mp TES3MPModule global tes3mp namespace functions
---@field I table<string, table<any, any>> Global script interfaces to be accessed by other mods

---@class DUtilModule
---@field getRequiredDataFiles fun(): DataFileRequirements Safer version of below function which doesn't modify global server state
---@field loadRequiredDataFiles fun(writeLog: boolean): DataFileRequirements Loads the required data files, whilst also initializing the server connection requirements. ONLY Call this once!
---@field io DUtilIO
---@field misc DUtilMisc
---@field vector3 Vector3Constructor

---@class SaveSubscriptionData
---@field filePath string Path of the file, relative to `server/data`, eg, `custom/myData.json`
---@field persistent boolean Whether or not to flush the data immediately after it's been saved, or keep it around
---@field data table<any, any> A persistent reference to the table to be saved. It must never be replaced!
---@field delay integer? Time in seconds between writes. This includes how long before the data is first saved.
---@field condition? fun(): boolean An optional condition function to run before determining whether or not to save.
---@field lastCheckedTime integer? The last time in seconds the subscription was checked for a save. Should NEVER be provided by the constructor! You will trip an assertion if you provide this asa parameter.

---@class StorageModule
---@field subscribeToSave fun(data: SaveSubscriptionData)

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
