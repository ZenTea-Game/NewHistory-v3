param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo   = 'ZenTea-Game/NewHistory-v3'
$branch = 'main'
$dir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile  = Join-Path $dir 'version.txt'

# Если системный TEMP сломан — работаем в своей папке
$tmpBase = $env:TEMP
try { if (-not $tmpBase -or -not (Test-Path -LiteralPath $tmpBase)) { $tmpBase = $dir } } catch { $tmpBase = $dir }

$BW  = 48
$IND = '   '

function Calc-Indent {
    try {
        $cw = [Console]::WindowWidth
        $script:IND = ' ' * [math]::Max(0, [math]::Floor(($cw - $BW) / 2))
    } catch {}
}
function Header {
    Clear-Host
    Calc-Indent
    Write-Host ''
    Write-Host ($IND + '╔' + ('═' * ($BW - 2)) + '╗') -ForegroundColor Cyan
    $t   = ' NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ '
    $pad = ($BW - 2) - $t.Length
    $l = [math]::Floor($pad / 2); $r = $pad - $l
    Write-Host ($IND + '║' + (' ' * $l) + $t + (' ' * $r) + '║') -ForegroundColor Cyan
    Write-Host ($IND + '╚' + ('═' * ($BW - 2)) + '╝') -ForegroundColor Cyan
    Write-Host ''
}
function W($text, $color = 'Gray') { Write-Host ($IND + $text) -ForegroundColor $color }
function Safe-Remove($p) {
    try { if ($p -and (Test-Path -LiteralPath $p)) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch {}
}
function Draw-Progress($pct, $doneMb, $totalMb) {
    $w = 30
    $f = [math]::Floor($w * $pct / 100)
    $bar = ('█' * $f) + ('░' * ($w - $f))
    Write-Host ("`r{0}[{1}] {2,3}%  ({3} / {4} MB)   " -f $IND, $bar, $pct, $doneMb, $totalMb) -NoNewline -ForegroundColor Cyan
}

# Скачивание: СРАЗУ спиннер «GitHub пакует», потом проценты
function Invoke-Download($url, $out) {
    $pf = Join-Path $tmpBase 'nh3_dl_progress.tmp'
    Safe-Remove $pf
    $job = Start-Job -ScriptBlock {
        param($u, $z, $pf)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'NH3-Updater')
        $wc.add_ProgressChanged({
            param($s, $e)
            if ($e.TotalBytesToReceive -gt 0) {
                $p = [math]::Floor($e.BytesReceived * 100 / $e.TotalBytesToReceive)
                try { [System.IO.File]::WriteAllText($pf, ('{0}|{1}|{2}' -f $p, $e.BytesReceived, $e.TotalBytesToReceive)) } catch {}
            }
        })
        $wc.DownloadFileAsync($u, $z)
        while ($wc.IsBusy) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path -LiteralPath $z)) { throw 'Не удалось скачать файл' }
    } -ArgumentList $url, $out, $pf

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $sp = @('|','/','-','\'); $i = 0; $have = $false
    while ($true) {
        try {
            if (Test-Path -LiteralPath $pf) {
                $raw = Get-Content -LiteralPath $pf -Raw -ErrorAction SilentlyContinue
                if ($raw) {
                    $have = $true
                    $p = $raw.Trim() -split '\|'
                    Draw-Progress ([int]$p[0]) ([math]::Round([long]$p[1]/1MB,1)) ([math]::Round([long]$p[2]/1MB,1))
                }
            }
        } catch {}
        if (-not $have) {
            Write-Host ("`r{0}[{1}] GitHub пакует архив... {2} сек (это нормально, там 670 МБ)   " -f $IND, $sp[$i % 4], [int]$sw.Elapsed.TotalSeconds) -NoNewline -ForegroundColor Yellow
        }
        if ($job.State -ne 'Running') { break }
        Start-Sleep -Milliseconds 150; $i++
    }
    Write-Host ''
    if ($job.State -ne 'Completed') {
        $e = Receive-Job $job 2>&1 | Out-String
        Remove-Job $job -Force
        throw $e
    }
    Remove-Job $job -Force
    Safe-Remove $pf
}

function Spin($work, $label, $jobargs) {
    $job = Start-Job -ScriptBlock $work -ArgumentList $jobargs
    $sp = @('|','/','-','\'); $i = 0
    while ($job.State -eq 'Running') {
        Write-Host ("`r{0}[{1}] {2}   " -f $IND, $sp[$i % 4], $label) -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 200; $i++
    }
    Write-Host ("`r{0}[OK] {1}   " -f $IND, $label) -ForegroundColor Green
    if ($job.State -ne 'Completed') {
        $e = Receive-Job $job 2>&1 | Out-String
        Remove-Job $job -Force
        throw $e
    }
    Remove-Job $job -Force
}

function Get-LocalVersion {
    if (Test-Path -LiteralPath $vFile) {
        foreach ($l in (Get-Content -LiteralPath $vFile -Encoding UTF8)) {
            if ($l -match '^\s*version\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return '0.0'
}
function To-Ver($s) { try { return [version]$s } catch { return [version]'0.0' } }

# ---------- проверка версии (API, а при 403 — raw) ----------
$remoteVer = $null; $msg = ''; $sha = ''; $date = ''
try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers @{ 'User-Agent' = 'NH3-Updater' }
    $msg  = $latest.commit.message.Split([char]10)[0]
    $sha  = $latest.sha.Substring(0, 7)
    $date = [DateTime]::Parse($latest.commit.committer.date).ToLocalTime().ToString('dd.MM.yyyy HH:mm')
    $mv = [regex]::Match($msg, 'v(\d+(?:\.\d+)*)')
    if (-not $mv.Success) { $mv = [regex]::Match($msg, '(\d+(?:\.\d+)+)') }
    if ($mv.Success) { $remoteVer = $mv.Groups[1].Value }
} catch {}
if (-not $remoteVer) {
    try {
        $txt = [string](Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$repo/$branch/version.txt" -Headers @{ 'User-Agent' = 'NH3-Updater' })
        $m2 = [regex]::Match($txt, 'version\s*=\s*(\d+(?:\.\d+)+)')
        if ($m2.Success) { $remoteVer = $m2.Groups[1].Value; $msg = 'API недоступен (WARP?) — версия из version.txt' }
    } catch {}
}
if (-not $remoteVer) {
    Header
    W 'Не удалось получить версию с GitHub (сеть/403/WARP).' Red
    Read-Host ($IND + 'Enter'); exit 1
}

$localVer = Get-LocalVersion
$lv = To-Ver $localVer; $rv = To-Ver $remoteVer

if ($Quiet) {
    Write-Host ("   Локально: v{0}   GitHub: v{1}  ->  " -f $localVer, $remoteVer) -NoNewline -ForegroundColor Cyan
    if ($rv -gt $lv)     { Write-Host 'ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat' -ForegroundColor Yellow }
    elseif ($rv -eq $lv) { Write-Host 'актуально =)' -ForegroundColor Green }
    else                 { Write-Host 'локальная новее (o_O)' -ForegroundColor Yellow }
    exit 0
}

Header
W "Твоя сборка     : v$localVer" Cyan
W "На GitHub       : v$remoteVer" White
W "Последний коммит: $msg" DarkGray
W "                  $sha · $date" DarkGray
Write-Host ''

if ($rv -gt $lv) {
    W "ДОСТУПНО ОБНОВЛЕНИЕ!  v$localVer -> v$remoteVer" Green
    Write-Host ''
    W '[1] Скачать и установить обновление' Green
    W '[2] Открыть список изменений (version.txt)' Gray
    W '[3] Выйти' Gray
    Write-Host ''
    $ch = (Read-Host ($IND + 'Выбор')).Trim()
    if ($ch -eq '1') {
        $zip = Join-Path $tmpBase 'nh3.zip'
        $url = "https://github.com/$repo/archive/refs/heads/$branch.zip"
        $tmp = Join-Path $tmpBase 'nh3_extract'
        try {
            Invoke-Download $url $zip
            Spin { param($z, $t)
                   if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force }
                   Expand-Archive -LiteralPath $z -DestinationPath $t -Force
                 } 'Распаковываю и заменяю файлы...' @($zip, $tmp)
        } catch {
            W ('Ошибка: ' + $_) Red
            Read-Host ($IND + 'Enter'); exit 1
        }
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
        robocopy $src $dir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XF version.txt token.txt *.bat options.txt servers.dat usercache.json usernamecache.json command_history.txt /XD .git logs screenshots downloads nh3_extract | Out-Null
        # СНАЧАЛА версия, потом уборка — уборка упадёт, обновление всё равно засчитается
        $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8); $done = $false
        for ($n = 0; $n -lt $lines.Count; $n++) {
            if ($lines[$n] -match '^\s*version\s*=') { $lines[$n] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -Path $vFile -Value $lines -Encoding UTF8
        Safe-Remove $zip
        Safe-Remove $tmp
        W "Готово! Сборка обновлена до v$remoteVer" Green
    }
    elseif ($ch -eq '2') { notepad $vFile }
}
elseif ($rv -eq $lv) {
    W 'У тебя свежая сборка, всё актуально =)' Green
    Write-Host ''
    W '[2] Открыть changelog   [Enter] выход' Gray
    if ((Read-Host ($IND + 'Выбор')).Trim() -eq '2') { notepad $vFile }
}
else {
    W 'Локальная версия новее, чем на GitHub (o_O)' Yellow
}
Write-Host ''
Read-Host ($IND + 'Enter для выхода')