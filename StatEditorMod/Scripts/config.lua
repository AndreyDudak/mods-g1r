local Config = {}

local INI_NAME = "StatEditorMod.ini"

local function Trim(Text)
    return tostring(Text or ""):match("^%s*(.-)%s*$")
end

local function ParseBool(Value, Default)
    local Normalized = string.upper(Trim(Value))
    if Normalized == "" then
        return Default
    end
    if Normalized == "1" or Normalized == "TRUE" or Normalized == "YES" or Normalized == "ON" then
        return true
    end
    if Normalized == "0" or Normalized == "FALSE" or Normalized == "NO" or Normalized == "OFF" then
        return false
    end
    return Default
end

local function ScriptDir()
    local Ok, Info = pcall(function()
        return debug.getinfo(1, "S")
    end)
    if not Ok or not Info or not Info.source then
        return nil
    end
    local Source = tostring(Info.source)
    if Source:sub(1, 1) == "@" then
        Source = Source:sub(2)
    end
    return Source:match("^(.*[\\/])[^\\/]*$")
end

local function ReadFile(Path)
    local File = io.open(Path, "r")
    if not File then
        return nil
    end
    local Content = File:read("*a")
    File:close()
    return Content
end

local function IniPaths()
    local Paths = {}
    local Dir = ScriptDir()
    if Dir then
        table.insert(Paths, Dir .. "..\\" .. INI_NAME)
        table.insert(Paths, Dir .. INI_NAME)
    end
    table.insert(Paths, "ue4ss\\Mods\\StatEditorMod\\" .. INI_NAME)
    table.insert(Paths, "Mods\\StatEditorMod\\" .. INI_NAME)
    table.insert(Paths, INI_NAME)
    return Paths
end

local function ParseIni(Content)
    local Values = {}
    for Line in string.gmatch(tostring(Content or ""), "[^\r\n]+") do
        local Stripped = Trim(Line)
        if Stripped ~= "" and Stripped:sub(1, 1) ~= ";" and Stripped:sub(1, 1) ~= "#" then
            local Key, Value = Stripped:match("^([%w_]+)%s*=%s*(.-)%s*$")
            if Key then
                Values[string.upper(Key)] = Value
            end
        end
    end
    return Values
end

Config.ShowInGameHud = true

function Config.Load()
    local Content = nil
    for _, Path in ipairs(IniPaths()) do
        Content = ReadFile(Path)
        if Content then
            break
        end
    end

    if not Content then
        print("[StatEditorMod] " .. INI_NAME .. " not found -> using defaults (ShowInGameHud=true)\n")
        return
    end

    local Ini = ParseIni(Content)
    Config.ShowInGameHud = ParseBool(Ini.SHOWINGAMEHUD, Config.ShowInGameHud)
end

function Config.IsInGameHudEnabled()
    return Config.ShowInGameHud ~= false
end

Config.Load()

return Config
