-- PassiveRegen - passive HP/Mana regeneration for Gothic 1 Remake (UE4SS Lua)
--
-- G1R uses GAS: HP/Mana are FGameplayAttributeData (BaseValue/CurrentValue) inside
-- AttributeSets on the GothicAbilitySystemComponent (at the PlayerState):
--   AttributeSet_Health : Health (current) + MaxHealth (maximum)
--   AttributeSet_Mana   : Mana   (current) + MaxMana  (maximum)
--
-- Write path: write the attribute directly (Base+Current), then refresh the HUD via
-- Player_Widget_C -> W_HealthBar/W_ManaBar (set the cached display fields + call the BP
-- function "Update Value"). The old Reset() crashes on this build, so "Update Value" is used.
--
-- Settings live in PassiveRegen.ini (one level above Scripts/); edit + Ctrl+R applies them.

local UEHelpers = require("UEHelpers")

-- ============ Configuration ============
-- Defaults; overridden on load from PassiveRegen.ini (see loadConfig below).
local Config = {
    -- HP
    hpRegen          = true,    -- HpRegenEnabled
    minStrengthForHp = 0,       -- MinStrengthForHp: HP only if Strength >= value (0 = off)
    regenHpInCombat  = false,   -- RegenHpInCombat: regen HP during combat/aggro too?
    -- MP
    manaRegen        = true,    -- MpRegenEnabled
    minMaxManaForMp  = 0,       -- MinMaxManaForMp: MP only if MaxMana >= value (0 = off)
    regenMpInCombat  = false,   -- RegenMpInCombat: regen MP during combat/aggro too?
    clearOutOfManaGate = true,  -- ClearOutOfManaGate: when mana hits 0, clear the game's hidden
                                -- "out of mana" cast block (else casting stays disabled after refill)
    -- Tuning
    hpPercentPerTick   = 0.01,  -- 1% of MaxHealth per tick
    manaPercentPerTick = 0.01,  -- 1% of MaxMana per tick
    tickIntervalMs     = 1000,
    combatCooldownSeconds = 10, -- cooldown after combat/aggro
    aggroBlocksRegen   = true,  -- block regen while a nearby enemy is aggressive (set false for max perf)
    aggroRangeUnits    = 4000,  -- range within which an aggressive enemy blocks regen (0 = any)
    -- Controls
    toggleKey        = "F8",    -- key that toggles the mod on/off; "NONE" to disable the toggle
}

-- Per-resource regen cadence in base loop ticks (HP and MP can use different clocks).
-- Computed from HpIntervalSeconds / MpIntervalSeconds in loadConfig (default = TickIntervalSeconds).
local hpEveryTicks, mpEveryTicks = 1, 1

-- ---------- Load INI (PassiveRegen.ini in the mod folder, one level above Scripts/) ----------
local INI_NAME = "PassiveRegen.ini"
local function _trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
local function _bool(v, d)
    local n = string.upper(_trim(v))
    if n == "" then return d end
    if n == "1" or n == "TRUE"  or n == "YES" or n == "ON"  then return true end
    if n == "0" or n == "FALSE" or n == "NO"  or n == "OFF" then return false end
    return d
end
local function _num(v, d) local n = tonumber(_trim(v)); if n == nil then return d end; return n end
local function _scriptDir()
    local ok, info = pcall(function() return debug.getinfo(1, "S") end)
    if not ok or not info or not info.source then return nil end
    local src = tostring(info.source); if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*[\\/])[^\\/]*$")
end
local function _readFile(p) local f = io.open(p, "r"); if not f then return nil end; local c = f:read("*a"); f:close(); return c end
local function _iniPaths()
    local paths, dir = {}, _scriptDir()
    if dir then paths[#paths+1] = dir .. "..\\" .. INI_NAME; paths[#paths+1] = dir .. INI_NAME end
    paths[#paths+1] = "ue4ss\\Mods\\PassiveRegen\\" .. INI_NAME
    paths[#paths+1] = "Mods\\PassiveRegen\\" .. INI_NAME
    paths[#paths+1] = INI_NAME
    return paths
end
local function _parseIni(content)
    local t = {}
    for line in string.gmatch(tostring(content or ""), "[^\r\n]+") do
        local s = _trim(line)
        if s ~= "" and s:sub(1,1) ~= ";" and s:sub(1,1) ~= "#" then
            local k, v = s:match("^([%w_]+)%s*=%s*(.-)%s*$")
            if k then t[string.upper(k)] = v end
        end
    end
    return t
end
local function loadConfig()
    local content
    for _, p in ipairs(_iniPaths()) do content = _readFile(p); if content then break end end
    if not content then print("[PassiveRegen] INI not found -> using defaults.\n"); return end
    local ini = _parseIni(content)
    Config.hpRegen          = _bool(ini.HPREGENENABLED,  Config.hpRegen)
    Config.minStrengthForHp = _num (ini.MINSTRENGTHFORHP, Config.minStrengthForHp)
    Config.regenHpInCombat  = _bool(ini.REGENHPINCOMBAT,  Config.regenHpInCombat)
    Config.manaRegen        = _bool(ini.MPREGENENABLED,   Config.manaRegen)
    Config.minMaxManaForMp  = _num (ini.MINMAXMANAFORMP,  Config.minMaxManaForMp)
    Config.regenMpInCombat  = _bool(ini.REGENMPINCOMBAT,  Config.regenMpInCombat)
    Config.clearOutOfManaGate = _bool(ini.CLEAROUTOFMANAGATE, Config.clearOutOfManaGate)
    Config.hpPercentPerTick   = _num(ini.HPPERCENTPERTICK, Config.hpPercentPerTick)
    Config.manaPercentPerTick = _num(ini.MPPERCENTPERTICK, Config.manaPercentPerTick)
    Config.tickIntervalMs   = math.max(100, math.floor(_num(ini.TICKINTERVALSECONDS, 1) * 1000))
    -- Separate clocks: HP and MP each regen every HpIntervalSeconds / MpIntervalSeconds
    -- (rounded to multiples of the base TickIntervalSeconds; default = base = same as before).
    local baseS = Config.tickIntervalMs / 1000
    hpEveryTicks = math.max(1, math.floor(_num(ini.HPINTERVALSECONDS, baseS) / baseS + 0.5))
    mpEveryTicks = math.max(1, math.floor(_num(ini.MPINTERVALSECONDS, baseS) / baseS + 0.5))
    Config.combatCooldownSeconds = _num(ini.COMBATCOOLDOWNSECONDS, Config.combatCooldownSeconds)
    Config.aggroBlocksRegen = _bool(ini.AGGROBLOCKSREGEN, Config.aggroBlocksRegen)
    Config.aggroRangeUnits  = _num(ini.AGGRORANGEUNITS, Config.aggroRangeUnits)
    local tk = _trim(ini.TOGGLEKEY); if tk ~= "" then Config.toggleKey = tk end
    print(string.format("[PassiveRegen] INI loaded: HP=%s(minStr=%s,inCombat=%s) MP=%s(minMaxMana=%s,inCombat=%s)\n",
        tostring(Config.hpRegen), tostring(Config.minStrengthForHp), tostring(Config.regenHpInCombat),
        tostring(Config.manaRegen), tostring(Config.minMaxManaForMp), tostring(Config.regenMpInCombat)))
end
loadConfig()

local enabled = true

-- ---------- Helpers ----------
local function safe(fn, fb) local ok, v = pcall(fn); if ok then return v end; return fb end
local function isUObject(v)
    if v == nil then return false end
    return safe(function() return v.IsValid ~= nil and v:IsValid() end, false)
end

-- Call a UFunction reflectively: find it via StaticFindObject, then invoke it. Needed because some
-- direct method calls (asc:MakeEffectContext()) crash on this UE4SS build with "Array failed
-- invariants"; the reflected path avoids that. The function object is cached.
-- Which invocation form works is SETUP-DEPENDENT: obj:CallFunction(fn) succeeds quietly on some
-- installs but fails on others (logging a benign "without both UFunction and calling context"),
-- where fn(obj, ...) is the form that works. So we try each form and REMEMBER the one that worked
-- for this function -> the noisy form is only ever attempted once, then skipped (clean log).
local _reflFn = {}
local _reflMode = {}  -- path -> "call" | "self" | "bare" (the form that last succeeded)
local function callReflected(obj, path, ...)
    if not isUObject(obj) then return false, "obj invalid" end
    local fn = _reflFn[path]
    if not isUObject(fn) then
        fn = safe(function() return StaticFindObject("Function " .. path) end, nil)
        if not isUObject(fn) then fn = safe(function() return StaticFindObject(path) end, nil) end
        _reflFn[path] = fn
    end
    if not isUObject(fn) then return false, "fn not found" end
    local a, n = { ... }, select("#", ...)
    local up = table.unpack or unpack
    local function invoke(m)
        if m == "self" then return fn(obj, up(a, 1, n)) end
        if m == "bare" then return fn(up(a, 1, n)) end
        return obj:CallFunction(fn, up(a, 1, n))
    end
    local order = ({ self = { "self", "call", "bare" }, bare = { "bare", "call", "self" } })[_reflMode[path]]
        or { "call", "self", "bare" }
    local firstErr
    for _, m in ipairs(order) do
        local ok, v = pcall(invoke, m)
        if ok then _reflMode[path] = m; return true, v end
        if firstErr == nil then firstErr = v end
    end
    return false, tostring(firstErr)
end

-- ---------- Player pawn / ASC / AttributeSets (cached) ----------
local C = { pawn = nil, asc = nil, health = nil, mana = nil, strength = nil, anim = nil, playerWidget = nil }

-- Ticks since the last combat action (for the cooldown). Start high -> regen allowed immediately.
local ticksSinceCombat = 1e9
local hpTickCounter, mpTickCounter = 0, 0  -- count base ticks for the separate HP/MP clocks
local lastHp = nil          -- previous Health reading, to detect "took damage" cheaply (no scan)

local function getPawn()
    local ok, pc = pcall(UEHelpers.GetPlayerController)   -- throws in the menu -> pcall
    if not ok or not isUObject(pc) then
        pc = safe(function() return FindFirstOf("PlayerController") end, nil)
    end
    if not isUObject(pc) then return nil end
    local pawn = safe(function() return pc.Pawn end, nil)
    if not isUObject(pawn) then return nil end
    return pawn
end

local function resolve()
    local pawn = getPawn()
    if not pawn then return false end
    local asc = safe(function() return pawn.Mesh.AbilityComp end, nil)
    if not isUObject(asc) then return false end
    C.pawn, C.asc, C.health, C.mana, C.strength = pawn, asc, nil, nil, nil
    C.playerWidget = nil  -- death/reload re-resolves the pawn -> drop the HUD widget cache too
    C.anim = safe(function() return pawn.Mesh.AnimScriptInstance end, nil)
    if not isUObject(C.anim) then C.anim = safe(function() return pawn.Mesh:GetAnimInstance() end, nil) end
    pcall(function()
        asc.SpawnedAttributes:ForEach(function(_, elem)
            local s = elem:get()
            if isUObject(s) then
                local cn = safe(function() return s:GetClass():GetFName():ToString() end, "")
                if     cn == "AttributeSet_Health"   then C.health   = s
                elseif cn == "AttributeSet_Mana"     then C.mana     = s
                elseif cn == "AttributeSet_Strength" then C.strength = s end
            end
        end)
    end)
    return isUObject(C.health) or isUObject(C.mana)
end

local function ensure()
    local needHp   = Config.hpRegen   and not isUObject(C.health)
    local needMana = Config.manaRegen and not isUObject(C.mana)
    local needStr  = Config.hpRegen and (Config.minStrengthForHp or 0) > 0 and not isUObject(C.strength)
    local needAnim = not isUObject(C.anim)  -- always needed (combat/death/cutscene detection)
    if needHp or needMana or needStr or needAnim or not isUObject(C.pawn) or not isUObject(C.asc) then return resolve() end
    return true
end

-- ---------- HUD bar sync ----------
-- Navigate Player_Widget_C -> W_HealthBar / W_ManaBar (UGameplayAttributeProgressBarWidget),
-- set the cached display fields and call the BP function "Update Value" (with a space!), which
-- redraws number + full bar. (The old Reset() crashes on this build.)
local barProp = { Health = "W_HealthBar", Mana = "W_ManaBar" }

-- The REAL on-screen HUD is the Player_UI widget that lives UNDER the persistent GothicGameInstance
-- (e.g. ".../GothicGameInstance_C_*.Player_UI"). After loading a savegame an orphaned copy lingers as
-- the bare "/Engine/Transient.Player_UI" (Player_UI in the name but NOT under GothicGameInstance);
-- updating that one is invisible -> only the shaded/lag bar follows. Verified in-game: BOTH live under
-- /Engine/Transient and IsInViewport() returns nil for both, so the GameInstance parent is the reliable
-- discriminator (not "Transient", not IsInViewport).
local function fullName(o) return tostring(safe(function() return o:GetFullName() end, "")) end
local function isRealHud(w)
    if not isUObject(w) then return false end
    local fn = fullName(w)
    return string.find(fn, "Player_UI", 1, true) ~= nil
        and string.find(fn, "GothicGameInstance", 1, true) ~= nil
end

-- HUD widget lookup. The cache MUST hold, otherwise the expensive FindAllOf (~30 ms!) runs every
-- regen tick. Hard-won rules from past stutter bugs:
--   * Do NOT disqualify widgets by "Transient" in the path: the REAL HUD itself lives under
--     /Engine/Transient, so excluding it made the cache miss every tick -> per-tick FindAllOf (1.0.4 bug).
--   * If isRealHud ever fails to match (e.g. a setup where the HUD path differs), RATE-LIMIT the re-scan
--     so it can never become a per-tick FindAllOf - at most once every few seconds, and self-healing.
local hudScanGate = 0
local function getPlayerWidget()
    if isRealHud(C.playerWidget) then return C.playerWidget end  -- ideal: real HUD cached -> no FindAllOf
    if isUObject(C.playerWidget) and hudScanGate > 0 then hudScanGate = hudScanGate - 1; return C.playerWidget end
    hudScanGate = math.max(1, math.floor(3000 / Config.tickIntervalMs))  -- >=3s between scans -> never per-tick
    local list = safe(function() return FindAllOf("Player_Widget_C") end, nil)
    if not list then return C.playerWidget end
    for _, w in ipairs(list) do  -- 1) the real GothicGameInstance HUD (excludes the /Engine/Transient orphan)
        if isRealHud(w) then C.playerWidget = w; return w end
    end
    for _, w in ipairs(list) do  -- 2) fallback: any non-Default instance (held until a real one appears)
        if isUObject(w) and not string.find(fullName(w), "Default__", 1, true) then C.playerWidget = w; return w end
    end
    return C.playerWidget
end

local function callBarUpdate(bar)
    for _, name in ipairs({ "Update Value", "UpdateValue" }) do
        local ok = pcall(function() local fn = bar[name]; fn(bar) end)
        if ok then return true end
    end
    return false
end

-- resource = "Health" | "Mana"
local function updateHudBar(resource, realValue, maxValue)
    if not realValue or not maxValue or maxValue <= 0 then return end
    local pw = getPlayerWidget()
    if not isUObject(pw) then return end
    local bar = safe(function() return pw[barProp[resource]] end, nil)
    if not isUObject(bar) then
        C.playerWidget = nil  -- possibly stale -> re-resolve next time
        return
    end
    local pct = realValue / maxValue
    pcall(function() bar.m_GameplayAttributeCurrentValue   = realValue end)
    pcall(function() bar.m_GameplayAttributeMaxValue       = maxValue end)
    pcall(function() bar.m_GameplayAttributeCurrentPercent = pct end)
    pcall(function() bar.m_GameplayAttributeInterpolatedPercent = pct end)
    callBarUpdate(bar)
end

-- ---------- Regenerate one attribute ----------
local function regenAttr(set, attrName, maxName, percent, noHealAtZero)
    if not isUObject(set) then return end
    local cur = safe(function() return set[attrName].CurrentValue end, nil)
    local max = safe(function() return set[maxName].CurrentValue end, nil)
    if not cur or not max or max <= 0 then return end
    if noHealAtZero and cur <= 0 then return end  -- HP: never heal at 0 (dead/K.O.). Mana: 0 is normal -> regen.
    if cur >= max then return end                 -- already full
    local nv = (cur < 0 and 0 or cur) + max * percent
    if nv > max then nv = max end
    pcall(function() set[attrName].BaseValue = nv end)
    pcall(function() set[attrName].CurrentValue = nv end)
    updateHudBar(attrName, nv, max)
end

-- ---------- "Out of mana" cast gate ----------
-- When mana hits exactly 0 the game blocks casting (a hidden GAS gate) and a direct attribute
-- write does NOT clear it - only applying a mana GameplayEffect through GAS does (what a potion
-- does). We apply GE_Item_Mana_Insta reflectively (adds ~0 mana, just clears the gate).
local manaEffectClass = nil  -- cached TSubclassOf<UGameplayEffect>
local function resolveManaEffect()
    if manaEffectClass ~= nil and isUObject(manaEffectClass) then return manaEffectClass end
    local defs = safe(function() return FindAllOf("ItemEffectDefinition") end, nil)  -- runs once, then cached
    if defs then
        for _, d in ipairs(defs) do
            if isUObject(d) and string.find(tostring(safe(function() return d:GetFullName() end, "")), "GE_Item_Mana_Insta", 1, true) then
                local ec = safe(function() return d.m_Effect end, nil)
                if ec ~= nil then manaEffectClass = ec; return ec end
            end
        end
    end
    return nil
end
-- Use a FRESHLY fetched ASC: the cached C.asc can be stale right after a state transition (e.g.
-- sleeping in a bed), which makes the reflected call fail with "...calling context". Give up after
-- a few genuine failures so we never keep retrying (and logging) on a setup that simply can't do this.
local manaGateFails = 0
local function clearManaGate()
    if manaGateFails >= 3 then return end  -- given up on this setup; mana still regenerates normally
    local pawn = getPawn()
    local asc  = pawn and safe(function() return pawn.Mesh.AbilityComp end, nil) or nil
    if not isUObject(asc) then asc = C.asc end
    if not isUObject(asc) then return end
    local ec = resolveManaEffect()
    if ec == nil then return end
    local okCtx, ctx = callReflected(asc, "/Script/GameplayAbilities.AbilitySystemComponent:MakeEffectContext")
    if okCtx then
        local okApply = callReflected(asc, "/Script/GameplayAbilities.AbilitySystemComponent:BP_ApplyGameplayEffectToSelf", ec, 1.0, ctx)
        if okApply then manaGateFails = 0; return end
    end
    manaGateFails = manaGateFails + 1
    if manaGateFails >= 3 then
        print("[PassiveRegen] Note: the out-of-mana cast gate fix isn't available on this setup; mana still regenerates normally.\n")
    end
end

-- ---------- State checks (cheap, readable AnimInstance bools) ----------
-- "In combat" = the hero's own combat action (m_IsInCombat). NOTE: the hero's own m_IsAggressive is
-- NOT usable - in-game it stays true even when peaceful (weapon drawn / lingers after a fight), so it
-- would wrongly block regen out of combat. We rely instead on m_IsInCombat + the "took damage" check
-- (in runTick) + the nearby-aggressive-ENEMY scan.
local function isInCombat()
    if not isUObject(C.anim) then return false end
    return safe(function() return C.anim.m_IsInCombat end, false) == true
end
local function isAlive()  -- death AND K.O. set m_IsAlive=false; only block when explicitly false
    if not isUObject(C.anim) then return true end
    return safe(function() return C.anim.m_IsAlive end, true) ~= false
end
local function isGamePaused()  -- UGameplayStatics.IsGamePaused(World) (does not crash on this build)
    local world = safe(function() return C.pawn:GetWorld() end, nil)
    if not isUObject(world) then return false end
    return safe(function() return UEHelpers.GetGameplayStatics():IsGamePaused(world) end, false) == true
end
local function isInCutsceneOrDialog()
    if not isUObject(C.anim) then return false end
    return safe(function() return C.anim.bIsInCinematic end, false) == true
        or safe(function() return C.anim.bIsInConversation end, false) == true
end
local function strengthOk()  -- HP requirement: Strength >= minStrengthForHp (0 = none)
    local minv = Config.minStrengthForHp or 0
    if minv <= 0 then return true end
    local s = safe(function() return C.strength.Strength.CurrentValue end, nil)
    return s == nil or s >= minv
end
local function maxManaOk()  -- MP requirement: MaxMana >= minMaxManaForMp (0 = none)
    local minv = Config.minMaxManaForMp or 0
    if minv <= 0 then return true end
    local mm = safe(function() return C.mana.MaxMana.CurrentValue end, nil)
    return mm == nil or mm >= minv
end

-- ---------- Nearby aggressive enemy? ----------
-- enemy.Mesh.AnimScriptInstance.m_IsAggressive turns true in combat. FindAllOf scans the whole
-- UObject array (expensive with bUseUObjectArrayCache=false), so cache the list and re-scan only
-- every ~5s; each call just iterates the cached pointers (despawned ones are filtered out).
local function loc(o)
    local v = safe(function() return o.RootComponent.RelativeLocation end, nil)
    if v == nil then return nil end
    return safe(function() return { x = v.X, y = v.Y, z = v.Z } end, nil)
end
local function dist(a, b)
    if not a or not b then return -1 end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end
local enemyList, enemyListAge = nil, 1e9
local function isEnemyAggro()
    -- Refresh the EXPENSIVE list (~30 ms FindAllOf) only ~once per combat-cooldown window; between
    -- refreshes we just re-read m_IsAggressive on the cached pointers (cheap), so detection stays
    -- responsive every tick. Already-present chasers are caught immediately; only a brand-new enemy
    -- that aggros mid-window waits up to one refresh.
    local refreshEvery = math.max(1, math.floor(Config.combatCooldownSeconds * 1000 / Config.tickIntervalMs))
    enemyListAge = enemyListAge + 1
    if not enemyList or enemyListAge >= refreshEvery then
        enemyList = safe(function() return FindAllOf("AIAgentCharacter") end, nil)
        enemyListAge = 0
    end
    if not enemyList then return false end
    local pPos = loc(C.pawn)
    local range = Config.aggroRangeUnits or 0
    for _, e in ipairs(enemyList) do
        if isUObject(e) and e ~= C.pawn then
            local ea = safe(function() return e.Mesh.AnimScriptInstance end, nil)
            if isUObject(ea) and safe(function() return ea.m_IsAggressive end, false) == true then
                if range <= 0 or not pPos then return true end
                local d = dist(pPos, loc(e))
                if d < 0 or d <= range then return true end  -- d<0 = unreadable -> block to be safe
            end
        end
    end
    return false
end

-- ---------- Report an unexpected error only ONCE, then stay silent ----------
local errLogged = {}
local function logErrOnce(key, err)
    if errLogged[key] then return end
    errLogged[key] = true
    print(string.format("[PassiveRegen] ERROR (%s): %s  (further ones suppressed)\n", key, tostring(err)))
end

-- ---------- One regen tick (full body, runs on the game thread) ----------
local function runTick()
        if not ensure() then return end

        -- While dead/K.O., paused, or in a cutscene/dialogue the mod does NOTHING and freezes its
        -- timers. (Crucial: otherwise pausing mid-combat burns through the combat cooldown, so on
        -- unpause an enemy that's still aggressive is no longer detected and regen resumes.)
        if not isAlive() then return end           -- dead / K.O.
        if isGamePaused() then return end          -- pause menu
        if isInCutsceneOrDialog() then return end  -- cutscene / dialogue

        -- Advance the combat-cooldown clock + the separate HP/MP clocks every base tick.
        ticksSinceCombat = ticksSinceCombat + 1
        hpTickCounter = hpTickCounter + 1
        mpTickCounter = mpTickCounter + 1
        local hpDue = hpTickCounter >= hpEveryTicks
        local mpDue = mpTickCounter >= mpEveryTicks
        if hpDue then hpTickCounter = 0 end
        if mpDue then mpTickCounter = 0 end

        -- Combat activity = your own attack OR taking damage -> reset the cooldown and re-arm the aggro
        -- scan. Runs every base tick (a cheap property read, ~0 ms). This makes "being hit" pause regen
        -- even if you never swing - which the IsInCombat flag alone misses. Our own regen only RAISES
        -- HP, so any drop can only be real damage.
        local hpNow = safe(function() return C.health.Health.CurrentValue end, nil)
        if isInCombat() or (hpNow ~= nil and lastHp ~= nil and hpNow < lastHp - 0.001) then
            ticksSinceCombat = 0
        end
        lastHp = hpNow

        if not hpDue and not mpDue then return end  -- nothing due this base tick

        -- Decide whether anything actually needs regenerating. When the due resource is full/
        -- disabled, return immediately -> no enemy scan (FindAllOf).
        local hpCur, hpMax, mpCur, mpMax
        if Config.hpRegen and hpDue then
            hpCur = safe(function() return C.health.Health.CurrentValue end, nil)
            hpMax = safe(function() return C.health.MaxHealth.CurrentValue end, nil)
        end
        if Config.manaRegen and mpDue then
            mpCur = safe(function() return C.mana.Mana.CurrentValue end, nil)
            mpMax = safe(function() return C.mana.MaxMana.CurrentValue end, nil)
        end
        local needHp = hpDue and hpCur ~= nil and hpMax ~= nil and hpCur > 0 and hpCur < hpMax and strengthOk()
        local needMp = mpDue and mpCur ~= nil and mpMax ~= nil and mpCur < mpMax and maxManaOk()  -- mana: from 0 too
        if not needHp and not needMp then return end

        -- Aggro: while inside the post-combat window, check the nearby enemies EVERY tick so a still-
        -- aggressive enemy reliably keeps the block alive (a single scan per window was too fragile - it
        -- missed enemies whose flag flickered). This is cheap: the per-tick check only re-reads
        -- m_IsAggressive on CACHED enemy pointers; the expensive FindAllOf only refreshes that list ~once
        -- per CombatCooldownSeconds (see isEnemyAggro). No scan while you fight (own-combat/damage hold
        -- the reset) or once peaceful (window expired). Disabled entirely via AggroBlocksRegen.
        local cooldownTicks = math.ceil(Config.combatCooldownSeconds * 1000 / Config.tickIntervalMs)
        if Config.aggroBlocksRegen and ticksSinceCombat > 0 and ticksSinceCombat < cooldownTicks then
            if isEnemyAggro() then ticksSinceCombat = 0 end
        end
        local recentlyFighting = ticksSinceCombat < cooldownTicks

        if needHp and (Config.regenHpInCombat or not recentlyFighting) then
            regenAttr(C.health, "Health", "MaxHealth", Config.hpPercentPerTick, true)   -- HP: don't heal at 0
        end
        if needMp and (Config.regenMpInCombat or not recentlyFighting) then
            regenAttr(C.mana, "Mana", "MaxMana", Config.manaPercentPerTick, false)      -- Mana: regen from 0
            -- If mana was empty, also clear the hidden "out of mana" cast gate (adds ~0 mana).
            if Config.clearOutOfManaGate and mpCur ~= nil and mpCur <= 0.01 then
                clearManaGate()
            end
        end
end

-- ---------- Main loop (each layer wrapped -> a single error can never kill the loop) ----------
LoopAsync(Config.tickIntervalMs, function()
    if not enabled then return false end
    local ok, err = pcall(function()
        ExecuteInGameThread(function()
            local ok2, err2 = pcall(runTick)
            if not ok2 then logErrOnce("tick", err2) end
        end)
    end)
    if not ok then logErrOnce("loop", err) end
    return false  -- keep the loop running
end)

-- Toggle key (configurable via INI: ToggleKey; default F8). UE4SS lets multiple mods bind the
-- same key without conflict (all callbacks fire), so this just lets users avoid a double-bind.
local toggleKeyLabel = "(none)"
do
    local name = string.upper((Config.toggleKey or "F8"):gsub("%s+", ""))
    if name ~= "" and name ~= "NONE" then
        local k = Key[name]
        if k == nil then
            print(string.format("[PassiveRegen] ToggleKey '%s' not recognized -> using F8.\n", name))
            name, k = "F8", Key.F8
        end
        toggleKeyLabel = name
        RegisterKeyBind(k, function()
            enabled = not enabled
            print(string.format("[PassiveRegen] %s\n", enabled and "ON" or "OFF"))
        end)
    end
end

-- ---------- Startup self-check: verify the required UE4SS APIs are present ----------
local function selfCheck()
    local checks = {
        { "FindFirstOf",        type(FindFirstOf) == "function" },
        { "FindAllOf",          type(FindAllOf) == "function" },
        { "LoopAsync",          type(LoopAsync) == "function" },
        { "ExecuteInGameThread",type(ExecuteInGameThread) == "function" },
        { "RegisterKeyBind",    type(RegisterKeyBind) == "function" },
        { "UEHelpers",          UEHelpers ~= nil },
        { "GameplayStatics",    safe(function() return UEHelpers.GetGameplayStatics() ~= nil end, false) },
    }
    local missing = {}
    for _, c in ipairs(checks) do
        if not c[2] then missing[#missing + 1] = c[1] end
    end
    if #missing == 0 then
        print("[PassiveRegen] Self-check OK (all APIs available).\n")
    else
        print(string.format("[PassiveRegen] Self-check: MISSING APIs -> %s (mod may run with reduced functionality)\n",
            table.concat(missing, ", ")))
    end
end
pcall(selfCheck)

print(string.format("[PassiveRegen] v1.0.5 loaded (HP/Mana %%, separate clocks, HUD sync, combat cooldown, death/KO, pause/cutscene stop). Toggle = %s.\n",
    toggleKeyLabel))
