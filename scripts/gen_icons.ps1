Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'tick.PNG'
$srcImg = [System.Drawing.Image]::FromFile($src)

function Save-SquareEdited([string]$dst, [int]$size, [float]$contentScale = 1.0) {
    $dir = Split-Path -Parent $dst
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)
    $target = [math]::Floor($size * $contentScale)
    $off = [math]::Floor(($size - $target) / 2)
    $g.DrawImage($srcImg, $off, $off, $target, $target)
    $g.Dispose()
    if ($dst -like '*.ico') {
        $h = $bmp.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($h)
        $fs = [System.IO.File]::Create($dst)
        $icon.Save($fs)
        $fs.Dispose()
        $icon.Dispose()
    } else {
        $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    $bmp.Dispose()
    if (Test-Path $dst) { Write-Output ("OK   " + $dst + "  " + (Get-Item $dst).Length) }
    else { Write-Output ("FAIL " + $dst) }
}

# iOS / macOS 1024x1024
Save-SquareEdited (Join-Path $root 'ios\Tick\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png') 1024
Save-SquareEdited (Join-Path $root 'macos\Tick\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png') 1024

# Windows EXE 图标(ico) + 运行图标 png
Save-SquareEdited (Join-Path $root 'windows\Assets\Tick.ico') 256
Save-SquareEdited (Join-Path $root 'windows\Assets\Tick.png') 256

# Linux 256 png
Save-SquareEdited (Join-Path $root 'linux\resources\app_icon.png') 256

# Android 自适应图标前景：432px，图标占中间 61% 安全区
Save-SquareEdited (Join-Path $root 'android\app\src\main\res\drawable-nodpi\tick_launcher_foreground.png') 432 0.61

# HarmonyOS 应用图标（AppScope + entry）
Save-SquareEdited (Join-Path $root 'harmonyos\AppScope\resources\base\media\app_icon.png') 512
Save-SquareEdited (Join-Path $root 'harmonyos\entry\src\main\resources\base\media\app_icon.png') 512

$srcImg.Dispose()
Write-Output 'icons generated'