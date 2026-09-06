@echo off
chcp 65001 >nul
cd /d "%~dp0"
title NewHistory-v3 Updater
mode con cols=55 lines=25 >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '%~dp0Updater.ps1' -Raw -Encoding UTF8)))"
pause