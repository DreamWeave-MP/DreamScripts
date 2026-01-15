---@meta

---@alias MWGender 0|1 0 indicates female, 1 is male

---@alias MWRace
---| 'argonian'
---| 'breton'
---| 'dark elf'
---| 'high elf'
---| 'imperial'
---| 'khajiit'
---| 'nord'
---| 'orc'
---| 'redguard'
---| 'wood elf'

---@alias CellDescription string Name of a cell as defined by content files
---@alias CommandTokens string[] pre-tokenized command string provided to all commandHandlers. The first value is always the name of the command entered, excluding the leading slash, and will always be lowercase.
---@alias CommandHandler fun(pid: PlayerId, cmd: CommandTokens) Special function type for handling chat commands
---@alias ContentFixMap table<CellDescription, ContentFixType>
---@alias DataFileRequirements table<string, string[]>
---@alias GUIID integer Unique numeric Identifier for GUIs
---@alias Inventory Item[]
---@alias PlayerId integer zero-based integer indicating a unique player ID.
---@alias RefNum integer reference to a unique reference number defined by content files

---@alias OSType
---| 'Windows'
---| 'Linux'
---| 'OS X'
---| 'Unknown OS' -- This one probably shouldn't happen!

---@class ContentFixType
---@field disable RefNum[]?
---@field unlock RefNum[]?

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
---@field ClearGameSettingValues fun(pid: PlayerId) Clears game setting values for a specific player, undoing changes made by calls to SetGameSetting
---@field ClearVRSettingValues fun(pid: PlayerId) Clears VR game setting values for a specific player, undoing changes made by calls to SetGameSetting
---@field CustomMessageBox fun(pid: PlayerId, id: integer, label: string, items: string) Displays a multiple-choice message box to the target PID
---@field GetAvgPing fun(pid: PlayerId): integer returns a specific player's average ping
---@field GetLastPlayerId fun(): PlayerId returns the last PID which connected to the server
---@field GetOperatingSystemType fun(): OSType
---@field GetSHA256Hash fun(input: string): string Given some string input, hashes it
---@field InputDialog fun(pid: PlayerId, id: GUIID, label: string, note: string) Displays an input dialog
---@field LogMessage fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field LogAppend fun(logLevel: LogLevel, logMessage: string) Emits a message to the server log & stdout at the provided log level
---@field PasswordDialog fun(pid: PlayerId, id: GUIID, label: string, note: string) Displays an input dialog whose inputs are displayed only as asterisks
---@field PlaySpeech fun(pid: PlayerId, speechPath: string) Plays a voice file for all players on the server. Intended to be used with speechHelper interface
---@field SetDifficulty fun(pid: PlayerId, difficulty: integer) Changes the difficulty for a player, but does NOT send a packet. Use SendSettings to notify clients of difficulty changes.
---@field SendMessage fun(pid: PlayerId, message: string, sendToAll: boolean?) Emits a chat message to a specific player, optionally relaying it to all players
---@field SendSettings fun(pid: PlayerId, sendToAll: boolean, skipAttachedPlayer: boolean) After constructing a settings packet using `SetEnforcedLogLevel`, `SetPhysicsFramerate`, SetGameSettingValue`, `SetVRSettingValue`, or `SetDifficulty`, send it to players, optionally including or omitting all players or just the `pid` provided
---@field SetBedRestAllowed fun(pid: PlayerId, bedAllowed: boolean) Set whether or not a specific player may use beds
---@field SetConsoleAllowed fun(pid: PlayerId, consoleAllowed: boolean) Set whether or not a specific player may use the console
---@field SetEnforcedLogLevel fun(pid: PlayerId, logLevel: LogLevel) Sets the enforced log level for a player. Doesn't send a packet on its own. Log level enforcement is important to prevent players from receiving information about world state they otherwise would not. Use a logLevel of -1 not to enforce this setting.
---@field SetGameSettingValue fun(pid: PlayerId, gameSetting: string, value: any) Override a setting from the `Game` category of settings.cfg. For valid settings and values, refer to here: https://openmw.readthedocs.io/en/openmw-0.47.0_a/reference/modding/settings/game.html
---@field SetPhysicsFramerate fun(pid: PlayerId, framerate: integer) Sets the physics framerate for a specific client. Doesn't send a packet. Use SendSettings to notify clients of changes.
---@field SetVRSettingValue fun(pid: PlayerId, vrSetting: string, value: any) Override a setting from the `VR` category of settings.cfg. For valid settings and values, refer to here: https://openmw.readthedocs.io/en/openmw-0.47.0_a/reference/modding/settings/game.html
---@field SetWaitAllowed fun(pid: PlayerId, waitAllowed: boolean) Set whether or not a specific player may wait
---@field SetWildernessRestAllowed fun(pid: PlayerId, wildernessRestAllowed: boolean) Set whether or not a specific player may rest in the wilderness
---@field StopServer fun(exitCode: integer) Terminate the server with a provided exit code
---@field UnbanAddress fun(ipAddress: string) Given an IP Address string, unbans it. Doesn't perform any validation, so caller functions need to do so themselves.
tes3mp = tes3mp
