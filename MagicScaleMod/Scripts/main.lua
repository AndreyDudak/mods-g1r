-- MagicScaleMod: rune/scroll damage *= MaxMana / ManaDivisor (default /10)

local Scale = require("scale")

local HOOK = "/Script/G1R.MagicScriptLibrary:FillWithDamageTypeAndDamageAmountFromRuneSpellContainer"

-- /Script/ hooks: 1st callback = PRE, 2nd = POST. Must scale AFTER native fills Damages[].
RegisterHook(HOOK, function()
end, function(_Context, GothicCharacter, _Container, _DamageType, Damages, _ReturnValue)
    local ok, err = pcall(function()
        local character = GothicCharacter:get()
        Scale.ApplyToDamages(Damages, character)
    end)
    if not ok then
        print("[MagicScaleMod] hook error: " .. tostring(err) .. "\n")
    end
end)

RegisterLoadMapPostHook(function()
    ExecuteInGameThread(function()
        Scale.ReloadConfig()
    end)
end)

print("[MagicScaleMod] Loaded: spell damage *= MaxMana / divisor (see MagicScaleMod.ini).\n")
