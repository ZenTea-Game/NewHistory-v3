param([switch]$Quiet)

# НАСТРОЙКИ
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Net.Http

$repo    = 'ZenTea-Game/NewHistory-v3'
$branch  = 'main'
$dir     = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vFile   = Join-Path $dir 'version.txt'
$modsDir = Join-Path $dir 'mods'
$zip     = Join-Path $dir 'nh3_update.zip'
$tmp     = Join-Path $dir 'nh3_extract'
$url     = "https://github.com/$repo/archive/refs/heads/$branch.zip"

# Ссылки
$githubUrl      = "https://github.com/$repo"
$googleDriveUrl = "https://drive.usercontent.google.com/download?id=1UixrKDtRj1VlEdMVgN2zu9vMiM64QtMN&export=download&confirm=t"
$imageUrl       = "https://i.pinimg.com/originals/f9/2c/e8/f92ce82f251033f30b8606224b81de0b.jpg?nii=t"
$videoUrl       = "https://www.youtube.com/watch?v=wOMFFPjGr4U"

# Тяжёлые моды (нужны для полной установки)
$driveMods = @(
    @{ Name = 'AoA3-1.21.1-3.7.16.1.jar'; Url = 'https://drive.usercontent.google.com/download?id=1UixrKDtRj1VlEdMVgN2zu9vMiM64QtMN&export=download&confirm=t' }
)

# ===== ВЕРСИИ САМИХ ФАЙЛОВ АПДЕЙТЕРА =====
$updaterVersion = 'v6.0'
$batVersion     = 'v1.2'
$checkVersion   = 'v1.2'
# =========================================

$RainbowColors = @('Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Magenta')

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

function Write-RainbowTitleBlock {
    $Width = 48
    $Inner = $Width - 2
    $Text = " NewHistory-v3  ·  АПДЕЙТЕР СБОРКИ "
    $TextLen = $Text.Length
    $Pad = $Inner - $TextLen
    $LeftPad = [math]::Floor($Pad / 2)
    $RightPad = $Pad - $LeftPad

    Write-Center ('╔' + ('═' * ($Width - 2)) + '╗') 'Cyan'

    $w = [Console]::WindowWidth
    $spaces = [math]::Max(0, [math]::Floor(($w - $Width) / 2))
    Write-Host (" " * $spaces) -NoNewline
    Write-Host "║" -NoNewline -ForegroundColor 'Cyan'
    Write-Host (" " * $LeftPad) -NoNewline

    $i = 0
    foreach ($ch in $Text.ToCharArray()) {
        $color = $RainbowColors[$i % $RainbowColors.Length]
        Write-Host $ch -NoNewline -ForegroundColor $color
        $i++
    }

    Write-Host (" " * $RightPad) -NoNewline
    Write-Host "║" -ForegroundColor 'Cyan'
    Write-Center ('╚' + ('═' * ($Width - 2)) + '╝') 'Cyan'
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

function Invoke-Download($u, $out) {
    $client = [System.Net.Http.HttpClient]::new()
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('NH3-Updater')

    $response = $client.GetAsync($u, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    $totalBytes = $response.Content.Headers.ContentLength

    if ($null -ne $totalBytes -and $totalBytes -gt 0) {
        Write-Center ("Архив весит: {0:N0} МБ" -f ($totalBytes / 1MB)) 'Cyan'
    } else {
        Write-Center 'Размер файла неизвестен, качаю...' 'Cyan'
        $totalBytes = 0
    }
    Write-Center 'Качаю, полоса ниже показывает прогресс:' 'Yellow'

    $contentStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $fileStream = [System.IO.File]::Create($out)

    $buffer = New-Object byte[] 10240
    $read = 0
    $downloaded = [long]0
    $lastPercent = -1
    $lastMB = -1
    $spinChars = @('|', '/', '-', '\')
    $spinIndex = 0
    $barLength = 30

    try {
        while (($read = $contentStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $downloaded += $read

            $percent = if ($totalBytes -gt 0) { [math]::Floor(($downloaded / $totalBytes) * 100) } else { -1 }
            $currentMB = [math]::Floor($downloaded / 1MB)

            if ($percent -ne $lastPercent -or $currentMB -ne $lastMB -or $spinIndex -eq 0) {
                $lastPercent = $percent
                $lastMB = $currentMB

                $spin = $spinChars[$spinIndex % $spinChars.Length]
                $downloadedMB = [math]::Round($downloaded / 1MB, 1)

                $barArray = @()
                for ($i = 0; $i -lt $barLength; $i++) { $barArray += ' ' }

                if ($totalBytes -gt 0) {
                    $totalMB = [math]::Round($totalBytes / 1MB, 1)
                    $filledCount = [math]::Floor($barLength * $percent / 100)
                    for ($i = 0; $i -lt $filledCount; $i++) { $barArray[$i] = '#' }

                    $emptyCount = $barLength - $filledCount
                    if ($emptyCount -gt 0) {
                        $range = $emptyCount * 2
                        $offset = $spinIndex % $range
                        if ($offset -ge $emptyCount) { $offset = $range - 1 - $offset }
                        $starPos = $filledCount + $offset
                        if ($starPos -ge $barLength) { $starPos = $barLength - 1 }
                        $barArray[$starPos] = '*'
                    }

                    $bar = '[' + ($barArray -join '') + ']'
                    $msg = "$spin $bar $percent% [$downloadedMB MB / $totalMB MB]"
                } else {
                    $range = $barLength * 2
                    $offset = $spinIndex % $range
                    if ($offset -ge $barLength) { $offset = $range - 1 - $offset }
                    $barArray[$offset] = '*'

                    $bar = '[' + ($barArray -join '') + ']'
                    $msg = "$spin $bar [$downloadedMB MB]"
                }

                Write-ProgressLine $msg 'Cyan'
                $spinIndex++
            }
        }
    }
    finally {
        $fileStream.Flush()
        $fileStream.Close()
        $contentStream.Close()
        $client.Dispose()
    }

    Write-Host ""
    $size = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)
    Write-Center ("Скачано: {0:N0} МБ" -f $size) 'Green'
}

function Update-OtherMods {
    Write-Center 'Скачиваю моды с GitHub...' 'Yellow'
    try {
        Invoke-Download $url $zip
        Write-Center 'Распаковываю архив...' 'Yellow'
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
        $srcMods = Join-Path $src 'mods'

        if (-not (Test-Path -LiteralPath $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
        Write-Center 'Обновляю папку модов (сохраняю локальные моды)...' 'Yellow'
        robocopy $srcMods $modsDir /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null

        Write-Center 'Моды обновлены!' 'Green'
    }
    catch {
        Write-Center ('Ошибка: ' + $_.Exception.Message) 'Red'
    }
    finally {
        try { if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force } } catch {}
        try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } } catch {}
    }
    Start-Sleep -Seconds 2
}

function Open-WebPage($url) {
    Start-Process $url
}

function Show-ParrotAnimation {
    Clear-Host
    Write-Center "Нажми любую клавишу, чтобы выйти из прикола с попугаем" 'Yellow'
    Write-Host ""

    $parrot = @"
    .-.
   (o.o)
    |=|
   __|__
 //.=|=.\\
// .=|=. \\
\\ .=|=. //
 \\(_=_)//
  (:| |:)
   || ||
   () ()
   || ||
   || ||
"@

    $frameIndex = 0
    while (-not [Console]::KeyAvailable) {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight

        $top = [math]::Max(0, [math]::Floor(($height - $parrot.Split("`n").Count) / 2))
        [Console]::SetCursorPosition(0, $top)

        $color = if ($frameIndex % 2 -eq 0) { 'Green' } else { 'Yellow' }
        foreach ($line in $parrot.Split("`n")) {
            $spaces = [math]::Max(0, [math]::Floor(($width - $line.Length) / 2))
            Write-Host (" " * $spaces + $line) -ForegroundColor $color
        }

        Start-Sleep -Milliseconds 300
        $frameIndex++

        [Console]::SetCursorPosition(0, $top)
        for ($i = 0; $i -lt $parrot.Split("`n").Count; $i++) {
            Write-Host (" " * $width)
        }
    }
    [Console]::ReadKey($true) | Out-Null
    Clear-Host
}

# ===== ИГРА ПИНГ-ПОНГ ПРОТИВ БОТА (оптимизированная) =====
function Start-PingPong {
    $playW = 40
    $playH = 14
    $paddleH = 4
    $speed = 80

    $playerY = [int](($playH - $paddleH) / 2)
    $botY = $playerY
    $ballX = [int]($playW / 2)
    $ballY = [int]($playH / 2)
    $ballDX = 1
    $ballDY = 1
    $playerScore = 0
    $botScore = 0
    $botSpeed = 2
    $botTick = 0

    try { [Console]::CursorVisible = $false } catch {}
    Clear-Host

    $prevField = New-Object 'string[,]' $playW, $playH
    for ($y = 0; $y -lt $playH; $y++) {
        for ($x = 0; $x -lt $playW; $x++) { $prevField[$x, $y] = " " }
    }

    $cw = [Console]::WindowWidth
    $ch = [Console]::WindowHeight

    $fieldTop = [int](($ch - ($playH + 6)) / 2)
    if ($fieldTop -lt 0) { $fieldTop = 0 }
    $fieldLeft = [int](($cw - ($playW + 4)) / 2)
    if ($fieldLeft -lt 0) { $fieldLeft = 0 }

    [Console]::SetCursorPosition(0, $fieldTop - 4)
    $titleLine1 = "  Счёт:   ВЫ $playerScore  :  $botScore  БОТ"
    $titleLine2 = "  W/S или ↑/↓ — двигать, Q или Esc — выход"
    $sp1 = [math]::Max(0, [int](($cw - $titleLine1.Length) / 2))
    $sp2 = [math]::Max(0, [int](($cw - $titleLine2.Length) / 2))
    Write-Host (" " * $sp1 + $titleLine1).PadRight($cw).Substring(0, $cw) -ForegroundColor Yellow
    [Console]::SetCursorPosition(0, $fieldTop - 3)
    Write-Host (" " * $sp2 + $titleLine2).PadRight($cw).Substring(0, $cw) -ForegroundColor DarkGray

    [Console]::SetCursorPosition($fieldLeft, $fieldTop)
    Write-Host ("+" + ("-" * $playW) + "+") -ForegroundColor Cyan
    for ($y = 0; $y -lt $playH; $y++) {
        [Console]::SetCursorPosition($fieldLeft, $fieldTop + 1 + $y)
        Write-Host ("|" + (" " * $playW) + "|") -ForegroundColor Cyan
    }
    [Console]::SetCursorPosition($fieldLeft, $fieldTop + 1 + $playH)
    Write-Host ("+" + ("-" * $playW) + "+") -ForegroundColor Cyan

    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::W -or $key.Key -eq [ConsoleKey]::UpArrow) {
                if ($playerY -gt 0) { $playerY-- }
            }
            elseif ($key.Key -eq [ConsoleKey]::S -or $key.Key -eq [ConsoleKey]::DownArrow) {
                if ($playerY -lt $playH - $paddleH) { $playerY++ }
            }
            elseif ($key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::Escape) {
                break
            }
        }

        $botTick++
        if ($botTick -ge $botSpeed) {
            $botTick = 0
            $botCenter = $botY + [int]($paddleH / 2)
            if ($ballY -lt $botCenter -and $botY -gt 0) { $botY-- }
            elseif ($ballY -gt $botCenter -and $botY -lt $playH - $paddleH) { $botY++ }
        }

        $ballX += $ballDX
        $ballY += $ballDY

        if ($ballY -le 0) { $ballY = 0; $ballDY = 1 }
        if ($ballY -ge $playH - 1) { $ballY = $playH - 1; $ballDY = -1 }

        $scored = $false
        if ($ballX -le 0) {
            if ($ballY -ge $playerY -and $ballY -lt $playerY + $paddleH) {
                $ballDX = 1
                $ballX = 1
            } else {
                $botScore++
                $scored = $true
            }
        }
        if ($ballX -ge $playW - 1) {
            if ($ballY -ge $botY -and $ballY -lt $botY + $paddleH) {
                $ballDX = -1
                $ballX = $playW - 2
            } else {
                $playerScore++
                $scored = $true
            }
        }

        $newField = New-Object 'string[,]' $playW, $playH
        for ($y = 0; $y -lt $playH; $y++) {
            for ($x = 0; $x -lt $playW; $x++) { $newField[$x, $y] = " " }
        }
        for ($y = $playerY; $y -lt $playerY + $paddleH; $y++) {
            if ($y -ge 0 -and $y -lt $playH) { $newField[0, $y] = "[" }
        }
        for ($y = $botY; $y -lt $botY + $paddleH; $y++) {
            if ($y -ge 0 -and $y -lt $playH) { $newField[$playW - 1, $y] = "]" }
        }
        if ($ballX -ge 0 -and $ballX -lt $playW -and $ballY -ge 0 -and $ballY -lt $playH) {
            $newField[$ballX, $ballY] = "O"
        }

        for ($y = 0; $y -lt $playH; $y++) {
            for ($x = 0; $x -lt $playW; $x++) {
                if ($newField[$x, $y] -ne $prevField[$x, $y]) {
                    [Console]::SetCursorPosition($fieldLeft + 1 + $x, $fieldTop + 1 + $y)
                    $ch2 = $newField[$x, $y]
                    $col = if ($ch2 -eq "O") { "Yellow" } elseif ($ch2 -eq "[") { "Green" } elseif ($ch2 -eq "]") { "Red" } else { "Cyan" }
                    Write-Host $ch2 -NoNewline -ForegroundColor $col
                }
            }
        }
        $prevField = $newField

        if ($scored) {
            $scoreLine = "  Счёт:   ВЫ $playerScore  :  $botScore  БОТ"
            $sp = [math]::Max(0, [int](($cw - $scoreLine.Length) / 2))
            [Console]::SetCursorPosition(0, $fieldTop - 4)
            Write-Host (" " * $sp + $scoreLine).PadRight($cw).Substring(0, $cw) -ForegroundColor Yellow
            Start-Sleep -Milliseconds 700
        }

        Start-Sleep -Milliseconds $speed
    }

    try { [Console]::CursorVisible = $true } catch {}
    Clear-Host
}

# ===== КНОПКА "НЕ НАЖИМАЙ" (2 СКРИНШОТА) =====
function Start-NoPress {
    Clear-Host
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $warnings = @(
        "ТЫ НАЖАЛ?! Я ЖЕ СКАЗАЛ НЕ НАЖИМАТЬ!",
        "ЛАДНО, САМ ВИНОВАТ...",
        "СЕЙЧАС БУДЕТ ФОТО!",
        "УЛЫБНИСЬ! :)"
    )

    foreach ($msg in $warnings) {
        Write-Center $msg 'Red'
        Start-Sleep -Milliseconds 600
    }

    Write-Host ""
    Write-Center "Фото через 3..." 'Yellow'
    Start-Sleep -Seconds 1
    Write-Center "Фото через 2..." 'Yellow'
    Start-Sleep -Seconds 1
    Write-Center "Фото через 1..." 'Yellow'
    Start-Sleep -Seconds 1

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

    # Фото 1
    Write-Center "ФОТО 1/2 — СНИМАЮ!" 'Green'
    try { [Console]::BackgroundColor = 'White'; Clear-Host } catch {}
    $bmp1 = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $g1 = [System.Drawing.Graphics]::FromImage($bmp1)
    $g1.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    $g1.Dispose()
    try { [Console]::BackgroundColor = 'Black'; Clear-Host } catch {}
    Write-Center "ФОТО 1/2 ГОТОВО!" 'Green'
    Start-Sleep -Milliseconds 800

    # Фото 2
    Write-Center "ФОТО 2/2 — СНИМАЮ!" 'Green'
    try { [Console]::BackgroundColor = 'White'; Clear-Host } catch {}
    $bmp2 = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
    $g2.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    $g2.Dispose()
    try { [Console]::BackgroundColor = 'Black'; Clear-Host } catch {}
    Write-Center "ФОТО 2/2 ГОТОВО!" 'Green'
    Start-Sleep -Seconds 1

    # Сохранение на рабочий стол и в TEMP
    $desktop = [Environment]::GetFolderPath('Desktop')
    $tempPath = [System.IO.Path]::GetTempPath()
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

    $file1Desktop = Join-Path $desktop "NH3_photo_${timestamp}_1.png"
    $file2Desktop = Join-Path $desktop "NH3_photo_${timestamp}_2.png"
    $file1Temp = Join-Path $tempPath "NH3_photo_${timestamp}_1.png"
    $file2Temp = Join-Path $tempPath "NH3_photo_${timestamp}_2.png"

    $bmp1.Save($file1Desktop, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp2.Save($file2Desktop, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp1.Save($file1Temp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp2.Save($file2Temp, [System.Drawing.Imaging.ImageFormat]::Png)

    $bmp1.Dispose()
    $bmp2.Dispose()

    Write-Host ""
    Write-Center "Сохранено на Рабочий стол и в TEMP:" 'Green'
    Write-Center (Split-Path $file1Desktop -Leaf) 'Cyan'
    Write-Center (Split-Path $file2Desktop -Leaf) 'Cyan'
    Write-Host ""
    Write-Center "Открываю фото..." 'Yellow'
    Start-Sleep -Seconds 2

    Start-Process $file1Desktop
    Start-Sleep -Milliseconds 700
    Start-Process $file2Desktop

    Start-Sleep -Seconds 3
    Clear-Host
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

function Update-Pack {
    try {
        Invoke-Download $url $zip

        Write-Center 'Распаковываю архив...' 'Yellow'
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)

        $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName

        Write-Center 'Очищаю старые файлы (mods, tacz, kubejs)...' 'Yellow'
        foreach ($folder in @('mods', 'tacz', 'kubejs')) {
            $folderPath = Join-Path $dir $folder
            if (Test-Path -LiteralPath $folderPath) {
                Remove-Item -LiteralPath $folderPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Center 'Применяю полное обновление (заменяю все файлы сборки)...' 'Yellow'
        robocopy $src $dir /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /XD config data emotes .git logs screenshots downloads nh3_extract /XF token.txt options.txt servers.dat usercache.json usernamecache.json command_history.txt nh3_update.zip | Out-Null

        # Обновление версии
        $lines = @()
        if (Test-Path -LiteralPath $vFile) { $lines = @(Get-Content -LiteralPath $vFile -Encoding UTF8) }
        $done = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*version\s*=') { $lines[$i] = "version=$remoteVer"; $done = $true; break }
        }
        if (-not $done) { $lines = @("version=$remoteVer") + $lines }
        Set-Content -LiteralPath $vFile -Value $lines -Encoding UTF8

        # Скачиваем тяжёлые моды с Google Drive (AoA3), если их нет
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

        Write-Center ("Готово! Сборка обновлена до v{0}" -f $remoteVer) 'Green'
    }
    catch {
        Write-Center ('Ошибка: ' + $_.Exception.Message) 'Red'
    }
    finally {
        try { if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force } } catch {}
        try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } } catch {}
    }
}

# Главный цикл меню
while ($true) {
    Clear-Host
    Write-Host ""
    Write-RainbowTitleBlock
    Write-Host ""
    Write-Center $status $statusColor
    Write-Center $desc $statusColor
    Write-Host ""

    Write-Center "═══════════════════════════════════" 'DarkGray'
    Write-Center "Версия Updater.ps1: $updaterVersion" 'White'
    Write-Center "Версия Updater.bat: $batVersion" 'White'
    Write-Center "Версия Check.bat:   $checkVersion" 'White'
    Write-Center "═══════════════════════════════════" 'DarkGray'
    Write-Host ""

    Write-Center "[1] Обновиться" 'Green'
    Write-Center "[2] Открыть GitHub и файл" 'Cyan'
    Write-Center "[3] Для тикета (фото + видео)" 'Magenta'
    Write-Center "[4] Прикол с попугаем" 'Yellow'
    Write-Center "[5] Посмотреть изменения" 'Gray'
    Write-Center "[6] Пинг-понг против бота" 'White'
    Write-Center "[7] Скачать остальные моды" 'White'
    Write-Center "[8] Не нажимай" 'DarkRed'
    Write-Center "[0] Выйти" 'Red'
    Write-Host ""

    $prompt = 'Выбор: '
    $w = [Console]::WindowWidth
    Write-Host (" " * [math]::Max(0, [math]::Floor(($w - $prompt.Length) / 2))) -NoNewline
    Write-Host $prompt -NoNewline
    $ch = Read-Host
    $ch = $ch.Trim()

    switch ($ch) {
        '1' { Update-Pack }
        '2' {
            Open-WebPage $githubUrl
            Open-WebPage $googleDriveUrl
            Write-Center 'Открыл GitHub и файл в браузере.' 'Green'
            Start-Sleep -Seconds 2
        }
        '3' {
            Open-WebPage $imageUrl
            Open-WebPage $videoUrl
            Write-Center 'Открыл фото и видео для тикета.' 'Magenta'
            Start-Sleep -Seconds 2
        }
        '4' { Show-ParrotAnimation }
        '5' {
            if (Test-Path -LiteralPath $vFile) {
                Start-Process notepad $vFile
            } else {
                Write-Center 'Файл изменений не найден.' 'Red'
                Start-Sleep -Seconds 1
            }
        }
        '6' { Start-PingPong }
        '7' { Update-OtherMods }
        '8' { Start-NoPress }
        '0' { exit 0 }
        default {
            Write-Center 'Неверный ввод, попробуй ещё раз.' 'Red'
            Start-Sleep -Seconds 1
        }
    }
}