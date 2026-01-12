---@meta

--- Helper class when using menuHelper to construct complex menus
---@class DisplayCondition
---@field conditionType string

--- Consequence of a menu element being activated
---@class MenuEffect
---@field effectType string

--- Helper class that defines the destination menu of another
---@class MenuDestination

--- Helper to store a variable associated with a menu element
---@class MenuVariable
---@field variableType string

---@class ItemCondition: DisplayCondition
---@field conditionType 'item'
---@field refIds string[]
---@field count integer

---@class AttributeCondition: DisplayCondition
---@field conditionType 'attribute'
---@field attributeName string
---@field attributeValue integer

---@class SkillCondition: DisplayCondition
---@field conditionType 'skill'
---@field skillName string
---@field skillValue integer

---@class RankCondition: DisplayCondition
---@field conditionType 'staffRank'
---@field rankValue integer

--- Special display class that runs a member function on a specific player,
--- And if it returns `true`, allows an element to be displayed
---@class PlayerFunctionCondition: DisplayCondition
---@field conditionType 'playerFunction'
---@field functionName string
---@field arguments any[]

---@class AddItemEffect: MenuEffect
---@field effectType 'item'
---@field action 'give'
---@field refId string
---@field count integer

---@class RemoveItemEffect: MenuEffect
---@field effectType 'item'
---@field action 'remove'
---@field refIds string[]
---@field count integer

---@class PlayerVariableEffect: MenuEffect
---@field effectType 'playerVariable'
---@field action 'data'
---@field variable string
---@field value any

---@class PlayerFunctionEffect: MenuEffect
---@field effectType 'playerFunction'
---@field functionName string
---@field arguments any[]

---@class GlobalFunctionEffect: MenuEffect
---@field effectType 'globalFunction'
---@field objectName string
---@field functionName string
---@field arguments any[]

---@class DefaultDestination: MenuDestination
---@field targetMenu string
---@field effects MenuEffect[]

---@class CustomVariableDestination: MenuDestination
---@field customVariable string

---@class ConditionalDestination
---@field targetMenu string
---@field conditions DisplayCondition[]
---@field effects MenuEffect[]

---@class PIDVariable: MenuVariable
---@field variableType 'pid'
---@field source 'current'

---@class ChatNameVariable: MenuVariable
---@field variableType 'chatName'
---@field source 'current'

---@class CurrentPlayerVariable: MenuVariable
---@field variableType 'playerVariable'
---@field source 'current'
---@field variableName string

---@class GlobalVariable: MenuVariable
---@field variableType 'globalVariable'
---@field objectName string
---@field variableName string

---@class ConcatenationVariable: MenuVariable
---@field variableType 'argumentArray'
---@field operation 'concatenation'
---@field delimiter string
---@field containedVariables any[]

---@class Button
---@field caption string
---@field displayConditions DisplayCondition[]---
---@field destinations MenuDestination[]
---@field effects MenuEffect[]
---@field variables MenuVariable[]
