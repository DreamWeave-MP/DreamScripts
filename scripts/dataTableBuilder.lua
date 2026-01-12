local dataTableBuilder = {}

function dataTableBuilder.BuildAIData(targetPid, targetUniqueIndex, action,
                                      posX, posY, posZ, distance, duration, shouldRepeat)
    local ai = {
        action = action,
        posX = posX,
        posY = posY,
        posZ = posZ,
        distance = distance,
        duration = duration,
        shouldRepeat = shouldRepeat,
    }

    if targetPid then
        ai.targetPlayer = Players[targetPid].accountName
    else
        ai.targetUniqueIndex = targetUniqueIndex
    end

    return ai
end

--- Use with logicHandler.CreateObject() functions
---@param refId string
---@param count integer?
---@param charge integer?
---@param enchantmentCharge integer?
---@param soul string?
---@return Item
function dataTableBuilder.BuildObjectData(refId, count, charge, enchantmentCharge, soul)
    return {
        refId = refId,
        count = count or 1,
        charge = charge or -1,
        enchantmentCharge = enchantmentCharge or -1,
        soul = soul or "",
    }
end

return dataTableBuilder
