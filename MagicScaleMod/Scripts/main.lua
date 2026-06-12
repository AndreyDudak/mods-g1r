-- MagicScaleMod v5: early native projectile hooks (Angelscript UFunction hooks fail on G1R).

local Scale = require("scale")

local HOOK_RUNE = "/Script/G1R.MagicScriptLibrary:FillWithDamageTypeAndDamageAmountFromRuneSpellContainer"
local HOOK_MAGIC_CIRCLE_DMG = "/Script/G1R.SpellProjectileDefinition:GetDamageByCharacterMagicCircle"
local HOOK_ITEM_STATS = "/Script/G1R.ContainerManagerWidget:GetItemStatsByPos_Implementation"
local HOOK_PROJECTILE_BEGIN = "/Script/G1R.ProjectileVisual:OnProjectileBeginPlay"
local HOOK_PROJECTILE_OVERLAP = "/Script/G1R.ProjectileVisual:OnOverlapBeginServer"
local HOOK_PROJECTILE_HIT = "/Script/G1R.ProjectileVisual:OnHitServer"
local HOOK_ACTOR_SPAWNED = "/Script/G1R.GameplayAbilitySpellBasic:OnActorSpawnedServer_Scriptable"
local HOOK_CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"

local function unwrap(param)
    if param == nil then
        return nil
    end
    local ok, value = pcall(function()
        return param:get()
    end)
    if ok then
        return value
    end
    return param
end

local function safeRegisterHook(path, preCb, postCb)
    local ok, err = pcall(function()
        RegisterHook(path, preCb or function() end, postCb or function() end)
    end)
    if not ok then
        print("[MagicScaleMod] Hook FAILED " .. path .. ": " .. tostring(err) .. "\n")
        return false
    end
    return true
end

safeRegisterHook(HOOK_RUNE, function()
end, function(_Context, _ReturnValue, GothicCharacter, _Container, _DamageType, Damages)
    pcall(function()
        Scale.ApplyToDamages(Damages, GothicCharacter)
    end)
end)

safeRegisterHook(HOOK_MAGIC_CIRCLE_DMG, function()
end, function(_Context, ReturnValue, Character, _DamageTag)
    pcall(function()
        Scale.OnMagicCircleDamagePost(ReturnValue, Character)
    end)
end)

safeRegisterHook(HOOK_ITEM_STATS, function()
end, function(_Context, ReturnValue, _Pos)
    pcall(function()
        Scale.ApplyToItemStatsMap(ReturnValue)
    end)
end)

safeRegisterHook(HOOK_PROJECTILE_BEGIN, function()
end, function(projectileSelf)
    pcall(function()
        Scale.OnProjectileEarly(unwrap(projectileSelf), "BeginPlay")
    end)
end)

safeRegisterHook(HOOK_PROJECTILE_OVERLAP, function(projectileSelf, _OverlappedComp, OtherActor)
    pcall(function()
        Scale.OnProjectileOverlapPre(unwrap(projectileSelf), OtherActor)
    end)
end, function()
end)

safeRegisterHook(HOOK_PROJECTILE_HIT, function()
end, function(projectileSelf, _HitComp, OtherActor)
    pcall(function()
        Scale.OnProjectileHitPost(unwrap(projectileSelf), OtherActor)
    end)
end)

safeRegisterHook(HOOK_ACTOR_SPAWNED, function()
end, function(_abilitySelf, actorSpawned)
    pcall(function()
        Scale.OnActorSpawnedPost(unwrap(_abilitySelf), actorSpawned)
    end)
end)

safeRegisterHook(HOOK_CLIENT_RESTART, function()
end, function(_Context, _NewPawn)
    ExecuteInGameThread(function()
        Scale.RefreshCachedPlayer()
    end)
end)

RegisterLoadMapPostHook(function()
    ExecuteInGameThread(function()
        Scale.ReloadConfig()
        Scale.RefreshCachedPlayer()
    end)
end)

ExecuteInGameThread(function()
    Scale.ReloadConfig()
    Scale.RefreshCachedPlayer()
end)

print("[MagicScaleMod] Loaded v5: OverlapPre + BeginPlay + Spawn + hit bonus (7 hooks).\n")
