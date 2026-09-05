param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$repo   = 'ZenTea-Game/NewHistory-v3'
$branch = 'main'

$dir = $PSScriptRoot
if (-not $dir) { $dir = (Get-Location).Path }
$vFile = Join-Path $dir 'version.txt'

function Get-LocalVersion {
    if (Test-Path $vFile) {
        foreach ($l in (Get-Content $vFile -Encoding UTF8)) {
            if ($l -match '^\s*version\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return '0.0'
}

function To-Ver($s) { try { return [version]$s } catch { return [version]'0.0' } }

function Header {
    cls
    Write-Host ''
    $t = ' NewHistory-v3  ·  Апдейтер '
    $w = 46
    Write-Host ('   ╔' + ('═' * $w) + '╗') -ForegroundColor Cyan
    $pad = $w - $t.Length; $l = [math]::Floor($pad / 2); $r = $pad - $l
    Write-Host ('   ║' + (' ' * $l) + $t + (' ' * $r) + '║') -ForegroundColor Cyan
    Write-Host ('   ╚' + ('═' * $w) + '╝') -ForegroundColor Cyan
    Write-Host ''
}

$heads = @{ 'User-Agent' = 'NH3-Updater'; Accept = 'application/vnd.github+json' }

try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers $heads
} catch {
    if ($Quiet) { Write-Host (' Ошибка: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    Header
    Write-Host ('   Ошибка GitHub: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host '   Проверь интернет и что репа уже ПАБЛИК:' -ForegroundColor Yellow
    Write-Host '   Settings -> General -> Danger Zone -> Change visibility' -ForegroundColor Yellow
    Read-Host '   Enter'
    exit 1
}

$msg  = $latest.commit.message.Split([char]10)[0]
$sha  = $latest.sha.Substring(0, 7)
$date = [DateTime]::Parse($latest.commit.committer.date).ToLocalTime().ToString('dd.MM.yyyy HH:mm')
$mv   = [regex]::Match($msg, '(\d+(?:\.\d+)+)')
$remoteVer = if ($mv.Success) { $mv.Groups[1].Value } else { $sha }
$localVer  = Get-LocalVersion

# ----- тихий режим для Check.bat -----
if ($Quiet) {
    Write-Host (' Локально: v' + $localVer + '   GitHub: v' + $remoteVer) -ForegroundColor Cyan
    if ((To-Ver $remoteVer) -gt (To-Ver $localVer)) {
        Write-Host ' >>> ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat <<<' -ForegroundColor Yellow
    } else {
        Write-Host ' >>> Актуально, обнов не нужен <<<' -ForegroundColor Green
    }
    exit 0
}

if (-not (Test-Path $vFile)) {
    Set-Content -Path $vFile -Encoding UTF8 -Value @(
        "version=$remoteVer", '',
        '════ Что изменилось ════',
        '(твои заметки, скрипт эти строки не трогает)'
    )
    $localVer = $remoteVer
}

Header
Write-Host "   Твоя сборка   : v$localVer" -ForegroundColor Cyan
Write-Host "   На GitHub     : v$remoteVer" -ForegroundColor White
Write-Host "   Последний коммит: $msg" -ForegroundColor DarkGray
Write-Host "                     $sha · $date" -ForegroundColor DarkGray
Write-Host ''

$lv = To-Ver $localVer; $rv = To-Ver $remoteVer

if ($rv -gt $lv) {
    Write-Host '   ► ДОСТУПНО ОБНОВЛЕНИЕ!' -ForegroundColor Green
    Write-Host ''
    Write-Host '   [1] Скачать и установить обновление' -ForegroundColor Green
    Write-Host '   [2] Открыть список изменений (version.txt)' -ForegroundColor Gray
    Write-Host '   [3] Выйти' -ForegroundColor Gray
    Write-Host ''
    $ch = (Read-Host '   Выбор').Trim()
    if ($ch -eq '1') {
        Write-Host '   Качаю архив с GitHub...' -ForegroundColor Yellow
        $zip = Join-Path $env:TEMP 'nh3.zip'
        Invoke-WebRequest -Uri "https://github.com/$repo/archive/refs/heads/$branch.zip" -OutFile $zip
        Write-Host '   Распаковываю и заменяю файлы...' -ForegroundColor Yellow
        $tmp = Join-Path $env:TEMP 'nh3_extract'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
        robocopy $src $dir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XF version.txt token.txt *.bat *.ps1 options.txt servers.dat usercache.json usernamecache.json command_history.txt /XD .git logs screenshots downloads | Out-Null
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $lines = @(Get-Content $vFile -Encoding UTF8); $done = $false
        for ($n = 0; $n -lt $lines.Count; $n++) {
            if ($lines[$n] -match '^\s*version\s*=') { $lines[$n] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -Path $vFile -Value $lines -Encoding UTF8
        Write-Host ''
        Write-Host "   Готово! Сборка обновлена до v$remoteVer" -ForegroundColor Green
    }
    elseif ($ch -eq '2') { notepad $vFile }
}
elseif ($rv -eq $lv) {
    Write-Host '   ► У тебя свежая сборка, всё актуально =)' -ForegroundColor Green
    Write-Host ''
    Write-Host '   [2] Открыть changelog   [Enter] выход' -ForegroundColor Gray
    if ((Read-Host '   Выбор').Trim() -eq '2') { notepad $vFile }
}
else {
    Write-Host '   ► Локальная версия новее, чем на GitHub (o_O)' -ForegroundColor Yellow
}
Write-Host ''
Read-Host '   Enter для выхода'