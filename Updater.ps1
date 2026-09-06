param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo   = 'ZenTea-Game/NewHistory-v3'
$branch = 'main'
$dir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile  = Join-Path $dir 'version.txt'

function Center($s, $w) {
    if ($s.Length -ge $w) { return $s.Substring(0, $w) }
    $p = $w - $s.Length; $l = [math]::Floor($p / 2)
    return (' ' * $l) + $s + (' ' * ($p - $l))
}

function Header {
    Clear-Host
    $w = 54
    Write-Host ''
    Write-Host ('   ╔' + ('═' * $w) + '╗') -ForegroundColor Cyan
    Write-Host ('   ║' + (Center 'NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ' $w) + '║') -ForegroundColor Cyan
    Write-Host ('   ║' + (Center 'ZenTea-Game/NewHistory-v3 · ветка main' $w) + '║') -ForegroundColor DarkCyan
    Write-Host ('   ╚' + ('═' * $w) + '╝') -ForegroundColor Cyan
    Write-Host ''
}

function Banner($text, $bg, $fg) {
    $w = 58
    Write-Host ('   ' + (' ' * $w)) -BackgroundColor $bg
    Write-Host ('   ' + (Center $text $w)) -BackgroundColor $bg -ForegroundColor $fg
    Write-Host ('   ' + (' ' * $w)) -BackgroundColor $bg
    Write-Host ''
}

function Wait-JobSpinner($job, $label) {
    $spin = @('|','/','-','\'); $i = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($job.State -eq 'Running') {
        Write-Host ("`r   [{0}] {1} ... {2}s   " -f $spin[$i % 4], $label, [int]$sw.Elapsed.TotalSeconds) -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 120; $i++
    }
    if ($job.State -eq 'Completed') {
        Write-Host ("`r   [OK] {0} — готово ({1}s)   " -f $label, [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host ("`r   [ERR] {0} — ошибка   " -f $label) -ForegroundColor Red
    }
}

function Invoke-Download($url, $out) {
    $job = Start-Job -ScriptBlock { param($u,$z)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent','NH3-Updater')
        $wc.DownloadFile($u, $z)
    } -ArgumentList $url, $out
    Wait-JobSpinner $job 'Качаю архив с GitHub'
    if ($job.State -ne 'Completed') { $e = Receive-Job $job 2>&1 | Out-String; Remove-Job $job -Force; throw $e }
    Remove-Job $job -Force
}

function Invoke-Extract($zip, $target) {
    $job = Start-Job -ScriptBlock { param($z,$t)
        if (Test-Path $t) { Remove-Item $t -Recurse -Force }
        Expand-Archive -LiteralPath $z -DestinationPath $t -Force
    } -ArgumentList $zip, $target
    Wait-JobSpinner $job 'Распаковываю и заменяю файлы'
    if ($job.State -ne 'Completed') { $e = Receive-Job $job 2>&1 | Out-String; Remove-Job $job -Force; throw $e }
    Remove-Job $job -Force
}

function Get-LocalVersion {
    if (Test-Path $vFile) {
        foreach ($l in (Get-Content $vFile -Encoding UTF8)) {
            if ($l -match '^\s*version\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return '0.0'
}
function To-Ver($s) { try { return [version]$s } catch { return [version]'0.0' } }

# ---------- проверка GitHub ----------
try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers @{ 'User-Agent' = 'NH3-Updater' }
} catch {
    if ($Quiet) { Write-Host ('   Ошибка: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    Header
    Banner ('Ошибка GitHub: ' + $_.Exception.Message) DarkRed White
    Write-Host '   Репа должна быть ПАБЛИК. Проверь интернет.' -ForegroundColor Yellow
    Read-Host '   Enter'; exit 1
}

$msg  = $latest.commit.message.Split([char]10)[0]
$sha  = $latest.sha.Substring(0, 7)
$date = [DateTime]::Parse($latest.commit.committer.date).ToLocalTime().ToString('dd.MM.yyyy HH:mm')
$mv   = [regex]::Match($msg, '(\d+(?:\.\d+)+)')
$remoteVer = if ($mv.Success) { $mv.Groups[1].Value } else { $sha }
$localVer  = Get-LocalVersion
$lv = To-Ver $localVer; $rv = To-Ver $remoteVer

if (-not (Test-Path $vFile)) {
    Set-Content -Path $vFile -Encoding UTF8 -Value @("version=$remoteVer", '', '════ Что изменилось ════')
    $localVer = $remoteVer
}

# ---------- тихий режим (Check.bat) ----------
if ($Quiet) {
    Write-Host ("   Локально: v{0}  |  GitHub: v{1}  →  " -f $localVer, $remoteVer) -NoNewline -ForegroundColor Cyan
    if ($rv -gt $lv)      { Write-Host 'ДОСТУПНО ОБНОВЛЕНИЕ! Запусти Updater.bat' -ForegroundColor Yellow }
    elseif ($rv -eq $lv)  { Write-Host 'актуально =)' -ForegroundColor Green }
    else                  { Write-Host 'локальная новее (o_O)' -ForegroundColor Yellow }
    exit 0
}

# ---------- красивый режим ----------
Header
Write-Host ('   Твоя сборка    : ') -NoNewline -ForegroundColor White; Write-Host "v$localVer" -ForegroundColor Cyan
Write-Host ('   На GitHub      : ') -NoNewline -ForegroundColor White; Write-Host "v$remoteVer" -ForegroundColor Cyan
Write-Host ('   Последний коммит: ') -NoNewline -ForegroundColor DarkGray; Write-Host $msg -ForegroundColor Gray
Write-Host ('                     ') -NoNewline -ForegroundColor DarkGray; Write-Host "$sha · $date" -ForegroundColor DarkGray
Write-Host ''

if ($rv -gt $lv) {
    Banner '► ДОСТУПНО ОБНОВЛЕНИЕ! (v' + $localVer + ' → v' + $remoteVer + ')' DarkYellow Black
    Write-Host '   [1] Скачать и установить обновление' -ForegroundColor Green
    Write-Host '   [2] Открыть changelog (version.txt)' -ForegroundColor Gray
    Write-Host '   [3] Выйти' -ForegroundColor Gray
    Write-Host ''
    $ch = (Read-Host '   Выбор').Trim()
    if ($ch -eq '1') {
        try {
            $zip = Join-Path $env:TEMP 'nh3.zip'
            $tmp = Join-Path $env:TEMP 'nh3_extract'
            Invoke-Download "https://github.com/$repo/archive/refs/heads/$branch.zip" $zip
            Invoke-Extract $zip $tmp
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
            Banner ('✔ Готово! Сборка обновлена до v' + $remoteVer) DarkGreen White
        } catch {
            Write-Host ''
            Banner ('Ошибка обновления: ' + $_.Exception.Message) DarkRed White
        }
    }
    elseif ($ch -eq '2') { notepad $vFile }
}
elseif ($rv -eq $lv) {
    Banner '✔ У тебя свежая сборка — всё актуально =)' DarkGreen White
    Write-Host '   [2] Открыть changelog   [Enter] выход' -ForegroundColor Gray
    if ((Read-Host '   Выбор').Trim() -eq '2') { notepad $vFile }
}
else {
    Banner 'Локальная версия новее, чем на GitHub (o_O)' DarkYellow Black
}
Write-Host ''
Read-Host '   Enter для выхода'