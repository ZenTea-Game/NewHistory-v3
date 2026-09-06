param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo   = 'ZenTea-Game/NewHistory-v3'
$branch = 'main'
$dir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile  = Join-Path $dir 'version.txt'
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

# Скачивание через curl с реальным прогресс-баром
function Invoke-Download($url, $out) {
    W "Скачиваю с GitHub (это может занять время)..." Yellow
    
    # Используем curl.exe (встроен в Windows 10/11)
    $curlArgs = @(
        '-L',                    # Follow redirects
        '-o', $out,             # Output file
        '--progress-bar',       # Show progress bar
        '-A', 'NH3-Updater',   # User agent
        $url
    )
    
    $process = Start-Process -FilePath 'curl.exe' -ArgumentList $curlArgs -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        throw "curl вернул код ошибки: $($process.ExitCode)"
    }
    
    if (-not (Test-Path -LiteralPath $out)) {
        throw "Файл не был скачан"
    }
    
    $size = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)
    W "Скачано: $size MB" Green
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

# Проверка версии
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

$localVer = Get-LocalVersion
$lv = To-Ver $localVer; $rv = To-Ver $remoteVer

if ($Quiet) {
    Write-Host (" Локально: v$localVer   GitHub: v$remoteVer  ->  ") -NoNewline -ForegroundColor Cyan
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
            
            W 'Распаковываю...' Yellow
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
            Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
            
            $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
            robocopy $src $dir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XF version.txt token.txt *.bat options.txt servers.dat usercache.json usernamecache.json command_history.txt /XD .git logs screenshots downloads nh3_extract | Out-Null
            
            # Обновляем версию ПОСЛЕ копирования
            $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8); $done = $false
            for ($n = 0; $n -lt $lines.Count; $n++) {
                if ($lines[$n] -match '^\s*version\s*=') { $lines[$n] = "version=$remoteVer"; $done = $true; break }
            }
            if (-not $done) { $lines = @("version=$remoteVer") + $lines }
            Set-Content -Path $vFile -Value $lines -Encoding UTF8
            
            Safe-Remove $zip
            Safe-Remove $tmp
            
            W "Готово! Сборка обновлена до v$remoteVer" Green
        } catch {
            W ('Ошибка: ' + $_) Red
            Read-Host ($IND + 'Enter'); exit 1
        }
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