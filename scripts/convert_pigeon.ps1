Add-Type -AssemblyName System.Drawing

$projDir = "C:\Users\User\Documents\KMUTT_UNI\Y2\Digital\Digital_final proj"
$imgPath = Join-Path $projDir "images.jpg"
$memDir  = Join-Path $projDir "mem"

$src = [System.Drawing.Bitmap]::new($imgPath)
$W = $src.Width
$H = $src.Height

# Crop tightly around the pigeon (x: 11%..88%, y: 14%..93%)
$cropX = [int]($W * 0.11)
$cropY = [int]($H * 0.14)
$cropW = [int]($W * 0.77)
$cropH = [int]($H * 0.79)

function Is-Foreground([int]$gx, [int]$gy, [System.Drawing.Color]$c) {
    $nx = $gx / [double]$W
    $ny = $gy / [double]$H

    if ($nx -lt 0.12 -or $nx -gt 0.87 -or $ny -lt 0.15 -or $ny -gt 0.925) { return $false }
    if ($nx -gt 0.80 -and $ny -gt 0.85) { return $false }

    $r = [int]$c.R
    $g = [int]$c.G
    $b = [int]$c.B
    $sum = $r + $g + $b

    # Upper region: head, eyes, beak, lips, neck, body (ny: 0.15 .. 0.665)
    if ($ny -le 0.665) {
        $cx = 0.445
        $halfW = if ($ny -lt 0.34) { 0.145 } elseif ($ny -lt 0.42) { 0.23 } else { 0.295 }
        if ([Math]::Abs($nx - $cx) -gt $halfW) { return $false }

        # Keep lips, beak, and eyes unconditionally
        if ($ny -ge 0.19 -and $ny -le 0.33 -and $nx -ge 0.33 -and $nx -le 0.555) {
            # Still reject bright beige headboard at top-left/top-right corners of head box
            if ($sum -gt 500 -and $r -gt ($b + 12) -and $ny -lt 0.26) { return $false }
            return $true
        }

        # Head/neck feathers are cool blue/gray/teal (B >= R - 10) or dark; reject warm beige/pink wall & pillows
        if ($r -gt ($b + 10) -and $sum -gt 300) { return $false }
        return $true
    }

    # Lower region: legs & big human feet (ny: 0.665 .. 0.925)
    # Exclude gap between the two legs/feet in the center
    if ($ny -gt 0.665 -and $ny -lt 0.78 -and $nx -ge 0.37 -and $nx -le 0.50) { return $false }
    if ($ny -ge 0.78  -and $nx -ge 0.38 -and $nx -le 0.54 -and ($g - $b) -lt 10) { return $false }

    # Tighter ankle width (ny: 0.665 .. 0.775) vs wider spread toes (ny >= 0.775)
    if ($ny -lt 0.775) {
        $inLeftAnkle  = ($nx -ge 0.235 -and $nx -le 0.37)
        $inRightAnkle = ($nx -ge 0.50  -and $nx -le 0.70)
        if (-not ($inLeftAnkle -or $inRightAnkle)) { return $false }
    } else {
        $inLeftFoot  = ($nx -ge 0.125 -and $nx -le 0.39)
        $inRightFoot = ($nx -ge 0.49  -and $nx -le 0.865)
        if (-not ($inLeftFoot -or $inRightFoot)) { return $false }
    }

    # Pink bedsheet has magenta/pink cast; skin has warm tan (G > B + 8) or dark toe creases
    $isPinkSheet = (($r - $g) -ge 20) -and (($b - $g) -ge -8) -and ($sum -gt 320)
    if ($isPinkSheet) { return $false }

    return (($g - $b) -ge 7) -or ($sum -lt 340)
}

$SIZE = 48

function Build-Frame([double]$angleDeg, [int]$yShift) {
    $bmp = [System.Drawing.Bitmap]::new($SIZE, $SIZE)
    $lines = New-Object System.Collections.Generic.List[string]
    $rad = $angleDeg * [Math]::PI / 180.0
    $cos = [Math]::Cos($rad)
    $sin = [Math]::Sin($rad)

    for ($y = 0; $y -lt $SIZE; $y++) {
        $rowTokens = New-Object System.Collections.Generic.List[string]
        for ($x = 0; $x -lt $SIZE; $x++) {
            $dx = $x - 23.5
            $dy = ($y - $yShift) - 23.5
            $rx = $dx * $cos + $dy * $sin + 23.5
            $ry = -$dx * $sin + $dy * $cos + 23.5

            if ($rx -lt 0 -or $rx -ge $SIZE -or $ry -lt 0 -or $ry -ge $SIZE) {
                $rowTokens.Add("F0F")
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 75, 185, 205))
                continue
            }

            $sx = [int]($cropX + ($rx / $SIZE) * $cropW)
            $sy = [int]($cropY + ($ry / $SIZE) * $cropH)
            $c = $src.GetPixel($sx, $sy)

            if (Is-Foreground $sx $sy $c) {
                $r4 = $c.R -shr 4
                $g4 = $c.G -shr 4
                $b4 = $c.B -shr 4
                if ($r4 -eq 15 -and $g4 -eq 0 -and $b4 -eq 15) { $g4 = 1 }
                $hex = "{0:X}{1:X}{2:X}" -f $r4, $g4, $b4
                $rowTokens.Add($hex)
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $r4 * 17, $g4 * 17, $b4 * 17))
            } else {
                $rowTokens.Add("F0F")
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 75, 185, 205))
            }
        }
        $lines.Add(($rowTokens -join " "))
    }
    return @{ Bmp = $bmp; Lines = $lines }
}

$down = Build-Frame -angleDeg 6.0  -yShift 1
$up   = Build-Frame -angleDeg -8.0 -yShift -1

[System.IO.File]::WriteAllLines((Join-Path $memDir "pigeon_down.mem"), $down.Lines)
[System.IO.File]::WriteAllLines((Join-Path $memDir "pigeon_up.mem"),   $up.Lines)

$prev = [System.Drawing.Bitmap]::new($SIZE * 8 + 16, $SIZE * 4)
$g = [System.Drawing.Graphics]::FromImage($prev)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 40))
$g.DrawImage($down.Bmp, 0, 0, $SIZE * 4, $SIZE * 4)
$g.DrawImage($up.Bmp, $SIZE * 4 + 16, 0, $SIZE * 4, $SIZE * 4)
$g.Dispose()
$prevPath = Join-Path $memDir "pigeon_preview.png"
$prev.Save($prevPath, [System.Drawing.Imaging.ImageFormat]::Png)
$prev.Dispose()
$src.Dispose()
Write-Output "Refined pigeon_down.mem & pigeon_up.mem successfully!"
