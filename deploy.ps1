# Copy mod sources into local ue4ss test folder and/or Steam install.
param(
    [switch]$Steam
)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$StatEditorSrc = Join-Path $Root "StatEditorMod"
$LocalDest = Join-Path $Root "ue4ss\Mods\StatEditorMod"
$SteamDest = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\StatEditorMod"
$NotesSrc = Join-Path $Root "specs\G1R-MODDING-NOTES.md"
$LocalNotesDest = Join-Path $Root "ue4ss\Mods\G1R-MODDING-NOTES.md"
$SteamNotesDest = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\G1R-MODDING-NOTES.md"

function Deploy-To($Label, $Dest) {
    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    }
    Copy-Item (Join-Path $StatEditorSrc "Scripts\*.lua") (Join-Path $Dest "Scripts\") -Force
    Copy-Item (Join-Path $StatEditorSrc "StatEditorMod.ini") (Join-Path $Dest "StatEditorMod.ini") -Force
    Write-Host "[$Label] StatEditorMod -> $Dest"
}

Deploy-To "local" $LocalDest
Copy-Item $NotesSrc $LocalNotesDest -Force
Write-Host "[local] specs -> $LocalNotesDest"

if ($Steam) {
    Deploy-To "steam" $SteamDest
    Copy-Item $NotesSrc $SteamNotesDest -Force
    Write-Host "[steam] specs -> $SteamNotesDest"
}

Write-Host "Done. Reload Lua in game: Ctrl+R"
