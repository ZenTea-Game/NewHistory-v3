@echo off
chcp 65001 >nul
cd /d "%~dp0"
title NewHistory-v3 — безопасное обновление апдейтера v13.0
mode con cols=80 lines=24 >nul 2>nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=(Get-Location).Path; $url='https://raw.githubusercontent.com/ZenTea-Game/NewHistory-v3/main/Updater.ps1'; $new=Join-Path $root 'Updater.ps1.new'; $current=Join-Path $root 'Updater.ps1'; $backup=Join-Path $root 'Updater.ps1.before-v13'; try { Invoke-WebRequest -Uri $url -OutFile $new -Headers @{'User-Agent'='NH3-Updater-v13'}; if ((Get-Item -LiteralPath $new).Length -lt 4096) { throw 'GitHub вернул неполный файл.' }; $tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile($new,[ref]$tokens,[ref]$errors) | Out-Null; if ($errors.Count) { throw ('Проверка синтаксиса не пройдена: ' + $errors[0].Message) }; if (Test-Path -LiteralPath $current) { Copy-Item -LiteralPath $current -Destination $backup -Force }; Move-Item -LiteralPath $new -Destination $current -Force; Write-Host 'Апдейтер v13.0 загружен и проверен. Старая копия сохранена рядом.' -ForegroundColor Green } catch { Write-Host ('Ошибка: ' + $_.Exception.Message) -ForegroundColor Red; if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Force }; exit 1 }"
if errorlevel 1 (
    echo.
    echo Не удалось обновить Updater.ps1. Проверь интернет и повтори позже.
    pause
    exit /b 1
)
if not exist "%~dp0Updater.bat" (
    echo Рядом не найден Updater.bat. Положи этот файл в папку сборки.
    pause
    exit /b 1
)
call "%~dp0Updater.bat"