local Stats = require("stats")

local Skills = {}

local SkillClassCache = {}
local CharacterMixinsStatics = nil
local CharacterStateMixinsStatics = nil

local MAGIC_CIRCLE_SKILL_NAMES = {
    [0] = { "GE_Skill_Mage_Circle_Untrained" },
    [1] = { "GE_Skill_Mage_Circle_1", "GE_Skill_Mage_Circle_Amateur" },
    [2] = { "GE_Skill_Mage_Circle_2" },
    [3] = { "GE_Skill_Mage_Circle_3" },
    [4] = { "GE_Skill_Mage_Circle_4" },
    [5] = { "GE_Skill_Mage_Circle_5" },
    [6] = { "GE_Skill_Mage_Circle_6" },
}

local function IsValidUObjectSafe(Obj)
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

local function GetCharacterMixinsStatics()
    if IsValidUObjectSafe(CharacterMixinsStatics) then
        return CharacterMixinsStatics
    end
    local Ok, Lib = pcall(function()
        return StaticFindObject("/Script/Angelscript.Default__Module_GAS_GASCharacterMixinsStatics")
    end)
    if Ok and IsValidUObjectSafe(Lib) then
        CharacterMixinsStatics = Lib
        return Lib
    end
    return nil
end

local function GetCharacterStateMixinsStatics()
    if IsValidUObjectSafe(CharacterStateMixinsStatics) then
        return CharacterStateMixinsStatics
    end
    local Ok, Lib = pcall(function()
        return StaticFindObject("/Script/Angelscript.Default__Module_GAS_GASCharacterStateMixinsStatics")
    end)
    if Ok and IsValidUObjectSafe(Lib) then
        CharacterStateMixinsStatics = Lib
        return Lib
    end
    return nil
end

local function GetWorldContext(Character)
    -- Do not use UEHelpers.GetWorld() — it calls FindAllOf(PlayerController) and crashes on G1R.

    if IsValidUObjectSafe(Character) then
        local Ok, CharWorld = pcall(function()
            return Character:GetWorld()
        end)
        if Ok and IsValidUObjectSafe(CharWorld) then
            return CharWorld
        end
    end

    local PC = Stats.GetPlayerController()
    if IsValidUObjectSafe(PC) then
        local Ok, PCWorld = pcall(function()
            return PC:GetWorld()
        end)
        if Ok and IsValidUObjectSafe(PCWorld) then
            return PCWorld
        end
    end

    local Ok, GameInstance = pcall(function()
        return FindFirstOf("GameInstance")
    end)
    if Ok and IsValidUObjectSafe(GameInstance) then
        local GiOk, GiWorld = pcall(function()
            return GameInstance:GetWorld()
        end)
        if GiOk and IsValidUObjectSafe(GiWorld) then
            return GiWorld
        end
    end

    return nil
end

local function FindSkillClass(SkillName)
    local Cached = SkillClassCache[SkillName]
    if IsValidUObjectSafe(Cached) then
        return Cached
    end

    local Paths = {
        "/Script/Angelscript." .. SkillName,
        "/Script/G1R." .. SkillName,
    }
    for _, Path in ipairs(Paths) do
        local Ok, Class = pcall(function()
            return StaticFindObject(Path)
        end)
        if Ok and IsValidUObjectSafe(Class) then
            SkillClassCache[SkillName] = Class
            return Class
        end
    end

    return nil
end

local function ReadMagicianLevel(Character)
    local Value, Err = Stats.ReadStat(
        Character,
        "/Script/G1R.AttributeSet_Mana",
        "MagicianLevel"
    )
    if type(Value) == "number" then
        return math.floor(Value + 0.5), nil
    end

    local Ok, Level = pcall(function()
        return Character:GetCharacterMagicCircleLevelFromAttr()
    end)
    if Ok and type(Level) == "number" then
        return math.floor(Level + 0.5), nil
    end

    return nil, Err or "read failed"
end

local function VerifyMagicianLevel(Character, ExpectedLevel)
    local Current = ReadMagicianLevel(Character)
    return Current == ExpectedLevel
end

local function TryApplySkillGEOnASC(ASC, SkillClass)
    if not IsValidUObjectSafe(ASC) then
        return false
    end

    local Ok, Handle = pcall(function()
        return ASC:BP_ApplyGameplayEffectToSelf(SkillClass, 1.0)
    end)
    if Ok and Handle ~= nil then
        return true
    end

    Ok = pcall(function()
        local Context = ASC:MakeEffectContext()
        ASC:BP_ApplyGameplayEffectToSelf(SkillClass, 1.0, Context)
    end)
    return Ok
end

local function TryApplySkillGE(Character, SkillClass)
    if TryApplySkillGEOnASC(Stats.GetAbilitySystem(Character), SkillClass) then
        return true
    end

    local State = Stats.GetCharacterState(Character)
    if TryApplySkillGEOnASC(SafeGet(State, "AbilitySystemComponent"), SkillClass) then
        return true
    end

    return false
end

local function TryGrantSkill(Character, SkillClass, World)
    local State = Stats.GetCharacterState(Character)
    local StateMixins = GetCharacterStateMixinsStatics()

    if State and IsValidUObjectSafe(StateMixins) then
        local Ok, Result = pcall(function()
            return StateMixins:LearnSkillForFree(State, SkillClass, World)
        end)
        if Ok and Result then
            return true, "LearnSkillForFree"
        end

        Ok, Result = pcall(function()
            return StateMixins:LearnSkill(State, SkillClass, false, World)
        end)
        if Ok and Result then
            return true, "LearnSkill"
        end
    end

    local CharMixins = GetCharacterMixinsStatics()
    if IsValidUObjectSafe(CharMixins) then
        local Ok, Result = pcall(function()
            return CharMixins:GiveSkill(Character, SkillClass, World)
        end)
        if Ok and Result ~= false then
            return true, "GiveSkill"
        end
    end

    if TryApplySkillGE(Character, SkillClass) then
        return true, "BP_ApplyGameplayEffectToSelf"
    end

    return false, nil
end

local function SyncMagicianAttribute(Character, CircleLevel)
    Stats.WriteAttribute(
        Character,
        "/Script/G1R.AttributeSet_Mana",
        "MagicianLevel",
        CircleLevel
    )
end

function Skills.SetMagicCircleLevel(Character, Level)
    local CircleLevel = math.floor(tonumber(Level) or -1)
    if CircleLevel < 0 or CircleLevel > 6 then
        return false, "magic circle must be 0-6"
    end

    local SkillNames = MAGIC_CIRCLE_SKILL_NAMES[CircleLevel]
    if not SkillNames then
        return false, "missing skill mapping"
    end

    local World = GetWorldContext(Character)
    if not IsValidUObjectSafe(World) then
        return false, "no world context (load a save first)"
    end

    local Failures = {}

    for _, SkillName in ipairs(SkillNames) do
        local SkillClass = FindSkillClass(SkillName)
        if not SkillClass then
            table.insert(Failures, SkillName .. ": class not found")
        else
            local Ok, Method = TryGrantSkill(Character, SkillClass, World)
            if Ok then
                SyncMagicianAttribute(Character, CircleLevel)
                if VerifyMagicianLevel(Character, CircleLevel) then
                    return true, Method .. " (" .. SkillName .. ")"
                end
                table.insert(Failures, SkillName .. ": " .. Method .. " but level unchanged")
            else
                table.insert(Failures, SkillName .. ": grant failed")
            end
        end
    end

    return false, table.concat(Failures, "; ")
end

return Skills
