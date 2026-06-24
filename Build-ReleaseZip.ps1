[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$OutputDirectory = 'dist'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$outputRoot = Join-Path $scriptRoot $OutputDirectory
$packageName = "FancyZonesHotkeyBridge-v$Version"
$stagingRoot = Join-Path $outputRoot $packageName
$zipPath = Join-Path $outputRoot ($packageName + '.zip')

$filesToCopy = @(
    'FancyZonesHotkeys.ps1',
    'Run-FancyZonesHotkeys.bat',
    'presets.json',
    'README.md'
)

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $scriptRoot $file
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing required file: $sourcePath"
    }

    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $stagingRoot $file)
}

$quickStart = @"
FancyZones Hotkey Bridge - Quick Start

1. Install Microsoft PowerToys and configure FancyZones custom layouts.
2. Edit presets.json to match your monitor setup and preferred hotkeys.
3. Run Run-FancyZonesHotkeys.bat.

Useful commands:
- List layouts:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListLayouts
- List monitors:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListMonitors
- Validate config:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ValidateConfig

If you want to move elevated windows, run the bridge as administrator too.
"@

Set-Content -LiteralPath (Join-Path $stagingRoot 'QUICKSTART.txt') -Value $quickStart -Encoding ASCII

$mediaRoot = Join-Path $scriptRoot 'media'
if (Test-Path -LiteralPath $mediaRoot) {
    Copy-Item -LiteralPath $mediaRoot -Destination (Join-Path $stagingRoot 'media') -Recurse -Force
}

Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Created release package: $zipPath"
