local config = require 'config'
local enumerations = require 'packages.networkEnums'
local tableHelper = require 'packages.tableHelper'

---@class ContentFixer
local contentFixer = {}

function contentFixer.AdjustSharedCorprusState(pid)
    local corprusId = "corprus"

    if WorldInstance.data.customVariables.corprusCured == true then
        if tableHelper.containsValue(Players[pid].data.spellbook, corprusId) == true then
            tableHelper.removeValue(Players[pid].data.spellbook, corprusId)
            tableHelper.cleanNils(Players[pid].data.spellbook)

            tes3mp.ClearSpellbookChanges(pid)
            tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.REMOVE)
            tes3mp.AddSpell(pid, corprusId)
            tes3mp.SendSpellbookChanges(pid)

            tes3mp.ClearSpellbookChanges(pid)
            tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.ADD)
            for _, spellId in ipairs({ "common disease immunity", "blight disease immunity", "corprus immunity" }) do
                table.insert(Players[pid].data.spellbook, spellId)
                tes3mp.AddSpell(pid, spellId)
            end
            tes3mp.SendSpellbookChanges(pid)
            tes3mp.MessageBox(pid, -1, "You have been cured of corprus.")
        end
    elseif WorldInstance.data.customVariables.corprusGained == true then
        if tableHelper.containsValue(Players[pid].data.spellbook, corprusId) == false then
            table.insert(Players[pid].data.spellbook, corprusId)

            tes3mp.ClearSpellbookChanges(pid)
            tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.ADD)
            tes3mp.AddSpell(pid, corprusId)
            tes3mp.SendSpellbookChanges(pid)
            tes3mp.MessageBox(pid, -1, "You have been afflicted with corprus.")
        end
    end
end

function contentFixer.AdjustWorldCorprusVariables(journal)
    local madeAdjustment = false

    for _, journalItem in ipairs(journal) do
        if journalItem.quest == "a2_3_corpruscure" and journalItem.index >= 50 then
            WorldInstance.data.customVariables.corprusCured = true
            madeAdjustment = true
        elseif journalItem.quest == "a2_2_6thhouse" and journalItem.index >= 50 then
            WorldInstance.data.customVariables.corprusGained = true
            madeAdjustment = true
        end
    end

    return madeAdjustment
end

---@type TES3MPScriptRegistration
return {
    interface = contentFixer,
    interfaceName = 'contentFixer',
    eventHandlers = {
        OnPlayerFinishLogin = function(_, pid)
            if not config.shareJournal then return end
            contentFixer.AdjustSharedCorprusState(pid)
        end,
        OnPlayerJournal = function(_, pid, playerPacket)
            if not config.shareJournal then return end
            local madeAdjustment = contentFixer.AdjustWorldCorprusVariables(playerPacket.journal)

            if madeAdjustment then
                for otherPid in pairs(Players) do
                    if otherPid ~= pid then
                        contentFixer.AdjustSharedCorprusState(otherPid)
                    end
                end
            end
        end,
        OnWorldReload = function(_)
            if not config.shareJournal then return end
            contentFixer.AdjustWorldCorprusVariables(WorldInstance.data.journal)
        end,
    },
}
