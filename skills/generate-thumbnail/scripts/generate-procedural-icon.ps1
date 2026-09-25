<#
.SYNOPSIS
    Generates a stylized procedural 256x256 icon.png for a R.E.P.O. mod.

.DESCRIPTION
    Creates a clean, high-contrast R.E.P.O.-themed thumbnail with industrial styling,
    hazard caution bars, and clean typography. Ideal for agents without multimodal image generation.

.PARAMETER Title
    The primary mod title to display on the icon.

.PARAMETER Subtitle
    Optional subtitle or tag (default: "R.E.P.O. MOD").

.PARAMETER OutputPath
    Output destination path (default: "icon.png").
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [string]$Subtitle = "R.E.P.O. MOD",
    [string]$OutputPath = "icon.png"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)

try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    # 1. Dark industrial background gradient
    $bgRect = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $cTop = [System.Drawing.ColorTranslator]::FromHtml("#18191f")
    $cBot = [System.Drawing.ColorTranslator]::FromHtml("#0b0c10")
    $bgBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($bgRect, $cTop, $cBot, 90.0)
    $g.FillRectangle($bgBrush, $bgRect)
    $bgBrush.Dispose()

    # 2. Hazard stripe top and bottom bars
    $stripeHeight = 18
    $yellow = [System.Drawing.ColorTranslator]::FromHtml("#f39c12")
    $darkStripe = [System.Drawing.ColorTranslator]::FromHtml("#15161b")
    $yellowBrush = [System.Drawing.SolidBrush]::new($yellow)
    $darkBrush = [System.Drawing.SolidBrush]::new($darkStripe)

    # Function to draw angled stripes
    function Draw-HazardBar([int]$yPos) {
        $g.FillRectangle($yellowBrush, 0, $yPos, $size, $stripeHeight)
        $stripeWidth = 14
        for ($x = -$stripeHeight; $x -lt $size + $stripeHeight; $x += ($stripeWidth * 2)) {
            $pts = @(
                [System.Drawing.Point]::new($x, $yPos),
                [System.Drawing.Point]::new($x + $stripeWidth, $yPos),
                [System.Drawing.Point]::new($x + $stripeWidth - 10, $yPos + $stripeHeight),
                [System.Drawing.Point]::new($x - 10, $yPos + $stripeHeight)
            )
            $g.FillPolygon($darkBrush, $pts)
        }
    }

    Draw-HazardBar 0
    Draw-HazardBar ($size - $stripeHeight)

    # 3. Outer border
    $borderPen = [System.Drawing.Pen]::new($yellow, 2)
    $g.DrawRectangle($borderPen, 1, 1, $size - 2, $size - 2)
    $borderPen.Dispose()

    # 4. Center icon / badge graphic
    $centerCirclePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml("#2a2b36"), 3)
    $g.DrawEllipse($centerCirclePen, 38, 48, 180, 140)
    $centerCirclePen.Dispose()

    # 5. Mod Title text formatting
    $titleFont = [System.Drawing.Font]::new("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $subFont = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Word wrap or truncate if title is long
    $titleRect = [System.Drawing.RectangleF]::new(12, 60, 232, 100)
    $shadowRect = [System.Drawing.RectangleF]::new(14, 62, 232, 100)

    # Text shadow
    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml("#000000"))
    $g.DrawString($Title, $titleFont, $shadowBrush, $shadowRect, $format)

    # Text foreground
    $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml("#ffffff"))
    $g.DrawString($Title, $titleFont, $whiteBrush, $titleRect, $format)

    # Subtitle pill badge
    $subRect = [System.Drawing.RectangleF]::new(16, 172, 224, 28)
    $pillBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml("#1f2029"))
    $g.FillRectangle($pillBrush, 48, 174, 160, 24)
    $pillBorderPen = [System.Drawing.Pen]::new($yellow, 1)
    $g.DrawRectangle($pillBorderPen, 48, 174, 160, 24)

    $subBrush = [System.Drawing.SolidBrush]::new($yellow)
    $g.DrawString($Subtitle.ToUpper(), $subFont, $subBrush, $subRect, $format)

    # Clean up brushes
    $yellowBrush.Dispose()
    $darkBrush.Dispose()
    $shadowBrush.Dispose()
    $whiteBrush.Dispose()
    $pillBrush.Dispose()
    $pillBorderPen.Dispose()
    $titleFont.Dispose()
    $subFont.Dispose()
    $format.Dispose()

    # Save PNG
    $outFull = [System.IO.Path]::GetFullPath($OutputPath)
    $outDir = [System.IO.Path]::GetDirectoryName($outFull)
    if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    if (Test-Path $outFull) {
        Remove-Item $outFull -Force
    }

    $bmp.Save($outFull, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Procedural icon generated: $outFull (256x256 PNG)" -ForegroundColor Green
}
finally {
    $g.Dispose()
    $bmp.Dispose()
}
