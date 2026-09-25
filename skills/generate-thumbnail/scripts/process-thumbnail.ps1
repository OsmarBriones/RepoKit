<#
.SYNOPSIS
    Crops and resizes any source image to a 256x256 PNG for Thunderstore icon.png.

.DESCRIPTION
    Takes an input image (PNG, JPG, BMP), performs a center-crop to 1:1 aspect ratio,
    and resizes to exactly 256x256 pixels using high-quality bicubic resampling.

.PARAMETER InputImage
    Path to the source image file.

.PARAMETER OutputPath
    Destination path for the icon (defaults to 'icon.png').
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputImage,
    [string]$OutputPath = "icon.png"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputImage)) {
    throw "Input image does not exist: $InputImage"
}

Add-Type -AssemblyName System.Drawing

$srcImg = [System.Drawing.Image]::FromFile((Resolve-Path $InputImage).Path)

try {
    $srcW = $srcImg.Width
    $srcH = $srcImg.Height
    Write-Host "Source image dimensions: ${srcW}x${srcH}" -ForegroundColor Gray

    # Determine center crop square
    $minDim = [Math]::Min($srcW, $srcH)
    $cropX = [int](($srcW - $minDim) / 2)
    $cropY = [int](($srcH - $minDim) / 2)
    $srcRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $minDim, $minDim)

    $targetSize = 256
    $destRect = [System.Drawing.Rectangle]::new(0, 0, $targetSize, $targetSize)

    $destBmp = [System.Drawing.Bitmap]::new($targetSize, $targetSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($destBmp)

    try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $graphics.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

        # Ensure output directory exists
        $outFull = [System.IO.Path]::GetFullPath($OutputPath)
        $outDir = [System.IO.Path]::GetDirectoryName($outFull)
        if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        if (Test-Path $outFull) {
            Remove-Item $outFull -Force
        }

        $destBmp.Save($outFull, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Successfully processed icon: $outFull (256x256 PNG)" -ForegroundColor Green
    }
    finally {
        $graphics.Dispose()
        $destBmp.Dispose()
    }
}
finally {
    $srcImg.Dispose()
}
