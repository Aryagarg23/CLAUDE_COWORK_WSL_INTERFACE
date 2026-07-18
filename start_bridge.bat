@echo off
REM cowork-wsl-bridge — foreground launcher.
REM Starts the bridge daemon in a visible WSL window. Keep it open while working.
title Cowork WSL Bridge
echo Starting Cowork WSL Bridge from %~dp0
wsl --cd "%~dp0" -e bash runner.sh
echo.
echo Bridge stopped.
pause
