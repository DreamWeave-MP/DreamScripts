local config = require 'tes3mp.config'
local patterns = require 'patterns'
local inventoryHelper = require 'inventoryHelper'

require 'doc.menuHelper'

--- Stateful helper module for building interfaces.
--- Must only be `require`'d once by serverCore.lua!
---@class MenuHelper
local menuHelper = {
    Menus = {},
    conditions = {
        --- Helper function to require a specific value of a specific attribute
        --- to display an interface element
        ---@param inputName string
        ---@param inputValue integer
        ---@return AttributeCondition
        requireAttribute = function(inputName, inputValue)
            ---@type AttributeCondition
            local condition = {
                conditionType = 'attribute',
                attributeName = inputName,
                attributeValue = inputValue
            }

            return condition
        end,
        --- Helper function to require a specific amount of a specifc item
        --- To display an interface element
        ---@param inputRefIds string|string[]
        ---@param inputCount integer?
        ---@return ItemCondition
        requireItem = function(inputRefIds, inputCount)
            if type(inputRefIds) ~= 'table' then
                inputRefIds = { inputRefIds }
            end

            ---@type ItemCondition
            local condition = {
                conditionType = 'item',
                refIds = inputRefIds,
                count = inputCount or 1
            }

            return condition
        end,

        --- Helper function to display a given interface element
        --- Only if the calling player passes a particular function call
        ---@param inputFunctionName string
        ---@param inputArguments any[]
        ---@return PlayerFunctionCondition
        requirePlayerFunction = function(inputFunctionName, inputArguments)
            ---@type PlayerFunctionCondition
            local condition = {
                conditionType = 'playerFunction',
                functionName = inputFunctionName,
                arguments = inputArguments
            }

            return condition
        end,

        --- Helper to require a given value of a given skill
        --- To display an interface element
        ---@param inputName string
        ---@param inputValue integer
        ---@return SkillCondition
        requireSkill = function(inputName, inputValue)
            ---@type SkillCondition
            local condition = {
                conditionType = 'skill',
                skillName = inputName,
                skillValue = inputValue
            }

            return condition
        end,

        --- Helper to require a particular staff rank to display an interface element
        ---@param inputValue integer staff rank required to display a given interface element
        ---@return RankCondition
        requireStaffRank = function(inputValue)
            ---@type RankCondition
            local condition = {
                conditionType = 'staffRank',
                rankValue = inputValue
            }

            return condition
        end,

    },

    effects = {
        --- Adds a number of a specific item to an inventory when an element is clicked
        ---@param inputRefId string
        ---@param inputCount integer
        ---@return AddItemEffect
        giveItem = function(inputRefId, inputCount)
            ---@type AddItemEffect
            local effect = {
                effectType = 'item',
                action = 'give',
                refId = inputRefId,
                count = inputCount
            }

            return effect
        end,

        --- Removes a set of items when an element is clicked
        ---@param inputRefIds string|string[]
        ---@param inputCount integer
        ---@return RemoveItemEffect
        removeItem = function(inputRefIds, inputCount)
            if type(inputRefIds) ~= 'table' then
                inputRefIds = { inputRefIds }
            end

            ---@type RemoveItemEffect
            local effect = {
                effectType = 'item',
                action = 'remove',
                refIds = inputRefIds,
                count = inputCount
            }

            return effect
        end,

        --- Helper that sets a specific player variable to a given value
        --- When an element is activated
        ---@param inputVariable string
        ---@param inputValue any
        ---@return PlayerVariableEffect
        setPlayerDataVariable = function(inputVariable, inputValue)
            ---@type PlayerVariableEffect
            local effect = {
                effectType = 'playerVariable',
                action = 'data',
                variable = inputVariable,
                value = inputValue
            }

            return effect
        end,

        --- Helper which runs a player function
        --- When an element is activated
        ---@param inputFunctionName string
        ---@param inputArguments any[]
        ---@return PlayerFunctionEffect
        runPlayerFunction = function(inputFunctionName, inputArguments)
            ---@type PlayerFunctionEffect
            local effect = {
                effectType = 'playerFunction',
                functionName = inputFunctionName,
                arguments = inputArguments
            }

            return effect
        end,

        --- Helper which runs a global function when a button is clicked
        ---@param inputObjectName string
        ---@param inputFunctionName string
        ---@param inputArguments string
        ---@return GlobalFunctionEffect
        runGlobalFunction = function(inputObjectName, inputFunctionName, inputArguments)
            local effect = {
                effectType = 'globalFunction',
                objectName = inputObjectName,
                functionName = inputFunctionName,
                arguments = inputArguments
            }

            return effect
        end,
    },

    destinations = {
        ---@param inputMenu string
        ---@param inputEffects MenuEffect[]?
        ---@return DefaultDestination
        setDefault = function(inputMenu, inputEffects)
            ---@type DefaultDestination
            local destination = {
                targetMenu = inputMenu,
                effects = inputEffects or {}
            }

            return destination
        end,

        ---@param inputVariable string
        ---@return CustomVariableDestination
        setFromCustomVariable = function(inputVariable)
            ---@type CustomVariableDestination
            local destination = {
                customVariable = inputVariable
            }

            return destination
        end,

        ---@param inputMenu string
        ---@param inputConditions DisplayCondition[]
        ---@param inputEffects MenuEffect[]?
        ---@return ConditionalDestination
        setConditional = function(inputMenu, inputConditions, inputEffects)
            ---@type ConditionalDestination
            local destination = {
                targetMenu = inputMenu,
                conditions = inputConditions,
                effects = inputEffects
            }

            return destination
        end,
    },

    variables = {
        --- Stores the current owner's PID
        ---@return PIDVariable
        currentPid = function()
            ---@type PIDVariable
            local variable = {
                variableType = 'pid',
                source = 'current'
            }

            return variable
        end,

        --- Stores the current owner's chat name
        ---@return ChatNameVariable
        currentChatName = function()
            ---@type ChatNameVariable
            local variable = {
                variableType = 'chatName',
                source = 'current'
            }

            return variable
        end,

        --- Stores the current owner
        ---@param inputVariableName string
        ---@return CurrentPlayerVariable
        currentPlayerVariable = function(inputVariableName)
            ---@type CurrentPlayerVariable
            local variable = {
                variableType = 'playerVariable',
                source = 'current',
                variableName = inputVariableName
            }

            return variable
        end,

        --- Stores any global variable
        ---@param inputObjectName string
        ---@param inputVariableName string
        ---@return GlobalVariable
        globalVariable = function(inputObjectName, inputVariableName)
            ---@type GlobalVariable
            local variable = {
                variableType = 'globalVariable',
                objectName = inputObjectName,
                variableName = inputVariableName
            }

            return variable
        end,

        ---@param inputDelimiter string
        ---@param ... any[]
        ---@return ConcatenationVariable
        concatenation = function(inputDelimiter, ...)
            ---@type ConcatenationVariable
            local variable = {
                variableType = 'argumentArray',
                operation = 'concatenation',
                delimiter = inputDelimiter,
                containedVariables = { ... }
            }

            return variable
        end,
    },
}

--- Checks whether a given player passes a certain DisplayCondition
---@param pid PlayerId
---@param condition DisplayCondition
---@return boolean conditionPassed
function menuHelper.CheckCondition(pid, condition)
    local targetPlayer = Players[pid]

    if condition.conditionType == 'item' then
        ---@cast condition ItemCondition
        local remainingCount = condition.count

        for _, currentRefId in ipairs(condition.refIds) do
            if inventoryHelper.containsItem(targetPlayer.data.inventory, currentRefId) then
                local itemIndex = inventoryHelper.getItemIndex(targetPlayer.data.inventory, currentRefId)
                local item = targetPlayer.data.inventory[itemIndex]

                remainingCount = remainingCount - item.count

                if remainingCount < 1 then
                    return true
                end
            end
        end
    elseif condition.conditionType == 'attribute' then
        ---@cast condition AttributeCondition
        if targetPlayer.data.attributes[condition.attributeName].base >= condition.attributeValue then
            return true
        end
    elseif condition.conditionType == 'skill' then
        ---@cast condition SkillCondition
        if targetPlayer.data.skills[condition.skillName].base >= condition.skillValue then
            return true
        end
    elseif condition.conditionType == 'staffRank' then
        ---@cast condition RankCondition
        if targetPlayer.data.settings.staffRank >= condition.rankValue then
            return true
        end
    elseif condition.conditionType == 'playerFunction' then
        ---@cast condition PlayerFunctionCondition
        local functionName = condition.functionName
        local arguments = condition.arguments

        if arguments == nil then
            arguments = {}
            -- Fill in any variables placed inside the arguments
        else
            arguments = menuHelper.ProcessVariables(pid, arguments)
        end

        if targetPlayer[functionName](targetPlayer, unpack(arguments)) then
            return true
        end
    end

    return false
end

--- Checks that a given player matches *all* conditions defined by a menu
---@param pid PlayerId
---@param conditions DisplayCondition[]
function menuHelper.CheckConditionTable(pid, conditions)
    local conditionCount = table.maxn(conditions)
    local conditionsMet = 0

    for _, condition in ipairs(conditions) do
        if menuHelper.CheckCondition(pid, condition) then
            conditionsMet = conditionsMet + 1
        end
    end

    if conditionsMet == conditionCount then
        return true
    end

    return false
end

--- Processes all menu variables associated with a given PID
---@param pid PlayerId
---@param inputTable MenuVariable[]
---@return any[] resultVariables all resulting variables for a given element
function menuHelper.ProcessVariables(pid, inputTable)
    local resultTable = {}

    for _, tableElement in ipairs(inputTable) do
        ---@type any
        local resultValue = 'nil'

        if type(tableElement) == 'table' and tableElement.variableType ~= nil then
            local variableType = tableElement.variableType
            -- local subType = tableElement.subType
            -- local source = tableElement.source

            if variableType == 'pid' then
                ---@cast tableElement PIDVariable
                if tableElement.source == 'current' then
                    resultValue = pid
                end
            elseif variableType == 'chatName' then
                ---@cast tableElement ChatNameVariable
                if tableElement.source == 'current' then
                    resultValue = logicHandler.GetChatName(pid)
                end
            elseif variableType == 'playerVariable' or variableType == 'globalVariable' then
                if variableType == 'playerVariable' and tableElement.source == 'current' then
                    ---@cast tableElement CurrentPlayerVariable
                    resultValue = Players[pid]
                elseif variableType == 'globalVariable' then
                    ---@cast tableElement GlobalVariable
                    local objectName = tableElement.objectName

                    if objectName ~= nil then
                        resultValue = _G[objectName]
                    else
                        resultValue = _G
                    end
                end

                if type(resultValue) == 'table' then
                    -- Allow for nested variables (such as character.race or location.cell)
                    -- by iterating through every value separated by a period
                    for nestedName in string.gmatch(tableElement.variableName, patterns.periodSplit) do
                        if type(resultValue[nestedName]) ~= 'nil' then
                            resultValue = resultValue[nestedName]
                        else
                            resultValue = 'nil'
                            break
                        end
                    end
                end
            elseif variableType == 'argumentArray' then
                ---@cast tableElement ConcatenationVariable
                local operation = tableElement.operation
                local delimiter = tableElement.delimiter

                local processedVariables = menuHelper.ProcessVariables(pid, tableElement.containedVariables)

                if operation == 'concatenation' then
                    resultValue = tableHelper.concatenateArrayValues(processedVariables, 1, delimiter)
                end
            end
        else
            resultValue = tostring(tableElement)
        end

        table.insert(resultTable, resultValue)
    end

    return resultTable
end

--- Process all side effects for a given UI Element
---@param pid PlayerId
---@param effects MenuEffect[]
function menuHelper.ProcessEffects(pid, effects)
    if not effects then return end

    local targetPlayer = Players[pid]
    local shouldReloadInventory = false

    for _, effect in ipairs(effects) do
        local effectType = effect.effectType

        if effectType == 'item' then
            shouldReloadInventory = true

            ---@cast effect AddItemEffect
            if effect.action == 'give' then
                inventoryHelper.addItem(targetPlayer.data.inventory, effect.refId, effect.count, -1, -1)
            elseif effect.action == 'remove' then
                ---@cast effect RemoveItemEffect
                local remainingCount = effect.count

                for _, currentRefId in ipairs(effect.refIds) do
                    if remainingCount > 0 and inventoryHelper.containsItem(targetPlayer.data.inventory,
                            currentRefId) then
                        -- If the item is equipped by the target, unequip it first
                        if inventoryHelper.containsItem(targetPlayer.data.equipment, currentRefId) then
                            local equipmentItemIndex = inventoryHelper.getItemIndex(targetPlayer.data.equipment,
                                currentRefId)
                            if equipmentItemIndex then
                                targetPlayer.data.equipment[equipmentItemIndex] = nil
                            end
                        end

                        local inventoryItemIndex = inventoryHelper.getItemIndex(targetPlayer.data.inventory,
                            currentRefId)

                        if inventoryItemIndex then
                            local item = targetPlayer.data.inventory[inventoryItemIndex]
                            item.count = item.count - remainingCount

                            if item.count < 1 then
                                remainingCount = 0 - item.count
                                item = nil
                            else
                                remainingCount = 0
                            end

                            targetPlayer.data.inventory[inventoryItemIndex] = item
                        end
                    end
                end
            end
        elseif effectType == 'playerVariable' then
            ---@cast effect PlayerVariableEffect
            if effect.action == 'data' then
                targetPlayer.data[effect.variable] = effect.value
            end
        elseif effectType == 'playerFunction' or effectType == 'globalFunction' then
            ---@cast effect PlayerFunctionEffect
            local functionName = effect.functionName
            local arguments = effect.arguments

            if not arguments then
                arguments = {}
                -- Fill in any variables placed inside the arguments
            else
                arguments = menuHelper.ProcessVariables(pid, arguments)
            end

            if effectType == 'playerFunction' then
                targetPlayer[functionName](targetPlayer, unpack(arguments))
            elseif effectType == 'globalFunction' then
                ---@cast effect GlobalFunctionEffect
                local objectName = effect.objectName

                if objectName then
                    local targetObject = _G[objectName]

                    -- If this object doesn't have a metatable, don't pass it to itself
                    -- as an argument
                    if getmetatable(targetObject) == nil then
                        targetObject[functionName](unpack(arguments))
                    else
                        targetObject[functionName](targetObject, unpack(arguments))
                    end
                else
                    _G[functionName](unpack(arguments))
                end
            end
        end
    end

    targetPlayer:QuicksaveToDrive()

    if shouldReloadInventory then
        targetPlayer:LoadInventory()
        targetPlayer:LoadEquipment()
    end
end

---@param pid PlayerId
---@param buttonPressed Button
---@return table
function menuHelper.GetButtonDestination(pid, buttonPressed)
    if not buttonPressed or not buttonPressed.destinations then return {} end

    local defaultDestination = {}

    for _, destination in ipairs(buttonPressed.destinations) do
        if destination.customVariable then
            local customVariable = destination.customVariable
            destination.targetMenu = Players[pid][customVariable]
        end

        if not destination.conditions then
            defaultDestination = destination
        else
            local conditionsMet = menuHelper.CheckConditionTable(pid, destination.conditions)

            if conditionsMet then
                return destination
            end
        end
    end

    return defaultDestination
end

--- Return the displayed buttons for a given menu element,
--- For a particular player
---@param pid PlayerId
---@param menuIndex integer
---@return Button[]
function menuHelper.GetDisplayedButtons(pid, menuIndex)
    if not menuIndex or not menuHelper.Menus[menuIndex] then return {} end
    local targetMenu = menuHelper.Menus[menuIndex]

    local displayedButtons = {}

    for _, button in ipairs(targetMenu.buttons) do
        -- Only display this button if there are no conditions for displaying it, or if
        -- the conditions for displaying it are met
        local conditionsMet = true

        if button.displayConditions then
            conditionsMet = menuHelper.CheckConditionTable(pid, button.displayConditions)
        end

        if conditionsMet then
            table.insert(displayedButtons, button)
        end
    end

    return displayedButtons
end

--- Displays a particular menu to a player given the unique indices of both
---@param pid PlayerId
---@param menuIndex integer
function menuHelper.DisplayMenu(pid, menuIndex)
    if not menuIndex or menuHelper.Menus[menuIndex] then return end

    local text = menuHelper.Menus[menuIndex].text

    -- Is this a table? If so, process the variables in it and then concatenate them
    if not text then
        text = ''
    elseif type(text) == 'table' then
        local processedTextVariables = menuHelper.ProcessVariables(pid, text)
        text = tableHelper.concatenateArrayValues(processedTextVariables, 1, '')
    end

    local displayedButtons = menuHelper.GetDisplayedButtons(pid, menuIndex)
    local buttonCount = tableHelper.getCount(displayedButtons)
    local buttonList = ""

    for buttonIndex, button in ipairs(displayedButtons) do
        local caption = button.caption

        -- Handle button captions the same way as menu text
        if type(caption) == "table" then
            local processedTextVariables = menuHelper.ProcessVariables(pid, caption)
            caption = tableHelper.concatenateArrayValues(processedTextVariables, 1, "")
        end

        buttonList = buttonList .. caption

        if buttonIndex < buttonCount then
            buttonList = buttonList .. ";"
        end
    end

    Players[pid].displayedMenuButtons = displayedButtons

    tes3mp.CustomMessageBox(pid, config.customMenuIds.menuHelper, text, buttonList)
end

return menuHelper
