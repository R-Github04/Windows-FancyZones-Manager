@echo off
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "FancyZonesHotkeys" /f
echo.
echo 시작 프로그램에서 FancyZonesHotkeys가 제거되었습니다.
echo.
pause
