# mods-g1r

UE4SS Lua mods for **Gothic 1 Remake** (G1R).

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) installed in `G1R/Binaries/Win64/ue4ss/`
- `Mods/shared/UEHelpers/` (ships with UE4SS)
- A loaded save, in-game (not main menu)

## Install

1. Copy mod folder(s) into:
   ```
   G1R/Binaries/Win64/ue4ss/Mods/
   ```
2. Enable in `Mods/mods.txt`:
   ```
   StatEditorMod : 1
   ```
3. Reload Lua: **Ctrl+R** (or restart the game if needed).

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
