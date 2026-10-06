@echo off
chcp 65001 >nul
cd /d "%~dp0"
title NH6 Check
mode con cols=80 lines=20 >nul 2>nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Updater.ps1" -Quiet
pause