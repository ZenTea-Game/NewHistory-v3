param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo   = 'ZenTea-Game/NewHistory-v3'
$branch = 'main'
$dir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile  = Join-Path $dir 'version.txt'

$BW  = 48
$IND = '   '

function Calc-Indent {
    try {
        $cw = [Console]::WindowWidth
        $script:IND = ' ' * [math]::Max(0, [math]::Floor(($cw - $BW) / 2))
    } catch {}
}

function Center($s, $w) {
    if ($s.Length -ge $w) { return $s.Substring(0, $w) }
    $p = $w - $s.Length
    $l = [math]::Floor($p / 2)
    return (' ' * $l) + $s + (' ' * ($p - $l))
}

function Header {
    Clear-Host
    Calc-Indent
    Write-Host ''
    Write-Host ($IND + '╔' + ('═' * ($BW - 2)) + '╗') -ForegroundColor Cyan
    $t   = ' NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ '
    $pad = ($BW - 2) - $t.Length
    $l   = [math]::Floor($pad / 2); $r = $pad - $l
    Write-Host ($IND + '║' + (' ' * $l) + $t + (' ' * $r) + '║') -ForegroundColor Cyan
    Write-Host ($IND + '╚' + ('═' * ($BW - 2)) + '╝') -ForegroundColor Cyan
    Write-Host ''
}

function W($text, $color = 'Gray') { Write-Host ($IND + $text) -ForegroundColor $color }

function Banner($text, $bg, $fg) {
    $ok = [Enum]::GetNames([System.ConsoleColor])
    if ($ok -notcontains $bg) { $bg = 'DarkYellow' }
    if ($ok -notcontains $fg) { $fg = 'White' }
    $w = 58
    Write-Host ('   ' + (' ' * $w)) -BackgroundColor $bg
    Write-Host ('   ' + (Center $text $w)) -BackgroundColor $bg -ForegroundColor $fg
    Write-Host ('   ' + (' ' * $w)) -BackgroundColor $bg
    Write-Host ''
}

function Spin($work, $label, $jobargs) {
    $job = Start-Job -ScriptBlock $work -ArgumentList $jobargs
    $sp = @('|','/','-','\'); $i = 0
    while ($job.State -eq 'Running') {
        Write-Host ("`r" + $IND + $label + '  ' + $sp[$i % 4]) -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 200
        $i++
    }
    if ($job.State -eq 'Completed') {
        Write-Host ("`r" + $IND + $label + '  OK') -ForegroundColor Green
    } else {
        Write-Host ("`r" + $IND + $label + '  ERROR') -ForegroundColor Red
        $e = Receive-Job $job 2>&1 | Out-String
        Remove-Job $job -Force
        throw $e
    }
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

try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?sha=$branch&per_page=1" -Headers @{ 'User-Agent' = 'NH3-Updater' }
} catch {
    if ($Quiet) { Write-Host (' Ошибка: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    Header
    Banner ("Ошибка GitHub: " + $_.Exception.Message) DarkRed White
    W 'Репа приватная или нет интернета.' Yellow
    Read-Host ($IND + 'Enter')
    exit 1
}

$msg  = $latest.commit.message.Split([char]10)[0]
$sha  = $latest.sha.Substring(0, 7)
$date = [DateTime]::Parse($latest.commit.committer.date).ToLocalTime().ToString('dd.MM.yyyy HH:mm')
$mv   = [regex]::Match($msg, '(\d+(?:\.\d+)+)')
$remoteVer = if ($mv.Success) { $mv.Groups[1].Value } else { $sha }

$localVer = Get-LocalVersion
$lv = To-Ver $localVer
$rv = To-Ver $remoteVer

if ($Quiet) {
    Write-Host (" Локально: v$localVer   GitHub: v$remoteVer") -ForegroundColor Cyan
    if ($rv -gt $lv) { Write-Host ' >>> ДОСТУПНО ОБНОВЛЕНИЕ, запусти Updater.bat <<<' -ForegroundColor Yellow }
    else { Write-Host ' >>> Актуально, обнов не нужен <<<' -ForegroundColor Green }
    exit 0
}

Header
W "Твоя сборка     : v$localVer" Cyan
W "На GitHub       : v$remoteVer" White
W "Последний коммит: $msg" DarkGray
W "                  $sha · $date" DarkGray
Write-Host ''

if ($rv -gt $lv) {
    Banner "ДОСТУПНО ОБНОВЛЕНИЕ!  v$localVer  ->  v$remoteVer" DarkYellow Black
    W '[1] Скачать и установить обновление' Green
    W '[2] Открыть список изменений (version.txt)' Gray
    W '[3] Выйти' Gray
    Write-Host ''
    $ch = (Read-Host ($IND + 'Выбор')).Trim()
    if ($ch -eq '1') {
        $zip = Join-Path $env:TEMP 'nh3.zip'
        $url = "https://github.com/$repo/archive/refs/heads/$branch.zip"
        $tmp = Join-Path $env:TEMP 'nh3_extract'
        try {
            Spin { param($u, $z) (New-Object System.Net.WebClient).DownloadFile($u, $z) } 'Качаю архив с GitHub...' @($url, $zip)
            Spin { param($z, $t)
                   if (Test-Path $t) { Remove-Item $t -Recurse -Force }
                   Expand-Archive -LiteralPath $z -DestinationPath $t -Force
                 } 'Распаковываю и заменяю файлы...' @($zip, $tmp)
        } catch {
            Banner ("Ошибка обновления: " + $_.Exception.Message) DarkRed White
            Read-Host ($IND + 'Enter')
            exit 1
        }
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
        robocopy $src $dir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XF version.txt token.txt *.bat options.txt servers.dat usercache.json usernamecache.json command_history.txt /XD .git logs screenshots downloads | Out-Null
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $lines = @(Get-Content $vFile -Encoding UTF8); $done = $false
        for ($n = 0; $n -lt $lines.Count; $n++) {
            if ($lines[$n] -match '^\s*version\s*=') { $lines[$n] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -Path $vFile -Value $lines -Encoding UTF8
        Banner "Готово! Сборка обновлена до v$remoteVer" DarkGreen White
    }
    elseif ($ch -eq '2') { notepad $vFile }
}
elseif ($rv -eq $lv) {
    Banner 'У тебя свежая сборка, всё актуально =)' DarkGreen White
    W '[2] Открыть changelog   [Enter] выход' Gray
    if ((Read-Host ($IND + 'Выбор')).Trim() -eq '2') { notepad $vFile }
}
else {
    Banner 'Локальная версия новее, чем на GitHub (o_O)' DarkYellow Black
}
Write-Host ''
Read-Host ($IND + 'Enter для выхода')