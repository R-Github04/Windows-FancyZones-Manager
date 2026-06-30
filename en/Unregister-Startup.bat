@echo off
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "FancyZonesHotkeys" /f
echo FancyZonesHotkeys has been removed from Windows startup.
echo.
pause
