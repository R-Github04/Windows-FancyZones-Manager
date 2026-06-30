@echo off
setlocal
set "EXE_PATH=%~dp0..\FancyZonesHotkeys.exe"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "FancyZonesHotkeys" /t REG_SZ /d "\"%EXE_PATH%\" -Language ko" /f
echo.
echo 시작 프로그램에 FancyZonesHotkeys가 등록되었습니다.
echo 다음 부팅 시부터 자동으로 백그라운드에서 실행됩니다.
echo.
pause
