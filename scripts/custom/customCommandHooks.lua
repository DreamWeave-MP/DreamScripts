--[[
    Example usage:

    customCommandHooks.registerCommand("test", function(pid, cmd)
        tes3mp.SendMessage(pid, "You can execute a normal command!\n", false)
    end)


    customCommandHooks.registerCommand("ranktest", function(pid, cmd)
        tes3mp.SendMessage(pid, "You can execute a rank-checked command!\n", false)
    end)
    customCommandHooks.setRankRequirement("ranktest", 2) -- must be at least rank 2


    customCommandHooks.registerCommand("nametest", function(pid, cmd)
        tes3mp.SendMessage(pid, "You can execute a name-checked command!\n", false)
    end)
    customCommandHooks.setNameRequirement("nametest", {"Admin", "Kneg", "Jiub"}) -- must be one of these names

]]

local color = require 'color'
local enumerations = require 'tes3mp.enumerations'
local tableHelper = require 'tes3mp.util.table'

---@class CustomCommandHooks
---@field commands table<string, TES3MPCommand>
local customCommandHooks = {
    commands = {},
}

---@param cmd string Name of the new command to register
---@param commandData TES3MPCommand
function customCommandHooks:registerCommand(cmd, commandData)
    commandData.definedBy = commandData.definedBy:lower()
    self.commands[cmd:lower()] = commandData
end

--- Searched for a given command by name
---@param cmd string Name of the command to look up
---@return TES3MPCommand? resulting command data, if found.
function customCommandHooks:getCommand(cmd)
    return self.commands[cmd:lower()]
end

--- Removes all commands registered by a particular script path.
--- Used by DScriptLoader whenever a script is loaded to flush old references to its registered commands.
---@param scriptPath string
function customCommandHooks:clearCommandsFromScript(scriptPath)
    scriptPath = scriptPath:lower()

    local toRemove = {}
    for commandName, commandData in pairs(self.commands) do
        if commandData.definedBy == scriptPath then
            toRemove[#toRemove + 1] = commandName
        end
    end

    for _, commandToRemove in ipairs(toRemove) do
        self.commands[commandToRemove] = nil
    end
end

---@param cmd string Name of the command to remove
function customCommandHooks:removeCommand(cmd)
    cmd = cmd:lower()

    if not self:getCommand(cmd) then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Could not remove the command %s because it does not exist!'):format(cmd)
        )
    end

    customCommandHooks.commands[cmd] = nil
end

---@param cmd string Name of the command whose callback you want to retrieve
---@return function?
function customCommandHooks:getCallback(cmd)
    cmd = cmd:lower()

    local command = self:getCommand(cmd)

    if not command then return end

    return command.callback
end

---@param cmd string name of the command to set a rank requirement for
---@param rank number server rank requirement in order to use this particular command
function customCommandHooks:setRankRequirement(cmd, rank)
    cmd = cmd:lower()

    local command = self.commands[cmd]

    if not command then return end

    command.rankRequirement = rank
end

---@param cmd string name of the command to strip a rank requirement from
function customCommandHooks:removeRankRequirement(cmd)
    cmd = cmd:lower()

    local command = self:getCommand(cmd)

    if not command then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Cannot remove the rank requirement from a command which doesn\'t exist: %s !')
            :format(cmd)
        )
    end

    command.rankRequirement = nil
end

---@param cmd string name of the command to set a name requirement for
function customCommandHooks:setNameRequirement(cmd, names)
    cmd = cmd:lower()

    local command = self:getCommand(cmd)

    if not command then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Cannot set a name requirement to a command which doesn\'t exist: %s !')
            :format(cmd)
        )
    end

    command.nameRequirement = names
end

---@param cmd string name of the command to add a name requirement to
---@param name string name to add to the rank requirement list
function customCommandHooks:addNameRequirement(cmd, name)
    cmd = cmd:lower()

    local command = self:getCommand(cmd)

    if not command then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Cannot add a name requirement to a command which doesn\'t exist: %s !')
            :format(cmd)
        )
    end

    command.nameRequirement = command.nameRequirement or {}

    if tableHelper.containsValue(command.nameRequirement, name) then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('%s is already on the name requirements list for the command %s!')
            :format(name, cmd)
        )
    end

    table.insert(command.nameRequirement, name)
end

---@param cmd string name of the command whose name requirement is to be removed
function customCommandHooks:removeNameRequirement(cmd)
    cmd = cmd:lower()

    local command = self:getCommand(cmd)

    if not command then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Cannot remove the name requirement for a command which doesn\'t exist: %s !')
            :format(cmd)
        )
    end

    command.nameRequirement = nil
end

---@param eventStatus EventStatusTable
---@param pid PlayerId
---@param message string
---@return EventStatusTable eventStatus if false, breaks the eventValidator chain for this event
function customCommandHooks.validator(eventStatus, pid, message)
    if message:sub(1, 1) ~= '/' then return eventStatus end

    ---@type CommandTokens
    local cmd = (message:sub(2, #message)):split(" ")

    local command = customCommandHooks:getCommand(cmd[1])
    if not command then
        tes3mp.SendMessage(
            pid,
            ('%sNot a valid command. Type /help for more info.%s\n'):format(color.Error, color.Default),
            false
        )
        return eventStatus
    end

    if not command.callback or type(command.callback) ~= 'function' then
        tes3mp.LogAppend(
            enumerations.log.ERROR,
            ('- CRITICAL ERROR: found a matching command for %s, but its callback was not a function: %s.\n- The server will now terminate.')
            :format(cmd[1], command.callback)
        )
        tes3mp.StopServer(6)
    end

    local commandNotAuthenticated = not command.rankRequirement and not command.nameRequirement

    local allowedByName = command.nameRequirement and
        tableHelper.containsValue(command.nameRequirement, Players[pid].accountName)

    local allowedByRank = command.rankRequirement and Players[pid].data.settings.staffRank >= command.rankRequirement

    if commandNotAuthenticated or allowedByName or allowedByRank then
        cmd[1] = cmd[1]:lower()
        command.callback(pid, cmd)
        eventStatus.validDefaultHandler = false
    end

    return eventStatus
end

---@type TES3MPScriptRegistration
return {
    interfaceName = 'customCommandHooks',
    ---@class CustomCommandHooksInterface
    interface = {
        ---@param scriptPath string Name of the new command to register
        clearCommandsFromScript = function(scriptPath)
            customCommandHooks:clearCommandsFromScript(scriptPath)
        end,
        ---@param commandName string Command to retrieve
        ---@return TES3MPCommand?
        getCommand = function(commandName)
            if not commandName or type(commandName) ~= 'string' then
                return tes3mp.LogAppend(
                    enumerations.log.WARN,
                    ('- customCommandHooks: Tried to find a command %s, but the input was invalid.')
                    :format(commandName)
                )
            end

            return customCommandHooks:getCommand(commandName)
        end,
        ---@param commandName string Name of the new command to register
        ---@param commandData TES3MPCommand
        registerCommand = function(commandName, commandData)
            if not commandName or type(commandName) ~= 'string' then
                error(
                    ('Cannot register command %s since the provided value was not a string!')
                    :format(commandName)
                )
            end

            if not commandData or type(commandData) ~= 'table' then
                error(
                    ('Cannot register command %s since the provided commandData was not a table: %s!')
                    :format(commandName, commandData)
                )
            end

            if not commandData.callback or type(commandData.callback) ~= 'function' then
                error(
                    ('Cannot register command %s since the provided callback was not a function: %s!')
                    :format(commandName, commandData.callback)
                )
            end

            customCommandHooks:registerCommand(commandName, commandData)
        end,
    },
    eventValidators = {
        OnPlayerSendMessage = customCommandHooks.validator,
    },
}
