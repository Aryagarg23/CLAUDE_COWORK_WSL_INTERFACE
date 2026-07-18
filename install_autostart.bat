@echo off
REM cowork-wsl-bridge — install auto-start.
REM Adds a launcher to your Startup folder (no admin rights needed) so the
REM bridge starts hidden every time you log in to Windows. Also starts it now.
setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "TARGET=%STARTUP%\cowork-wsl-bridge.vbs"

> "%TARGET%" echo CreateObject("WScript.Shell").Run "wscript.exe ""%~dp0start_bridge_hidden.vbs""", 0, False

echo Installed autostart launcher:
echo   %TARGET%
echo.
echo Starting bridge now (hidden)...
wscript.exe "%~dp0start_bridge_hidden.vbs"
echo Done. The bridge will start automatically at every Windows login.
pause
