---@meta

---@alias CommandTokens string[] pre-tokenized command string provided to all commandHandlers. The first value is always the name of the command entered, including the leading slash.
---@alias CommandHandler fun(pid: PlayerId, cmd: CommandTokens) Special function type for handling chat commands
---@alias GUIID integer Unique numeric Identifier for GUIs
---@alias Inventory Item[]
---@alias PlayerId integer zero-based integer indicating a unique player ID.

---@alias OSType
---| 'Windows'
---| 'Linux'
---| 'OS X'
---| 'Unknown OS' -- This one probably shouldn't happen!

---@class Item
---@field enchantmentCharge integer -1 if not enchanted.
---@field soul string soul inhabiting an enchanted item. Must be present, but may be empty.
---@field refId string recordId of an inventory item
---@field count integer Number of items in a particular item stack. Must be at least 1.
---@field charge integer -1 if not enchanted.

---@class TES3MPCommand
---@field definedBy string path of the script which defined this command. The name of the script which defines a command it kept so that old references to it may be removed.
---@field callback CommandHandler handler function for whenever this command is invoked
---@field nameRequirement string[]? optional list of exclusive names which may run a given command
---@field rankRequirement integer? optional rank requirement to run a command

---@class TES3MPModule
---@field BanAddress fun(ipAddress: string) Given an IP Address string, bans it. Doesn't perform any validation, so caller functions need to do so themselves.
---@field CustomMessageBox fun(pid: PlayerId, id: integer, label: string, items: string) Displays a multiple-choice message box to the target PID
---@field GetAvgPing fun(pid: PlayerId): integer returns a specific player's average ping
---@field GetLastPlayerId fun(): PlayerId returns the last PID which connected to the server
---@field GetOperatingSystemType fun(): OSType
---@field GetSHA256Hash fun(input: string): string Given some string input, hashes it
---@field InputDialog fun(pid: PlayerId, id: GUIID, label: string, note: string) Displays an input dialog
---@field LogMessage fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field LogAppend fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field PasswordDialog fun(pid: PlayerId, id: GUIID, label: string, note: string) Displays an input dialog whose inputs are displayed only as asterisks
---@field SendMessage fun(pid: PlayerId, message: string, sendToAll: boolean?) Emits a chat message to a specific player, optionally relaying it to all players
---@field StopServer fun(exitCode: integer) Terminate the server with a provided exit code
---@field UnbanAddress fun(ipAddress: string) Given an IP Address string, unbans it. Doesn't perform any validation, so caller functions need to do so themselves.
tes3mp = tes3mp
