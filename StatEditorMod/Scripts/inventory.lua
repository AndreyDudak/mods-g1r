local Stats = require("stats")
local ModLog = require("modlog")

local Inventory = {}

local DataModuleLibrary = StaticFindObject("/Script/G1R.Default__DataModuleLibrary")
local AIInventoryLibrary = StaticFindObject("/Script/G1R.Default__AIInventoryLibrary")

local INVENTORY_MAIN = 1 -- EInventoryTypes::MainContainer
local DEFAULT_SLOT_COUNT = 334

-- Inventory footer shows 1-based slot numbers (e.g. 18/334).
local UI_POS_OFFSET = 1

local function UserPosToApiPos(UserPos)
    return UserPos - UI_POS_OFFSET
end

local function ApiPosToUserPos(ApiPos)
    return ApiPos + UI_POS_OFFSET
end

local function Log(Message, Ar)
    local Line = "[StatEditorMod Inv] " .. Message
    ModLog.Write(Line)
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

local function SafeGetMember(Obj, Key)
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

local function SafeCallMethod(Obj, Method, ...)
    if Obj == nil then
        return nil
    end
    local Args = { ... }
    local Ok, Result = pcall(function()
        return Obj[Method](Obj, table.unpack(Args))
    end)
    if Ok then
        return Result
    end
    return nil
end

local function GetContainerModule(Character)
    if not IsValidUObject(DataModuleLibrary) then
        return nil
    end
    if not IsValidUObject(Character) then
        return nil
    end

    local Container = SafeCallMethod(DataModuleLibrary, "GetContainerDataModule", Character)
    if IsValidUObject(Container) then
        return Container
    end
    return nil
end

local function GetInventoryComponent(Character)
    if not IsValidUObject(Character) then
        return nil
    end

    local Inv = SafeCallMethod(Character, "GetInventory")
    if IsValidUObject(Inv) then
        return Inv
    end

    local State = Stats.GetCharacterState(Character)
    if State then
        Inv = SafeCallMethod(State, "GetInventory")
        if IsValidUObject(Inv) then
            return Inv
        end

        Inv = SafeGetMember(State, "InventoryComponent")
        if IsValidUObject(Inv) then
            return Inv
        end
    end

    return nil
end

local function AddItemsToCharacter(Character, ItemClass, Count)
    local Inv = GetInventoryComponent(Character)
    if Inv then
        local Ok, Err = pcall(function()
            Inv:AddItemOfClass(ItemClass, Count)
        end)
        if Ok then
            return true, "InventoryComponent"
        end
        return false, tostring(Err)
    end

    if IsValidUObject(AIInventoryLibrary) then
        local Ok, Err = pcall(function()
            AIInventoryLibrary:AddItem(Character, ItemClass, Count)
        end)
        if Ok then
            return true, "AIInventoryLibrary"
        end
        return false, tostring(Err)
    end

    return false, "no inventory access"
end

local function RemoveItemsFromCharacter(Character, ItemClass, Count)
    local Inv = GetInventoryComponent(Character)
    if Inv then
        local Removed = 0
        local Ok, Err = pcall(function()
            Removed = Inv:RemoveItemOfClass(ItemClass, Count)
        end)
        if Ok then
            return true, Removed, "InventoryComponent"
        end
        return false, 0, tostring(Err)
    end

    if IsValidUObject(AIInventoryLibrary) then
        local Removed = 0
        local Ok, Err = pcall(function()
            Removed = AIInventoryLibrary:RemoveItem(Character, ItemClass, Count)
        end)
        if Ok then
            return true, Removed, "AIInventoryLibrary"
        end
        return false, 0, tostring(Err)
    end

    return false, 0, "no inventory access"
end

local function ReadItemClass(SlotData)
    if not SlotData then
        return nil
    end

    local Ok, ItemClass = pcall(function()
        return SlotData.m_ItemDefinition
    end)
    if Ok and ItemClass and ItemClass:IsValid() then
        return ItemClass
    end
    return nil
end

local function ReadItemCount(SlotData)
    if not SlotData then
        return 0
    end

    local Ok, Count = pcall(function()
        return SlotData.m_ItemCount
    end)
    if Ok and type(Count) == "number" then
        return Count
    end
    return 0
end

local function ReadItemId(Item)
    local Ok, Id = pcall(function()
        return Item.m_Id
    end)
    if Ok and type(Id) == "number" then
        return Id
    end
    return nil
end

local function IsParamWrapper(Value)
    if type(Value) ~= "userdata" or not Value.type then
        return false
    end

    local Ok, ValueType = pcall(function()
        return Value:type()
    end)
    if not Ok or not ValueType then
        return false
    end

    return ValueType == "RemoteUnrealParam" or ValueType == "LocalUnrealParam"
end

local function UnwrapValue(Value)
    if Value == nil then
        return nil
    end
    if IsParamWrapper(Value) then
        local Ok, Unwrapped = pcall(function()
            return Value:get()
        end)
        if Ok and Unwrapped ~= nil then
            return UnwrapValue(Unwrapped)
        end
    end
    return Value
end

local function ReadSlotData(Item)
    if not Item then
        return nil
    end

    local Ok, SlotData = pcall(function()
        return Item.m_SlotData
    end)
    if Ok then
        return SlotData
    end
    return nil
end

local function GetArrayLength(Items)
    if Items == nil then
        return 0
    end

    local Ok, Count = pcall(function()
        return Items:GetArrayNum()
    end)
    if Ok and type(Count) == "number" then
        return Count
    end

    if type(Items) == "table" then
        return #Items
    end
    return 0
end

local function GetArrayElement(Items, Index)
    local Ok, Element = pcall(function()
        return Items[Index]
    end)
    if Ok then
        return UnwrapValue(Element)
    end

    if type(Items) == "table" then
        return UnwrapValue(Items[Index + 1])
    end
    return nil
end

local function IterateItems(Items, Visitor)
    if Items == nil then
        return
    end

    local function Visit(Index, RawItem)
        local Item = UnwrapValue(RawItem)
        if Item then
            return Visitor(Index, Item)
        end
        return false
    end

    if type(Items) == "table" and SafeGetMember(Items, "GetArrayNum") == nil then
        for Index, RawItem in ipairs(Items) do
            if Visit(Index - 1, RawItem) then
                return
            end
        end
        return
    end

    local Count = GetArrayLength(Items)
    if Count > 0 then
        for Index = 0, Count - 1 do
            local ItemOk, RawItem = pcall(function()
                return Items[Index]
            end)
            if ItemOk and Visit(Index, RawItem) then
                return
            end
        end
        return
    end

    if type(Items) == "table" then
        for Index, RawItem in ipairs(Items) do
            if Visit(Index - 1, RawItem) then
                return
            end
        end
    end
end

local function GetItemClassName(ItemClass)
    local Ok, Name = pcall(function()
        return ItemClass:GetFullName()
    end)
    if Ok and Name then
        return Name
    end
    return "ItemDefinition"
end

-- GetBaseConfigByPos returns ItemDefinition object; AddItemOfClass wants UClass.
local function ToItemDefinitionClass(ItemDefOrClass)
    if ItemDefOrClass == nil then
        return nil
    end

    local Ok, UClass = pcall(function()
        return ItemDefOrClass:GetClass()
    end)
    if Ok and UClass then
        local ValidOk, Valid = pcall(function()
            return UClass:IsValid()
        end)
        if ValidOk and Valid then
            return UClass
        end
    end

    local ValidOk, Valid = pcall(function()
        return ItemDefOrClass:IsValid()
    end)
    if ValidOk and Valid then
        return ItemDefOrClass
    end

    return nil
end

local function GetShortClassName(FullName)
    if not FullName then
        return "ItemDefinition"
    end
    local Short = string.match(FullName, "%.([^%.]+)$")
    return Short or FullName
end

local function TextToString(Text)
    if not Text then
        return nil
    end
    local Ok, Str = pcall(function()
        if Text.ToString then
            return Text:ToString()
        end
        return tostring(Text)
    end)
    if Ok and Str and Str ~= "" then
        return Str
    end
    return nil
end

local function FindItemAtPos(Character, Pos)
    local Container = GetContainerModule(Character)
    if not Container then
        return nil, "no container module"
    end

    local Ok, Items = pcall(function()
        return Container:GetItemsIn(INVENTORY_MAIN)
    end)
    if not Ok or not Items then
        return nil, "GetItemsIn failed"
    end

    local Found = nil
    local ScanOk, ScanErr = pcall(function()
        IterateItems(Items, function(_, Item)
            if Found then
                return true
            end
            if ReadItemId(Item) == Pos then
                local SlotData = ReadSlotData(Item)
                local ItemClass = ReadItemClass(SlotData)
                if ItemClass then
                    Found = {
                        class = ItemClass,
                        count = ReadItemCount(SlotData),
                        pos = Pos,
                    }
                    return true
                end
            end
            return false
        end)
    end)
    if not ScanOk then
        return nil, tostring(ScanErr)
    end

    if Found then
        return Found, nil
    end

    return nil, string.format("no item at pos %d (empty slot?)", Pos)
end

local function FindFirstValid(ClassNames)
    for _, Name in ipairs(ClassNames) do
        local Ok, Obj = pcall(function()
            return FindFirstOf(Name)
        end)
        if Ok and IsLiveUObject(Obj) then
            return Obj, Name
        end
    end
    return nil, nil
end

local function TryGetInventoryWidgetFromManagement(ManagementMain)
    if not IsLiveUObject(ManagementMain) then
        return nil
    end

    local InvWidget = SafeCallMethod(ManagementMain, "GetInventoryWidget")
    if IsLiveUObject(InvWidget) then
        return InvWidget
    end

    InvWidget = SafeGetMember(ManagementMain, "W_Inventory_Main")
    if IsLiveUObject(InvWidget) then
        return InvWidget
    end

    return nil
end

local function GetInventoryMainWidget()
    local Ok, Widget = pcall(function()
        local Hud = FindFirstValid({"HUDManagementController"})
        if Hud then
            local ManagementMain = SafeGetMember(Hud, "m_ManagementMain")
            local InvWidget = TryGetInventoryWidgetFromManagement(ManagementMain)
            if InvWidget then
                return InvWidget
            end
        end

        local DirectWidget = FindFirstValid({
            "W_Inventory_Main_C",
            "InventoryMain",
        })
        if DirectWidget then
            return DirectWidget
        end

        local Management = FindFirstValid({
            "ManagementMain",
            "W_Management_Main_C",
        })
        return TryGetInventoryWidgetFromManagement(Management)
    end)
    if Ok and IsLiveUObject(Widget) then
        return Widget
    end
    return nil
end

local function GetContainerWidget()
    local Widget = FindFirstValid({
        "ContainerManagerWidget",
        "W_ContainerManager_C",
        "W_ContainerManagerWidget_C",
    })
    if Widget then
        return Widget
    end

    local Main = GetInventoryMainWidget()
    if Main and SafeGetMember(Main, "GetItemAmountByPos_Implementation") then
        return Main
    end

    return nil
end

local function GetInventoryBaseFromUi()
    local Main = GetInventoryMainWidget()
    if Main then
        local Base = SafeCallMethod(Main, "GetInventoryBase")
        if IsLiveUObject(Base) then
            return Base
        end

        Base = SafeGetMember(Main, "InventoryBase")
        if IsLiveUObject(Base) then
            return Base
        end
    end

    return FindFirstValid({"InventoryBase"})
end

local function InventoryTypeEquals(Left, Right)
    if Left == nil or Right == nil then
        return false
    end
    if Left == Right then
        return true
    end
    if type(Left) == "number" and type(Right) == "number" then
        return Left == Right
    end
    local LeftNum = tonumber(tostring(Left))
    local RightNum = tonumber(tostring(Right))
    return LeftNum ~= nil and RightNum ~= nil and LeftNum == RightNum
end

local function ReadInventoryType(VirtualData)
    if not VirtualData then
        return nil
    end
    local Ok, InvType = pcall(function()
        return VirtualData.m_InventoryType
    end)
    if Ok and InvType ~= nil then
        return InvType
    end
    return nil
end

local function GetMainContainerVirtualData(Container)
    if not Container then
        return nil
    end

    local Ok, InvMap = pcall(function()
        return Container.m_Inventory
    end)
    if not Ok or InvMap == nil then
        return nil
    end

    local ValuesOk, ValuesWrap = pcall(function()
        return InvMap.m_Values
    end)
    if ValuesOk and ValuesWrap then
        local DirectSlotsOk, DirectSlots = pcall(function()
            return ValuesWrap.m_Slots
        end)
        if DirectSlotsOk and DirectSlots then
            return ValuesWrap
        end

        local ItemsOk, Items = pcall(function()
            return ValuesWrap.Items
        end)
        if ItemsOk and Items then
            local Found = nil
            IterateItems(Items, function(_, Data)
                if Found then
                    return true
                end
                if InventoryTypeEquals(ReadInventoryType(Data), INVENTORY_MAIN) then
                    Found = UnwrapValue(Data)
                    return true
                end
                return false
            end)
            if Found then
                return Found
            end

            local Count = GetArrayLength(Items)
            for Index = 0, Count - 1 do
                local Data = UnwrapValue(GetArrayElement(Items, Index))
                if Data then
                    local SlotsOk, Slots = pcall(function()
                        return Data.m_Slots
                    end)
                    if SlotsOk and Slots and GetArrayLength(Slots) > 0 then
                        return Data
                    end
                end
            end
        end

        if ValuesWrap.GetArrayNum then
            local Count = ValuesWrap:GetArrayNum()
            for Index = 0, Count - 1 do
                local Data = UnwrapValue(GetArrayElement(ValuesWrap, Index))
                if Data then
                    local SlotsOk, Slots = pcall(function()
                        return Data.m_Slots
                    end)
                    if SlotsOk and Slots and GetArrayLength(Slots) > 0 then
                        return Data
                    end
                end
            end
        end
    end

    local KeysOk, Keys = pcall(function()
        return InvMap.m_Keys
    end)
    if KeysOk and Keys and ValuesOk and ValuesWrap then
        local KeyCount = GetArrayLength(Keys)
        for Index = 0, KeyCount - 1 do
            local Key = GetArrayElement(Keys, Index)
            if InventoryTypeEquals(Key, INVENTORY_MAIN) then
                local Data = GetArrayElement(ValuesWrap, Index)
                if not Data then
                    local ItemsOk, Items = pcall(function()
                        return ValuesWrap.Items
                    end)
                    if ItemsOk and Items then
                        Data = GetArrayElement(Items, Index)
                    end
                end
                if Data then
                    return UnwrapValue(Data)
                end
            end
        end
    end

    return nil
end

local function GetLiveInventoryBase()
    local Ok, Base = pcall(function()
        local Main = GetInventoryMainWidget()
        if not Main then
            return nil
        end

        local LiveBase = SafeGetMember(Main, "InventoryBase")
        if IsLiveUObject(LiveBase) then
            return LiveBase
        end

        LiveBase = SafeCallMethod(Main, "GetInventoryBase")
        if IsLiveUObject(LiveBase) then
            return LiveBase
        end

        return nil
    end)
    if Ok and IsLiveUObject(Base) then
        return Base
    end
    return nil
end

local function BuildUiPosCandidates(UserPos)
    local ApiPos = UserPosToApiPos(UserPos)
    if ApiPos < 0 then
        return {}
    end
    return { ApiPos }
end

local function IsGridSlotOccupied(Base, ApiPos)
    if not Base or ApiPos == nil or ApiPos < 0 then
        return false
    end

    local ValidOk, Valid = pcall(function()
        return Base:IsItemValidByPos(ApiPos)
    end)
    if ValidOk and Valid then
        return true
    end

    local AmountOk, Amount = pcall(function()
        return Base:GetItemAmountByPos(ApiPos)
    end)
    if AmountOk and type(Amount) == "number" and Amount > 0 then
        return true
    end

    return false
end

local function ReadItemClassFromBase(Base, ApiPos, Character, InternalId)
    if Base then
        local ClassOk, ItemDef = pcall(function()
            return Base:GetBaseConfigByPos(ApiPos)
        end)
        if ClassOk and ItemDef then
            local ItemClass = ToItemDefinitionClass(ItemDef)
            if ItemClass then
                return ItemClass
            end
        end
    end

    if InternalId ~= nil then
        local ItemInfo = FindItemAtPos(Character, InternalId)
        if ItemInfo and ItemInfo.class then
            return ToItemDefinitionClass(ItemInfo.class)
        end
    end

    return nil
end

local function TryResolveViaInventoryBase(Character, UserPos)
    local Base = GetLiveInventoryBase()
    if not Base then
        return nil
    end

    local ApiPos = UserPosToApiPos(UserPos)
    if ApiPos < 0 or not IsGridSlotOccupied(Base, ApiPos) then
        return nil
    end

    local Amount = 0
    local AmountOk, Value = pcall(function()
        return Base:GetItemAmountByPos(ApiPos)
    end)
    if AmountOk and type(Value) == "number" then
        Amount = Value
    end

    local InternalId = nil
    local IdOk, Id = pcall(function()
        return Base:GetItemIdByPos(ApiPos)
    end)
    if IdOk and type(Id) == "number" then
        InternalId = Id
    end

    local ItemClass = ReadItemClassFromBase(Base, ApiPos, Character, InternalId)
    local ItemName = nil
    local NameOk, Text = pcall(function()
        return Base:GetItemNameByPos(ApiPos)
    end)
    if NameOk then
        ItemName = TextToString(Text)
    end
    if not ItemName and ItemClass then
        ItemName = GetShortClassName(GetItemClassName(ItemClass))
    end

    return {
        uiPos = UserPos,
        apiPos = ApiPos,
        id = InternalId,
        count = Amount,
        name = ItemName or "?",
        class = ItemClass and ToItemDefinitionClass(ItemClass) or ItemClass,
        source = "InventoryBase",
    }, nil
end

local function GetMainContainerSlots(Container)
    local VirtualData = GetMainContainerVirtualData(Container)
    if not VirtualData then
        return nil, 0
    end

    local SlotsOk, Slots = pcall(function()
        return VirtualData.m_Slots
    end)
    if not SlotsOk or Slots == nil then
        return nil, 0
    end

    local SlotCount = GetArrayLength(Slots)
    local CapOk, Capacity = pcall(function()
        return VirtualData.m_Capacity
    end)
    if CapOk and type(Capacity) == "number" and Capacity > SlotCount then
        SlotCount = Capacity
    end
    if SlotCount <= 0 then
        SlotCount = DEFAULT_SLOT_COUNT
    end

    return Slots, SlotCount
end

local function ReadSlotItemInfo(Item)
    if not Item then
        return nil
    end

    local SlotData = ReadSlotData(Item)
    local Count = ReadItemCount(SlotData)
    local Id = ReadItemId(Item)
    if Count <= 0 and Id == nil then
        return nil
    end

    local ItemClass = ReadItemClass(SlotData)
    return {
        id = Id,
        count = Count,
        class = ItemClass,
        name = ItemClass and GetShortClassName(GetItemClassName(ItemClass)) or nil,
    }
end

local function ReadSlotItemAtApiPos(Slots, SlotCount, ApiPos)
    if not Slots or ApiPos == nil or ApiPos < 0 or ApiPos >= SlotCount then
        return nil
    end

    local Item = GetArrayElement(Slots, ApiPos)
    return ReadSlotItemInfo(Item)
end

local function TryResolveViaContainerGrid(Character, UserPos, ApiPos)
    local Container = GetContainerModule(Character)
    if not Container then
        return nil
    end

    local Slots, SlotCount = GetMainContainerSlots(Container)
    if not Slots or ApiPos == nil or ApiPos < 0 or ApiPos >= SlotCount then
        return nil
    end

    local Info = ReadSlotItemAtApiPos(Slots, SlotCount, ApiPos)
    if not Info then
        return nil
    end

    if Info.class == nil and Info.id ~= nil then
        local ItemInfo = FindItemAtPos(Character, Info.id)
        if ItemInfo then
            Info.class = ItemInfo.class
            if Info.count <= 0 then
                Info.count = ItemInfo.count
            end
        end
    end

    return {
        uiPos = UserPos,
        apiPos = ApiPos,
        id = Info.id,
        count = Info.count,
        name = Info.name or "?",
        class = Info.class,
        source = "container-grid",
    }, nil
end

local function ResolveItemAtApiPos(Character, UserPos, ApiPos)
    local Container = GetContainerModule(Character)
    if not Container then
        return nil, "no container module"
    end

    local Slots, SlotCount = GetMainContainerSlots(Container)
    if not Slots then
        return nil, "no main container slots"
    end

    local Info = ReadSlotItemAtApiPos(Slots, SlotCount, ApiPos)
    if not Info then
        return nil, string.format("no item at ui pos %d (empty slot?)", UserPos)
    end

    if Info.class == nil and Info.id ~= nil then
        local ItemInfo = FindItemAtPos(Character, Info.id)
        if ItemInfo then
            Info.class = ItemInfo.class
            Info.count = ItemInfo.count
        end
    end

    return {
        uiPos = UserPos,
        apiPos = ApiPos,
        id = Info.id,
        count = Info.count,
        name = Info.name or "?",
        class = Info.class,
        source = "container",
    }, nil
end

local function GetFullInventory(UI)
    if not UI then
        return nil
    end

    local Ok, Inventory = pcall(function()
        return UI.m_LocalPlayerInventory
    end)
    if Ok and Inventory then
        return Inventory
    end
    return nil
end

local function GetItemDisplayNameFromWidget(Widget, ApiPos)
    if not Widget or ApiPos == nil or not Widget.GetItemNameByPos_Implementation then
        return nil
    end

    local NameOk, Text = pcall(function()
        return Widget:GetItemNameByPos_Implementation(ApiPos)
    end)
    if NameOk then
        return TextToString(Text)
    end
    return nil
end

local function GetItemDisplayNameFromBase(Base, ApiPos)
    if not Base or ApiPos == nil or not Base.GetItemNameByPos then
        return nil
    end

    local NameOk, Text = pcall(function()
        return Base:GetItemNameByPos(ApiPos)
    end)
    if NameOk then
        return TextToString(Text)
    end
    return nil
end

local function GetInternalIdFromWidget(Widget, ApiPos)
    if not Widget or ApiPos == nil then
        return nil
    end

    if Widget.GetIdByPos then
        local Ok, InternalId = pcall(function()
            return Widget:GetIdByPos(ApiPos)
        end)
        if Ok and type(InternalId) == "number" then
            return InternalId
        end
    end

    return nil
end

local function GetInternalIdFromBase(Base, ApiPos)
    if not Base or ApiPos == nil or not Base.GetItemIdByPos then
        return nil
    end

    local Ok, InternalId = pcall(function()
        return Base:GetItemIdByPos(ApiPos)
    end)
    if Ok and type(InternalId) == "number" then
        return InternalId
    end
    return nil
end

local function GetItemAmountFromWidget(Widget, ApiPos)
    if not Widget or ApiPos == nil or not Widget.GetItemAmountByPos_Implementation then
        return nil
    end

    local Ok, Amount = pcall(function()
        return Widget:GetItemAmountByPos_Implementation(ApiPos)
    end)
    if Ok and type(Amount) == "number" then
        return Amount
    end
    return nil
end

local function GetItemAmountFromBase(Base, ApiPos)
    if not Base or ApiPos == nil or not Base.GetItemAmountByPos then
        return nil
    end

    local Ok, Amount = pcall(function()
        return Base:GetItemAmountByPos(ApiPos)
    end)
    if Ok and type(Amount) == "number" then
        return Amount
    end
    return nil
end

local function GetVirtualDataFromWidget(Widget, ApiPos)
    if not Widget or ApiPos == nil or not Widget.GetItemVirtualDataByPos_Implementation then
        return nil
    end

    local Ok, Virtual = pcall(function()
        return Widget:GetItemVirtualDataByPos_Implementation(ApiPos)
    end)
    if Ok and Virtual then
        return UnwrapValue(Virtual)
    end
    return nil
end

local function TryResolveViaContainerWidget(Character, UserPos)
    local Widget = GetContainerWidget()
    if not Widget then
        return nil
    end

    local ApiPos = UserPosToApiPos(UserPos)
    if ApiPos < 0 then
        return nil
    end

    local Amount = GetItemAmountFromWidget(Widget, ApiPos)
    if not Amount or Amount <= 0 then
        return nil
    end

    local Virtual = GetVirtualDataFromWidget(Widget, ApiPos)
    local InternalId = Virtual and ReadItemId(Virtual) or nil
    local SlotData = Virtual and ReadSlotData(Virtual) or nil
    local ItemClass = ReadItemClass(SlotData)
    local Count = Amount
    local Name = GetItemDisplayNameFromWidget(Widget, ApiPos)

    if InternalId ~= nil then
        local ItemInfo = FindItemAtPos(Character, InternalId)
        if ItemInfo then
            if not ItemClass then
                ItemClass = ItemInfo.class
            end
            if Count <= 0 then
                Count = ItemInfo.count
            end
        end
    end

    if not Name and ItemClass then
        Name = GetShortClassName(GetItemClassName(ItemClass))
    end

    return {
        uiPos = UserPos,
        apiPos = ApiPos,
        id = InternalId,
        count = Count,
        name = Name or "?",
        class = ItemClass,
        source = "ContainerManagerWidget",
    }
end

local function ResolveItemAtUiPos(Character, UserPos)
    if UserPos < UI_POS_OFFSET then
        return nil, string.format("pos must be >= %d", UI_POS_OFFSET)
    end

    local ApiPos = UserPosToApiPos(UserPos)

    local Info
    local BaseOk, BaseInfo = pcall(function()
        return TryResolveViaInventoryBase(Character, UserPos)
    end)
    if BaseOk and BaseInfo then
        return BaseInfo, nil
    end

    Info = TryResolveViaContainerWidget(Character, UserPos)
    if Info then
        return Info, nil
    end

    Info = TryResolveViaContainerGrid(Character, UserPos, ApiPos)
    if Info then
        return Info, nil
    end

    if not GetLiveInventoryBase() then
        return nil, string.format(
            "no item at ui pos %d (open inventory tab first; footer e.g. 18/334)",
            UserPos
        )
    end

    return nil, string.format("no item at ui pos %d (empty grid slot?)", UserPos)
end

local function GetItemAmountByApiPos(Provider, ApiPos)
    if not Provider then
        return nil
    end
    if Provider.kind == "widget" then
        return GetItemAmountFromWidget(Provider.obj, ApiPos)
    end
    return GetItemAmountFromBase(Provider.obj, ApiPos)
end

local function GetInternalIdByApiPos(Provider, ApiPos)
    if not Provider then
        return nil
    end
    if Provider.kind == "widget" then
        return GetInternalIdFromWidget(Provider.obj, ApiPos)
    end
    return GetInternalIdFromBase(Provider.obj, ApiPos)
end

local function GetItemDisplayNameByApiPos(Provider, ApiPos)
    if not Provider then
        return nil
    end
    if Provider.kind == "widget" then
        return GetItemDisplayNameFromWidget(Provider.obj, ApiPos)
    end
    return GetItemDisplayNameFromBase(Provider.obj, ApiPos)
end

local function GetVirtualDataByApiPos(Provider, ApiPos)
    if not Provider or Provider.kind ~= "widget" then
        return nil
    end
    return GetVirtualDataFromWidget(Provider.obj, ApiPos)
end

local function GetSlotCount(Provider)
    if Provider and Provider.kind == "widget" then
        local Inventory = GetFullInventory(Provider.obj)
        local Count = GetArrayLength(Inventory)
        if Count > 0 then
            return Count
        end

        if Provider.obj.GetInventorySize_Implementation then
            local Ok, Size = pcall(function()
                return Provider.obj:GetInventorySize_Implementation(0)
            end)
            if Ok and type(Size) == "number" and Size > 0 then
                return Size
            end
        end
    end

    return DEFAULT_SLOT_COUNT
end

function Inventory.DumpPosList(Ar)
    RunOnGameThread("inventory list", function()
        local Character = Stats.GetPlayerCharacter()
        if not Character then
            Log("No player character (load a save first)", Ar)
            return
        end

        local Container = GetContainerModule(Character)
        if not Container then
            Log("no container module", Ar)
            return
        end

        local Slots, SlotCount = GetMainContainerSlots(Container)
        if SlotCount <= 0 then
            SlotCount = DEFAULT_SLOT_COUNT
        end

        ModLog.BeginBatch()
        Log("--- inventory (ui pos = number at bottom of inventory) ---", Ar)
        Log(string.format("grid slots: %d  (use pos from this list, not internal id)", SlotCount), Ar)

        local Rows = {}
        local Source = "none"

        local Base = GetLiveInventoryBase()
        if not Base then
            local Main = GetInventoryMainWidget()
            if Main then
                Log("InventoryMain ok, InventoryBase missing — open inventory tab fully", Ar)
            else
                Log("InventoryMain not found — open inventory tab before Numpad 9", Ar)
            end
        end

        if Base then
            Source = "InventoryBase (inventory open)"
            for ApiPos = 0, SlotCount - 1 do
                if IsGridSlotOccupied(Base, ApiPos) then
                    local Amount = 0
                    local AmountOk, Value = pcall(function()
                        return Base:GetItemAmountByPos(ApiPos)
                    end)
                    if AmountOk and type(Value) == "number" then
                        Amount = Value
                    end

                    local Id = nil
                    local IdOk, Value = pcall(function()
                        return Base:GetItemIdByPos(ApiPos)
                    end)
                    if IdOk and type(Value) == "number" then
                        Id = Value
                    end

                    local ItemClass = ReadItemClassFromBase(Base, ApiPos, Character, Id)
                    local Name = nil
                    local NameOk, Text = pcall(function()
                        return Base:GetItemNameByPos(ApiPos)
                    end)
                    if NameOk then
                        Name = TextToString(Text)
                    end
                    if not Name and ItemClass then
                        Name = GetShortClassName(GetItemClassName(ItemClass))
                    end

                    table.insert(Rows, {
                        uiPos = ApiPosToUserPos(ApiPos),
                        id = Id,
                        name = Name or "?",
                        count = Amount,
                    })
                end
            end
        elseif Slots then
            Source = "container-grid (inventory closed)"
            for ApiPos = 0, SlotCount - 1 do
                local Info = ReadSlotItemAtApiPos(Slots, SlotCount, ApiPos)
                if Info then
                    if Info.class == nil and Info.id ~= nil then
                        local ItemInfo = FindItemAtPos(Character, Info.id)
                        if ItemInfo then
                            Info.class = ItemInfo.class
                            if Info.count <= 0 then
                                Info.count = ItemInfo.count
                            end
                            if not Info.name or Info.name == "?" then
                                Info.name = GetShortClassName(GetItemClassName(ItemInfo.class))
                            end
                        end
                    end
                    table.insert(Rows, {
                        uiPos = ApiPosToUserPos(ApiPos),
                        id = Info.id,
                        name = Info.name or "?",
                        count = Info.count,
                    })
                end
            end
        end

        Log(string.format("via %s", Source), Ar)

        for _, Row in ipairs(Rows) do
            if Row.id ~= nil then
                Log(string.format(
                    "pos %d: %s x %d  (id %d)",
                    Row.uiPos, Row.name, Row.count, Row.id
                ), Ar)
            else
                Log(string.format("pos %d: %s x %d", Row.uiPos, Row.name, Row.count), Ar)
            end
        end

        if #Rows == 0 then
            Log("(empty — open inventory tab, then Numpad 9 again)", Ar)
            Log("internal ids from GetItemsIn (NOT ui pos):", Ar)
            local Ok, Items = pcall(function()
                return Container:GetItemsIn(INVENTORY_MAIN)
            end)
            if Ok and Items then
                IterateItems(Items, function(_, Item)
                    local Id = ReadItemId(Item)
                    local SlotData = ReadSlotData(Item)
                    local ItemClass = ReadItemClass(SlotData)
                    if ItemClass and Id ~= nil then
                        Log(string.format(
                            "id %d: %s x %d  (internal id, not ui pos)",
                            Id,
                            GetShortClassName(GetItemClassName(ItemClass)),
                            ReadItemCount(SlotData)
                        ), Ar)
                    end
                    return false
                end)
            end
        else
            Log(string.format("Inventory list: %d items", #Rows), Ar)
        end
        ModLog.EndBatch()
    end, Ar)
end

function Inventory.PrintLookupHelp(Ar)
    Log("Numpad 9: dump items by ui grid pos (open inventory tab first)", Ar)
    Log("Numpad 7: <pos> then Enter  (e.g. 18 for ore at 18/334)", Ar)
    Log("pos = footer number (18/334), NOT internal id (id 5)", Ar)
    Log("Esc: close slot lookup line", Ar)
end

function Inventory.PrintHelp(Ar)
    Log("Numpad 8: <pos> <count> then Enter  (e.g. 18 55 or 18 -10)", Ar)
    Log("pos = ui pos from inventory footer / Numpad 9 list", Ar)
    Log("Esc: close inventory command line", Ar)
end

function Inventory.ExecuteLookupLine(Line, Ar)
    Line = string.match(Line or "", "^%s*(.-)%s*$")
    if Line == "" then
        return
    end

    if string.match(Line, "%s") then
        Log("Usage: <pos>  e.g. 18  (Numpad 9 = full list)", Ar)
        return
    end

    local ItemPos = tonumber(Line)
    if ItemPos == nil then
        Log(string.format("Invalid pos number '%s'", Line), Ar)
        return
    end
    if ItemPos < UI_POS_OFFSET then
        Log(string.format("pos must be >= %d", UI_POS_OFFSET), Ar)
        return
    end

    RunOnGameThread("inventory lookup", function()
        local Character = Stats.GetPlayerCharacter()
        if not Character then
            Log("No player character (load a save first)", Ar)
            return
        end

        local ItemInfo, Err = ResolveItemAtUiPos(Character, ItemPos)
        if ItemInfo then
            local SourceNote = ItemInfo.source and string.format(" [%s]", ItemInfo.source) or ""
            if ItemInfo.id ~= nil then
                Log(string.format(
                    "pos %d: %s x %d  (id %d)%s",
                    ItemPos, ItemInfo.name or "?", ItemInfo.count, ItemInfo.id, SourceNote
                ), Ar)
            else
                Log(string.format(
                    "pos %d: %s x %d%s",
                    ItemPos, ItemInfo.name or "?", ItemInfo.count, SourceNote
                ), Ar)
            end
            return
        end

        Log(Err or "item lookup failed", Ar)
    end, Ar)
end

local MAX_ITEM_DELTA = 999

local function ResolveWriteItemClass(Character, ItemInfo)
    if ItemInfo == nil then
        return nil, "no item info"
    end

    -- Same path as Numpad 7: live InventoryBase at ui grid pos.
    if ItemInfo.apiPos ~= nil then
        local Base = GetLiveInventoryBase()
        if Base then
            local ItemClass = ReadItemClassFromBase(Base, ItemInfo.apiPos, Character, ItemInfo.id)
            if ItemClass then
                return ItemClass, "InventoryBase"
            end
        end
    end

    if ItemInfo.class then
        local ItemClass = ToItemDefinitionClass(ItemInfo.class)
        if ItemClass then
            return ItemClass, ItemInfo.source or "lookup"
        end
    end

    return nil, string.format(
        "open inventory tab (pos %d); cannot resolve item class (internal id %s)",
        ItemInfo.uiPos or 0,
        tostring(ItemInfo.id)
    )
end

function Inventory.ExecuteLine(Line, Ar)
    Line = string.match(Line or "", "^%s*(.-)%s*$")
    if Line == "" then
        return
    end

    local PosText, CountText = string.match(Line, "^(%S+)%s+(%S+)$")
    if not PosText or not CountText then
        Log("Usage: <pos> <count>  e.g. 18 55 or 18 -10", Ar)
        return
    end

    local ItemPos = tonumber(PosText)
    local Delta = tonumber(CountText)
    if ItemPos == nil or Delta == nil then
        Log(string.format("Invalid numbers: '%s' '%s'", PosText, CountText), Ar)
        return
    end
    if ItemPos < UI_POS_OFFSET then
        Log(string.format("pos must be >= %d", UI_POS_OFFSET), Ar)
        return
    end
    if Delta == 0 then
        Log("count must not be 0", Ar)
        return
    end
    if math.abs(Delta) > MAX_ITEM_DELTA then
        Log(string.format("count per command must be between -%d and %d", MAX_ITEM_DELTA, MAX_ITEM_DELTA), Ar)
        return
    end

    RunOnGameThread("inventory", function()
        local Character = Stats.GetPlayerCharacter()
        if not Character then
            Log("No player character (load a save first)", Ar)
            return
        end

        local ItemInfo, Err = ResolveItemAtUiPos(Character, ItemPos)
        if not ItemInfo then
            Log(Err or "item lookup failed", Ar)
            return
        end

        local ItemClass, ClassSource = ResolveWriteItemClass(Character, ItemInfo)
        if not ItemClass then
            Log(ClassSource or "cannot resolve item class", Ar)
            return
        end

        local ItemName = ItemInfo.name or GetShortClassName(GetItemClassName(ItemClass))
        local Before = ItemInfo.count
        local IdNote = ItemInfo.id and string.format(" (id %d)", ItemInfo.id) or ""

        if Delta > 0 then
            local AddOk, AddVia = AddItemsToCharacter(Character, ItemClass, Delta)
            if not AddOk then
                Log(string.format("Add failed%s: %s", IdNote, AddVia or "unknown"), Ar)
                return
            end
            Log(string.format(
                "pos %d: +%d x %s%s (was %d, class via %s, write via %s)",
                ItemPos, Delta, ItemName, IdNote, Before, ClassSource, AddVia
            ), Ar)
            return
        end

        local RemoveCount = -Delta
        if Before > 0 and RemoveCount > Before then
            RemoveCount = Before
        end
        if RemoveCount <= 0 then
            Log(string.format("pos %d: nothing to remove", ItemPos), Ar)
            return
        end

        local RemoveOk, Removed, RemoveVia = RemoveItemsFromCharacter(Character, ItemClass, RemoveCount)
        if not RemoveOk then
            Log(string.format("Remove failed%s: %s", IdNote, RemoveVia or "unknown"), Ar)
            return
        end
        Log(string.format(
            "pos %d: -%d x %s%s (removed %d, was %d, class via %s, write via %s)",
            ItemPos, RemoveCount, ItemName, IdNote, Removed, Before, ClassSource, RemoveVia
        ), Ar)
    end, Ar)
end

return Inventory
