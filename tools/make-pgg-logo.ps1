# Draws the PGG community emblem: chunky yellow "PGG" with a dark outline on a purple sunburst, 512 x 512.
# Run: powershell -ExecutionPolicy Bypass -File tools/make-pgg-logo.ps1
param([string]$Out = (Join-Path $PSScriptRoot "..\Thumbnails & Icon\PGG Logo.png"))
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$S = 512
$bmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
function C($hex) { return [System.Drawing.ColorTranslator]::FromHtml("#$hex") }

# purple background with a soft sunburst
$g.Clear((C "4B3F7C"))
$ray = New-Object System.Drawing.SolidBrush (C "5B4E90")
for ($k = 0; $k -lt 16; $k += 2) {
    $a0 = $k * [math]::PI / 8; $a1 = ($k + 1) * [math]::PI / 8
    $pts = @(
        (New-Object System.Drawing.PointF ($S / 2), ($S / 2)),
        (New-Object System.Drawing.PointF ($S / 2 + [math]::Cos($a0) * $S), ($S / 2 + [math]::Sin($a0) * $S)),
        (New-Object System.Drawing.PointF ($S / 2 + [math]::Cos($a1) * $S), ($S / 2 + [math]::Sin($a1) * $S))
    )
    $g.FillPolygon($ray, [System.Drawing.PointF[]]$pts)
}

# little sparkles
$white = New-Object System.Drawing.SolidBrush (C "FFFFFF")
function Sparkle($cx, $cy, $r) {
    $p = @()
    for ($k = 0; $k -lt 8; $k++) { $rr = if ($k % 2) { $r * 0.28 } else { $r }; $a = $k * [math]::PI / 4 - [math]::PI / 2; $p += (New-Object System.Drawing.PointF ($cx + [math]::Cos($a) * $rr), ($cy + [math]::Sin($a) * $rr)) }
    $g.FillPolygon($white, [System.Drawing.PointF[]]$p)
}
Sparkle 92 104 26; Sparkle 420 410 20; Sparkle 428 96 14

# "PGG": dark outline, then yellow fill, nudged down for a chunky drop shadow
$family = New-Object System.Drawing.FontFamily "Arial Black"
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$fmt.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
$rect = New-Object System.Drawing.RectangleF 0, 10, $S, $S
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddString("PGG", $family, [int][System.Drawing.FontStyle]::Bold, 150, $rect, $fmt)
$ink = C "1A1430"
$shadow = $path.Clone()
$m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(0, 14); $shadow.Transform($m)
$thick = New-Object System.Drawing.Pen $ink, 30; $thick.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($thick, $shadow); $g.FillPath((New-Object System.Drawing.SolidBrush $ink), $shadow)
$g.DrawPath($thick, $path)
$g.FillPath((New-Object System.Drawing.SolidBrush (C "FFC93C")), $path)
# a light band across the top of the letters
$g.SetClip($path)
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 240, 190))), 0, 0, $S, 262)
$g.ResetClip()

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "Saved $Out"
