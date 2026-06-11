# mods-g1r

UE4SS Lua mods for **Gothic 1 Remake** (G1R).

**Dev project:** `D:\project\games\mods\Gothic_Remake`  
**GitHub:** https://github.com/AndreyDudak/mods-g1r

## Project layout

```
Gothic_Remake/
  StatEditorMod/Scripts/   <- edit here (tracked by git)
  specs/                   <- modding notes
  ue4ss/                   <- local test install (gitignored)
  deploy.ps1               <- copy mod into ue4ss / Steam
```

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) installed in `G1R/Binaries/Win64/ue4ss/`
- `Mods/shared/UEHelpers/` (ships with UE4SS)
- A loaded save, in-game (not main menu)

## Install (players)

1. Copy `StatEditorMod/` into:
   ```
   G1R/Binaries/Win64/ue4ss/Mods/
   ```
2. Each mod folder includes an empty `enabled.txt` — UE4SS loads it automatically (no need to edit `mods.txt`).
3. Reload Lua: **Ctrl+R** (or restart the game if needed).

## Develop

From `D:\project\games\mods\Gothic_Remake`:

```powershell
# deploy to local ue4ss test folder
.\deploy.ps1

# deploy to Steam install too
.\deploy.ps1 -Steam
```

Then **Ctrl+R** in game to reload Lua.

```powershell
git add -A
git commit -m "..."
git push
```

## Mods

See [`specs/G1R-MODDING-NOTES.md`](specs/G1R-MODDING-NOTES.md) for reverse-engineering notes, API findings, and setup details.

### StatEditorMod

In-game stat and inventory editor via numpad command lines. Output goes to `UE4SS.log`.

| Key | Action |
|-----|--------|
| **Numpad 0** | Mod guide |
| **Numpad 5** | Stat editor — `lp 100`, `mc 5`, etc. + Enter |
| **Numpad 6** | Dump all stats |
| **Numpad 7** | Item lookup — `18` + Enter (ui pos from inventory footer) |
| **Numpad 8** | Inventory edit — `18 55` or `18 -10` + Enter |
| **Numpad 9** | Dump inventory list (open inventory tab first) |

**Stats examples:** `hp 500`, `mp 200`, `str 20`, `lp 100`, `mc 5` (magic circle 0–6)

**Inventory:** use **ui pos** from the inventory footer (e.g. `18/334`), not internal item id.

Esc closes any open command line.

## License

Use at your own risk. Not affiliated with Alkimia Interactive / THQ Nordic.
