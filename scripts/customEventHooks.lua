---@class CustomEventHooks
local customEventHooks = {
    validators = {},
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

---@param event string
---@param callback function
function customEventHooks.registerValidator(event, callback)
    if not customEventHooks.validators[event] then
        customEventHooks.validators[event] = {}
    end

    table.insert(customEventHooks.validators[event], callback)
end

---@param event string
---@param callback function
function customEventHooks.registerHandler(event, callback)
    if not customEventHooks.handlers[event] then
        customEventHooks.handlers[event] = {}
    end

    table.insert(customEventHooks.handlers[event], callback)
end

---@param event string
---@param args any[]
---@return EventStatusTable
function customEventHooks.triggerValidators(event, args)
    local eventStatus = customEventHooks.makeEventStatus(true, true)
    if customEventHooks.validators[event] ~= nil then
        for _, callback in ipairs(customEventHooks.validators[event]) do
            eventStatus = customEventHooks.updateEventStatus(eventStatus, callback(eventStatus, unpack(args)))
        end
    end
    return eventStatus
end

---@param event string
---@param eventStatus EventStatusTable
---@param args any[]
function customEventHooks.triggerHandlers(event, eventStatus, args)
    if customEventHooks.handlers[event] ~= nil then
        for _, callback in ipairs(customEventHooks.handlers[event]) do
            eventStatus = customEventHooks.updateEventStatus(eventStatus, callback(eventStatus, unpack(args)))
        end
    end
end

return customEventHooks
