$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot

$distDir = Join-Path $ScriptRoot "dist"
$portableDir = Join-Path $distDir "Portable"

if (Test-Path $distDir) { Remove-Item -Path $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $portableDir | Out-Null

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

$cscPath = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    $cscPath = "$env:windir\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

Write-Host "Compiling C# wrapper to EXE..."
$csharpCode = @"
using System;
using System.Diagnostics;
using System.IO;

[assembly: System.Reflection.AssemblyTitle("FancyZonesHotkeys")]
[assembly: System.Reflection.AssemblyProduct("FancyZonesHotkeys")]

namespace FancyZonesHotkeysLauncher
{
    class Program
    {
        static void Main(string[] args)
        {
            bool createdNew;
            using (System.Threading.Mutex mutex = new System.Threading.Mutex(true, "FancyZonesHotkeys_SingleInstance", out createdNew))
            {
                if (!createdNew)
                {
                    return;
                }

                string exeDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(exeDir, "FancyZonesHotkeys.ps1");
                
                if (!File.Exists(scriptPath)) return;

                ProcessStartInfo psi = new ProcessStartInfo("powershell.exe");
                psi.Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\"", scriptPath);
                psi.CreateNoWindow = true;
                psi.UseShellExecute = false;
                psi.WindowStyle = ProcessWindowStyle.Hidden;

                Process p = Process.Start(psi);
                p.WaitForExit();
            }
        }
    }
}
"@

$wrapperSrc = Join-Path $distDir "Wrapper.cs"
Set-Content -Path $wrapperSrc -Value $csharpCode -Encoding UTF8

$exePath = Join-Path $portableDir "FancyZonesHotkeys.exe"
& $cscPath /nologo /target:winexe /out:$exePath $wrapperSrc
Remove-Item $wrapperSrc

Write-Host "Copying PowerShell script to Portable directory..."
$ps1Path = Join-Path $ScriptRoot "FancyZonesHotkeys.ps1"
Copy-Item -Path $ps1Path -Destination $portableDir -Force

Write-Host "Packaging Portable version..."
if (Test-Path (Join-Path $ScriptRoot "presets.yaml")) {
    Copy-Item -Path (Join-Path $ScriptRoot "presets.yaml") -Destination $portableDir
}
Copy-Item -Path (Join-Path $ScriptRoot "Register-Startup.bat") -Destination $portableDir
Copy-Item -Path (Join-Path $ScriptRoot "Unregister-Startup.bat") -Destination $portableDir
Copy-Item -Path (Join-Path $ScriptRoot "QUICKSTART.txt") -Destination $portableDir -ErrorAction SilentlyContinue

$zipPath = Join-Path $distDir "FancyZonesHotkeys_Portable.zip"
Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -Force

Write-Host "Building Installer version..."
$issPath = Join-Path $ScriptRoot "setup.iss"
& $isccPath $issPath

Write-Host "Build complete! Check the 'dist' folder."
