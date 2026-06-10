local UEHelpers = require("UEHelpers")
local Stats = require("stats")

local Notifications = {}

-- Screen position for mod messages (top-right avoids inventory/stats on the left).
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

local Cache = {
    TextLib = nil,
    MagicLib = nil,
    LayoutLib = nil,
    SimpleTextWidget = nil,
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

local function GetTextLib()
    if IsValidUObject(Cache.TextLib) then
        return Cache.TextLib
    end
    Cache.TextLib = UEHelpers.GetKismetTextLibrary()
    return Cache.TextLib
end

local function GetMagicLib()
    if IsValidUObject(Cache.MagicLib) then
        return Cache.MagicLib
    end
    local Ok, Lib = pcall(function()
        return StaticFindObject("/Script/G1R.Default__MagicScriptLibrary")
    end)
    if Ok and Lib ~= nil then
        Cache.MagicLib = Lib
    end
    return Cache.MagicLib
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

local function MakeAnchors()
    return {
        Minimum = { X = Layout.AnchorMinX, Y = Layout.AnchorMinY },
        Maximum = { X = Layout.AnchorMaxX, Y = Layout.AnchorMaxY },
    }
end

local function MakeVector2D(X, Y)
    return { X = X, Y = Y }
end

local function ApplyCanvasSlotLayout(TargetWidget)
    if not IsValidUObject(TargetWidget) then
        return false
    end

    local LayoutLib = GetLayoutLib()
    if not IsValidUObject(LayoutLib) then
        return false
    end

    local Ok, Slot = pcall(function()
        return LayoutLib:SlotAsCanvasSlot(TargetWidget)
    end)
    if not Ok or not IsValidUObject(Slot) then
        return false
    end

    pcall(function()
        Slot:SetAnchors(MakeAnchors())
        Slot:SetAlignment(MakeVector2D(Layout.AlignX, Layout.AlignY))
        Slot:SetPosition(MakeVector2D(Layout.PosX, Layout.PosY))
        Slot:SetZOrder(Layout.ZOrder)
    end)
    return true
end

local function ApplyViewportLayout(RootWidget)
    if not IsValidUObject(RootWidget) then
        return false
    end

    local Ok = pcall(function()
        RootWidget:SetAnchorsInViewport(MakeAnchors())
        RootWidget:SetAlignmentInViewport(MakeVector2D(Layout.AlignX, Layout.AlignY))
        RootWidget:SetPositionInViewport(MakeVector2D(Layout.PosX, Layout.PosY), false)
    end)
    return Ok
end

local function ConfigureTextBlock(TextBlock)
    if not IsValidUObject(TextBlock) then
        return
    end

    pcall(function()
        TextBlock:SetAutoWrapText(true)
        TextBlock:SetMinDesiredWidth(520.0)
        TextBlock:SetJustification(0)
    end)

    local LayoutLib = GetLayoutLib()
    if not IsValidUObject(LayoutLib) then
        return
    end

    local Ok, Slot = pcall(function()
        return LayoutLib:SlotAsCanvasSlot(TextBlock)
    end)
    if Ok and IsValidUObject(Slot) then
        pcall(function()
            Slot:SetSize(MakeVector2D(520.0, 420.0))
        end)
    end
end

local function ApplyMessageLayout(Widget)
    if not IsValidUObject(Widget) then
        return
    end

    ApplyViewportLayout(Widget)

    local TextBlock = SafeGet(Widget, "TextBlock_Message")
    if ApplyCanvasSlotLayout(TextBlock) then
        ConfigureTextBlock(TextBlock)
        return
    end

    ApplyCanvasSlotLayout(Widget)
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

local function GetSimpleTextWidget()
    if IsValidUObject(Cache.SimpleTextWidget) then
        return Cache.SimpleTextWidget
    end

    local Ok, GothicHUD = pcall(function()
        return FindFirstOf("GothicHUD")
    end)
    if Ok and IsValidUObject(GothicHUD) then
        local Controller = SafeGet(GothicHUD, "HUDSimpleTextMessageController")
        if IsValidUObject(Controller) then
            local Widget = SafeGet(Controller, "m_Widget")
            if IsValidUObject(Widget) then
                Cache.SimpleTextWidget = Widget
                return Widget
            end
        end
    end

    local WidgetOk, Widget = pcall(function()
        return FindFirstOf("W_SimpleTextMessage_C")
    end)
    if WidgetOk and IsValidUObject(Widget) then
        Cache.SimpleTextWidget = Widget
        return Widget
    end

    return nil
end

local function TryShowSimpleTextWidget(Message)
    local Widget = GetSimpleTextWidget()
    if not Widget then
        return false
    end

    local Text = ToDisplayText(Message)
    if Text == nil then
        return false
    end

    local Ok = pcall(function()
        ApplyMessageLayout(Widget)
        Widget:ShowSimpleTextMessage(Text)
        ApplyMessageLayout(Widget)
    end)
    return Ok
end

local function TryShowClientMessage(Message)
    local PC = Stats.GetPlayerController()
    if not IsValidUObject(PC) then
        return false
    end

    local Ok = pcall(function()
        PC:ClientMessage(Message, "All", 4.0)
    end)
    return Ok
end

local function TryShowDebugPrint(Message)
    local MagicLib = GetMagicLib()
    if not IsValidUObject(MagicLib) then
        return false
    end

    local Ok = pcall(function()
        MagicLib:DebugPrintMessage(Message, { R = 1.0, G = 0.9, B = 0.4, A = 1.0 })
    end)
    return Ok
end

local function TryShowInternal(Message)
    if Message == nil or Message == "" then
        return
    end

    if TryShowSimpleTextWidget(Message) then
        return
    end
    if TryShowClientMessage(Message) then
        return
    end
    TryShowDebugPrint(Message)
end

function Notifications.TryShow(Message)
    ExecuteInGameThread(function()
        pcall(TryShowInternal, Message)
    end)
end

function Notifications.ClearCache()
    Cache.SimpleTextWidget = nil
    Cache.LayoutLib = nil
end

return Notifications
