# G1R Modding Notes

Personal reference for Gothic 1 Remake + UE4SS. Add new findings here instead of re-searching the dump.

**Canonical path:** `D:\project\games\mods\Gothic_Remake\specs\G1R-MODDING-NOTES.md` — keep notes here only, not in game `ue4ss\Mods\`.

---

## Setup

| Item | Path / value |
|---|---|
| UE4SS folder | `G1R\Binaries\Win64\ue4ss\` |
| Game exe | `G1R\Binaries\Win64\G1R-Win64-Shipping.exe` |
| Injector | `G1R\Binaries\Win64\dwmapi.dll` |
| Mod list | `ue4ss\Mods\mods.txt` (built-in UE4SS mods) |
| Our mods enable | empty `enabled.txt` in each mod folder — **do not** edit `mods.txt` for repo mods |
| Log | `ue4ss\UE4SS.log` |
| Object dump | `ue4ss\UE4SS_ObjectDump.txt` (~124 MB) |
| Engine | UE 5.4 |
| UE4SS version | 3.0.1 Beta |

### Stable mods.txt (tested)

```
MyFirstMod : 1
Keybinds : 1
; everything else : 0 for stability
```

### UE4SS-settings.ini tweaks for stability

- `bUseUObjectArrayCache = false`
- `HookAActorTick = 0`

---

## How to generate / read the dump

| Action | Keys | Output |
|---|---|---|
| Full object dump | **Ctrl+J** | `UE4SS_ObjectDump.txt` |
| C++ headers (SDK) | **Ctrl+H** | folder in `ue4ss\` |
| Actors on current level | **Ctrl+7** | dump file in `ue4ss\` |

No in-game popup — check `UE4SS.log` for `Dumping GUObjectArray took ... seconds`.

### Search tips (dump)

| Bad | Good |
|---|---|
| `Health` (6000+ hits) | `Class /Script/G1R.AttributeSet` |
| random `Health` | `AttributeSet_Health:` |
| UI classes | `AttributeSet_*` for real stats |

**Line format:**
```
FloatProperty /Script/G1R.SomeClass:FieldName [o: 40]
Function /Script/G1R.SomeClass:MethodName
Class /Script/G1R.SomeClass
```

---

## Character architecture

```
GothicCharacter                    ← actor in the world
├── AttributeSet_*                 ← real numeric stats (GAS)
├── m_DataModule_BaseStats
├── m_DataModule_Combat
├── m_DataModule_Locomotion
├── m_MagicComponent
├── m_CharacterState               ← GothicCharacterState
└── m_HealthBarComponent           ← UI only
```

**Rule:** modify stats via `AttributeSet_*`, not via HUD/Inventory UI fields.

### Key classes

| Class | Role | Dump line (approx.) |
|---|---|---|
| `GothicCharacter` | Base character actor | ~49367 |
| `ClientAuthoritativeCharacter` | Player-side character | ~49363 |
| `AIAgentCharacter` | NPC variant | ~49635 |
| `GothicCharacterState` | Character state machine | ~53406 |
| `AttributeSetBase` | Base for all attribute sets | ~51999 |
| `InventoryMain` | Inventory UI (stat display copy) | ~65773 area |

### Useful GothicCharacter methods

```
IsPlayerCharacter
IsPlayerCharacterOrPlayerControlled
IsNPCCharacter
IsDead
IsDefeated
HasGameplayTag
GetHealthBarComponent          ← UI, not HP logic
```

---

## Attribute sets (real stats)

Search dump: `Class /Script/G1R.AttributeSet` (~line 51999+)

### AttributeSet_Health

```
Health
MaxHealth
DamageMultiplier
RecoveryRatePerHourOfSleep
OnRep_Health                   ← hook candidate
OnRep_MaxHealth
OnRep_DamageMultiplier
```

### AttributeSet_Mana

```
Mana
MaxMana
MagicianLevel
RecoveryRatePerHourOfSleep
OnRep_Mana
OnRep_MaxMana
OnRep_MagicianLevel
```

### AttributeSet_Strength

```
Strength
Critical_Fists
Critical_OneHand
Critical_TwoHand
Critical_Orc
OnRep_Strength
```

### AttributeSet_Dexterity

```
Dexterity
OnRep_Dexterity
```

### AttributeSet_LevelProgression

```
Level
Experience
SkillPoints
Toughness
ToughnessA
ToughnessB
ToughnessC
XPExecutedBounty
XPKillOrDefeatBounty
OnRep_Level
OnRep_Experience
OnRep_Skillpoints
```

### AttributeSet_Armor

```
SuperArmor
MaxSuperArmor
Resistance_Blunt
Resistance_Edge
Resistance_Point
Resistance_Fire
Resistance_Energy
Resistance_Ice
Resistance_Wind
Resistance_Falling
```

### AttributeSet_Fatigue

```
Fatigue
MaxFatigue
FillRatio
FillRatioPeriod
MaxThresholdIndex
RecoveryRatePerHourOfSleep
```

### AttributeSet_Sleep

```
SleepTime
MaxSleepTime
MaxRestTime
SleepTimeRecoveryAmount
SleepTimeRecoveryPeriod
```

### AttributeSet_Alcohol

```
Alcohol
MaxAlcohol
AlcoholDepletionRate
```

### AttributeSet_Oxygen

```
Oxygen
MaxOxygen
OxygenDepletionRate
OxygenRecoveryRate
CriticalLevelPercent
```

### AttributeSet_Swampweed

```
Swampweed
MaxSwampweed
SwampweedDepletionRate
```

### AttributeSet_Movement

```
SpeedModifier
OnRep_SpeedModifier
```

### AttributeSet_Lockpicking

```
LockpickDurability
LockpickPrecision
```

### AttributeSet_Pickpocketing

```
PickPocketing
```

---

## Classic Gothic stat → code mapping

| In-game stat | AttributeSet field |
|---|---|
| HP | `AttributeSet_Health:Health` |
| Max HP | `AttributeSet_Health:MaxHealth` |
| Mana | `AttributeSet_Mana:Mana` |
| Strength | `AttributeSet_Strength:Strength` |
| Dexterity | `AttributeSet_Dexterity:Dexterity` |
| Toughness | `AttributeSet_LevelProgression:Toughness` |
| Level | `AttributeSet_LevelProgression:Level` |
| XP | `AttributeSet_LevelProgression:Experience` |
| Learning points | `AttributeSet_LevelProgression:SkillPoints` |
| Weapon crits | `AttributeSet_Strength:Critical_*` |
| Armor / resistances | `AttributeSet_Armor:Resistance_*` |
| Fatigue | `AttributeSet_Fatigue:Fatigue` |
| Sleep | `AttributeSet_Sleep:SleepTime` |
| Alcohol | `AttributeSet_Alcohol:Alcohol` |
| Lockpicking | `AttributeSet_Lockpicking` |
| Pickpocketing | `AttributeSet_Pickpocketing` |
| Move speed mod | `AttributeSet_Movement:SpeedModifier` |

---

## UI copies (do NOT use for gameplay mods)

`InventoryMain` fields (~line 65773) — display only:

```
Health, Mana, Strength, Dexterity, Toughness, SkillPoints, MagicCircle
```

Also UI-only: `HealthBar`, `HUDBoss*`, `NPCOverheadInfoWidget`, `3DDebugCharacterWidget`

---

## Lua mod template

```lua
-- Mods\MyMod\Scripts\main.lua
local UEHelpers = require("UEHelpers")

RegisterHook("/Script/G1R.AttributeSet_Health:OnRep_Health", function(self, OldHealth)
    print("[MyMod] Health changed\n")
end)

RegisterKeyBind(Key.F9, function()
    local PC = UEHelpers.GetPlayerController()
    if PC:IsValid() then
        print(string.format("[MyMod] Pawn: %s\n", UEHelpers.GetPlayer():GetFullName()))
    end
end)
```

Enable our repo mods with an empty `enabled.txt` in the mod folder (preferred). For ad-hoc test mods you can still use `mods.txt`:
```
MyMod : 1
```

---

## Built-in UE4SS mods

| Mod | Purpose | Safe to enable? |
|---|---|---|
| `Keybinds` | Ctrl+J dump, etc. | Yes |
| `MyFirstMod` | Our test mod | Yes |
| `StatEditorMod` | Numpad 0=guide, 5=stats cmd, 6=dump stats, 7=slot lookup, 8=inv edit, 9=inv list | Yes (test in-game) |
| `LineTraceMod` | Ctrl+L — object under crosshair | Test individually |
| `ConsoleEnablerMod` | ~ / F10 console | Crashed at ~30s before — retest |
| `CheatManagerEnablerMod` | Cheat manager | Retest individually |
| `BPModLoaderMod` | Blueprint mods | Not needed yet |

---

## In-game stat editor (feasible)

Stats are GAS attributes on `GothicCharacter` → `GetAbilitySystemComponent()` → `GothicAbilitySystemComponent` (extends `AngelscriptAbilitySystemComponent`).

| Action | API |
|---|---|
| Read | `AIGASLibrary:GetAttributeValue(Entity, AttributeSetClass, FName)` |
| Read (alt) | `ASC:TryGetAttributeBaseValue(AttributeSetClass, FName, OutValue)` |
| Write | `ASC:TrySetAttributeBaseValue(AttributeSetClass, FName, NewValue)` |
| Write (alt) | `ASC:SetAttributeBaseValue(...)` — no bool return |

Prototype mod: `Mods/StatEditorMod/` — in-game command lines + optional HUD text (no custom UMG from Lua).

**Source (git):** `D:\project\games\mods\Gothic_Remake\StatEditorMod\`  
**Deploy:** `.\deploy.ps1 -Steam` from `Gothic_Remake\` → copies `Scripts\*.lua` to Steam `ue4ss\Mods\StatEditorMod\` and local test folder.

| Key | Action |
|---|---|
| **Numpad 0** | Mod guide (log + optional HUD) |
| **Numpad 5** | Stat command line: `<alias> <value>` + Enter (e.g. `lp 100`); opens with comma-separated alias list |
| **Numpad 6** | Dump all stats (log + optional HUD batch) |
| **Numpad 7** | Lookup: `<pos>` + Enter — item at UI pos (e.g. `18`) |
| **Numpad 8** | Inventory command line: `<pos> <count>` (e.g. `18 55` or `18 -10`) + Enter |
| **Numpad 9** | Dump inventory list with UI `pos` numbers (footer, e.g. 18/334) |

| Example | Action |
|---|---|
| Numpad 0 | full mod guide |
| Numpad 5 → `lp 100` | set SkillPoints |
| `mp 200` | set Mana |
| `mm 250` | set MaxMana |
| `18 55` | add 55 of item type at UI slot 18 |
| `18 -10` | remove 10 of same item type |
| `18` (Numpad 7) | show name and count at UI pos 18 |

Output: **`UE4SS.log` always**; optional **in-game HUD** (see below).

Only one command line (stats, slot lookup, or inventory) can be open at a time.

### Stat aliases (Numpad 5)

Short names accepted by the stat command line (also full stat labels):

`hp`, `health`, `mh`, `maxhealth`, `mp`, `mm`, `str`, `dex`, `lvl`, `exp`, `xp`, `lp`, `sp`, `tough`, `fatigue`, `mf`, `circle`, `magic`, `mc`, `magician`, … — `MagicianLevel` / `mc` / `circle` must be **0–6**.

On Numpad 5 open, HUD shows one line: `aliases: hp, health, mh, …` (full list in log).

### In-game HUD output (StatEditorMod)

| File | Role |
|---|---|
| `modlog.lua` | All mod messages → `print` (UE4SS.log) + in-game HUD |
| `notifications.lua` | HUD via game's `W_SimpleTextMessage` (top-right) |

**Batch lists:** multi-line output (guide, stat dump, inv list) is batched into **one HUD block** (`ModLog.BeginBatch` / `EndBatch`) so the widget is not overwritten line-by-line.

**HUD widget path (safe):**

```
GothicHUD → HUDSimpleTextMessageController → m_Widget (W_SimpleTextMessage_C)
→ ShowSimpleTextMessage(FText)
```

TextBlock configured for wrap + ~520×420 px, anchored top-right.

**Do NOT use from Lua on G1R (tested, bad):**

| API | Result |
|---|---|
| `HUDNotificationController` + `AddNotificationSoft` + `MakeInstancedStruct` | silent fail or **native crash** |
| `KismetSystemLibrary:PrintString` | no visible text in shipping build |
| `UEHelpers.GetWorld()` / `FindAllOf("PlayerController")` | unstable — use cached player from `ClientRestart` |

Fallbacks if SimpleTextMessage missing: `PlayerController:ClientMessage`, `MagicScriptLibrary:DebugPrintMessage`.

### Slot lookup (Numpad 7) and pos list (Numpad 6)

**Important:** The number at the **bottom of the inventory** (e.g. `18 / 334`) is **UI slot position / total slots**, NOT item count or stack size.

Use that **UI pos** in commands (e.g. ore at `18/334` → type `18`).

| Key | Action |
|-----|--------|
| **Numpad 9** | Dump all items: `pos 18: Ore x 5  (id 5)` |
| **Numpad 7** | Enter UI pos, e.g. `18` + Enter |

Example list line:
```
[StatEditorMod Inv] pos 18: Ore x 5  (id 5)
```

Then `18 55` on Numpad 8 adds 55 ore; `18 -10` removes 10.

Open inventory tab once so `InventoryMain` / `InventoryBase` is available (not `GothicUIManager` — that is a CDO only).

### Inventory commands (Numpad 8)

Format: `<pos> <count>` — UI pos from inventory footer or Numpad 6 list.

Format: `<pos> <count>` — no prefix words.

| Command | Effect |
|---|---|
| `18 55` | add 55 items of the same type as UI slot 18 |
| `18 -10` | remove 10 items of that type |

Flow:

1. `GothicUIManager:GetIdByPos(uiPos)` → internal `m_Id`
2. `DataModuleLibrary:GetContainerDataModule(Character)` → item class at `m_Id`
3. `InventoryComponent:AddItemOfClass` / `RemoveItemOfClass`

Slot must not be empty — pos is the number shown at the bottom of inventory (e.g. `18/334`).

### UE4SS debug GUI console (StatEditorMod)

**UE4SS 3.0:** вкладка **Console** у Debug GUI — **тільки лог**, поле вводу вимкнене в коді UE4SS.

| Спосіб вводу | Як |
|---|---|
| **Win32 консоль** | `ConsoleEnabled = 1` → `lp 100` + Enter |
| **Numpad 5 in-game** | `lp 100` + Enter, Esc = закрити |

`GuiConsoleEnabled = 0` — Debug GUI вимкнено.

Win32: `lp 100`. In-game `~` / F10 (`ConsoleEnablerMod`) stays off.

### UI options (hardest → easiest for player-facing editor)

1. **Lua UMG widgets** — full in-game window, no C++ (see SupraTools example)
2. **Blueprint mod + UMG** — via `BPModLoaderMod`
3. **C++ mod + ImGui tab** — UE4SS debug GUI API
4. **Keybinds + log + optional HUD** — `StatEditorMod` (current)
5. **UE4SS `GuiConsoleEnabled`** — debug only, performance cost, untested on G1R

Caveats: some stats may clamp or revert via gameplay systems; `MaxHealth` vs `Health` are separate; UI inventory numbers may lag until refresh.

---

## Known issues

- `FUObjectHashTables::Get()` not found in log — warning only, game runs
- Crash ~30s with ConsoleEnabler + CheatManager enabled — use minimal mods.txt
- Dump has no live values — only class/field names; use in-game mod or inventory UI to see numbers
- After editing `.lua` — **Ctrl+R** reloads Lua in game (full restart if something breaks)
- StatEditorMod UMG crash (`0x0e000010`) — caused by wrong `StaticConstructObject` args; use 3-arg form only
- `UEHelpers.GetPlayerController()` + `FindAllOf` can throw `ArrayNum exceeds ArrayMax` on G1R — StatEditorMod caches player from `ClientRestart` instead

---

## Discoveries log

Add new entries below as we find them.

### 2026-06-09 — Initial setup

- UE4SS works with G1R (UE 5.4)
- Dump file: `UE4SS_ObjectDump.txt`, generated with Ctrl+J
- Character stats live in `AttributeSet_*` classes under `/Script/G1R`
- `GothicCharacter` is the main character class
- `InventoryMain:Health` is UI copy, not gameplay HP

### 2026-06-09 — Stat editor UI (phase 2)

- UMG panel with SpinBox per stat (arbitrary numeric input)
- Numpad 0 / 1 / 2 keybinds
- Split into `stats.lua`, `ui.lua`, `main.lua`

### 2026-06-09 — Slot lookup (Numpad 7)

- `invlookupconsole.lua` — one param: slot number
- Output: `pos N: <name> x <count>` to `UE4SS.log`
- Display name via `GothicUIManager:GetItemNameByPos_Implementation` when available

### 2026-06-09 — Inventory command line (Numpad 8)

- `inventory.lua` + `invconsole.lua` in StatEditorMod
- Format: `<pos> <count>` — positive add, negative remove (`34 -10`)
- Item lookup via `DataModule_Container:GetItemsIn(MainContainer)`, not UI `InventoryMain`
- Write path: `InventoryComponent:AddItemOfClass` / `RemoveItemOfClass`

### 2026-06-09 — StatEditorMod in-game HUD

- `modlog.lua` — unified log + HUD; batch mode for multi-line lists
- `notifications.lua` — `W_SimpleTextMessage` via `GothicHUD` / `HUDSimpleTextMessageController`
- HUD position: top-right (canvas slot wrap enabled)
- Numpad **0** = mod guide, **6** = dump stats, **9** = inv list (was documented wrong as 0/6)
- Numpad **5** open shows comma-separated stat alias list on HUD
- Deploy: `deploy.ps1 -Steam` from git repo → Steam + local `ue4ss\Mods\StatEditorMod\`
- Avoid `HUDNotificationController` / `MakeInstancedStruct` / `PrintString` from Lua (see HUD section above)

<!-- Template for new entries:
### YYYY-MM-DD — Short title
- finding 1
- finding 2
-->
