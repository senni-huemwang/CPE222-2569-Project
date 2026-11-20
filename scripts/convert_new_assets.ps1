Add-Type -AssemblyName System.Drawing

$projDir = "C:\Users\User\Documents\KMUTT_UNI\Y2\Digital\Digital_final proj"
$imgDir  = Join-Path $projDir "image"
$memDir  = Join-Path $projDir "mem"

function To-Hex444([int]$r, [int]$g, [int]$b) {
    $r4 = $r -shr 4
    $g4 = $g -shr 4
    $b4 = $b -shr 4
    if ($r4 -eq 15 -and $g4 -eq 0 -and $b4 -eq 15) { $g4 = 1 }
    return ("{0:X}{1:X}{2:X}" -f $r4, $g4, $b4), ($r4 * 17), ($g4 * 17), ($b4 * 17)
}

# 1. Convert Sticker PNGs (BirdPing.png, BirdPeem.png) with white background removal -> 48x48
function Convert-Sticker([string]$srcName, [string]$outMem) {
    $bmpSrc = [System.Drawing.Bitmap]::new((Join-Path $imgDir $srcName))
    $small  = [System.Drawing.Bitmap]::new(48, 48)
    $g = [System.Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmpSrc, 0, 0, 48, 48)
    $g.Dispose()
    $bmpSrc.Dispose()

    $lines = New-Object System.Collections.Generic.List[string]
    for ($y = 0; $y -lt 48; $y++) {
        $row = New-Object System.Collections.Generic.List[string]
        for ($x = 0; $x -lt 48; $x++) {
            $c = $small.GetPixel($x, $y)
            # Remove transparent or bright white sticker border
            if ($c.A -lt 128 -or ($c.R -gt 235 -and $c.G -gt 235 -and $c.B -gt 235)) {
                $row.Add("F0F")
                $small.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 60, 60, 80))
            } else {
                $hex, $rr, $gg, $bb = To-Hex444 $c.R $c.G $c.B
                $row.Add($hex)
                $small.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $rr, $gg, $bb))
            }
        }
        $lines.Add(($row -join " "))
    }
    [System.IO.File]::WriteAllLines((Join-Path $memDir $outMem), $lines)
    return $small
}

$pingBmp = Convert-Sticker "BirdPing.png" "card_ping.mem"
$peemBmp = Convert-Sticker "BirdPeem.png" "card_peem.mem"

# 2. Die-cut Boss_TA.jpg head -> 24x24 (buff_head.mem) AND 48x48 Chibi Student Boss (boss_chibi.mem)
$taSrc = [System.Drawing.Bitmap]::new((Join-Path $imgDir "Boss_TA.jpg"))
$tw = $taSrc.Width
$th = $taSrc.Height

# Crop around TA's head (x: 12%..88%, y: 4%..74%)
$hx0 = [int]($tw * 0.12); $hy0 = [int]($th * 0.04)
$hw  = [int]($tw * 0.76); $hh  = [int]($th * 0.70)

# 2A. 24x24 Buff Head
$buffBmp = [System.Drawing.Bitmap]::new(24, 24)
$buffLines = New-Object System.Collections.Generic.List[string]
for ($y = 0; $y -lt 24; $y++) {
    $row = New-Object System.Collections.Generic.List[string]
    for ($x = 0; $x -lt 24; $x++) {
        $nx = ($x - 11.5) / 10.8
        $ny = ($y - 11.5) / 11.2
        if (($nx * $nx + $ny * $ny) -gt 1.0) {
            $row.Add("F0F")
            $buffBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 60, 60, 80))
        } else {
            $sx = [int]($hx0 + ($x / 24.0) * $hw)
            $sy = [int]($hy0 + ($y / 24.0) * $hh)
            $c  = $taSrc.GetPixel($sx, $sy)
            $hex, $rr, $gg, $bb = To-Hex444 $c.R $c.G $c.B
            $row.Add($hex)
            $buffBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $rr, $gg, $bb))
        }
    }
    $buffLines.Add(($row -join " "))
}
[System.IO.File]::WriteAllLines((Join-Path $memDir "buff_head.mem"), $buffLines)

# 2B. 48x48 Chibi Boss (Rows 0..31 = Big TA Head, Rows 32..47 = Small Student Uniform)
$bossBmp = [System.Drawing.Bitmap]::new(48, 48)
$bossLines = New-Object System.Collections.Generic.List[string]
for ($y = 0; $y -lt 48; $y++) {
    $row = New-Object System.Collections.Generic.List[string]
    for ($x = 0; $x -lt 48; $x++) {
        if ($y -lt 32) {
            $nx = ($x - 23.5) / 17.5
            $ny = ($y - 16.0) / 15.5
            $dist = $nx * $nx + $ny * $ny
            if ($dist -gt 1.0) {
                $row.Add("F0F")
                $bossBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 60, 60, 80))
            } elseif ($dist -gt 0.88) {
                $row.Add("111")
                $bossBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 17, 17, 17))
            } else {
                $sx = [int]($hx0 + (($x - 6) / 36.0) * $hw)
                $sy = [int]($hy0 + ($y / 32.0) * $hh)
                if ($sx -lt 0) { $sx = 0 }; if ($sx -ge $tw) { $sx = $tw - 1 }
                if ($sy -lt 0) { $sy = 0 }; if ($sy -ge $th) { $sy = $th - 1 }
                $c = $taSrc.GetPixel($sx, $sy)
                $hex, $rr, $gg, $bb = To-Hex444 $c.R $c.G $c.B
                $row.Add($hex)
                $bossBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $rr, $gg, $bb))
            }
        } else {
            # Small Chibi University Student Uniform (Rows 32..47, X=14..33)
            $hex = "F0F"
            if ($y -lt 40) {
                if ($x -ge 14 -and $x -le 33) {
                    if ($x -eq 14 -or $x -eq 33) { $hex = "111" }
                    elseif ($y -eq 39)           { $hex = "222" } # black belt
                    elseif ($x -ge 22 -and $x -le 25) { $hex = "111" } # black tie
                    elseif ($x -le 16 -or $x -ge 31)  { $hex = "EC9" } # chibi hands
                    else                         { $hex = "FFF" } # white shirt
                }
            } elseif ($y -lt 45) {
                if ($x -ge 16 -and $x -le 31) {
                    if ($x -ge 23 -and $x -le 24) { $hex = "F0F" }
                    elseif ($x -eq 16 -or $x -eq 31 -or $x -eq 22 -or $x -eq 25) { $hex = "111" }
                    else { $hex = "223" } # dark student pants
                }
            } elseif ($y -lt 47) {
                if (($x -ge 15 -and $x -le 21) -or ($x -ge 26 -and $x -le 32)) {
                    $hex = "111" # shoes
                }
            }
            $row.Add($hex)
            if ($hex -eq "F0F") {
                $bossBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 60, 60, 80))
            } else {
                $r4 = [Convert]::ToInt32($hex.Substring(0,1), 16) * 17
                $g4 = [Convert]::ToInt32($hex.Substring(1,1), 16) * 17
                $b4 = [Convert]::ToInt32($hex.Substring(2,1), 16) * 17
                $bossBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $r4, $g4, $b4))
            }
        }
    }
    $bossLines.Add(($row -join " "))
}
[System.IO.File]::WriteAllLines((Join-Path $memDir "boss_chibi.mem"), $bossLines)
$taSrc.Dispose()

# Save preview image of all 4 new assets
$prev = [System.Drawing.Bitmap]::new(440, 120)
$pg = [System.Drawing.Graphics]::FromImage($prev)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$pg.Clear([System.Drawing.Color]::FromArgb(255, 25, 25, 35))
$pg.DrawImage($pingBmp, 8,   12, 96, 96)
$pg.DrawImage($peemBmp, 114, 12, 96, 96)
$pg.DrawImage($bossBmp, 220, 12, 96, 96)
$pg.DrawImage($buffBmp, 332, 24, 72, 72)
$pg.Dispose()
$prev.Save((Join-Path $memDir "assets_preview.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$prev.Dispose()
$pingBmp.Dispose(); $peemBmp.Dispose(); $bossBmp.Dispose(); $buffBmp.Dispose()
Write-Output "Converted all 4 new assets successfully!"
