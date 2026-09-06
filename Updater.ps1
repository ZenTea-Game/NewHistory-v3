param([switch]$Quiet)

# НАСТРОЙКИ
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

function W($t, $c = 'Gray') { Write-Host ("   " + $t) -ForegroundColor $c }

function Get-ModBase($fileName) {
    $n = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $n = $n -replace '^\[[^\]]*\]\s*', ''
    $n = $n -replace '\s*v?\d+(\.\d+)+.*$', ''
    $n = $n -replace '[-_\s]+$]', ''
    $n = $n -replace '[-_\s]+$', ''
    return $n.ToLower()
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

function Show-Size($u) {
    try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.Method = 'HEAD'
        $req.AllowAutoRedirect = $true
        $req.UserAgent = 'NH3-Updater'
        $resp = $req.GetResponse()
        $len = $resp.ContentLength
        $resp.Close()
        if ($len -gt 0) { W ("Архив весит: {0:N0} МБ" -f ($len / 1MB)) Cyan }
    } catch {}
}

function Download-WithProgress($u, $out) {
    Show-Size $u
    W 'Качаю, полоса ниже показывает прогресс:' Yellow
    & curl.exe -L --fail --progress-bar -o $out $u
    if ($LASTEXITCODE -ne 0) { throw "curl вернул код $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath $out)) { throw 'Файл не скачался' }
    W ("Скачано: {0:N0} МБ" -f ((Get-Item -LiteralPath $out).Length / 1MB)) Green
}

# ================= ОСНОВНАЯ ЧАСТЬ =================
$remoteVer = Get-RemoteVersion
$localVer  = Get-LocalVersion

if ($null -eq $remoteVer) {
    if ($Quiet) { W 'Не удалось узнать версию с GitHub (сеть/403/WARP).' Red; exit 1 }
    W 'Не удалось узнать версию с GitHub.' Red
    W 'Проверь интернет или отключи WARP/VPN.' Yellow
    Read-Host '   Enter'; exit 1
}

if ($Quiet) {
    Write-Host ("   Локально: v{0}   GitHub: v{1}  ->  " -f $localVer, $remoteVer) -NoNewline -ForegroundColor Cyan
    if ([version]$remoteVer -gt [version]$localVer) { W 'ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat' Yellow }
    elseif ([version]$remoteVer -eq [version]$localVer) { W 'актуально =)' Green }
    else { W 'локальная новее (o_0)' Red }
    exit 0
}

# Сравнение версий (только цветной ТЕКСТ, фон обычный)
$lv = [version]$localVer
$rv = [version]$remoteVer

if ($rv -gt $lv) {
    $statusColor = 'Green'
    $header = '╔══════════════════════════════════════════════╗'
    $title  = '║      NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ       ║'
    $bot    = '╚══════════════════════════════════════════════╝'
    $status = "ДОСТУПНО ОБНОВЛЕНИЕ: v$localVer -> v$remoteVer"
    $desc   = "Обновляйся, там приколы!"
}
elseif ($rv -eq $lv) {
    $statusColor = 'Yellow'
    $header = '╔══════════════════════════════════════════════╗'
    $title  = '║      NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ       ║'
    $bot    = '╚══════════════════════════════════════════════╝'
    $status = "У тебя v$localVer и на GitHub v$remoteVer"
    $desc   = "прикол (а зачем такая же версия)"
}
else {
    $statusColor = 'Red'
    $header = '╔══════════════════════════════════════════════╗'
    $title  = '║      NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ       ║'
    $bot    = '╚══════════════════════════════════════════════╝'
    $status = "У тебя v$localVer, а на GitHub v$remoteVer!"
    $desc   = "Откуда у тебя сборка выше версии (o_0)"
}

W $header Cyan
W $title Cyan
W $bot Cyan
W $status $statusColor
W $desc $statusColor
Write-Host ''

# Всегда показываем меню, можно скачать даже если версии совпадают
W '[1] Обновиться    [2] Выйти' White
$ch = (Read-Host '   Выбор').Trim()
if ($ch -eq '1') {
    try {
        # 1) качаем архив
        Download-WithProgress $url $zip

        # 2) распаковка
        W 'Распаковываю архив...' Yellow
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName

        # 3) Полное зеркалирование (удаляет старые моды, обновляет KubeJS, конфиги, апдейтеры)
        # Личные файлы защищены:
        W 'Применяю полное обновление (заменяю все файлы сборки)...' Yellow
        robocopy $src $dir /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /XF token.txt options.txt servers.dat usercache.json usernamecache.json command_history.txt nh3_update.zip /XD .git logs screenshots downloads nh3_extract | Out-Null

        # 4) Обновляем версию
        $lines = @()
        if (Test-Path -LiteralPath $vFile) { $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8) }
        $done = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*version\s*=') { $lines[$i] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -LiteralPath $vFile -Value $lines -Encoding UTF8

        W ("Готово! Сборка обновлена до v{0}" -f $remoteVer) Green
    }
    catch {
        W ('Ошибка: ' + $_.Exception.Message) Red
    }
    try { if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force } } catch {}
    try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } } catch {}
}

# Тяжёлые моды с Google Drive, если отсутствуют локально
if (-not (Test-Path -LiteralPath $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
foreach ($m in $driveMods) {
    $dest = Join-Path $modsDir $m.Name
    if (-not (Test-Path -LiteralPath $dest)) {
        Write-Host ''
        W ("Мод {0} не найден — качаю с Google Drive..." -f $m.Name) Yellow
        try {
            Download-WithProgress $m.Url $dest
            $len = (Get-Item -LiteralPath $dest).Length
            if ($len -lt 102400) {
                Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
                W 'Google Drive отдал страницу ошибки, попробуй позже.' Red
            }
        }
        catch { W ('Не удалось скачать ' + $m.Name + ': ' + $_.Exception.Message) Red }
    }
}

Write-Host ''
Read-Host '   Enter для выхода'