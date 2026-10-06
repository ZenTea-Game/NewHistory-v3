@echo off
chcp 65001 >nul
cd /d "%~dp0"
title NewHistory 6 Updater v14.1
mode con cols=80 lines=40 >nul 2>nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Updater.ps1"
if errorlevel 1 pause
