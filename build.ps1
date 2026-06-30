$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot

$distDir = Join-Path $ScriptRoot "dist"
$portableDir = Join-Path $distDir "Portable"

if (Test-Path $distDir) { Remove-Item -Path $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $portableDir | Out-Null

Write-Host "Checking for ps2exe module..."
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing ps2exe (setting up NuGet and trusting PSGallery)..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Checking for Inno Setup..."
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$isccPath = $isccPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $isccPath) {
    Write-Host "Inno Setup not found. Installing via winget..."
    Start-Process -FilePath "winget" -ArgumentList "install -e --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow
    $isccPath = $isccPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $isccPath) {
        Write-Error "Failed to install Inno Setup or ISCC.exe not found in expected paths."
    }
}

Write-Host "Compiling PowerShell script to EXE..."
$ps1Path = Join-Path $ScriptRoot "FancyZonesHotkeys.ps1"
$exePath = Join-Path $portableDir "FancyZonesHotkeys.exe"
Invoke-ps2exe -inputFile $ps1Path -outputFile $exePath -noConsole -noOutput -noError

Write-Host "Packaging Portable version..."
if (Test-Path (Join-Path $ScriptRoot "presets.json")) {
    Copy-Item -Path (Join-Path $ScriptRoot "presets.json") -Destination $portableDir
}
Copy-Item -Path (Join-Path $ScriptRoot "Register-Startup.bat") -Destination $portableDir
Copy-Item -Path (Join-Path $ScriptRoot "Unregister-Startup.bat") -Destination $portableDir

$zipPath = Join-Path $distDir "FancyZonesHotkeys_Portable.zip"
Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -Force

Write-Host "Building Installer version..."
$issPath = Join-Path $ScriptRoot "setup.iss"
& $isccPath $issPath

Write-Host "Build complete! Check the 'dist' folder."
