local Inventory = require("inventory")

local InvLookupConsole = {}

local TOGGLE_KEY = Key.NUM_SEVEN

local State = {
    active = false,
    buffer = "",
}

function InvLookupConsole.IsActive()
    return State.active
end

function InvLookupConsole.Close()
    if not State.active then
        return
    end
    State.active = false
    State.buffer = ""
    print("[StatEditorMod] Slot lookup line closed\n")
end

local function CloseOtherConsoles()
    local OkStat, ChatConsole = pcall(require, "chatconsole")
    if OkStat and ChatConsole.Close then
        ChatConsole.Close()
    end

    local OkInv, InvConsole = pcall(require, "invconsole")
    if OkInv and InvConsole.Close then
        InvConsole.Close()
    end
end

local function PrintPrompt()
    local Prompt = State.buffer ~= "" and State.buffer or "(slot number, Enter=lookup, Esc=close)"
    print(string.format("[StatEditorMod Slot]> %s\n", Prompt))
end

local function Toggle()
    if State.active then
        InvLookupConsole.Close()
        return
    end

    CloseOtherConsoles()
    State.active = true
    State.buffer = ""
    print("[StatEditorMod] Slot lookup open (Numpad 7). Example: 34 + Enter\n")
    Inventory.PrintLookupHelp(nil)
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
    print(string.format("[StatEditorMod Slot] exec: %s\n", Line))
    Inventory.ExecuteLookupLine(Line, nil)
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
        InvLookupConsole.Close()
    end
end)

RegisterKeyBind(Key.BACKSPACE, function()
    RequireActive(Backspace)
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

print("[StatEditorMod] Numpad 9 = inv pos list, Numpad 7 = lookup by pos\n")

return InvLookupConsole
