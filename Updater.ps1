param([switch]$Quiet)

# НАСТРОЙКИ
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$repo    = 'ZenTea-Game/NewHistory-v3'
$branch  = 'main'
$dir     = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile   = Join-Path $dir 'version.txt'
$modsDir = Join-Path $dir 'mods'
$zip     = Join-Path $dir 'nh3_update.zip'
$tmp     = Join-Path $dir 'nh3_extract'
$url     = "https://github.com/$repo/archive/refs/heads/$branch.zip"

# Тяжёлые моды, которых нет на GitHub
$driveMods = @(
    @{ Name = 'AoA3-1.21.1-3.7.16.1.jar'; Url = 'https://drive.usercontent.google.com/download?id=1UixrKDtRj1VlEdMVgN2zu9vMiM64QtMN&export=download&confirm=t' }
)

function Write-Center([string]$Text, [ConsoleColor]$Color = 'Gray') {
    $width = [Console]::WindowWidth
    $spaces = [math]::Max(0, [math]::Floor(($width - $Text.Length) / 2))
    Write-Host (" " * $spaces + $Text) -ForegroundColor $Color
}

function Write-ProgressLine([string]$Text, [ConsoleColor]$Color = 'Cyan') {
    [Console]::SetCursorPosition(0, [Console]::CursorTop)
    Write-Host (" " * [Console]::WindowWidth) -NoNewline
    [Console]::SetCursorPosition(0, [Console]::CursorTop)
    $spaces = [math]::Max(0, [math]::Floor(([Console]::WindowWidth - $Text.Length) / 2))
    Write-Host (" " * $spaces + $Text) -NoNewline -ForegroundColor $Color
}

# ===== ВЕРСИИ САМИХ ФАЙЛОВ АПДЕЙТЕРА =====
$updaterVersion = 'v1.3'
$batVersion     = 'v1.2'
$checkVersion   = 'v1.2'
# =========================================

# Версия файла по имени (если файл не найден, возвращает '0.0')
function Get-FileVersionFromName($name) {
    if (Test-Path -LiteralPath (Join-Path $dir $name)) {
        $content = Get-Content -LiteralPath (Join-Path $dir $name) -Raw -Encoding UTF8
        if ($content -match "# VER: (.+)") { return $Matches[1].Trim() }
    }
    return '0.0'
}

function Get-LocalVersion {
    if (Test-Path -LiteralPath $vFile) {
        foreach ($l in (Get-Content -LiteralPath $vFile -Encoding UTF8)) {
            if ($l -match '^\s*version\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return '0.0'
}

function Get-RemoteVersion {
    try {
        $api = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers @{ 'User-Agent' = 'NH3-Updater' }
        $m  = $api.commit.message.Split([char]10)[0]
        $mv = [regex]::Match($m, 'v(\d+(?:\.\d+)*)')
        if (-not $mv.Success) { $mv = [regex]::Match($m, '(\d+(?:\.\d+)+)') }
        if ($mv.Success) { return $mv.Groups[1].Value }
    } catch {}
    try {
        $txt = [string](Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$repo/$branch/version.txt" -Headers @{ 'User-Agent' = 'NH3-Updater' })
        $mv = [regex]::Match($txt, 'version\s*=\s*(\d+(?:\.\d+)+)')
        if ($mv.Success) { return $mv.Groups[1].Value }
    } catch {}
    return $null
}

# Скачиватель
function Invoke-Download($u, $out) {
    $request = [System.Net.HttpWebRequest]::Create($u)
    $request.UserAgent = 'NH3-Updater'
    $request.AllowAutoRedirect = $true
    
    $response = $request.GetResponse()
    $totalBytes = $response.ContentLength
    
    if ($totalBytes -gt 0) {
        Write-Center ("Архив весит: {0:N0} МБ" -f ($totalBytes / 1MB)) 'Cyan'
    } else {
        Write-Center 'Размер файла неизвестен, качаю...' 'Cyan'
    }
    Write-Center 'Качаю, полоса ниже показывает прогресс:' 'Yellow'
    
    $responseStream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($out)
    
    $buffer = New-Object byte[] 10240
    $read = 0
    $downloaded = [long]0
    $lastPercent = -1
    $spinChars = @('|', '/', '-', '\')
    $spinIndex = 0
    
    while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fileStream.Write($buffer, 0, $read)
        $downloaded += $read
        
        if ($totalBytes -gt 0) { 
            $percent = [math]::Floor(($downloaded / $totalBytes) * 100) 
        } else { 
            $percent = 0 
        }
        
        if ($percent -ne $lastPercent -or $spinIndex -eq 0) {
            $lastPercent = $percent
            $barLength = 30
            $filled = [math]::Floor($barLength * $percent / 100)
            $bar = '[' + ('=' * $filled) + (' ' * ($barLength - $filled)) + ']'
            $spin = $spinChars[$spinIndex % $spinChars.Length]
            $downloadedMB = [math]::Round($downloaded / 1MB, 1)
            
            if ($totalBytes -gt 0) {
                $totalMB = [math]::Round($totalBytes / 1MB, 1)
                $msg = "$spin $bar $percent% [$downloadedMB MB / $totalMB MB]"
            } else {
                $msg = "$spin $bar [$downloadedMB MB]"
            }
            
            Write-ProgressLine $msg 'Cyan'
            $spinIndex++
        }
    }
    
    $fileStream.Close()
    $responseStream.Close()
    $response.Close()
    
    Write-Host ""
    $size = [math]::Round((Get-Item $out).Length / 1MB, 1)
    Write-Center ("Скачано: {0:N0} МБ" -f $size) 'Green'
}

# ================= ОСНОВНАЯ ЧАСТЬ =================
$remoteVer = Get-RemoteVersion
$localVer  = Get-LocalVersion

if ($null -eq $remoteVer) {
    if ($Quiet) { Write-Center 'Не удалось узнать версию с GitHub (сеть/403/WARP).' 'Red'; exit 1 }
    Write-Center 'Не удалось узнать версию с GitHub.' 'Red'
    Write-Center 'Проверь интернет или отключи WARP/VPN.' 'Yellow'
    Read-Host '   Enter'; exit 1
}

if ($Quiet) {
    $w = [Console]::WindowWidth
    Write-Host (" " * [math]::Max(0, [math]::Floor(($w - 30) / 2))) -NoNewline
    Write-Host ("Локально: v{0}   GitHub: v{1}  ->  " -f $localVer, $remoteVer) -NoNewline -ForegroundColor Cyan
    if ([version]$remoteVer -gt [version]$localVer) { Write-Host 'ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat' -ForegroundColor Yellow }
    elseif ([version]$remoteVer -eq [version]$localVer) { Write-Host 'актуально =)' -ForegroundColor Green }
    else { Write-Host 'локальная новее (o_0)' -ForegroundColor Red }
    exit 0
}

$lv = [version]$localVer
$rv = [version]$remoteVer

if ($rv -gt $lv) {
    $statusColor = 'Green'
    $status = "ДОСТУПНО ОБНОВЛЕНИЕ: v$localVer -> v$remoteVer"
    $desc   = "Обновляйся, там приколы!"
}
elseif ($rv -eq $lv) {
    $statusColor = 'Yellow'
    $status = "У тебя v$localVer и на GitHub v$remoteVer"
    $desc   = "прикол (а зачем такая же версия)"
}
else {
    $statusColor = 'Red'
    $status = "У тебя v$localVer, а на GitHub v$remoteVer!"
    $desc   = "Откуда у тебя сборка выше версии (o_0)"
}

Clear-Host
Write-Host ""
Write-Center "╔══════════════════════════════════════════════╗" 'Cyan'
Write-Center "║      NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ       ║" 'Cyan'
Write-Center "╚══════════════════════════════════════════════╝" 'Cyan'
Write-Host ""
Write-Center $status $statusColor
Write-Center $desc $statusColor
Write-Host ""

# ===== ВЕРСИИ ФАЙЛОВ АПДЕЙТЕРА =====
Write-Center "═══════════════════════════════════" 'DarkGray'
Write-Center "Версия Updater.ps1: $updaterVersion" 'White'
Write-Center "Версия Updater.bat: $batVersion" 'White'
Write-Center "Версия Check.bat:   $checkVersion" 'White'
Write-Center "═══════════════════════════════════" 'DarkGray'
Write-Host ""

Write-Center "[1] Обновиться    [2] Выйти" 'White'
Write-Host ""

$prompt = 'Выбор: '
$w = [Console]::WindowWidth
Write-Host (" " * [math]::Max(0, [math]::Floor(($w - $prompt.Length) / 2))) -NoNewline
Write-Host $prompt -NoNewline
$ch = Read-Host
$ch = $ch.Trim()

if ($ch -eq '1') {
    try {
        Invoke-Download $url $zip
        
        Write-Center 'Распаковываю архив...' 'Yellow'
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
        
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName

        # УДАЛЯЕМ ТОЛЬКО mods, tacz, kubejs
        Write-Center 'Очищаю старые файлы (mods, tacz, kubejs)...' 'Yellow'
        foreach ($folder in @('mods', 'tacz', 'kubejs')) {
            $folderPath = Join-Path $dir $folder
            if (Test-Path -LiteralPath $folderPath) {
                Remove-Item -LiteralPath $folderPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Center 'Применяю полное обновление (заменяю все файлы сборки)...' 'Yellow'
        # /XD config data emotes - НЕ ТРОГАЕМ эти папки!
        # ВСЕ остальные файлы, включая сами .bat и .ps1, ЗАМЕНЯЮТСЯ НА НОВЫЕ!
        robocopy $src $dir /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /XD config data emotes .git logs screenshots downloads nh3_extract /XF token.txt options.txt servers.dat usercache.json usernamecache.json command_history.txt nh3_update.zip | Out-Null

        $lines = @()
        if (Test-Path -LiteralPath $vFile) { $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8) }
        $done = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*version\s*=') { $lines[$i] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -LiteralPath $vFile -Value $lines -Encoding UTF8

        Write-Center ("Готово! Сборка обновлена до v{0}" -f $remoteVer) 'Green'
    }
    catch {
        Write-Center ('Ошибка: ' + $_.Exception.Message) 'Red'
    }
    try { if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force } } catch {}
    try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } } catch {}
}

# Тяжёлые моды с Google Drive
if (-not (Test-Path -LiteralPath $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
foreach ($m in $driveMods) {
    $dest = Join-Path $modsDir $m.Name
    if (-not (Test-Path -LiteralPath $dest)) {
        Write-Host ""
        Write-Center ("Мод {0} не найден — качаю с Google Drive..." -f $m.Name) 'Yellow'
        try {
            Invoke-Download $m.Url $dest
            $len = (Get-Item -LiteralPath $dest).Length
            if ($len -lt 102400) {
                Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
                Write-Center 'Google Drive отдал страницу ошибки, попробуй позже.' 'Red'
            }
        }
        catch { Write-Center ('Не удалось скачать ' + $m.Name + ': ' + $_.Exception.Message) 'Red' }
    }
}

Write-Host ""
Read-Host '   Enter для выхода'