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

# 1. HomePage.png -> 160x120 RGB444 (scaled 4x to 640x480 on VGA)
$homeSrc = [System.Drawing.Bitmap]::new((Join-Path $imgDir "HomePage.png"))
$homeSmall = [System.Drawing.Bitmap]::new(160, 120)
$hg = [System.Drawing.Graphics]::FromImage($homeSmall)
$hg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$hg.DrawImage($homeSrc, 0, 0, 160, 120)
$hg.Dispose()
$homeSrc.Dispose()

$homeLines = New-Object System.Collections.Generic.List[string]
for ($y = 0; $y -lt 120; $y++) {
    $row = New-Object System.Collections.Generic.List[string]
    for ($x = 0; $x -lt 160; $x++) {
        $c = $homeSmall.GetPixel($x, $y)
        $hex, $rr, $gg, $bb = To-Hex444 $c.R $c.G $c.B
        $row.Add($hex)
        $homeSmall.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $rr, $gg, $bb))
    }
    $homeLines.Add(($row -join " "))
}
[System.IO.File]::WriteAllLines((Join-Path $memDir "home_bg.mem"), $homeLines)

# 2. Boss_TA2.jpg (already die-cut on white) -> paste onto Chibi Student body (48x48)
$bossSrc = [System.Drawing.Bitmap]::new((Join-Path $imgDir "Boss_TA2.jpg"))
$headSmall = [System.Drawing.Bitmap]::new(36, 32)
$bg = [System.Drawing.Graphics]::FromImage($headSmall)
$bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$bg.DrawImage($bossSrc, 0, 0, 36, 32)
$bg.Dispose()
$bossSrc.Dispose()

$bossBmp = [System.Drawing.Bitmap]::new(48, 48)
$bossLines = New-Object System.Collections.Generic.List[string]
for ($y = 0; $y -lt 48; $y++) {
    $row = New-Object System.Collections.Generic.List[string]
    for ($x = 0; $x -lt 48; $x++) {
        $hex = "F0F"
        if ($y -lt 32) {
            if ($x -ge 6 -and $x -lt 42) {
                $c = $headSmall.GetPixel($x - 6, $y)
                # Remove pure white background around die-cut head
                if (-not ($c.R -gt 238 -and $c.G -gt 238 -and $c.B -gt 238)) {
                    $hex, $rr, $gg, $bb = To-Hex444 $c.R $c.G $c.B
                }
            }
        } else {
            # Small Chibi University Student Uniform (Rows 32..47, X=14..33)
            if ($y -lt 40) {
                if ($x -ge 14 -and $x -le 33) {
                    if ($x -eq 14 -or $x -eq 33) { $hex = "111" }
                    elseif ($y -eq 39)           { $hex = "222" }
                    elseif ($x -ge 22 -and $x -le 25) { $hex = "111" }
                    elseif ($x -le 16 -or $x -ge 31)  { $hex = "EC9" }
                    else                         { $hex = "FFF" }
                }
            } elseif ($y -lt 45) {
                if ($x -ge 16 -and $x -le 31) {
                    if ($x -ge 23 -and $x -le 24) { $hex = "F0F" }
                    elseif ($x -eq 16 -or $x -eq 31 -or $x -eq 22 -or $x -eq 25) { $hex = "111" }
                    else { $hex = "223" }
                }
            } elseif ($y -lt 47) {
                if (($x -ge 15 -and $x -le 21) -or ($x -ge 26 -and $x -le 32)) { $hex = "111" }
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
    $bossLines.Add(($row -join " "))
}
[System.IO.File]::WriteAllLines((Join-Path $memDir "boss_chibi.mem"), $bossLines)

# Save preview
$prev = [System.Drawing.Bitmap]::new(280, 130)
$pg = [System.Drawing.Graphics]::FromImage($prev)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$pg.Clear([System.Drawing.Color]::FromArgb(255, 20, 20, 30))
$pg.DrawImage($homeSmall, 5, 5, 160, 120)
$pg.DrawImage($bossBmp, 175, 17, 96, 96)
$pg.Dispose()
$prev.Save((Join-Path $memDir "v3_preview.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$prev.Dispose()
$homeSmall.Dispose(); $headSmall.Dispose(); $bossBmp.Dispose()
Write-Output "Converted HomePage.png & Boss_TA2.jpg successfully!"
