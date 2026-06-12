local Scale = {}

local INI_NAME = "MagicScaleMod.ini"

local Config = {
    manaDivisor = 10,
    debugLog = false,
}

local AIGASLibrary = StaticFindObject("/Script/G1R.Default__AIGASLibrary")
local GothicGASLibrary = StaticFindObject("/Script/G1R.Default__GothicGASLibrary")
local ManaSetClass = StaticFindObject("/Script/G1R.AttributeSet_Mana")
local HealthSetClass = StaticFindObject("/Script/G1R.AttributeSet_Health")
local FireBoltDef = StaticFindObject("/Script/Angelscript.Default__FireBoltProjectileDefinition")

local cachedPlayer = nil
local logCounts = {}

local function trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function bool(v, default)
    local n = string.upper(trim(v))
    if n == "" then
        return default
    end
    if n == "1" or n == "TRUE" or n == "YES" or n == "ON" then
        return true
    end
    if n == "0" or n == "FALSE" or n == "NO" or n == "OFF" then
        return false
    end
    return default
end

local function num(v, default)
    local n = tonumber(trim(v))
    if n == nil then
        return default
    end
    return n
end

local function scriptDir()
    local ok, info = pcall(function()
        return debug.getinfo(1, "S")
    end)
    if not ok or not info or not info.source then
        return nil
    end
    local src = tostring(info.source)
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    return src:match("^(.*[\\/])[^\\/]*$")
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function iniPaths()
    local paths = {}
    local dir = scriptDir()
    if dir then
        paths[#paths + 1] = dir .. "..\\" .. INI_NAME
        paths[#paths + 1] = dir .. INI_NAME
    end
    paths[#paths + 1] = "ue4ss\\Mods\\MagicScaleMod\\" .. INI_NAME
    paths[#paths + 1] = "Mods\\MagicScaleMod\\" .. INI_NAME
    paths[#paths + 1] = INI_NAME
    return paths
end

local function parseIni(content)
    local t = {}
    for line in string.gmatch(tostring(content or ""), "[^\r\n]+") do
        local s = trim(line)
        if s ~= "" and s:sub(1, 1) ~= ";" and s:sub(1, 1) ~= "#" then
            local k, v = s:match("^([%w_]+)%s*=%s*(.-)%s*$")
            if k then
                t[string.upper(k)] = v
            end
        end
    end
    return t
end

function Scale.ReloadConfig()
    local content
    for _, path in ipairs(iniPaths()) do
        content = readFile(path)
        if content then
            break
        end
    end
    if not content then
        return
    end
    local ini = parseIni(content)
    Config.manaDivisor = math.max(0.001, num(ini.MANADIVISOR, Config.manaDivisor))
    Config.debugLog = bool(ini.DEBUGLOG, Config.debugLog)
end

Scale.ReloadConfig()

local function isValid(obj)
    if obj == nil then
        return false
    end
    local ok, valid = pcall(function()
        return obj.IsValid ~= nil and obj:IsValid()
    end)
    return ok and valid
end

local function unwrap(param)
    if param == nil then
        return nil
    end
    if type(param) ~= "userdata" and type(param) ~= "table" then
        return param
    end
    local ok, value = pcall(function()
        return param:get()
    end)
    if ok then
        return value
    end
    return param
end

local function fullName(obj)
    if not isValid(obj) then
        return ""
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    return ok and tostring(name) or ""
end

function Scale.RefreshCachedPlayer()
    if isValid(cachedPlayer) then
        return cachedPlayer
    end
    local okPc, pc = pcall(function()
        return FindFirstOf("PlayerController")
    end)
    if okPc and isValid(pc) then
        local pawnOk, pawn = pcall(function()
            return pc.Pawn
        end)
        if pawnOk and isValid(pawn) then
            cachedPlayer = pawn
            return cachedPlayer
        end
    end
    local ok, player = pcall(function()
        return FindFirstOf("GothicPlayerCharacter")
    end)
    if ok and isValid(player) then
        cachedPlayer = player
        return player
    end
    return nil
end

function Scale.GetCachedPlayer()
    if isValid(cachedPlayer) then
        return cachedPlayer
    end
    return Scale.RefreshCachedPlayer()
end

local function isPlayerActor(actor)
    actor = unwrap(actor)
    if not isValid(actor) then
        return false
    end
    local cached = Scale.GetCachedPlayer()
    if isValid(cached) and cached == actor then
        return true
    end
    local ok, yes = pcall(function()
        if actor.IsPlayerCharacter and actor:IsPlayerCharacter() then
            return true
        end
        if actor.IsPlayerCharacterOrPlayerControlled and actor:IsPlayerCharacterOrPlayerControlled() then
            return true
        end
        return actor:IsPlayerControlled()
    end)
    return ok and yes == true
end

function Scale.ResolveScalingCharacter(character)
    character = unwrap(character)
    if isPlayerActor(character) then
        return character
    end
    return Scale.GetCachedPlayer()
end

function Scale.GetMaxMana(character)
    character = Scale.ResolveScalingCharacter(character)
    if not isValid(character) then
        return nil
    end

    if isValid(AIGASLibrary) and isValid(ManaSetClass) then
        local ok, value = pcall(function()
            return AIGASLibrary:GetAttributeValue(
                character,
                ManaSetClass,
                UEHelpers.FindFName("MaxMana")
            )
        end)
        if ok and type(value) == "number" then
            return value
        end
    end

    local okAsc, asc = pcall(function()
        return character:GetAbilitySystemComponent()
    end)
    if okAsc and isValid(asc) then
        local found = nil
        pcall(function()
            asc.SpawnedAttributes:ForEach(function(_, elem)
                if found then
                    return
                end
                local set = elem:get()
                if not isValid(set) then
                    return
                end
                local cnOk, cn = pcall(function()
                    return set:GetClass():GetFName():ToString()
                end)
                if cnOk and cn == "AttributeSet_Mana" then
                    found = set
                end
            end)
        end)
        if found then
            local okVal, value = pcall(function()
                local field = found.MaxMana
                if field == nil then
                    return nil
                end
                if type(field.CurrentValue) == "number" then
                    return field.CurrentValue
                end
                return field.BaseValue
            end)
            if okVal and type(value) == "number" then
                return value
            end
        end
    end

    return nil
end

function Scale.GetDamageMultiplier(character)
    local maxMana = Scale.GetMaxMana(character)
    if maxMana == nil then
        return 1.0, nil
    end
    return maxMana / Config.manaDivisor, maxMana
end

local function logOnce(tag, multiplier, maxMana, detail)
    logCounts[tag] = (logCounts[tag] or 0) + 1
    if not Config.debugLog and logCounts[tag] > 8 then
        return
    end
    print(string.format(
        "[MagicScaleMod] %s x%.1f MaxMana=%.0f%s\n",
        tag,
        multiplier,
        maxMana or -1,
        detail or ""
    ))
end

function Scale.IsPlayerSpellProjectile(projectile, player)
    projectile = unwrap(projectile)
    player = Scale.ResolveScalingCharacter(player)
    if not isValid(projectile) or not isValid(player) then
        return false
    end

    if fullName(projectile):find("Default__", 1, true) then
        return false
    end

    local okOwner, owner = pcall(function()
        return projectile:GetOwner()
    end)
    if okOwner and isPlayerActor(owner) then
        return true
    end

    local okInst, instigator = pcall(function()
        return projectile.Instigator
    end)
    if okInst and isPlayerActor(instigator) then
        return true
    end

    return false
end

local function computeScaledSpellLevel(before, multiplier)
    if type(multiplier) ~= "number" or multiplier <= 1.0 then
        return nil
    end
    if type(before) ~= "number" or before <= 0 then
        return math.max(1, math.floor(multiplier + 0.5))
    end
    return math.max(1, math.floor(before * multiplier + 0.5))
end

function Scale.ApplyScaledSpellLevel(projectile, tag)
    projectile = unwrap(projectile)
    if not isValid(projectile) then
        return false
    end

    local player = Scale.GetCachedPlayer()
    if not Scale.IsPlayerSpellProjectile(projectile, player) then
        return false
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(player)
    if multiplier <= 1.0 then
        return false
    end

    local before = nil
    pcall(function()
        before = projectile.m_SpellLevel
        if type(before) ~= "number" then
            before = projectile:GetSpellLevel()
        end
    end)

    local after = computeScaledSpellLevel(before, multiplier)
    if after == nil then
        return false
    end

    local wrote = false
    pcall(function()
        projectile.m_SpellLevel = after
        wrote = true
    end)

    if wrote then
        logOnce(tag, multiplier, maxMana,
            string.format(" lvl %s->%d", tostring(before), after))
    end
    return wrote
end

function Scale.GetSpellBaseDamage(player, projectileDef)
    player = Scale.ResolveScalingCharacter(player)
    if not isValid(player) then
        return nil
    end

    local def = projectileDef
    if not isValid(def) and isValid(FireBoltDef) then
        def = FireBoltDef
    end
    if not isValid(def) then
        return nil
    end

    local damage = nil
    pcall(function()
        damage = def:GetDamageByCharacterMagicCircle(player)
    end)
    if type(damage) == "number" and damage > 0 then
        return damage
    end

    return nil
end

local function findHealthAttributeSet(character)
    local asc = nil
    if isValid(GothicGASLibrary) then
        pcall(function()
            asc = GothicGASLibrary:GetAbilitySystemComponent(character)
        end)
    end
    if not isValid(asc) then
        pcall(function()
            asc = character:GetAbilitySystemComponent()
        end)
    end
    if not isValid(asc) then
        return nil, nil
    end

    local healthSet = nil
    pcall(function()
        asc.SpawnedAttributes:ForEach(function(_, elem)
            if healthSet then
                return
            end
            local set = elem:get()
            if not isValid(set) then
                return
            end
            local cnOk, cn = pcall(function()
                return set:GetClass():GetFName():ToString()
            end)
            if cnOk and cn == "AttributeSet_Health" then
                healthSet = set
            end
        end)
    end)
    return asc, healthSet
end

function Scale.ApplyHealthDelta(character, delta)
    character = unwrap(character)
    if not isValid(character) or type(delta) ~= "number" or delta == 0 then
        return false
    end

    local asc, healthSet = findHealthAttributeSet(character)
    if isValid(healthSet) then
        local okWrite = false
        pcall(function()
            local cur = healthSet.Health.CurrentValue
            if type(cur) ~= "number" then
                cur = healthSet.Health.BaseValue
            end
            if type(cur) == "number" then
                local newValue = cur + delta
                healthSet.Health.CurrentValue = newValue
                healthSet.Health.BaseValue = newValue
                okWrite = true
            end
        end)
        if okWrite then
            return true
        end
    end

    if isValid(asc) then
        local okMod = pcall(function()
            asc:ModAttributeUnsafe(HealthSetClass.Health, 0, delta)
        end)
        if okMod then
            return true
        end
    end

    if isValid(AIGASLibrary) and isValid(HealthSetClass) then
        local okCur, current = pcall(function()
            return AIGASLibrary:GetAttributeValue(
                character,
                HealthSetClass,
                UEHelpers.FindFName("Health")
            )
        end)
        if okCur and type(current) == "number" then
            local newValue = current + delta
            if isValid(healthSet) then
                pcall(function()
                    healthSet.Health.CurrentValue = newValue
                    healthSet.Health.BaseValue = newValue
                end)
                return true
            end
        end
    end

    return false
end

function Scale.ApplySpellBonusDamage(target, player, projectile, tag)
    target = unwrap(target)
    player = Scale.ResolveScalingCharacter(player)
    if not isValid(target) or not isValid(player) or isPlayerActor(target) then
        return false
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(player)
    if multiplier <= 1.0 then
        return false
    end

    local def = nil
    if isValid(projectile) then
        pcall(function()
            def = projectile.m_ProjectileDefinition
        end)
    end

    local baseDamage = Scale.GetSpellBaseDamage(player, def)
    if baseDamage == nil then
        if Config.debugLog then
            logOnce(tag .. " noBase", multiplier, maxMana, "")
        end
        return false
    end

    local bonus = baseDamage * (multiplier - 1.0)
    if bonus <= 0 then
        return false
    end

    if Scale.ApplyHealthDelta(target, -bonus) then
        logOnce(tag, multiplier, maxMana,
            string.format(" -%.0f hp (base %.0f)", bonus, baseDamage))
        return true
    end

    if Config.debugLog then
        logOnce(tag .. " writeFail", multiplier, maxMana,
            string.format(" base %.0f bonus %.0f", baseDamage, bonus))
    end
    return false
end

function Scale.OnProjectileEarly(projectileSelf, tag)
    Scale.ApplyScaledSpellLevel(projectileSelf, tag)
end

function Scale.OnProjectileOverlapPre(projectileSelf, otherActorParam)
    local projectile = unwrap(projectileSelf)
    local other = unwrap(otherActorParam)
    if not isValid(projectile) or not isValid(other) or isPlayerActor(other) then
        return
    end

    if not Scale.ApplyScaledSpellLevel(projectile, "OverlapPre") then
        return
    end

    local player = Scale.GetCachedPlayer()
    Scale.ApplySpellBonusDamage(other, player, projectile, "OverlapBonus")
end

function Scale.OnProjectileHitPost(projectileSelf, otherActorParam)
    local projectile = unwrap(projectileSelf)
    local target = unwrap(otherActorParam)
    local player = Scale.GetCachedPlayer()

    if not isValid(projectile) or not isValid(target) or not isValid(player) then
        return
    end
    if not Scale.IsPlayerSpellProjectile(projectile, player) or isPlayerActor(target) then
        return
    end

    Scale.ApplyScaledSpellLevel(projectile, "HitLate")
    Scale.ApplySpellBonusDamage(target, player, projectile, "HitBonus")
end

function Scale.OnActorSpawnedPost(_abilitySelf, actorSpawnedParam)
    Scale.ApplyScaledSpellLevel(actorSpawnedParam, "Spawn")
end

local function isDamageStatKey(key)
    key = string.lower(tostring(key or ""))
    if key == "" then
        return false
    end
    return key:find("damage", 1, true)
        or key:find("schaden", 1, true)
        or key:find("dmg", 1, true)
        or key:find("урон", 1, true)
        or key:find("magic circle", 1, true)
        or key:find("magischer", 1, true)
end

local function scaleIntParam(param, multiplier)
    local okGet, value = pcall(function()
        return param:get()
    end)
    if not okGet or type(value) ~= "number" or value == 0 then
        return false
    end
    local scaled = math.floor(value * multiplier + 0.5)
    if scaled == value then
        return false
    end
    local okSet = pcall(function()
        param:set(scaled)
    end)
    return okSet, value, scaled
end

function Scale.ApplyToItemStatsMap(statsMapParam)
    local player = Scale.GetCachedPlayer()
    if not isValid(player) then
        return
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(player)
    if multiplier <= 1.0 then
        return
    end

    local scaledAny = false
    local sample = ""

    pcall(function()
        statsMapParam:ForEach(function(_idx, elem)
            local pair = elem:get()
            if type(pair) ~= "table" then
                return
            end
            local key = pair.Key or pair.key or pair[1]
            local valueElem = pair.Value or pair.value or pair[2]
            if isDamageStatKey(key) and valueElem ~= nil then
                local ok, before, after = scaleIntParam(valueElem, multiplier)
                if ok then
                    scaledAny = true
                    if sample == "" then
                        sample = string.format(" %s:%d->%d", tostring(key), before, after)
                    end
                end
            end
        end)
    end)

    if not scaledAny then
        local ok, map = pcall(function()
            return statsMapParam:get()
        end)
        if ok and type(map) == "table" then
            for key, value in pairs(map) do
                if isDamageStatKey(key) and type(value) == "number" and value ~= 0 then
                    local scaled = math.floor(value * multiplier + 0.5)
                    map[key] = scaled
                    scaledAny = true
                    if sample == "" then
                        sample = string.format(" %s:%d->%d", tostring(key), value, scaled)
                    end
                end
            end
            if scaledAny then
                pcall(function()
                    statsMapParam:set(map)
                end)
            end
        end
    end

    if scaledAny then
        logOnce("itemStats", multiplier, maxMana, sample)
    end
end

local function scaleDamagesParam(DamagesParam, multiplier)
    local scaledAny = false
    pcall(function()
        DamagesParam:ForEach(function(_idx, elem)
            local ok, value = pcall(function()
                return elem:get()
            end)
            if ok and type(value) == "number" and value ~= 0 then
                pcall(function()
                    elem:set(value * multiplier)
                end)
                scaledAny = true
            end
        end)
    end)
    if scaledAny then
        return true
    end

    local ok, arr = pcall(function()
        return DamagesParam:get()
    end)
    if not ok or type(arr) ~= "table" then
        return false
    end

    if #arr > 0 then
        for i = 1, #arr do
            if type(arr[i]) == "number" then
                arr[i] = arr[i] * multiplier
            end
        end
    else
        for k, v in pairs(arr) do
            if type(k) == "number" and type(v) == "number" then
                arr[k] = v * multiplier
            end
        end
    end

    return pcall(function()
        DamagesParam:set(arr)
    end)
end

function Scale.ApplyToDamages(DamagesParam, character)
    character = Scale.ResolveScalingCharacter(character)
    if not isValid(character) then
        return
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(character)
    if multiplier <= 1.0 then
        return
    end

    if scaleDamagesParam(DamagesParam, multiplier) then
        logOnce("FillWithDamage", multiplier, maxMana, "")
    end
end

function Scale.OnMagicCircleDamagePost(returnValueParam, character)
    character = Scale.ResolveScalingCharacter(character)
    if not isValid(character) then
        return
    end

    local multiplier, maxMana = Scale.GetDamageMultiplier(character)
    if multiplier <= 1.0 then
        return
    end

    local okGet, value = pcall(function()
        return returnValueParam:get()
    end)
    if not okGet or type(value) ~= "number" then
        return
    end

    local before = value
    local okSet = pcall(function()
        returnValueParam:set(value * multiplier)
    end)
    if okSet then
        logOnce("MagicCircle", multiplier, maxMana, string.format(" %.0f->%.0f", before, before * multiplier))
    end
end

return Scale
