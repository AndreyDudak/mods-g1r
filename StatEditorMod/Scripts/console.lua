local Stats = require("stats")
local ModLog = require("modlog")

local Console = {}

local function Log(Message, Ar, Direct)
    local Line = "[StatEditorMod] " .. Message
    ModLog.Write(Line, Direct == true)
    if Ar and type(Ar) == "userdata" and Ar:type() == "FOutputDevice" then
        Ar:Log(Line)
    end
end

local function RunOnGameThread(Name, Fn, Ar)
    ExecuteInGameThread(function()
        local Ok, Err = pcall(Fn)
        if not Ok then
            Log(string.format("%s error: %s", Name, tostring(Err)), Ar)
        end
    end)
end

local function RequirePlayer(Ar, Fn)
    RunOnGameThread("console", function()
        local Character = Stats.GetPlayerCharacter()
        if not Character then
            Log("No player character (load a save first)", Ar)
            return
        end
        Fn(Character, Ar)
    end, Ar)
end

function Console.PrintModGuide(Ar)
    ModLog.BeginBatch()
    Log("--- StatEditorMod ---", Ar)
    Log("Numpad 0: this guide", Ar)
    Log("Numpad 5: <stat> <value> + Enter  (e.g. lp 100)  Esc=close", Ar)
    Log("Numpad 6: dump all stats", Ar)
    Log("Numpad 7: <pos> + Enter — lookup item  (e.g. 18)  Esc=close", Ar)
    Log("Numpad 8: <pos> <count> + Enter  (e.g. 18 55 or 18 -10)  Esc=close", Ar)
    Log("Numpad 9: dump inventory list (open inventory tab first)", Ar)
    Log("Stat aliases: hp/mh, mp/mm, lp/sp, str, dex, lvl, exp/xp, tough, fatigue/mf, circle/magic/mc (0-6)", Ar)
    Log("Inventory pos = footer number (18/334), NOT internal id", Ar)
    Log("After .lua edits: Ctrl+R reloads Lua (full game restart if something breaks)", Ar)
    ModLog.EndBatch()
end

function Console.PrintHelp(Ar)
    Console.PrintModGuide(Ar)
end

local function CollectAllAliases()
    local Seen = {}
    local List = {}

    local function Add(Alias)
        if Alias == nil or Alias == "" or Seen[Alias] then
            return
        end
        Seen[Alias] = true
        table.insert(List, Alias)
    end

    for _, Def in ipairs(Stats.STAT_DEFS) do
        Add(string.lower(Def.label))
    end
    for Alias in pairs(Stats.ALIASES) do
        Add(Alias)
    end

    table.sort(List)
    return List
end

function Console.PrintStatAliases(Ar)
    local Aliases = CollectAllAliases()
    Log(string.format("aliases: %s", table.concat(Aliases, ", ")), Ar)
end

local function HandleSet(StatName, ValueText, Ar)
    local Def = Stats.FindDefByQuery(StatName)
    if not Def then
        Log(string.format("Unknown stat '%s'", StatName), Ar)
        return
    end

    local Value = tonumber(ValueText)
    if Value == nil then
        Log(string.format("Invalid value '%s' for %s", ValueText, Def.label), Ar)
        return
    end

    if Def.label == "MagicianLevel" and (Value < 0 or Value > 6) then
        Log("MagicianLevel (magic circle) must be 0-6", Ar)
        return
    end

    RequirePlayer(Ar, function(Character, Output)
        local Ok, Err = Stats.WriteStat(Character, Def.set, Def.attr, Value)
        if Ok then
            if Def.label == "MagicianLevel" and Err and Err ~= "" then
                Log(string.format("MagicianLevel = %.0f (%s)", Value, Err), Output, true)
            else
                Log(string.format("%s = %.2f", Def.label, Value), Output, true)
            end
            return
        end

        Log(string.format("Write failed for %s: %s", Def.label, Err or "unknown"), Output, true)
    end)
end

function Console.DumpAll(Ar)
    RequirePlayer(Ar, function(Character, Output)
        ModLog.BeginBatch(true)
        Log("--- stats ---", Output, true)
        local Count = 0
        for _, Def in ipairs(Stats.STAT_DEFS) do
            local Value, Err = Stats.ReadStat(Character, Def.set, Def.attr)
            if Value ~= nil then
                Log(string.format("%s = %.2f", Def.label, Value), Output, true)
                Count = Count + 1
            else
                Log(string.format("%s = ? (%s)", Def.label, Err or "read failed"), Output, true)
            end
        end
        Log(string.format("Stats dump: %d values", Count), Output, true)
        ModLog.EndBatch()
    end)
end

function Console.ExecuteLine(Line, Ar)
    Line = string.match(Line or "", "^%s*(.-)%s*$")
    if Line == "" then
        return
    end

    local Parameters = {}
    for Word in string.gmatch(Line, "%S+") do
        table.insert(Parameters, Word)
    end

    if #Parameters ~= 2 then
        Log("Usage: <stat> <value>  e.g. lp 100", Ar)
        return
    end

    HandleSet(Parameters[1], Parameters[2], Ar)
end

local function RegisterAliasHandlers()
    local Registered = {}

    local function RegisterAlias(Name)
        local Key = string.lower(Name)
        if Registered[Key] then
            return
        end
        Registered[Key] = true

        RegisterConsoleCommandGlobalHandler(Key, function(FullCommand, Parameters, Output)
            if #Parameters < 1 then
                Log(string.format("Usage: %s <value>", Key), Output)
                return true
            end
            HandleSet(Key, Parameters[1], Output)
            return true
        end)
    end

    for Alias in pairs(Stats.ALIASES) do
        RegisterAlias(Alias)
    end

    for _, Def in ipairs(Stats.STAT_DEFS) do
        RegisterAlias(Def.label)
    end
end

RegisterAliasHandlers()

return Console
