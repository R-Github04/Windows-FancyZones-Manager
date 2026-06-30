[Setup]
AppName=FancyZonesHotkeys
AppVersion=1.1.0
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
Source: "dist\Portable\presets.yaml"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\en\Register-Startup.bat"; DestDir: "{app}\en"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\en\Unregister-Startup.bat"; DestDir: "{app}\en"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\en\QUICKSTART.txt"; DestDir: "{app}\en"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\en\Run-FancyZonesHotkeys.bat"; DestDir: "{app}\en"; Flags: ignoreversion skipifsourcedoesntexist

Source: "dist\Portable\ko\Register-Startup.bat"; DestDir: "{app}\ko"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\ko\Unregister-Startup.bat"; DestDir: "{app}\ko"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\ko\QUICKSTART.txt"; DestDir: "{app}\ko"; Flags: ignoreversion skipifsourcedoesntexist
Source: "dist\Portable\ko\Run-FancyZonesHotkeys.bat"; DestDir: "{app}\ko"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\FancyZonesHotkeys"; Filename: "{app}\FancyZonesHotkeys.exe"
Name: "{group}\Uninstall FancyZonesHotkeys"; Filename: "{uninstallexe}"

[Registry]
; Automatically register to startup on install, remove on uninstall
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FancyZonesHotkeys"; ValueData: """{app}\FancyZonesHotkeys.exe"""; Flags: uninsdeletevalue
