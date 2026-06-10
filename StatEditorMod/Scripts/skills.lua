local UEHelpers = require("UEHelpers")
local Stats = require("stats")

local Skills = {}

local CharacterMixinsStatics = StaticFindObject("/Script/Angelscript.Default__Module_GAS_GASCharacterMixinsStatics")
local CharacterStateMixinsStatics = StaticFindObject("/Script/Angelscript.Default__Module_GAS_GASCharacterStateMixinsStatics")

local SkillClassCache = {}

local MAGIC_CIRCLE_SKILL_NAMES = {
    [0] = "GE_Skill_Mage_Circle_Untrained",
    [1] = "GE_Skill_Mage_Circle_1",
    [2] = "GE_Skill_Mage_Circle_2",
    [3] = "GE_Skill_Mage_Circle_3",
    [4] = "GE_Skill_Mage_Circle_4",
    [5] = "GE_Skill_Mage_Circle_5",
    [6] = "GE_Skill_Mage_Circle_6",
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

local function GetWorldContext()
    local World = UEHelpers.GetWorld()
    if IsValidUObjectSafe(World) then
        return World
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

local function TryGiveSkill(Character, SkillClass)
    local World = GetWorldContext()

    if IsValidUObjectSafe(CharacterMixinsStatics) then
        local Ok, Result = pcall(function()
            return CharacterMixinsStatics:GiveSkill(Character, SkillClass, World)
        end)
        if Ok and Result ~= false then
            return true, "GiveSkill"
        end
    end

    local State = Stats.GetCharacterState(Character)
    if State and IsValidUObjectSafe(CharacterStateMixinsStatics) then
        local Ok, Result = pcall(function()
            return CharacterStateMixinsStatics:LearnSkillForFree(State, SkillClass, World)
        end)
        if Ok and Result then
            return true, "LearnSkillForFree"
        end
    end

    return false, nil
end

local function TryApplySkillGE(Character, SkillClass)
    local ASC = Stats.GetAbilitySystem(Character)
    if not IsValidUObjectSafe(ASC) then
        return false, nil
    end

    local Ok = pcall(function()
        ASC:BP_ApplyGameplayEffectToSelf(SkillClass, 1.0)
    end)
    if Ok then
        return true, "BP_ApplyGameplayEffectToSelf"
    end

    Ok = pcall(function()
        local Context = ASC:MakeEffectContext()
        ASC:BP_ApplyGameplayEffectToSelf(SkillClass, 1.0, Context)
    end)
    if Ok then
        return true, "BP_ApplyGameplayEffectToSelf+Context"
    end

    return false, nil
end

function Skills.SetMagicCircleLevel(Character, Level)
    local CircleLevel = math.floor(tonumber(Level) or -1)
    if CircleLevel < 0 or CircleLevel > 6 then
        return false, "magic circle must be 0-6"
    end

    local SkillName = MAGIC_CIRCLE_SKILL_NAMES[CircleLevel]
    if not SkillName then
        return false, "missing skill mapping"
    end

    local SkillClass = FindSkillClass(SkillName)
    if not SkillClass then
        return false, "missing skill class " .. SkillName
    end

    local Ok, Method = TryGiveSkill(Character, SkillClass)
    if not Ok then
        Ok, Method = TryApplySkillGE(Character, SkillClass)
    end

    if not Ok then
        local AttrOk, AttrErr = Stats.WriteAttribute(
            Character,
            "/Script/G1R.AttributeSet_Mana",
            "MagicianLevel",
            CircleLevel
        )
        if AttrOk then
            return true, "attribute only (skill grant failed)"
        end
        return false, AttrErr or "skill grant failed"
    end

    Stats.WriteAttribute(
        Character,
        "/Script/G1R.AttributeSet_Mana",
        "MagicianLevel",
        CircleLevel
    )

    return true, Method
end

return Skills
