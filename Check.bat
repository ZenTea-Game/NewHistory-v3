@echo off
chcp 65001 >nul
cd /d "%~dp0"
title NH3 Check
mode con cols=80 lines=20 >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '%~dp0Updater.ps1' -Raw -Encoding UTF8))) -Quiet"
pause