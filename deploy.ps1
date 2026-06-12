# Copy mod sources into local ue4ss test folder and/or Steam install.

param(

    [switch]$Steam

)



$Root = Split-Path -Parent $MyInvocation.MyCommand.Path



function Deploy-Mod($Label, $ModName, $Dest) {

    $Src = Join-Path $Root $ModName

    if (-not (Test-Path $Dest)) {

        New-Item -ItemType Directory -Force -Path $Dest | Out-Null

    }



    foreach ($folder in @("Scripts", "scripts")) {

        $srcScripts = Join-Path $Src $folder

        if (Test-Path $srcScripts) {

            $destScripts = Join-Path $Dest $folder

            if (-not (Test-Path $destScripts)) {

                New-Item -ItemType Directory -Force -Path $destScripts | Out-Null

            }

            Copy-Item (Join-Path $srcScripts "*.lua") $destScripts -Force

        }

    }



    $Ini = Join-Path $Src "$ModName.ini"

    if (Test-Path $Ini) {

        Copy-Item $Ini (Join-Path $Dest "$ModName.ini") -Force

    }



    $Enabled = Join-Path $Src "enabled.txt"

    if (Test-Path $Enabled) {

        Copy-Item $Enabled (Join-Path $Dest "enabled.txt") -Force

    }

    $Shared = Join-Path $Src "shared"

    if (Test-Path $Shared) {

        Copy-Item $Shared (Join-Path $Dest "shared") -Recurse -Force

    }



    Write-Host "[$Label] $ModName -> $Dest"

}



$Mods = @(

    @{ Name = "StatEditorMod"; Local = Join-Path $Root "ue4ss\Mods\StatEditorMod"; Steam = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\StatEditorMod" }

    @{ Name = "MagicScaleMod"; Local = Join-Path $Root "ue4ss\Mods\MagicScaleMod"; Steam = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\MagicScaleMod" }

    @{ Name = "PassiveRegen"; Local = Join-Path $Root "ue4ss\Mods\PassiveRegen"; Steam = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\PassiveRegen" }

    @{ Name = "LockpickSettings"; Local = Join-Path $Root "ue4ss\Mods\LockpickSettings"; Steam = "D:\Games\Steam\steamapps\common\Gothic 1 Remake\G1R\Binaries\Win64\ue4ss\Mods\LockpickSettings" }

)



foreach ($Mod in $Mods) {

    Deploy-Mod "local" $Mod.Name $Mod.Local

    if ($Steam) {

        Deploy-Mod "steam" $Mod.Name $Mod.Steam

    }

}



Write-Host "Done. Reload Lua in game: Ctrl+R"

