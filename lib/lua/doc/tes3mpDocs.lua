---@meta

---@alias OSType
---| 'Windows'
---| 'Linux'
---| 'OS X'
---| 'Unknown OS' -- This one probably shouldn't happen!

---@class TES3MPModule
---@field GetOperatingSystemType fun(): OSType
---@field LogMessage fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field LogAppend fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
tes3mp = tes3mp
