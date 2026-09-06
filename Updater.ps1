param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo    = 'ZenTea-Game/NewHistory-v3'
$branch  = 'main'
$dir     = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile   = Join-Path $dir 'version.txt'
$modsDir = Join-Path $dir 'mods'

# === ТЯЖЁЛЫЕ МОДЫ (>100 МБ) — на GitHub не влезут, лежат на Google Drive ===
# Если файла нет в папке mods — апдейтер сам скачает его оттуда.
# Хочешь добавить ещё такой мод — просто допиши строку в этот список.
$driveMods = @(
    @{
        Name = 'AoA3-1.21.1-3.7.16.1.jar'
        Url  = 'https://drive.usercontent.google.com/download?id=1UixrKDtRj1VlEdMVgN2zu9vMiM64QtMN&export=download&confirm=t'
    }
)

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

function Invoke-Download($url, $out) {
    $pf = Join-Path $dir 'nh3_dl_progress.tmp'
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

    while ($true) {
        try {
            if (Test-Path -LiteralPath $pf) {
                $raw = Get-Content -LiteralPath $pf -Raw -ErrorAction SilentlyContinue
                if ($raw) {
                    $p = $raw.Trim() -split '\|'
                    Draw-Progress ([int]$p[0]) ([math]::Round([long]$p[1]/1MB,1)) ([math]::Round([long]$p[2]/1MB,1))
                }
            }
        } catch {}
        if ($job.State -ne 'Running') { break }
        Start-Sleep -Milliseconds 150
    }
    Write-Host ''
    if ($job.State -ne 'Completed') {
        $e = Receive-Job $job 2>&1 | Out-String
        Remove-Job $job -Force
        Safe-Remove $pf
        throw $e
    }
    Remove-Job $job -Force
    Safe-Remove $pf
}

# === Проверка тяжёлых модов с Google Drive, докачка если нет ===
function Ensure-DriveMods {
    if (-not (Test-Path -LiteralPath $modsDir)) { New-Item -ItemType Directory -Path $modsDir | Out-Null }
    foreach ($m in $driveMods) {
        $target = Join-Path $modsDir $m.Name
        if (Test-Path -LiteralPath $target) {
            W ("[OK] {0} уже на месте" -f $m.Name) DarkGray
            continue
        }
        W ("Мод {0} не найден — качаю с Google Drive (~135 MB)..." -f $m.Name) Yellow
        try {
            Invoke-Download $m.Url $target
            $len = (Get-Item -LiteralPath $target).Length
            if ($len -lt 102400) {   # Drive отдал страницу ошибки вместо файла
                Safe-Remove $target
                W 'Google Drive отдал страницу ошибки. Попробуй ещё раз или скачай мод вручную.' Red
            } else {
                W ("Готово: {0} ({1} MB)" -f $m.Name, [math]::Round($len/1MB,1)) Green
            }
        } catch {
            Safe-Remove $target
            W ("Не удалось скачать {0}: {1}" -f $m.Name, $_) Red
        }
    }
}

# ===== Проверка версии =====
try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers @{ 'User-Agent' = 'NH3-Updater' }
} catch {
    if ($Quiet) { Write-Host (' Ошибка: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    Header
    W ('Ошибка GitHub: ' + $_.Exception.Message) Red
    Read-Host ($IND + 'Enter'); exit 1
}

$msg  = $latest.commit.message.Split([char]10)[0]
$sha  = $latest.sha.Substring(0, 7)
$date = [DateTime]::Parse($latest.commit.committer.date).ToLocalTime().ToString('dd.MM.yyyy HH:mm')
$mv   = [regex]::Match($msg, 'v(\d+(?:\.\d+)*)')
if (-not $mv.Success) { $mv = [regex]::Match($msg, '(\d+(?:\.\d+)+)') }
$remoteVer = if ($mv.Success) { $mv.Groups[1].Value } else { $sha }

function Get-LocalVersion {
    if (Test-Path -LiteralPath $vFile) {
        foreach ($l in (Get-Content -LiteralPath $vFile -Encoding UTF8)) {
            if ($l -match '^\s*version\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return '0.0'
}
function To-Ver($s) { try { return [version]$s } catch { return [version]'0.0' } }

$localVer = Get-LocalVersion
$lv = To-Ver $localVer; $rv = To-Ver $remoteVer

if ($Quiet) {
    Write-Host (" Локально: v$localVer   GitHub: v$remoteVer  ->  ") -NoNewline -ForegroundColor Cyan
    if ($rv -gt $lv)     { Write-Host 'ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat' -ForegroundColor Yellow }
    elseif ($rv -eq $lv) { Write-Host 'актуально =)' -ForegroundColor Green }
    else                 { Write-Host 'локальная новее (o_O)' -ForegroundColor Yellow }
    foreach ($m in $driveMods) {
        if (-not (Test-Path -LiteralPath (Join-Path $modsDir $m.Name))) {
            Write-Host (' Нет мода: ' + $m.Name + ' (запусти Updater.bat)') -ForegroundColor Yellow
        }
    }
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
        $zip = Join-Path $dir 'nh3.zip'
        $url = "https://github.com/$repo/archive/refs/heads/$branch.zip"
        $tmp = Join-Path $dir 'nh3_extract'
        try {
            Invoke-Download $url $zip
            W 'Распаковываю и заменяю файлы...' Yellow
            $job = Start-Job -ScriptBlock {
                param($z, $t)
                if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force }
                Expand-Archive -LiteralPath $z -DestinationPath $t -Force
            } -ArgumentList $zip, $tmp
            while ($job.State -eq 'Running') { Start-Sleep -Milliseconds 200 }
            if ($job.State -ne 'Completed') { $e = Receive-Job $job 2>&1 | Out-String; Remove-Job $job -Force; throw $e }
            Remove-Job $job -Force
            $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
            robocopy $src $dir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XF version.txt token.txt *.bat options.txt servers.dat usercache.json usernamecache.json command_history.txt /XD .git logs screenshots downloads nh3_extract | Out-Null
            Safe-Remove $zip
            Safe-Remove $tmp
            $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8); $done = $false
            for ($n = 0; $n -lt $lines.Count; $n++) {
                if ($lines[$n] -match '^\s*version\s*=') { $lines[$n] = "version=$remoteVer"; $done = $true; break }
            }
            if (-not $done) { $lines = @("version=$remoteVer") + $lines }
            Set-Content -Path $vFile -Value $lines -Encoding UTF8
            W "Готово! Сборка обновлена до v$remoteVer" Green
        } catch {
            W ('Ошибка обновления: ' + $_) Red
        }
    }
    elseif ($ch -eq '2') { notepad $vFile }
}
elseif ($rv -eq $lv) {
    W 'У тебя свежая сборка, всё актуально =)' Green
}
else {
    W 'Локальная версия новее, чем на GitHub (o_O)' Yellow
}

Write-Host ''
W '─── Проверка тяжёлых модов (Google Drive) ───' Cyan
Ensure-DriveMods

Write-Host ''
Read-Host ($IND + 'Enter для выхода')