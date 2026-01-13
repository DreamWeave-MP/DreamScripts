local enumerations = require 'tes3mp.enumerations'

---@class InventoryHelper
local inventoryHelper = {}

---@param inventory Inventory
---@param refId string
---@param charge integer?
---@param enchantmentCharge integer?
---@param soul string?
function inventoryHelper.containsItem(inventory, refId, charge, enchantmentCharge, soul)
    if charge then charge = math.floor(charge) end
    if enchantmentCharge then enchantmentCharge = math.floor(enchantmentCharge) end

    --- FIXME: *Maybe* we can use an ipairs iterator safely?
    for _, item in pairs(inventory) do
        if item.refId:ciEqual(refId) then
            local isValid = true

            if soul ~= nil and item.soul ~= soul then
                isValid = false
            elseif charge ~= nil and item.charge ~= nil and math.floor(item.charge) ~= charge then
                isValid = false
            elseif enchantmentCharge ~= nil and item.enchantmentCharge ~= nil and
                math.floor(item.enchantmentCharge) ~= enchantmentCharge then
                isValid = false
            end

            if isValid then
                return true
            end
        end
    end

    return false
end

---@param inventory Inventory
---@param refId string
---@param charge integer?
---@param enchantmentCharge integer?
---@param soul string?
---@return integer? inventoryItemIndex index of the inventory in which a matching item was found
function inventoryHelper.getItemIndex(inventory, refId, charge, enchantmentCharge, soul)
    if charge then charge = math.floor(charge) end
    if enchantmentCharge then enchantmentCharge = math.floor(enchantmentCharge) end

    --- FIXME: *Maybe* we can use an ipairs iterator safely?
    for itemIndex, item in pairs(inventory) do
        if item.refId:ciEqual(refId) then
            local isValid = true

            if soul and item.soul ~= soul then
                isValid = false
            elseif charge and item.charge and math.floor(item.charge) ~= charge then
                isValid = false
            elseif enchantmentCharge and item.enchantmentCharge and math.floor(item.enchantmentCharge) ~= enchantmentCharge then
                isValid = false
            end

            if isValid then
                return itemIndex
            end
        end
    end
end

--- Searches an inventory for any items matching the given refId case-insensitively
---@param inventory Inventory
---@param refId string
---@return integer[] inventoryItemIndices indices of all matching inventory items
function inventoryHelper.getItemIndices(inventory, refId)
    local indices = {}

    --- FIXME: *Maybe* we can use an ipairs iterator safely?
    for itemIndex, item in pairs(inventory) do
        if item.refId:ciEqual(refId) then
            table.insert(indices, itemIndex)
        end
    end

    return indices
end

---@param inventory Inventory
---@param refId string
---@param count integer?
---@param charge integer?
---@param enchantmentCharge integer?
---@param soul string?
function inventoryHelper.addItem(inventory, refId, count, charge, enchantmentCharge, soul)
    if not inventory or type(inventory) ~= 'table' then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Invalid inventory input: %s to inventoryHelper.addItem!'):format(inventory)
        )
    elseif not refId or type(refId) ~= 'string' or refId == '' then
        return tes3mp.LogAppend(
            enumerations.log.WARN,
            ('Invalid refId input: %s to inventoryHelper.addItem!'):format(refId)
        )
    end

    count = math.floor(count or 1)
    charge = math.floor(charge or -1)
    enchantmentCharge = math.floor(enchantmentCharge or -1)
    soul = soul or ''

    if inventoryHelper.containsItem(inventory, refId, charge, enchantmentCharge, soul) then
        local index = inventoryHelper.getItemIndex(inventory, refId, charge, enchantmentCharge, soul)

        inventory[index].count = inventory[index].count + count
    else
        ---@type Item
        local item = {
            charge = charge,
            count = count,
            enchantmentCharge = enchantmentCharge,
            refId = refId,
            soul = soul,
        }

        table.insert(inventory, item)
    end
end

-- Return true if an item (comparedItem) is closer to a desired item (idealItem) than
-- another item is (otherItem)
---@param idealItem Item
---@param comparedItem Item
---@param otherItem Item
function inventoryHelper.compareClosenessToItem(idealItem, comparedItem, otherItem)
    if comparedItem == otherItem then
        return false
    end

    -- A difference in refIds instantly resolves the comparison
    if idealItem.refId and not comparedItem.refId:ciEqual(otherItem.refId) then
        if idealItem.refId:ciEqual(comparedItem.refId) then
            return true
        elseif idealItem.refId:ciEqual(otherItem.refId) then
            return false
        end
    end

    if idealItem.soul then
        if not comparedItem.soul then
            comparedItem.soul = ''
        end

        if not otherItem.soul then
            otherItem.soul = ''
        end

        -- A difference in souls also instantly resolves the comparison
        if not comparedItem.soul:ciEqual(otherItem.soul) then
            if idealItem.soul:ciEqual(comparedItem.soul) then
                return true
            elseif idealItem.soul:ciEqual(otherItem.soul) then
                return false
            end
        end
    end

    -- The TES3MP server doesn't yet load up data files, so it doesn't actually know what the
    -- maximum charge and enchantmentCharge are supposed to be for a particular refId
    --
    -- Use some dirty workarounds here to ignore that fact until the sensible and elegant
    -- solution becomes available

    local comparedChargeDiff, otherChargeDiff = 0, 0
    local comparedEnchantmentChargeDiff, otherEnchantmentChargeDiff = 0, 0

    if idealItem.charge and comparedItem.charge ~= otherItem.charge then
        if not comparedItem.charge then
            comparedItem.charge = -1
        end

        if not otherItem.charge then
            otherItem.charge = -1
        end

        local maxValue = math.max(idealItem.charge, comparedItem.charge, otherItem.charge)

        if maxValue < 400 then maxValue = maxValue + 400 end

        local adjustedIdealCharge = idealItem.charge
        local adjustedComparedCharge = comparedItem.charge
        local adjustedOtherCharge = otherItem.charge

        if adjustedIdealCharge == -1 then adjustedIdealCharge = maxValue + maxValue / 2 end
        if adjustedComparedCharge == -1 then adjustedComparedCharge = maxValue + maxValue / 2 end
        if adjustedOtherCharge == -1 then adjustedOtherCharge = maxValue + maxValue / 2 end

        comparedChargeDiff = math.abs(adjustedIdealCharge - adjustedComparedCharge)
        otherChargeDiff = math.abs(adjustedIdealCharge - adjustedOtherCharge)
    end

    if idealItem.enchantmentCharge and comparedItem.enchantmentCharge ~= otherItem.enchantmentCharge then
        if not comparedItem.enchantmentCharge then
            comparedItem.enchantmentCharge = -1
        end

        if not otherItem.enchantmentCharge then
            otherItem.enchantmentCharge = -1
        end

        local maxValue = math.max(idealItem.enchantmentCharge, comparedItem.enchantmentCharge,
            otherItem.enchantmentCharge)

        if maxValue < 200 then maxValue = maxValue + 200 end

        local adjustedIdealEnchantmentCharge = idealItem.enchantmentCharge
        local adjustedComparedEnchantmentCharge = comparedItem.enchantmentCharge
        local adjustedOtherEnchantmentCharge = otherItem.enchantmentCharge

        if adjustedIdealEnchantmentCharge == -1 then adjustedIdealEnchantmentCharge = maxValue + maxValue / 2 end
        if adjustedComparedEnchantmentCharge == -1 then adjustedComparedEnchantmentCharge = maxValue + maxValue / 2 end
        if adjustedOtherEnchantmentCharge == -1 then adjustedOtherEnchantmentCharge = maxValue + maxValue / 2 end

        comparedEnchantmentChargeDiff = math.abs(adjustedIdealEnchantmentCharge - adjustedComparedEnchantmentCharge)
        otherEnchantmentChargeDiff = math.abs(adjustedIdealEnchantmentCharge - adjustedOtherEnchantmentCharge)
    end

    if comparedChargeDiff + comparedEnchantmentChargeDiff < otherChargeDiff + otherEnchantmentChargeDiff then
        return true
    end

    return false
end

---@param inventory Inventory
---@param refId string
---@param count integer
---@param charge integer
---@param enchantmentCharge integer
---@param soul string
function inventoryHelper.removeClosestItem(inventory, refId, count, charge, enchantmentCharge, soul)
    if inventoryHelper.containsItem(inventory, refId) then
        local itemIndicesToCompare = inventoryHelper.getItemIndices(inventory, refId)
        local itemIndicesByCloseness = {}
        local idealItem = {
            refId = refId,
            charge = charge,
            enchantmentCharge = enchantmentCharge,
            soul = soul
        }

        for _, comparedItemIndex in ipairs(itemIndicesToCompare) do
            local comparedItem = inventory[comparedItemIndex]
            local isLeastClose = true

            for closenessRanking, otherItemIndex in ipairs(itemIndicesByCloseness) do
                local otherItem = inventory[otherItemIndex]

                if inventoryHelper.compareClosenessToItem(idealItem, comparedItem, otherItem) then
                    table.insert(itemIndicesByCloseness, closenessRanking, comparedItemIndex)
                    isLeastClose = false
                    break
                end
            end

            if isLeastClose then
                table.insert(itemIndicesByCloseness, comparedItemIndex)
            end
        end

        local remainingCount = count

        for _, currentItemIndex in ipairs(itemIndicesByCloseness) do
            if remainingCount > 0 then
                ---@type Item?
                local currentItem = inventory[currentItemIndex]

                if currentItem then
                    currentItem.count = currentItem.count - remainingCount

                    if currentItem.count < 1 then
                        remainingCount = 0 - currentItem.count
                        currentItem = nil
                    else
                        remainingCount = 0
                    end
                end

                inventory[currentItemIndex] = currentItem
            else
                break
            end
        end
    end
end

---@param inventory Inventory
---@param refId string
---@param count integer
---@param charge integer
---@param enchantmentCharge integer
---@param soul string
function inventoryHelper.removeExactItem(inventory, refId, count, charge, enchantmentCharge, soul)
    if inventoryHelper.containsItem(inventory, refId, charge, enchantmentCharge, soul) then
        local index = inventoryHelper.getItemIndex(inventory, refId, charge, enchantmentCharge, soul)

        if not index then
            return tes3mp.LogAppend(
                enumerations.log.WARN,
                ('Could not remove the item %s because it was not in the inventory %s'):format(refId, inventory)
            )
        end

        local item = inventory[index]

        if not item then return end

        item.count = item.count - count

        if item.count < 1 then
            inventory[index] = nil
        end
    end
end

-- Deprecated
function inventoryHelper.removeItem()
    error('inventoryHelper.removeItem is now deprecated! Use inventoryHelper.removeClosestItem instead.')
end

return inventoryHelper
