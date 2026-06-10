local Inventory = require("inventory")

local InvConsole = {}

local TOGGLE_KEY = Key.NUM_EIGHT

local State = {
    active = false,
    buffer = "",
}

function InvConsole.IsActive()
    return State.active
end

function InvConsole.Close()
    if not State.active then
        return
    end
    State.active = false
    State.buffer = ""
    print("[StatEditorMod] Inventory command line closed\n")
end

local function CloseOtherConsoles()
    local OkStat, ChatConsole = pcall(require, "chatconsole")
    if OkStat and ChatConsole.Close then
        ChatConsole.Close()
    end

    local OkLookup, InvLookupConsole = pcall(require, "invlookupconsole")
    if OkLookup and InvLookupConsole.Close then
        InvLookupConsole.Close()
    end
end

local function PrintPrompt()
    local Prompt = State.buffer ~= "" and State.buffer or "(pos count, Enter=run, Esc=close)"
    print(string.format("[StatEditorMod Inv]> %s\n", Prompt))
end

local function Toggle()
    if State.active then
        InvConsole.Close()
        return
    end

    CloseOtherConsoles()
    State.active = true
    State.buffer = ""
    print("[StatEditorMod] Inventory command line open (Numpad 8). Example: 34 55 or 34 -10 + Enter\n")
    Inventory.PrintHelp(nil)
    PrintPrompt()
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
    print(string.format("[StatEditorMod Inv] exec: %s\n", Line))
    Inventory.ExecuteLine(Line, nil)
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
        InvConsole.Close()
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

print("[StatEditorMod] Numpad 8 = inventory commands (34 55, 34 -10)\n")

return InvConsole
