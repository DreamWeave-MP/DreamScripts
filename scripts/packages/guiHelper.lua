local logicHandler = require 'packages.logicHandler'
local tableHelper = require 'packages.tableHelper'

---@class GUIHelper
local guiHelper = {
    names = { 'LOGIN', 'REGISTER', 'PLAYERSLIST', 'CELLSLIST' },
}
guiHelper.ID = tableHelper.enum(guiHelper.names)

---@param pid PlayerId
function guiHelper.ShowLogin(pid)
    tes3mp.PasswordDialog(pid, guiHelper.ID.LOGIN, 'Enter your password:', '')
end

---@param pid PlayerId
function guiHelper.ShowRegister(pid)
    tes3mp.PasswordDialog(pid, guiHelper.ID.REGISTER, 'Create new password:',
        'Warning: there is no guarantee that your password will be stored securely on any game server, so you should use ' ..
        'a unique one for each server.')
end

---@return string PlayerListString
local function GetConnectedPlayerList()
    local lastPid = tes3mp.GetLastPlayerId()
    local list = ''
    local divider = ''

    for playerIndex = 0, lastPid do
        if playerIndex == lastPid then
            divider = ''
        else
            divider = '\n'
        end
        if Players[playerIndex] ~= nil and Players[playerIndex]:IsLoggedIn() then
            list = list .. tostring(Players[playerIndex].name) .. ' (pid: ' .. tostring(Players[playerIndex].pid) ..
                ', ping: ' .. tostring(tes3mp.GetAvgPing(Players[playerIndex].pid)) .. ')' .. divider
        end
    end

    return list
end

---@return string LoadedCellString
local function GetLoadedCellList()
    local list = ''
    local divider = ''

    local cellCount = logicHandler.GetLoadedCellCount()
    local cellIndex = 0

    for key in pairs(LoadedCells) do
        cellIndex = cellIndex + 1

        if cellIndex == cellCount then
            divider = ''
        else
            divider = '\n'
        end

        list = list .. key .. ' (auth: ' .. LoadedCells[key]:GetAuthority() .. ', loaded by ' ..
            LoadedCells[key]:GetVisitorCount() .. ')' .. divider
    end

    return list
end

---@return string LoadedRegionString
local function GetLoadedRegionList()
    local list = ''
    local divider = ''

    local regionCount = logicHandler.GetLoadedRegionCount()
    local regionIndex = 0

    for key in pairs(WorldInstance.storedRegions) do
        local visitorCount = WorldInstance:GetRegionVisitorCount(key)

        if visitorCount > 0 then
            regionIndex = regionIndex + 1

            if regionIndex == regionCount then
                divider = ''
            else
                divider = '\n'
            end

            list = list .. key .. ' (auth: ' .. WorldInstance:GetRegionAuthority(key) .. ', loaded by ' ..
                visitorCount .. ')' .. divider
        end
    end

    return list
end

---@param pid PlayerId
---@return string InventoryItemList
local function GetPlayerInventoryList(pid)
    local list = ''
    local divider = ''
    local lastItemIndex = tableHelper.getCount(Players[pid].data.inventory)

    for index, currentItem in ipairs(Players[pid].data.inventory) do
        if index == lastItemIndex then
            divider = ''
        else
            divider = '\n'
        end

        list = list .. index .. ': ' .. currentItem.refId .. ' (count: ' .. currentItem.count .. ')' .. divider
    end

    return list
end

--- Display a list box to a specific PID, of all connected players
---@param pid PlayerId
function guiHelper.ShowPlayerList(pid)
    local playerCount = logicHandler.GetConnectedPlayerCount()
    local label = playerCount .. ' connected player'

    if playerCount ~= 1 then
        label = label .. 's'
    end

    tes3mp.ListBox(pid, guiHelper.ID.PLAYERSLIST, label, GetConnectedPlayerList())
end

--- Show all loaded cells
---@param pid PlayerId
function guiHelper.ShowCellList(pid)
    local cellCount = logicHandler.GetLoadedCellCount()
    local label = cellCount .. ' loaded cell'

    if cellCount ~= 1 then
        label = label .. 's'
    end

    tes3mp.ListBox(pid, guiHelper.ID.CELLSLIST, label, GetLoadedCellList())
end

--- Displays all loaded regions
---@param pid PlayerId
function guiHelper.ShowRegionList(pid)
    local regionCount = logicHandler.GetLoadedRegionCount()
    local label = regionCount .. ' loaded region'

    if regionCount ~= 1 then
        label = label .. 's'
    end

    tes3mp.ListBox(pid, guiHelper.ID.CELLSLIST, label, GetLoadedRegionList())
end

--- Displays to pid the inventory of inventoryPid
---@param menuId integer
---@param pid PlayerId
---@param inventoryPid PlayerId
function guiHelper.ShowInventoryList(menuId, pid, inventoryPid)
    local inventoryCount = tableHelper.getCount(Players[pid].data.inventory)
    local label = inventoryCount .. ' item'

    if inventoryCount ~= 1 then
        label = label .. 's'
    end

    tes3mp.ListBox(pid, menuId, label, GetPlayerInventoryList(inventoryPid))
end

return guiHelper
