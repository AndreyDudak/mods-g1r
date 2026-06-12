local UEHelpers = require("UEHelpers")

local Stats = {}

local AIGASLibrary = StaticFindObject("/Script/G1R.Default__AIGASLibrary")
local CharacterStateClass = StaticFindObject("/Script/G1R.GothicCharacterState")
local ASBlueprintLibrary = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary")
local ClassCache = {}

local function IsValidUObjectSafe(Obj)
    if Obj == nil then
        return false
    end
    local Ok, Valid = pcall(function()
        return Obj:IsValid()
    end)
    return Ok and Valid
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

local function GetASCFromCharacterState(State)
    if not IsValidUObjectSafe(State) then
        return nil
    end
    local ASC = SafeGetMember(State, "AbilitySystemComponent")
    if IsValidUObjectSafe(ASC) then
        return ASC
    end
    return nil
end

local function GetAbilitySystem(Character)
    if not IsValidUObjectSafe(Character) then
        return nil
    end

    local ASC = SafeCallMethod(Character, "GetAbilitySystemComponent")
    if IsValidUObjectSafe(ASC) then
        return ASC
    end

    ASC = GetASCFromCharacterState(SafeCallMethod(Character, "BP_GetCharacterState"))
    if ASC then
        return ASC
    end

    ASC = GetASCFromCharacterState(SafeGetMember(Character, "m_CharacterState"))
    if ASC then
        return ASC
    end

    if IsValidUObjectSafe(CharacterStateClass) then
        local State = SafeCallMethod(CharacterStateClass, "TryGetCharacterStateFromActor", Character)
        ASC = GetASCFromCharacterState(State)
        if ASC then
            return ASC
        end
    end

    if IsValidUObjectSafe(ASBlueprintLibrary) then
        ASC = SafeCallMethod(ASBlueprintLibrary, "GetAbilitySystemComponent", Character)
        if IsValidUObjectSafe(ASC) then
            return ASC
        end
    end

    return nil
end

Stats.ALIASES = {
    hp = "Health",
    health = "Health",
    mh = "MaxHealth",
    maxhealth = "MaxHealth",
    mp = "Mana",
    mm = "MaxMana",
    str = "Strength",
    strength = "Strength",
    dex = "Dexterity",
    dexterity = "Dexterity",
    lvl = "Level",
    level = "Level",
    exp = "Experience",
    xp = "Experience",
    lp = "SkillPoints",
    sp = "SkillPoints",
    skillpoints = "SkillPoints",
    tough = "Toughness",
    toughness = "Toughness",
    fatigue = "Fatigue",
    mf = "MaxFatigue",
    maxfatigue = "MaxFatigue",
    circle = "MagicianLevel",
    magic = "MagicianLevel",
    mc = "MagicianLevel",
    magician = "MagicianLevel",
    magicianlevel = "MagicianLevel",
    magiclevel = "MagicianLevel",
}

Stats.STAT_DEFS = {
    { label = "Health",      set = "/Script/G1R.AttributeSet_Health",           attr = "Health" },
    { label = "MaxHealth",   set = "/Script/G1R.AttributeSet_Health",           attr = "MaxHealth" },
    { label = "Mana",        set = "/Script/G1R.AttributeSet_Mana",             attr = "Mana" },
    { label = "MaxMana",     set = "/Script/G1R.AttributeSet_Mana",             attr = "MaxMana" },
    { label = "MagicianLevel", set = "/Script/G1R.AttributeSet_Mana",           attr = "MagicianLevel" },
    { label = "Strength",    set = "/Script/G1R.AttributeSet_Strength",         attr = "Strength" },
    { label = "Dexterity",   set = "/Script/G1R.AttributeSet_Dexterity",        attr = "Dexterity" },
    { label = "Level",       set = "/Script/G1R.AttributeSet_LevelProgression", attr = "Level" },
    { label = "Experience",  set = "/Script/G1R.AttributeSet_LevelProgression", attr = "Experience" },
    { label = "SkillPoints", set = "/Script/G1R.AttributeSet_LevelProgression", attr = "SkillPoints" },
    { label = "Toughness",   set = "/Script/G1R.AttributeSet_LevelProgression", attr = "Toughness" },
    { label = "Fatigue",     set = "/Script/G1R.AttributeSet_Fatigue",          attr = "Fatigue" },
    { label = "MaxFatigue",  set = "/Script/G1R.AttributeSet_Fatigue",          attr = "MaxFatigue" },
}

local function NormalizeQuery(Query)
    if not Query or Query == "" then
        return ""
    end
    return string.lower(Query)
end

function Stats.FindDefByQuery(Query)
    local Key = NormalizeQuery(Query)
    if Key == "" then
        return nil
    end

    local AliasLabel = Stats.ALIASES[Key]
    if AliasLabel then
        Key = NormalizeQuery(AliasLabel)
    end

    for _, Def in ipairs(Stats.STAT_DEFS) do
        if NormalizeQuery(Def.label) == Key then
            return Def
        end
    end

    return nil
end

local function FindClass(Path)
    if not ClassCache[Path] then
        ClassCache[Path] = StaticFindObject(Path)
    end
    local Class = ClassCache[Path]
    if Class and Class:IsValid() then
        return Class
    end
    return nil
end

local function ClassNameFromSetPath(SetPath)
    return SetPath and SetPath:match("([^%.]+)$") or nil
end

local function CollectAbilitySystems(Character)
    local List = {}
    local Seen = {}

    local function Add(ASC)
        if IsValidUObjectSafe(ASC) and not Seen[ASC] then
            Seen[ASC] = true
            table.insert(List, ASC)
        end
    end

    Add(GetAbilitySystem(Character))

    local Mesh = SafeGetMember(Character, "Mesh")
    Add(SafeGetMember(Mesh, "AbilityComp"))

    local State = Stats.GetCharacterState(Character)
    Add(SafeGetMember(State, "AbilitySystemComponent"))

    return List
end

local function FindSpawnedAttributeSet(Character, SetPath)
    local Want = ClassNameFromSetPath(SetPath)
    if not Want then
        return nil
    end

    for _, ASC in ipairs(CollectAbilitySystems(Character)) do
        local Found = nil
        pcall(function()
            ASC.SpawnedAttributes:ForEach(function(_, Elem)
                if Found then
                    return
                end
                local Set = Elem:get()
                if not IsValidUObjectSafe(Set) then
                    return
                end
                local Ok, ClassName = pcall(function()
                    return Set:GetClass():GetFName():ToString()
                end)
                if Ok and ClassName == Want then
                    Found = Set
                end
            end)
        end)
        if Found then
            return Found
        end
    end

    return nil
end

local function WriteAttributeSetField(AttrSet, AttrName, NewValue)
    local Wrote = false
    pcall(function()
        AttrSet[AttrName].BaseValue = NewValue
        Wrote = true
    end)
    pcall(function()
        AttrSet[AttrName].CurrentValue = NewValue
        Wrote = true
    end)
    return Wrote
end

local BarProp = { Health = "W_HealthBar", Mana = "W_ManaBar", MaxHealth = "W_HealthBar", MaxMana = "W_ManaBar" }

local function FullName(Obj)
    return tostring(SafeCallMethod(Obj, "GetFullName") or "")
end

-- Real HUD = Player_Widget_C under GothicGameInstance (not the /Engine/Transient orphan after load).
-- Do NOT exclude Transient in the path — the real widget lives there too.
local CachedPlayerWidget = nil
local HudScanGate = 0
local HudRescanEvery = 3  -- min seconds between FindAllOf scans when cache misses

local function IsRealHudWidget(Widget)
    if not IsValidUObjectSafe(Widget) then
        return false
    end
    local Fn = FullName(Widget)
    return string.find(Fn, "Player_UI", 1, true) ~= nil
        and string.find(Fn, "GothicGameInstance", 1, true) ~= nil
end

local function GetPlayerHudWidget()
    if IsRealHudWidget(CachedPlayerWidget) then
        return CachedPlayerWidget
    end
    if IsValidUObjectSafe(CachedPlayerWidget) and HudScanGate > 0 then
        HudScanGate = HudScanGate - 1
        return CachedPlayerWidget
    end
    HudScanGate = HudRescanEvery

    local List = nil
    local OkAll, All = pcall(function()
        return FindAllOf("Player_Widget_C")
    end)
    if OkAll and type(All) == "table" then
        List = All
    end
    if not List then
        return CachedPlayerWidget
    end

    for _, Widget in ipairs(List) do
        if IsRealHudWidget(Widget) then
            CachedPlayerWidget = Widget
            return Widget
        end
    end
    for _, Widget in ipairs(List) do
        if IsValidUObjectSafe(Widget)
            and not string.find(FullName(Widget), "Default__", 1, true) then
            CachedPlayerWidget = Widget
            return Widget
        end
    end
    return CachedPlayerWidget
end

local function SyncResourceBar(AttrName, CurrentValue, MaxValue)
    local BarKey = BarProp[AttrName]
    if not BarKey or not CurrentValue or not MaxValue or MaxValue <= 0 then
        return
    end

    local PlayerWidget = GetPlayerHudWidget()
    if not IsValidUObjectSafe(PlayerWidget) then
        return
    end

    local Bar = SafeGetMember(PlayerWidget, BarKey)
    if not IsValidUObjectSafe(Bar) then
        CachedPlayerWidget = nil
        return
    end

    local Pct = CurrentValue / MaxValue
    pcall(function()
        Bar.m_GameplayAttributeCurrentValue = CurrentValue
        Bar.m_GameplayAttributeMaxValue = MaxValue
        Bar.m_GameplayAttributeCurrentPercent = Pct
        Bar.m_GameplayAttributeInterpolatedPercent = Pct
    end)

    for _, Name in ipairs({ "Update Value", "UpdateValue" }) do
        local Ok = pcall(function()
            Bar[Name](Bar)
        end)
        if Ok then
            break
        end
    end
end

local function SyncHudAfterWrite(AttrSet, SetPath, AttrName)
    if SetPath ~= "/Script/G1R.AttributeSet_Health" and SetPath ~= "/Script/G1R.AttributeSet_Mana" then
        return
    end

    local CurrentName = AttrName
    local MaxName = AttrName
    if AttrName == "Health" then
        MaxName = "MaxHealth"
    elseif AttrName == "MaxHealth" then
        CurrentName = "Health"
    elseif AttrName == "Mana" then
        MaxName = "MaxMana"
    elseif AttrName == "MaxMana" then
        CurrentName = "Mana"
    else
        return
    end

    local Cur = SafeGetMember(SafeGetMember(AttrSet, CurrentName), "CurrentValue")
    local Max = SafeGetMember(SafeGetMember(AttrSet, MaxName), "CurrentValue")
    if type(Cur) == "number" and type(Max) == "number" then
        SyncResourceBar(CurrentName, Cur, Max)
    end
end

local function WriteAttributeDirect(Character, SetPath, AttrName, NewValue)
    local AttrSet = FindSpawnedAttributeSet(Character, SetPath)
    if not AttrSet then
        return false, "attribute set not found on ASC"
    end
    if not WriteAttributeSetField(AttrSet, AttrName, NewValue) then
        return false, "direct attribute write failed"
    end
    SyncHudAfterWrite(AttrSet, SetPath, AttrName)
    return true, nil
end

local CachedPlayer = CreateInvalidObject()
local CachedPlayerController = CreateInvalidObject()

function Stats.ClearPlayerCache()
    CachedPlayer = CreateInvalidObject()
    CachedPlayerController = CreateInvalidObject()
end

function Stats.SetPlayerCache(Controller, Pawn)
    if Controller and Controller:IsValid() then
        CachedPlayerController = Controller
    end
    if Pawn and Pawn:IsValid() then
        CachedPlayer = Pawn
    end
end

function Stats.GetPlayerController()
    if CachedPlayerController:IsValid() then
        return CachedPlayerController
    end

    local Ok, PC = pcall(function()
        return FindFirstOf("PlayerController")
    end)
    if Ok and PC and PC:IsValid() then
        CachedPlayerController = PC
        return PC
    end

    return CreateInvalidObject()
end

function Stats.GetPlayerCharacter()
    if CachedPlayer:IsValid() then
        return CachedPlayer
    end

    local PC = Stats.GetPlayerController()
    if PC:IsValid() then
        local PawnOk, Pawn = pcall(function()
            return PC.Pawn
        end)
        if PawnOk and IsValidUObjectSafe(Pawn) then
            CachedPlayer = Pawn
            return Pawn
        end
    end

    local Ok, Player = pcall(function()
        return FindFirstOf("GothicPlayerCharacter")
    end)
    if Ok and IsValidUObjectSafe(Player) then
        CachedPlayer = Player
        return Player
    end

    return nil
end

function Stats.ReadStat(Character, SetPath, AttrName)
    local SetClass = FindClass(SetPath)
    if not SetClass then
        return nil, "missing class"
    end
    if not AIGASLibrary or not AIGASLibrary:IsValid() then
        return nil, "missing AIGASLibrary"
    end
    if not Character or not IsValidUObjectSafe(Character) then
        return nil, "invalid character"
    end

    local Ok, Value = pcall(function()
        return AIGASLibrary:GetAttributeValue(Character, SetClass, UEHelpers.FindFName(AttrName))
    end)
    if Ok then
        return Value, nil
    end
    return nil, tostring(Value)
end

function Stats.GetAbilitySystem(Character)
    return GetAbilitySystem(Character)
end

function Stats.GetCharacterState(Character)
    if not IsValidUObjectSafe(Character) then
        return nil
    end

    local State = SafeCallMethod(Character, "BP_GetCharacterState")
    if IsValidUObjectSafe(State) then
        return State
    end

    State = SafeGetMember(Character, "m_CharacterState")
    if IsValidUObjectSafe(State) then
        return State
    end

    if IsValidUObjectSafe(CharacterStateClass) then
        State = SafeCallMethod(CharacterStateClass, "TryGetCharacterStateFromActor", Character)
        if IsValidUObjectSafe(State) then
            return State
        end
    end

    return nil
end

function Stats.WriteAttribute(Character, SetPath, AttrName, NewValue)
    local SetClass = FindClass(SetPath)
    if not SetClass then
        return false, "missing class"
    end
    if not Character or not IsValidUObjectSafe(Character) then
        return false, "invalid character"
    end

    -- G1R + UE4SS 3.x: ASC TrySet/Set crash ("Array failed invariants").
    -- Direct AttributeSet write only (same approach as PassiveRegen).
    local DirectOk, DirectErr = WriteAttributeDirect(Character, SetPath, AttrName, NewValue)
    if DirectOk then
        return true, nil
    end

    return false, DirectErr or "direct attribute write failed"
end

function Stats.WriteStat(Character, SetPath, AttrName, NewValue)
    if AttrName == "MagicianLevel" then
        local Skills = require("skills")
        return Skills.SetMagicCircleLevel(Character, NewValue)
    end
    return Stats.WriteAttribute(Character, SetPath, AttrName, NewValue)
end

function Stats.ReadAll(Character)
    local Values = {}
    for Index, Def in ipairs(Stats.STAT_DEFS) do
        local Value, Err = Stats.ReadStat(Character, Def.set, Def.attr)
        Values[Index] = { value = Value, error = Err }
    end
    return Values
end

function Stats.ApplyAll(Character, ValuesByIndex)
    local Applied = 0
    local Failed = 0
    for Index, Def in ipairs(Stats.STAT_DEFS) do
        local NewValue = ValuesByIndex[Index]
        if NewValue ~= nil then
            local Ok, _ = Stats.WriteStat(Character, Def.set, Def.attr, NewValue)
            if Ok then
                Applied = Applied + 1
            else
                Failed = Failed + 1
            end
        end
    end
    return Applied, Failed
end

return Stats
