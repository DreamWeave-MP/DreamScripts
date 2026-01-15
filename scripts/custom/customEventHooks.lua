local enumerations = require 'tes3mp.enumerations'
local tableHelper = require 'tes3mp.util.table'

---@class EventHandler
---@field definedBy string Path of the script which defined this particular event
---@field callback function

---@alias EventHandlersList table<string, EventHandler[]>

---@class CustomEventHooks
local customEventHooks = {
    ---@type EventHandlersList
    validators = {},
    ---@type EventHandlersList
    handlers = {},
}

---@class EventStatusTable
---@field validDefaultHandler boolean?
---@field validCustomHandlers boolean?

---@param validDefaultHandler boolean?
---@param validCustomHandlers boolean?
---@return EventStatusTable
function customEventHooks.makeEventStatus(validDefaultHandler, validCustomHandlers)
    return {
        validDefaultHandler = validDefaultHandler,
        validCustomHandlers = validCustomHandlers
    }
end

---@param oldStatus EventStatusTable
---@param newStatus EventStatusTable?
---@return EventStatusTable
function customEventHooks.updateEventStatus(oldStatus, newStatus)
    if not newStatus then
        return oldStatus
    end

    local result = {}

    if newStatus.validDefaultHandler ~= nil then
        result.validDefaultHandler = newStatus.validDefaultHandler
    else
        result.validDefaultHandler = oldStatus.validDefaultHandler
    end

    if newStatus.validCustomHandlers ~= nil then
        result.validCustomHandlers = newStatus.validCustomHandlers
    else
        result.validCustomHandlers = oldStatus.validCustomHandlers
    end

    return result
end

--- Given a script path, removes all validators and handlers this script defined.
--- Used by the scriptLoader when (re)loading a script.
---@param scriptPath string
function customEventHooks.clearEventsFromScript(scriptPath)
    assert(scriptPath and type(scriptPath) == 'string', 'Invalid input to customEventHooks.clearEventsFromScript!')

    local lowercasePath = scriptPath:lower()
    for _, handlersTable in ipairs { customEventHooks.handlers, customEventHooks.validators, } do
        for _, eventRegistrations in pairs(handlersTable) do
            for eventIndex = #eventRegistrations, 1, -1 do
                if eventRegistrations[eventIndex].definedBy:lower() == lowercasePath then
                    eventRegistrations[eventIndex] = nil
                end
            end
        end
    end
end

---@param event string
---@param validator EventHandler
function customEventHooks.registerValidator(event, validator)
    event = event:lower()
    validator.definedBy = validator.definedBy:lower()

    customEventHooks.validators[event] = customEventHooks.validators[event] or {}
    local eventValidators = customEventHooks.validators[event]

    for i = #eventValidators, 1, -1 do
        if eventValidators[i].definedBy == validator.definedBy then eventValidators[i] = nil end
    end

    customEventHooks.validators[#customEventHooks.validators + 1] = validator
end

---@param event string
---@param handler EventHandler
function customEventHooks.registerHandler(event, handler)
    event = event:lower()
    handler.definedBy = handler.definedBy:lower()

    customEventHooks.handlers[event] = customEventHooks.handlers[event] or {}
    local eventHandlers = customEventHooks.handlers[event]

    for i = #eventHandlers, 1, -1 do
        if eventHandlers[i].definedBy == handler.definedBy then eventHandlers[i] = nil end
    end

    customEventHooks.handlers[#customEventHooks.handlers + 1] = handler
end

---@param event string
---@param args any[]
---@return EventStatusTable
function customEventHooks.triggerValidators(event, args)
    event = event:lower()

    local eventStatus = customEventHooks.makeEventStatus(true, true)
    local eventValidators = customEventHooks.validators[event]
    if not eventValidators then
        tableHelper.print(customEventHooks.validators)
        return eventStatus
    end

    if eventValidators then
        for i, eventHandlerData in ipairs(eventValidators) do
            tes3mp.LogAppend(enumerations.log.WARN,
                ('Triggering validator %d for event %s from script %s')
                :format(i, event, eventHandlerData.definedBy)
            )
            eventStatus = customEventHooks.updateEventStatus(
                eventStatus,
                eventHandlerData.callback(eventStatus, unpack(args))
            )
        end
    end

    return eventStatus
end

---@param event string
---@param eventStatus EventStatusTable
---@param args any[]
function customEventHooks.triggerHandlers(event, eventStatus, args)
    event = event:lower()
    local eventHandlers = customEventHooks.handlers[event]
    if not eventHandlers then
        tableHelper.print(customEventHooks.handlers)
        return
    end


    for i, eventHandlerData in ipairs(eventHandlers) do
        tes3mp.LogAppend(enumerations.log.WARN,
            ('Triggering handler %d for event %s from script %s')
            :format(i, event, eventHandlerData.definedBy)
        )
        eventStatus = customEventHooks.updateEventStatus(
            eventStatus,
            eventHandlerData.callback(eventStatus, unpack(args))
        )
    end
end

---@type TES3MPScriptRegistration
return {
    interfaceName = 'customEventHooks',
    interface = customEventHooks,
}
