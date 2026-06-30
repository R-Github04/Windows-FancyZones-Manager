@echo off
setlocal
set "EXE_PATH=%~dp0..\FancyZonesHotkeys.exe"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "FancyZonesHotkeys" /t REG_SZ /d "\"%EXE_PATH%\"" /f
echo FancyZonesHotkeys has been registered to start with Windows.
echo It will run automatically in the background from the next boot.
echo.
pause
