local UEHelpers = require("UEHelpers")
local Stats = require("stats")

local Notifications = {}

local Layout = {
    AnchorMinX = 1.0,
    AnchorMinY = 0.0,
    AnchorMaxX = 1.0,
    AnchorMaxY = 0.0,
    AlignX = 1.0,
    AlignY = 0.0,
    PosX = -48.0,
    PosY = 120.0,
    ZOrder = 200,
}

local WARMUP_INTERVAL_MS = 250
local WARMUP_MAX_ATTEMPTS = 24

local Cache = {
    TextLib = nil,
    LayoutLib = nil,
    LayoutApplied = false,
    SimpleTextWidget = nil,
    WarmupRunning = false,
    WarnedNotReady = false,
}

local function IsValidUObject(Obj)
    if Obj == nil then
        return false
    end
    local Ok, Valid = pcall(function()
        return Obj:IsValid()
    end)
    return Ok and Valid
end

local function IsLiveUObject(Obj)
    if not IsValidUObject(Obj) then
        return false
    end
    local Ok, Name = pcall(function()
        return Obj:GetFullName()
    end)
    if Ok and Name and string.find(Name, "Default__", 1, true) then
        return false
    end
    return true
end

local function SafeGet(Obj, Key)
    if Obj == nil then
        return nil
    end
    local Ok, Value = pcall(function()
        return Obj[Key]
    end)
    if Ok then
        return Value
    end
    return nil
end

local function WidgetFromController(Controller)
    if not IsLiveUObject(Controller) then
        return nil
    end
    return SafeGet(Controller, "m_Widget")
end

local function WidgetFromGothicHUD(GothicHUD)
    if not IsLiveUObject(GothicHUD) then
        return nil
    end
    return WidgetFromController(SafeGet(GothicHUD, "HUDSimpleTextMessageController"))
end

local function GetTextLib()
    if IsValidUObject(Cache.TextLib) then
        return Cache.TextLib
    end
    Cache.TextLib = UEHelpers.GetKismetTextLibrary()
    return Cache.TextLib
end

local function GetLayoutLib()
    if IsValidUObject(Cache.LayoutLib) then
        return Cache.LayoutLib
    end
    local Ok, Lib = pcall(function()
        return StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    end)
    if Ok and Lib ~= nil then
        Cache.LayoutLib = Lib
    end
    return Cache.LayoutLib
end

local function ApplyTextBlockLayoutOnce(TextBlock)
    if Cache.LayoutApplied or not IsValidUObject(TextBlock) then
        return
    end

    local LayoutLib = GetLayoutLib()
    if not IsValidUObject(LayoutLib) then
        return
    end

    local Ok, Slot = pcall(function()
        return LayoutLib:SlotAsCanvasSlot(TextBlock)
    end)
    if not Ok or not IsValidUObject(Slot) then
        return
    end

    pcall(function()
        Slot:SetAnchors({
            Minimum = { X = Layout.AnchorMinX, Y = Layout.AnchorMinY },
            Maximum = { X = Layout.AnchorMaxX, Y = Layout.AnchorMaxY },
        })
        Slot:SetAlignment({ X = Layout.AlignX, Y = Layout.AlignY })
        Slot:SetPosition({ X = Layout.PosX, Y = Layout.PosY })
        Slot:SetZOrder(Layout.ZOrder)
        TextBlock:SetAutoWrapText(true)
        TextBlock:SetMinDesiredWidth(520.0)
        TextBlock:SetJustification(0)
    end)
    Cache.LayoutApplied = true
end

local function ToDisplayText(Message)
    local TextLib = GetTextLib()
    if not TextLib then
        return nil
    end
    local Ok, Text = pcall(function()
        return TextLib:Conv_StringToText(Message)
    end)
    if Ok then
        return Text
    end
    return nil
end

local function ResolveSimpleTextWidget()
    if IsLiveUObject(Cache.SimpleTextWidget) then
        return Cache.SimpleTextWidget
    end
    Cache.SimpleTextWidget = nil

    local PC = Stats.GetPlayerController()
    if IsLiveUObject(PC) then
        local HudOk, GothicHUD = pcall(function()
            return PC:GetGothicHUD()
        end)
        if HudOk then
            local Widget = WidgetFromGothicHUD(GothicHUD)
            if IsLiveUObject(Widget) then
                Cache.SimpleTextWidget = Widget
                return Widget
            end
        end
    end

    local Ok, GothicHUD = pcall(function()
        return FindFirstOf("GothicHUD")
    end)
    if Ok then
        local Widget = WidgetFromGothicHUD(GothicHUD)
        if IsLiveUObject(Widget) then
            Cache.SimpleTextWidget = Widget
            return Widget
        end
    end

    local ControllerOk, Controller = pcall(function()
        return FindFirstOf("HUDSimpleTextMessageController")
    end)
    if ControllerOk then
        local Widget = WidgetFromController(Controller)
        if IsLiveUObject(Widget) then
            Cache.SimpleTextWidget = Widget
            return Widget
        end
    end

    local WidgetOk, Widget = pcall(function()
        return FindFirstOf("W_SimpleTextMessage_C")
    end)
    if WidgetOk and IsLiveUObject(Widget) then
        Cache.SimpleTextWidget = Widget
        return Widget
    end

    return nil
end

local function TryShowSimpleTextWidget(Message)
    local Widget = ResolveSimpleTextWidget()
    if not Widget then
        return false
    end

    local Text = ToDisplayText(Message)
    if Text == nil then
        return false
    end

    local Ok = pcall(function()
        Widget:ShowSimpleTextMessage(Text)
    end)
    if Ok then
        Cache.WarnedNotReady = false
        ApplyTextBlockLayoutOnce(SafeGet(Widget, "TextBlock_Message"))
    end
    return Ok
end

local function TryShowInternal(Message)
    if Message == nil or Message == "" then
        return
    end

    if TryShowSimpleTextWidget(Message) then
        return
    end

    if not Cache.WarnedNotReady then
        Cache.WarnedNotReady = true
        print("[StatEditorMod][HUD] widget not ready yet (retrying in background)\n")
    end
    Notifications.Warmup()
end

function Notifications.TryShow(Message)
    pcall(TryShowInternal, Message)
end

local function WarmupTick()
    local Widget = ResolveSimpleTextWidget()
    return Widget ~= nil
end

function Notifications.Warmup()
    if Cache.WarmupRunning then
        return
    end

    Cache.WarmupRunning = true
    local Attempts = 0

    local function Step()
        ExecuteInGameThread(function()
            Attempts = Attempts + 1
            if WarmupTick() or Attempts >= WARMUP_MAX_ATTEMPTS then
                Cache.WarmupRunning = false
                return
            end

            if type(LoopAsync) ~= "function" then
                Cache.WarmupRunning = false
                return
            end

            LoopAsync(WARMUP_INTERVAL_MS, function()
                Step()
                return true
            end)
        end)
    end

    Step()
end

function Notifications.ClearCache()
    Cache.SimpleTextWidget = nil
    Cache.LayoutLib = nil
    Cache.LayoutApplied = false
    Cache.WarmupRunning = false
    Cache.WarnedNotReady = false
end

return Notifications
