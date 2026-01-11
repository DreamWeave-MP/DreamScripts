---@meta

---@alias CommandTokens string[] pre-tokenized command string provided to all commandHandlers. The first value is always the name of the command entered, including the leading slash.
---@alias CommandHandler fun(pid: PlayerId, cmd: CommandTokens) Special function type for handling chat commands
---@alias PlayerId integer zero-based integer indicating a unique player ID.

---@alias OSType
---| 'Windows'
---| 'Linux'
---| 'OS X'
---| 'Unknown OS' -- This one probably shouldn't happen!

---@class TES3MPModule
---@field BanAddress fun(ipAddress: string) Given an IP Address string, bans it. Doesn't perform any validation, so caller functions need to do so themselves.
---@field GetOperatingSystemType fun(): OSType
---@field LogMessage fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field LogAppend fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field SendMessage fun(pid: PlayerId, message: string, sendToAll: boolean?) Emits a chat message to a specific player, optionally relaying it to all players
---@field StopServer fun(exitCode: integer) Terminate the server with a provided exit code
---@field UnbanAddress fun(ipAddress: string) Given an IP Address string, unbans it. Doesn't perform any validation, so caller functions need to do so themselves.
tes3mp = tes3mp
