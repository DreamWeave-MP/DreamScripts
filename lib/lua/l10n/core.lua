local config = require 'tes3mp.config'
local enumerations = require 'tes3mp.enumerations'
local languageCodes = require 'l10n.languageCodes'
local yamlInterface = require 'yamlInterface'

---@type LFSFFIModule
local lfs = require 'lfs'

local LocalizationPathFormatter = 'l10n/%s/%s.%s'
local ValidYAMLExtensions = { 'yml', 'yaml' }

---@param contextName string name of the directory in which localization files live, relative to the configured server data directory's l10n folder, eg, `test`, would default to `server/data/test/en.yaml`
---@return L10NSearchFunction l10nContext
return function(contextName)
  local found, yamlInterfacePath

  local languages = { 'en', }
  if languageCodes[config.preferredLocale] then
    if config.preferredLocale ~= 'en' then
      table.insert(languages, 1, config.preferredLocale)
    end
  else
    tes3mp.LogAppend(
      enumerations.log.WARN,
      ('The preferred language %s is not a valid ISO country code and so will not be used when searching localization contexts for %s.')
      :format(config.preferredLocale, contextName)
    )
  end

  for _, possibleLanguage in ipairs(languages) do
    for _, possibleExtension in ipairs(ValidYAMLExtensions) do
      yamlInterfacePath = LocalizationPathFormatter
          :format(
            contextName,
            possibleLanguage,
            possibleExtension
          )

      print('Searching for localization module at', yamlInterfacePath)
      local attributes = lfs.attributes(('%s/%s'):format(config.dataPath, yamlInterfacePath))

      if attributes and attributes.mode == 'file' then
        found = true
        break
      end
    end
  end

  if not found then
    error(
      ('Could not find a valid localization context matching: %s')
      :format(contextName)
    )
  end

  local localizationResult = assert(yamlInterface(yamlInterfacePath))

  local function searcher(fieldName, params)
    if type(localizationResult[fieldName]) ~= 'string' then return fieldName end

    local template = localizationResult[fieldName] or fieldName

    if not params or type(params) ~= 'table' or not template:match('{.-}') then
      return template
    end

    local result, _ = template:gsub('{(.-)}', function(key)
      local cleanKey = key:match('^%s*(.-)%s*$')

      local foundParam = params[cleanKey]

      if foundParam then
        return tostring(foundParam)
      end

      return ('{%s}'):format(key)
    end)

    return result
  end

  return searcher
end
