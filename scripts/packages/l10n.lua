local config = require 'config'
local nEnums = require 'packages.networkEnums'
---@type LFSFFIModule
local lfs = require 'lfs'
local yamlInterface = require 'packages.yamlInterface'

local LocalizationPathFormatter = 'custom/%s/l10n/%s.%s'
local ValidYAMLExtensions = { 'yml', 'yaml' }

local LanguageCodes = {
  aa = true,
  ab = true,
  ae = true,
  af = true,
  ak = true,
  am = true,
  an = true,
  ar = true,
  as = true,
  av = true,
  ay = true,
  az = true,
  ba = true,
  be = true,
  bg = true,
  bi = true,
  bm = true,
  bn = true,
  bo = true,
  br = true,
  bs = true,
  ca = true,
  ce = true,
  ch = true,
  co = true,
  cr = true,
  cs = true,
  cu = true,
  cv = true,
  cy = true,
  da = true,
  de = true,
  dv = true,
  dz = true,
  ee = true,
  el = true,
  en = true,
  eo = true,
  es = true,
  et = true,
  eu = true,
  fa = true,
  ff = true,
  fi = true,
  fj = true,
  fo = true,
  fr = true,
  fy = true,
  ga = true,
  gd = true,
  gl = true,
  gn = true,
  gu = true,
  gv = true,
  ha = true,
  he = true,
  hi = true,
  ho = true,
  hr = true,
  ht = true,
  hu = true,
  hy = true,
  hz = true,
  ia = true,
  id = true,
  ie = true,
  ig = true,
  ii = true,
  ik = true,
  io = true,
  is = true,
  it = true,
  iu = true,
  ja = true,
  jv = true,
  ka = true,
  kg = true,
  ki = true,
  kj = true,
  kk = true,
  kl = true,
  km = true,
  kn = true,
  ko = true,
  kr = true,
  ks = true,
  ku = true,
  kv = true,
  kw = true,
  ky = true,
  la = true,
  lb = true,
  lg = true,
  li = true,
  ln = true,
  lo = true,
  lt = true,
  lu = true,
  lv = true,
  mg = true,
  mh = true,
  mi = true,
  mk = true,
  ml = true,
  mn = true,
  mr = true,
  ms = true,
  mt = true,
  my = true,
  na = true,
  nb = true,
  nd = true,
  ne = true,
  ng = true,
  nl = true,
  nn = true,
  no = true,
  nr = true,
  nv = true,
  ny = true,
  oc = true,
  oj = true,
  om = true,
  ['or'] = true,
  os = true,
  pa = true,
  pi = true,
  pl = true,
  ps = true,
  pt = true,
  qu = true,
  rm = true,
  rn = true,
  ro = true,
  ru = true,
  rw = true,
  sa = true,
  sc = true,
  sd = true,
  se = true,
  sg = true,
  si = true,
  sk = true,
  sl = true,
  sm = true,
  sn = true,
  so = true,
  sq = true,
  sr = true,
  ss = true,
  st = true,
  su = true,
  sv = true,
  sw = true,
  ta = true,
  te = true,
  tg = true,
  th = true,
  ti = true,
  tk = true,
  tl = true,
  tn = true,
  to = true,
  tr = true,
  ts = true,
  tt = true,
  tw = true,
  ty = true,
  ug = true,
  uk = true,
  ur = true,
  uz = true,
  ve = true,
  vi = true,
  vo = true,
  wa = true,
  wo = true,
  xh = true,
  yi = true,
  yo = true,
  za = true,
  zh = true,
  zu = true,
}

local Languages = { 'en', }
if LanguageCodes[config.preferredLocale] then
  if config.preferredLocale ~= 'en' then
    table.insert(Languages, 1, config.preferredLocale)
  end
else
  tes3mp.LogAppend(
    nEnums.log.WARN,
    ('The preferred language %s is not a valid ISO country code and so will not be used when searching for localization contexts.')
    :format(config.preferredLocale)
  )
end

---@param contextName string name of the directory in which localization files live, relative to the configured server data directory's l10n folder, eg, `test`, would default to `server/data/test/en.yaml`
---@return L10NSearchFunction l10nContext
return function(contextName)
  local found, yamlInterfacePath

  for _, possibleLanguage in ipairs(Languages) do
    for _, possibleExtension in ipairs(ValidYAMLExtensions) do
      yamlInterfacePath = LocalizationPathFormatter
          :format(
            contextName,
            possibleLanguage,
            possibleExtension
          )

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

  local localizationResult = yamlInterface(yamlInterfacePath)

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
