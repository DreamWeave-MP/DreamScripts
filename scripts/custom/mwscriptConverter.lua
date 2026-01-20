local enumerations = require 'tes3mp.enumerations'
local jsonInterface = require 'jsonInterface'

---@type LFSFFIModule
local lfs = require 'lfs'
local tableHelper = require 'tes3mp.util.table'

local scriptConvertMethods = {}
local ScriptRecordStore = RecordStores.script

local ScriptList = jsonInterface.load 'custom/mwScriptList.json' or {}

local function updateList()
	jsonInterface.save('custom/mwScriptList.json', ScriptList)
end

local function mwScriptPath(fileName)
	return ('%s/custom/MWScripts/%s.es3'):format(tes3mp.GetDataPath(), fileName)
end

function scriptConvertMethods.readAllLines(fileName)
	local filePath = mwScriptPath(fileName)
	local attributes = lfs.attributes(filePath)

	if not attributes or attributes.mode ~= 'file' then return end

	local lines = {}

	for line in io.lines(filePath) do
		lines[#lines + 1] = line
	end

	return lines
end

function scriptConvertMethods.createScriptRecord(pid, scriptName)
	local lines = scriptConvertMethods.readAllLines(scriptName)

	if not lines then return end

	local scriptToAdd = ''

	for _, v in pairs(lines) do
		scriptToAdd = scriptToAdd .. v .. '\n'
	end

	local scriptTable = {}

	scriptTable.scriptText = scriptToAdd

	scriptConvertMethods.push(pid, scriptName, scriptTable)

	ScriptRecordStore.data.permanentRecords[scriptName] = scriptTable

	ScriptRecordStore:QuicksaveToDrive()

	return scriptTable
end

function scriptConvertMethods.dumpScripts(pid)
	for _, scriptFile in pairs(ScriptList) do
		local fileName = mwScriptPath(scriptFile)

		tes3mp.LogAppend(enumerations.log.WARN, 'Dumping: ' .. fileName)

		scriptConvertMethods.createScriptRecord(pid, fileName)
	end
end

function scriptConvertMethods.insertScript(pid, cmd)
	local scriptName = cmd[2]

	if not scriptName then return tes3mp.SendMessage(pid, 'No script provided.') end

	tes3mp.LogAppend(enumerations.log.WARN, 'Checking Script: ' .. scriptName)

	local filePath = mwScriptPath(scriptName)
	local attributes = lfs.attributes(filePath)

	if not attributes or attributes.mode ~= 'file' then
		return tes3mp.SendMessage(pid, 'Script does not exist. Please check your spelling and case sensitivity.')
	end

	tableHelper.insertValueIfMissing(ScriptList, scriptName)

	updateList()

	local scriptTable = scriptConvertMethods.createScriptRecord(pid, scriptName)

	scriptConvertMethods.push(pid, scriptName, scriptTable)
end

function scriptConvertMethods.push(pid, scriptName, scriptTable)
	tes3mp.LogAppend(
		enumerations.log.WARN,
		'Attempting to push script: %s\nWith scriptText:'
	)

	tes3mp.ClearRecords()

	tes3mp.SetRecordType(enumerations.recordType.SCRIPT)

	tes3mp.SetRecordId(scriptName)

	tes3mp.SetRecordScriptText(scriptTable.scriptText)

	tes3mp.AddRecord()

	tes3mp.SendRecordDynamic(pid, true, false)
end

---@type TES3MPScriptRegistration
return {
	chatCommands = {
		dump = { callback = scriptConvertMethods.dumpScripts, rankRequirement = enumerations.staffRank.ADMIN, },
		newScript = { callback = scriptConvertMethods.insertScript, rankRequirement = enumerations.staffRank.ADMIN, },
	},
}
