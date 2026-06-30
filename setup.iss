[Setup]
AppName=FancyZonesHotkeys
AppVersion=1.0.0
AppPublisher=FancyZonesHotkeys
DefaultDirName={autopf}\FancyZonesHotkeys
DefaultGroupName=FancyZonesHotkeys
OutputDir=dist
OutputBaseFilename=FancyZonesHotkeys_Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\FancyZonesHotkeys.exe
ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "dist\Portable\FancyZonesHotkeys.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\Portable\FancyZonesHotkeys.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\Portable\presets.json"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\Register-Startup.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\Portable\Unregister-Startup.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\Portable\QUICKSTART.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\FancyZonesHotkeys"; Filename: "{app}\FancyZonesHotkeys.exe"
Name: "{group}\Uninstall FancyZonesHotkeys"; Filename: "{uninstallexe}"

[Registry]
; Automatically register to startup on install, remove on uninstall
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FancyZonesHotkeys"; ValueData: """{app}\FancyZonesHotkeys.exe"""; Flags: uninsdeletevalue
