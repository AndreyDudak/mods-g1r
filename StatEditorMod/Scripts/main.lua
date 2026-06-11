-- StatEditorMod: Numpad 0=guide | 5=stats | 6=dump stats | 7=slot | 8=inv edit | 9=inv list

local Stats = require("stats")
local Console = require("console")
local Inventory = require("inventory")
local ModLog = require("modlog")
local Notifications = require("notifications")
require("chatconsole")
require("invlookupconsole")
require("invconsole")

RegisterKeyBind(Key.NUM_ZERO, function()
    Console.PrintModGuide(nil)
end)

RegisterKeyBind(Key.NUM_SIX, function()
    Console.DumpAll(nil)
end)

RegisterKeyBind(Key.NUM_NINE, function()
    Inventory.DumpPosList(nil)
end)

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    local Controller = self:get()
    local Pawn = NewPawn:get()
    ExecuteInGameThread(function()
        Stats.SetPlayerCache(Controller, Pawn)
        Notifications.ClearCache()
    end)
end)

RegisterLoadMapPostHook(function()
    ExecuteInGameThread(function()
        Stats.ClearPlayerCache()
        Notifications.ClearCache()
    end)
end)

ModLog.Write("[StatEditorMod] Numpad0=guide, Numpad6=stats, Numpad9=inv list, Numpad7=pos, Numpad8=inv")
