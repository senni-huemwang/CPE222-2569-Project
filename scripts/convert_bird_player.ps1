Add-Type -AssemblyName System.Drawing

$projDir = "C:\Users\User\Documents\KMUTT_UNI\Y2\Digital\Digital_final proj"
$imgPath = Join-Path $projDir "image\BirdPlayer.png"
$memDir  = Join-Path $projDir "mem"

$src = [System.Drawing.Bitmap]::new($imgPath)
$SIZE = 64

function Build-BirdFrame([double]$angleDeg) {
    $bmp = [System.Drawing.Bitmap]::new($SIZE, $SIZE)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.TranslateTransform($SIZE / 2.0, $SIZE / 2.0)
    $g.RotateTransform([float]$angleDeg)
    $g.TranslateTransform(-$SIZE / 2.0, -$SIZE / 2.0)
    $g.DrawImage($src, 2, 2, $SIZE - 4, $SIZE - 4)
    $g.Dispose()

    $lines = New-Object System.Collections.Generic.List[string]
    for ($y = 0; $y -lt $SIZE; $y++) {
        $row = New-Object System.Collections.Generic.List[string]
        for ($x = 0; $x -lt $SIZE; $x++) {
            $c = $bmp.GetPixel($x, $y)
            # Remove transparent or pure white background
            if ($c.A -lt 128 -or ($c.R -gt 238 -and $c.G -gt 238 -and $c.B -gt 238)) {
                $row.Add("F0F")
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 20, 20, 40))
            } else {
                $r4 = $c.R -shr 4
                $g4 = $c.G -shr 4
                $b4 = $c.B -shr 4
                if ($r4 -eq 15 -and $g4 -eq 0 -and $b4 -eq 15) { $g4 = 1 }
                $row.Add(("{0:X}{1:X}{2:X}" -f $r4, $g4, $b4))
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $r4 * 17, $g4 * 17, $b4 * 17))
            }
        }
        $lines.Add(($row -join " "))
    }
    return @{ Bmp = $bmp; Lines = $lines }
}

$down = Build-BirdFrame -angleDeg 8.0
$up   = Build-BirdFrame -angleDeg -10.0

[System.IO.File]::WriteAllLines((Join-Path $memDir "pigeon_down.mem"), $down.Lines)
[System.IO.File]::WriteAllLines((Join-Path $memDir "pigeon_up.mem"),   $up.Lines)

$prev = [System.Drawing.Bitmap]::new(280, 140)
$pg = [System.Drawing.Graphics]::FromImage($prev)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$pg.Clear([System.Drawing.Color]::FromArgb(255, 15, 15, 30))
$pg.DrawImage($down.Bmp, 6,   6, 128, 128)
$pg.DrawImage($up.Bmp,   146, 6, 128, 128)
$pg.Dispose()
$prev.Save((Join-Path $memDir "bird_player_preview.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$prev.Dispose(); $down.Bmp.Dispose(); $up.Bmp.Dispose(); $src.Dispose()
Write-Output "Converted BirdPlayer.png to 64x64 pigeon_down.mem & pigeon_up.mem!"
