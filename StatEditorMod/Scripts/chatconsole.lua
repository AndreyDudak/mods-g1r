local Console = require("console")
local ModLog = require("modlog")

local ChatConsole = {}

local TOGGLE_KEY = Key.NUM_FIVE

local State = {
    active = false,
    buffer = "",
}

function ChatConsole.IsActive()
    return State.active
end

function ChatConsole.Close()
    if not State.active then
        return
    end
    State.active = false
    State.buffer = ""
    ModLog.Write("[StatEditorMod] Command line closed")
end

local function CloseOtherConsoles()
    local OkInv, InvConsole = pcall(require, "invconsole")
    if OkInv and InvConsole.Close then
        InvConsole.Close()
    end

    local OkLookup, InvLookupConsole = pcall(require, "invlookupconsole")
    if OkLookup and InvLookupConsole.Close then
        InvLookupConsole.Close()
    end
end

local function PrintPrompt()
    local Prompt = State.buffer ~= "" and State.buffer or "(type command, Enter=run, Esc=close)"
    ModLog.Write(string.format("[StatEditorMod Cmd]> %s", Prompt))
end

local function Toggle()
    if State.active then
        ChatConsole.Close()
        return
    end

    CloseOtherConsoles()
    State.active = true
    State.buffer = ""
    ModLog.BeginBatch()
    ModLog.Write("[StatEditorMod] Command line open (Numpad 5). Example: lp 100 + Enter, Esc=close")
    Console.PrintStatAliases(nil)
    ModLog.Write("[StatEditorMod Cmd]> (type command, Enter=run, Esc=close)")
    ModLog.EndBatch()
end

local function RequireActive(Fn)
    if not State.active then
        return
    end
    Fn()
end

local function AppendText(Text)
    State.buffer = State.buffer .. Text
    PrintPrompt()
end

local function Backspace()
    if State.buffer == "" then
        return
    end
    State.buffer = string.sub(State.buffer, 1, -2)
    PrintPrompt()
end

local function Execute()
    local Line = State.buffer
    State.buffer = ""
    ModLog.Write(string.format("[StatEditorMod Cmd] exec: %s", Line))
    Console.ExecuteLine(Line, nil)
    if State.active then
        PrintPrompt()
    end
end

RegisterKeyBind(TOGGLE_KEY, Toggle)

RegisterKeyBind(Key.RETURN, function()
    RequireActive(Execute)
end)

RegisterKeyBind(Key.ESCAPE, function()
    if State.active then
        ChatConsole.Close()
    end
end)

RegisterKeyBind(Key.BACKSPACE, function()
    RequireActive(Backspace)
end)

RegisterKeyBind(Key.SPACE, function()
    RequireActive(function()
        AppendText(" ")
    end)
end)

RegisterKeyBind(Key.OEM_MINUS, function()
    RequireActive(function()
        AppendText("-")
    end)
end)

RegisterKeyBind(Key.OEM_PERIOD, function()
    RequireActive(function()
        AppendText(".")
    end)
end)

local LetterKeys = {
    { Key.A, "a" }, { Key.B, "b" }, { Key.C, "c" }, { Key.D, "d" }, { Key.E, "e" },
    { Key.F, "f" }, { Key.G, "g" }, { Key.H, "h" }, { Key.I, "i" }, { Key.J, "j" },
    { Key.K, "k" }, { Key.L, "l" }, { Key.M, "m" }, { Key.N, "n" }, { Key.O, "o" },
    { Key.P, "p" }, { Key.Q, "q" }, { Key.R, "r" }, { Key.S, "s" }, { Key.T, "t" },
    { Key.U, "u" }, { Key.V, "v" }, { Key.W, "w" }, { Key.X, "x" }, { Key.Y, "y" },
    { Key.Z, "z" },
}

for _, Entry in ipairs(LetterKeys) do
    RegisterKeyBind(Entry[1], function()
        RequireActive(function()
            AppendText(Entry[2])
        end)
    end)
end

local DigitKeys = {
    { Key.ZERO, "0" }, { Key.ONE, "1" }, { Key.TWO, "2" }, { Key.THREE, "3" },
    { Key.FOUR, "4" }, { Key.FIVE, "5" }, { Key.SIX, "6" }, { Key.SEVEN, "7" },
    { Key.EIGHT, "8" }, { Key.NINE, "9" },
}

for _, Entry in ipairs(DigitKeys) do
    RegisterKeyBind(Entry[1], function()
        RequireActive(function()
            AppendText(Entry[2])
        end)
    end)
end

ModLog.Write("[StatEditorMod] Numpad 5 = command line (lp 100), Numpad 0 = mod guide")

return ChatConsole
