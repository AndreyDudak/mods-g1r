-- StatEditorMod: Numpad 0=guide | ./= HUD toggle | 5=stats | 6=dump | 7=slot | 8=inv | 9=list

local Stats = require("stats")
local Console = require("console")
local Inventory = require("inventory")
local ModLog = require("modlog")
local Notifications = require("notifications")
require("chatconsole")
require("invlookupconsole")
require("invconsole")

local function OnGameThread(Fn)
    ExecuteInGameThread(function()
        pcall(Fn)
    end)
end

RegisterKeyBind(Key.NUM_ZERO, function()
    OnGameThread(function()
        Console.PrintModGuide(nil)
    end)
end)

local function ToggleHudMessages()
    OnGameThread(function()
        ModLog.ToggleHud()
    end)
end

RegisterKeyBind(Key.DECIMAL, ToggleHudMessages)
RegisterKeyBind(Key.DIVIDE, ToggleHudMessages)

RegisterKeyBind(Key.NUM_SIX, function()
    OnGameThread(function()
        Console.DumpAll(nil)
    end)
end)

RegisterKeyBind(Key.NUM_NINE, function()
    OnGameThread(function()
        Inventory.DumpPosList(nil)
    end)
end)

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    local Controller = self:get()
    local Pawn = NewPawn:get()
    ExecuteInGameThread(function()
        Stats.SetPlayerCache(Controller, Pawn)
        Notifications.ClearCache()
        Notifications.Warmup()
    end)
end)

RegisterLoadMapPostHook(function()
    ExecuteInGameThread(function()
        Stats.ClearPlayerCache()
        Notifications.ClearCache()
        Notifications.Warmup()
    end)
end)

ModLog.Write("[StatEditorMod] Numpad0=guide, Numpad ./ = HUD on/off, Numpad6=stats, Numpad9=inv list, Numpad7=pos, Numpad8=inv")
