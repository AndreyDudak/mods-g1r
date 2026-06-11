local UEHelpers = require("UEHelpers")

local Scale = {}

local INI_NAME = "MagicScaleMod.ini"

local Config = {
    manaDivisor = 10,
    debugLog = false,
}

local AIGASLibrary = StaticFindObject("/Script/G1R.Default__AIGASLibrary")
local ManaSetClass = StaticFindObject("/Script/G1R.AttributeSet_Mana")

local debugLogCount = 0
local DEBUG_LOG_LIMIT = 8

local function trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function bool(v, default)
    local n = string.upper(trim(v))
    if n == "" then
        return default
    end
    if n == "1" or n == "TRUE" or n == "YES" or n == "ON" then
        return true
    end
    if n == "0" or n == "FALSE" or n == "NO" or n == "OFF" then
        return false
    end
    return default
end

local function num(v, default)
    local n = tonumber(trim(v))
    if n == nil then
        return default
    end
    return n
end

local function scriptDir()
    local ok, info = pcall(function()
        return debug.getinfo(1, "S")
    end)
    if not ok or not info or not info.source then
        return nil
    end
    local src = tostring(info.source)
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    return src:match("^(.*[\\/])[^\\/]*$")
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function iniPaths()
    local paths = {}
    local dir = scriptDir()
    if dir then
        paths[#paths + 1] = dir .. "..\\" .. INI_NAME
        paths[#paths + 1] = dir .. INI_NAME
    end
    paths[#paths + 1] = "ue4ss\\Mods\\MagicScaleMod\\" .. INI_NAME
    paths[#paths + 1] = "Mods\\MagicScaleMod\\" .. INI_NAME
    paths[#paths + 1] = INI_NAME
    return paths
end

local function parseIni(content)
    local t = {}
    for line in string.gmatch(tostring(content or ""), "[^\r\n]+") do
        local s = trim(line)
        if s ~= "" and s:sub(1, 1) ~= ";" and s:sub(1, 1) ~= "#" then
            local k, v = s:match("^([%w_]+)%s*=%s*(.-)%s*$")
            if k then
                t[string.upper(k)] = v
            end
        end
    end
    return t
end

function Scale.ReloadConfig()
    local content
    for _, path in ipairs(iniPaths()) do
        content = readFile(path)
        if content then
            break
        end
    end

    if not content then
        print("[MagicScaleMod] INI not found, using defaults (MaxMana/10).\n")
        return
    end

    local ini = parseIni(content)
    Config.manaDivisor = math.max(0.001, num(ini.MANADIVISOR, Config.manaDivisor))
    Config.debugLog = bool(ini.DEBUGLOG, Config.debugLog)
end

Scale.ReloadConfig()

local function isValid(obj)
    if obj == nil then
        return false
    end
    local ok, valid = pcall(function()
        return obj.IsValid ~= nil and obj:IsValid()
    end)
    return ok and valid
end

function Scale.IsPlayerCharacter(character)
    if not isValid(character) then
        return false
    end

    local ok, player = pcall(function()
        return UEHelpers.GetPlayer()
    end)
    if ok and isValid(player) and player == character then
        return true
    end

    local controlledOk, controlled = pcall(function()
        return character:IsPlayerControlled()
    end)
    return controlledOk and controlled == true
end

function Scale.GetMaxMana(character)
    if not isValid(character) then
        return nil
    end
    if not isValid(AIGASLibrary) or not isValid(ManaSetClass) then
        return nil
    end

    local ok, value = pcall(function()
        return AIGASLibrary:GetAttributeValue(
            character,
            ManaSetClass,
            UEHelpers.FindFName("MaxMana")
        )
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

function Scale.GetDamageMultiplier(character)
    local maxMana = Scale.GetMaxMana(character)
    if maxMana == nil then
        return 1.0, nil
    end
    return maxMana / Config.manaDivisor, maxMana
end

local function scaleDamagesParam(DamagesParam, multiplier)
    if multiplier == 1.0 then
        return true
    end

    local ok, arr = pcall(function()
        return DamagesParam:get()
    end)
    if not ok or type(arr) ~= "table" or #arr == 0 then
        return false
    end

    for i = 1, #arr do
        local v = arr[i]
        if type(v) == "number" then
            arr[i] = v * multiplier
        end
    end

    local setOk = pcall(function()
        DamagesParam:set(arr)
    end)
    return setOk
end

function Scale.ApplyToDamages(DamagesParam, character)
    if not Scale.IsPlayerCharacter(character) then
        return
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(character)
    if multiplier == 1.0 then
        return
    end

    scaleDamagesParam(DamagesParam, multiplier)

    if Config.debugLog and debugLogCount < DEBUG_LOG_LIMIT then
        debugLogCount = debugLogCount + 1
        print(string.format(
            "[MagicScaleMod] scale x%.2f (MaxMana=%.0f / %g)\n",
            multiplier,
            maxMana or -1,
            Config.manaDivisor
        ))
    end
end

return Scale
