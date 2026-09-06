<#
.SYNOPSIS
    Full Vox Populi + EUI sync from this Community-Patch-DLL checkout into a live
    Civ V installation. Replaces both the release-installer .exe and the manual
    copy-paste method described on the CivFanatics forum.

.DESCRIPTION
    Deploys the "Vox Populi (with EUI)" component set from this checkout:
      (1) Community Patch   -> MODS   (LUA subfolder deleted, per EUI)
      (2) Vox Populi        -> MODS   (LUA subfolder deleted, per EUI)
      (3a) EUI Compat Files -> MODS
      VPUI\                 -> Assets\DLC\VPUI
      UI_bc1\               -> Assets\DLC\UI_bc1
      VPUI Text\VPUI_tips_en_us.xml            -> My Games\...\Text
      Expansion2_VoxPopuli.Civ5Pkg             -> Assets\DLC\Expansion2\Expansion2.Civ5Pkg
      MinorCivSounds_VoxPopuli.xml             -> Assets\DLC\Expansion2\Sounds\XML
    ...then clears the game's cache folder.

    The deployed DLL is the one COMMITTED IN THE REPO for this checkout, unless a
    self-built DLL is found under BuildOutput\{Release,Debug}\ (MSVC) or
    clang-output\{Release,Debug}\ (build_vp_clang.py) - in which case the newest one
    is overlaid automatically (opt out with -NoBuiltDll).

    Fail-fast: every source is validated up front. If any source is missing (e.g. an
    older version names things differently), the script aborts before making changes.

.PARAMETER RepoRoot
    The Community-Patch-DLL checkout to sync FROM. Defaults to this script's own
    repo (it lives in <repo>\.claude\skills\sync-voxpopuli\).

.PARAMETER SteamDir
    The Civ V game install (contains Assets\DLC).

.PARAMETER ModsDir
    The user MODS folder. Its parent is used to locate Text\ and cache\.

.PARAMETER DryRun
    Print every action without executing it.

.PARAMETER NoBuiltDll
    Skip the automatic overlay of the self-built DLL, leaving the DLL committed in the
    repo deployed. Use this to test against the stock DLL.

.PARAMETER DllConfig
    Which self-built config to overlay: Release, Debug, or Auto (default = newest
    built, across both BuildOutput and clang-output).

.EXAMPLE
    .\Sync-VoxPopuli.ps1
.EXAMPLE
    .\Sync-VoxPopuli.ps1 -DryRun
.EXAMPLE
    .\Sync-VoxPopuli.ps1 -NoBuiltDll     # deploy the committed DLL, not my build
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$SteamDir = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V",
    [string]$ModsDir  = "C:\Users\kting\Documents\My Games\Sid Meier's Civilization 5\MODS",
    [switch]$DryRun,
    [switch]$NoBuiltDll,
    [ValidateSet('Auto','Release','Debug')]
    [string]$DllConfig = 'Auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say  ($m) { Write-Host $m }
function Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "    [ok] $m" -ForegroundColor Green }
function Plan ($m) { Write-Host "    [dry-run] $m" -ForegroundColor Yellow }

# --- Resolve derived paths -------------------------------------------------
$Dlc      = Join-Path $SteamDir 'Assets\DLC'
$UserDir  = Split-Path -Parent $ModsDir                 # ...\Sid Meier's Civilization 5
$TextDir  = Join-Path $UserDir 'Text'
$CacheDir = Join-Path $UserDir 'cache'

# --- Sources (in the repo) -------------------------------------------------
$s_cp    = Join-Path $RepoRoot '(1) Community Patch'
$s_vp    = Join-Path $RepoRoot '(2) Vox Populi'
$s_eui   = Join-Path $RepoRoot '(3a) VP - EUI Compatibility Files'
$s_vpui  = Join-Path $RepoRoot 'VPUI'
$s_uibc1 = Join-Path $RepoRoot 'UI_bc1'
$s_tips  = Join-Path $RepoRoot 'VPUI Text\VPUI_tips_en_us.xml'
$s_pkg   = Join-Path $RepoRoot 'Expansion2_VoxPopuli.Civ5Pkg'
$s_snd   = Join-Path $RepoRoot 'MinorCivSounds_VoxPopuli.xml'

# OPTIONAL self-built DLL: MSVC writes to BuildOutput\<Config>\, build_vp_clang.py
# writes to clang-output\<Config>\. -DllConfig Release|Debug forces one config;
# Auto (default) picks whichever file (from either toolchain) was built most recently.
$dllCandidates = @{
    Release = @(
        (Join-Path $RepoRoot 'BuildOutput\Release\CvGameCore_Expansion2.dll'),
        (Join-Path $RepoRoot 'clang-output\Release\CvGameCore_Expansion2.dll')
    )
    Debug = @(
        (Join-Path $RepoRoot 'BuildOutput\Debug\CvGameCore_Expansion2.dll'),
        (Join-Path $RepoRoot 'clang-output\Debug\CvGameCore_Expansion2.dll')
    )
}
switch ($DllConfig) {
    'Release' { $cands = @($dllCandidates.Release) }
    'Debug'   { $cands = @($dllCandidates.Debug) }
    default   { $cands = @($dllCandidates.Release + $dllCandidates.Debug) }
}
$cands = @($cands | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
$s_dll = $null
if ($cands.Count -gt 0) {
    $s_dll = $cands | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTime } -Descending | Select-Object -First 1
}
$dllPicked = if ($s_dll) { $s_dll.Substring($RepoRoot.Length).TrimStart('\') } else { $null }

# --- Destinations ----------------------------------------------------------
$d_cp    = Join-Path $ModsDir '(1) Community Patch'
$d_vp    = Join-Path $ModsDir '(2) Vox Populi'
$d_eui   = Join-Path $ModsDir '(3a) VP - EUI Compatibility Files'
$d_vpui  = Join-Path $Dlc 'VPUI'
$d_uibc1 = Join-Path $Dlc 'UI_bc1'
$d_tips  = Join-Path $TextDir 'VPUI_tips_en_us.xml'
$d_pkg   = Join-Path $Dlc 'Expansion2\Expansion2.Civ5Pkg'
$d_snd   = Join-Path $Dlc 'Expansion2\Sounds\XML\MinorCivSounds_VoxPopuli.xml'
$d_dll   = Join-Path $d_cp 'CvGameCore_Expansion2.dll'

# ===========================================================================
# 1. VALIDATE  (fail before touching anything)
# ===========================================================================
Step 'Validating environment and sources'

foreach ($root in @(
        @{ P = $RepoRoot; What = 'RepoRoot' },
        @{ P = $SteamDir; What = 'SteamDir' },
        @{ P = $Dlc;      What = "Steam Assets\DLC" },
        @{ P = $ModsDir;  What = 'ModsDir' })) {
    if (-not (Test-Path -LiteralPath $root.P -PathType Container)) {
        throw "$($root.What) not found: $($root.P)"
    }
}

# Every source must exist for THIS checkout, else abort (version mismatch).
$sourceDirs  = @($s_cp, $s_vp, $s_eui, $s_vpui, $s_uibc1)
$sourceFiles = @($s_tips, $s_pkg, $s_snd)
$missing = @()
foreach ($p in $sourceDirs)  { if (-not (Test-Path -LiteralPath $p -PathType Container)) { $missing += $p } }
foreach ($p in $sourceFiles) { if (-not (Test-Path -LiteralPath $p -PathType Leaf))      { $missing += $p } }
if ($missing.Count -gt 0) {
    throw ("Missing source(s) in this checkout - this script may not support this version:`n  " +
           ($missing -join "`n  "))
}
Ok 'All sources present.'

# Report which version we are about to deploy (best-effort).
try {
    $commit = & git -C $RepoRoot rev-parse --short HEAD 2>$null
    $desc   = & git -C $RepoRoot describe --tags --always 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "Deploying from commit $commit ($desc)" }
} catch { }

if ($DryRun) { Say "`n*** DRY RUN - no changes will be made ***" }

# ===========================================================================
# 2. HELPERS
# ===========================================================================
function Sync-Tree {
    param([string]$Source, [string]$Dest)
    if (Test-Path -LiteralPath $Dest) {
        if ($DryRun) { Plan "remove existing $Dest" }
        else         { Remove-Item -LiteralPath $Dest -Recurse -Force }
    }
    if ($DryRun) { Plan "copy $Source -> $Dest" }
    else {
        Copy-Item -LiteralPath $Source -Destination $Dest -Recurse -Force
        Ok "$Dest"
    }
}

function Sync-File {
    param([string]$Source, [string]$Dest)
    $parent = Split-Path -Parent $Dest
    if (-not (Test-Path -LiteralPath $parent)) {
        if ($DryRun) { Plan "create dir $parent" }
        else         { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }
    if ($DryRun) { Plan "copy $Source -> $Dest" }
    else {
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        Ok "$Dest"
    }
}

function Remove-LuaFolder {
    param([string]$ModFolder)
    $lua = Join-Path $ModFolder 'LUA'
    if (Test-Path -LiteralPath $lua) {
        if ($DryRun) { Plan "delete LUA folder $lua" }
        else         { Remove-Item -LiteralPath $lua -Recurse -Force; Ok "deleted LUA in $ModFolder" }
    } else {
        Ok "no LUA folder in $ModFolder (nothing to delete)"
    }
}

# ===========================================================================
# 3. DEPLOY
# ===========================================================================
Step 'Copying mods into MODS folder'
Sync-Tree $s_cp  $d_cp
Sync-Tree $s_vp  $d_vp
Sync-Tree $s_eui $d_eui

Step 'Removing LUA folders (EUI provides its own UI)'
Remove-LuaFolder $d_cp
Remove-LuaFolder $d_vp

Step 'Overlaying self-built DLL'
# The (1) folder copy above deployed the DLL committed in the repo. If you built your own,
# overlay it now so it survives every sync automatically (opt out with -NoBuiltDll).
$builtDllDeployed = $false
if ($NoBuiltDll) {
    Ok 'skipped (-NoBuiltDll): keeping the DLL committed in the checkout'
} elseif ($s_dll) {
    if ($DryRun) { Plan "copy [$dllPicked] $s_dll -> $d_dll" }
    else {
        Copy-Item -LiteralPath $s_dll -Destination $d_dll -Force
        Ok "deployed self-built DLL [$dllPicked] -> $d_dll"
    }
    $builtDllDeployed = $true
} else {
    Ok "no self-built DLL under BuildOutput\{Release,Debug} or clang-output\{Release,Debug} (keeping the committed DLL)"
}

Step 'Copying UI packages into Assets\DLC'
Sync-Tree $s_vpui  $d_vpui
Sync-Tree $s_uibc1 $d_uibc1

Step 'Copying Text and Expansion2 DLC files'
Sync-File $s_tips $d_tips
Sync-File $s_pkg  $d_pkg
Sync-File $s_snd  $d_snd

Step 'Clearing game cache'
if (Test-Path -LiteralPath $CacheDir) {
    if ($DryRun) { Plan "remove cache $CacheDir" }
    else         { Remove-Item -LiteralPath $CacheDir -Recurse -Force; Ok "cleared $CacheDir" }
} else {
    Ok 'no cache folder present'
}

# ===========================================================================
# 4. DONE
# ===========================================================================
Step 'Vox Populi + EUI sync complete'
if ($DryRun) {
    Say 'Dry run finished - re-run without -DryRun to apply.'
} elseif ($builtDllDeployed) {
    Say "Deployed your self-built [$dllPicked] DLL. Ready to launch."
} elseif ($NoBuiltDll) {
    Say 'Deployed the DLL COMMITTED in this checkout (-NoBuiltDll).'
} else {
    Say 'Deployed the DLL COMMITTED in this checkout - no self-built DLL was found.'
    Say 'Build the DLL, then re-run this script to overlay it automatically.'
}
