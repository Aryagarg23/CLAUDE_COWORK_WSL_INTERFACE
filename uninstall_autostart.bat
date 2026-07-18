@echo off
REM cowork-wsl-bridge — remove auto-start and stop the daemon.
setlocal
set "TARGET=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\cowork-wsl-bridge.vbs"

if exist "%TARGET%" (
    del "%TARGET%"
    echo Removed autostart launcher.
) else (
    echo No autostart launcher found.
)

echo Stopping bridge daemon (if running)...
wsl -e pkill -f "bash runner.sh" 2>nul
echo Done.
pause
