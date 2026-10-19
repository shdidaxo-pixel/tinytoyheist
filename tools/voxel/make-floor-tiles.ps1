# Generates the voxel floor tiles for the Kid's Bedroom as OBJ meshes that share one palette texture.
#   assets/floor-tiles/carpet.obj, wood.obj, creaky.obj, floor-tiles.mtl, floor-palette.png
# Each tile is 24 x 24 studs, built from 0.5-stud voxels (48 x 48 columns). Its bottom is at y = -1 and the walkable
# top at y = 0; carpet tufts and lifted boards stick up above that. Faces are greedy-meshed and each colour samples
# the middle of its own 16 x 16 block in the palette, so mipmaps don't bleed colours into each other.
# Run: powershell -ExecutionPolicy Bypass -File tools/voxel/make-floor-tiles.ps1
param([string]$OutDir = (Join-Path $PSScriptRoot "..\..\assets\floor-tiles"))
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$N = 48          # voxels across a tile
$Layers = 4      # layers: 0 = -1..-0.5, 1 = -0.5..0 (walk surface), 2 = 0..0.5, 3 = 0.5..1
$V = 0.5         # voxel size in studs
$Y0 = -1.0       # bottom of the tile

# Palette: name -> hex. Order is the texture order.
$PaletteHex = [ordered]@{
    carpetBase = "5A4C8E"; carpet1 = "6A5BA0"; carpet2 = "7465AA"; carpet3 = "5F5096"; tuft = "8A7AC2"; tuftTip = "A091D6"
    woodGroove = "4A3422"; wood1 = "8A6A48"; wood2 = "9A7853"; wood3 = "7C5E3F"; grain = "6E5236"
    creakGroove = "2E2016"; creak1 = "6B4F35"; creak2 = "5E442D"; creak3 = "755839"; creakGrain = "4E3826"; crack = "24180F"; nail = "B8BFC8"
}
$Names = @($PaletteHex.Keys)
$Index = @{}; for ($i = 0; $i -lt $Names.Count; $i++) { $Index[$Names[$i]] = $i + 1 }

# Seeded random numbers so every run makes the same tiles.
$script:seed = 1
function Rand { $script:seed = ($script:seed * 1103515245 + 12345) % 2147483648; return $script:seed / 2147483648 }
function RandInt([int]$lo, [int]$hi) { return $lo + [int][math]::Floor((Rand) * ($hi - $lo + 1)) }

function New-Grid { return ,(New-Object 'int[,,]' $N, $Layers, $N) }   # [x, layer, z], 0 = empty
function Fill($g, $x0, $x1, $l0, $l1, $z0, $z1, $c) {
    for ($x = [math]::Max(0, $x0); $x -le [math]::Min($N - 1, $x1); $x++) {
        for ($l = $l0; $l -le $l1; $l++) { for ($z = [math]::Max(0, $z0); $z -le [math]::Min($N - 1, $z1); $z++) { $g[$x, $l, $z] = $c } }
    }
}

# ---------------------------------------------------------------- tiles
function Make-Carpet {
    $script:seed = 11
    $g = New-Grid
    Fill $g 0 ($N - 1) 0 0 0 ($N - 1) $Index.carpetBase
    # walk surface in 4 x 4 patches of three shades
    for ($px = 0; $px -lt $N; $px += 4) { for ($pz = 0; $pz -lt $N; $pz += 4) {
        $c = @($Index.carpet1, $Index.carpet1, $Index.carpet2, $Index.carpet3)[(RandInt 0 3)]
        Fill $g $px ($px + 3) 1 1 $pz ($pz + 3) $c } }
    # tufts: little 2 x 2 loops, some with a 1-voxel tip
    for ($k = 0; $k -lt 150; $k++) {
        $x = RandInt 0 ($N - 2); $z = RandInt 0 ($N - 2)
        Fill $g $x ($x + 1) 2 2 $z ($z + 1) $Index.tuft
        if ((Rand) -lt 0.35) { $g[$x, 3, $z] = $Index.tuftTip }
    }
    return ,$g
}

function Make-Boards($kind) {
    # Boards run along x. Wood: 3-stud planks; creaky: 4-stud boards, darker, warped and nailed.
    $creaky = $kind -eq "creaky"
    $script:seed = if ($creaky) { 31 } else { 21 }
    $width = if ($creaky) { 8 } else { 6 }
    $groove = if ($creaky) { $Index.creakGroove } else { $Index.woodGroove }
    $tones = if ($creaky) { @($Index.creak1, $Index.creak2, $Index.creak3) } else { @($Index.wood1, $Index.wood2, $Index.wood3) }
    $grain = if ($creaky) { $Index.creakGrain } else { $Index.grain }
    $g = New-Grid
    Fill $g 0 ($N - 1) 0 0 0 ($N - 1) $groove
    for ($z0 = 0; $z0 -lt $N; $z0 += $width) {
        # one end joint per board row, somewhere in the middle
        $joint = RandInt 10 ($N - 11)
        $segments = @(@(0, ($joint - 1)), @(($joint + 1), ($N - 1)))
        foreach ($s in $segments) {
            $c = $tones[(RandInt 0 2)]
            Fill $g $s[0] $s[1] 1 1 ($z0 + 1) ($z0 + $width - 1) $c       # groove row at z0 stays low
            for ($k = 0; $k -lt 3; $k++) {                                 # grain streaks
                $gx = RandInt $s[0] ([math]::Max($s[0], $s[1] - 8)); $gz = RandInt ($z0 + 2) ($z0 + $width - 2)
                Fill $g $gx ([math]::Min($s[1], $gx + (RandInt 3 8))) 1 1 $gz $gz $grain
            }
            if ($creaky) {
                foreach ($nx in @(($s[0] + 1), ($s[1] - 1))) {             # nail heads near both ends
                    $g[$nx, 2, ($z0 + 2)] = $Index.nail; $g[$nx, 2, ($z0 + $width - 2)] = $Index.nail
                }
                if ((Rand) -lt 0.3) {                                      # a warped end that sticks up
                    $wx = if ((Rand) -lt 0.5) { $s[0] } else { [math]::Max($s[0], $s[1] - 7) }
                    Fill $g $wx ([math]::Min($s[1], $wx + 7)) 2 2 ($z0 + 1) ($z0 + $width - 1) $c
                }
                if ((Rand) -lt 0.35) {                                     # a crack
                    $cx = RandInt $s[0] ([math]::Max($s[0], $s[1] - 10)); $cz = RandInt ($z0 + 2) ($z0 + $width - 2)
                    for ($x = $cx; $x -le [math]::Min($s[1], $cx + (RandInt 5 10)); $x++) { $g[$x, 1, $cz] = 0 }
                }
            }
        }
    }
    return ,$g
}

# ---------------------------------------------------------------- greedy mesher
# Visible faces only. The tile's outer sides are skipped for layers 0-1 (neighbouring tiles hide them); bottoms
# are always skipped. Returns quads as @{ c; p = 4 corner points [x,y,z] in voxel units; n = normal }.
function Get-Quads($g) {
    $quads = New-Object System.Collections.Generic.List[object]
    function At($x, $l, $z) { if ($x -lt 0 -or $x -ge $N -or $z -lt 0 -or $z -ge $N -or $l -lt 0 -or $l -ge $Layers) { return 0 }; return $g[$x, $l, $z] }
    # direction: axis (0 = x, 1 = layer, 2 = z) and sign
    foreach ($d in @(@(1, 1), @(0, 1), @(0, -1), @(2, 1), @(2, -1))) {
        $axis = $d[0]; $sign = $d[1]
        $dims = @($N, $Layers, $N)
        $u = ($axis + 1) % 3; $w = ($axis + 2) % 3
        for ($s = 0; $s -lt $dims[$axis]; $s++) {
            $mask = New-Object 'int[,]' $dims[$u], $dims[$w]
            for ($a = 0; $a -lt $dims[$u]; $a++) { for ($b = 0; $b -lt $dims[$w]; $b++) {
                $p = @(0, 0, 0); $p[$axis] = $s; $p[$u] = $a; $p[$w] = $b
                $c = At $p[0] $p[1] $p[2]
                if ($c -eq 0) { continue }
                $q = @($p[0], $p[1], $p[2]); $q[$axis] += $sign
                $outside = $q[0] -lt 0 -or $q[0] -ge $N -or $q[2] -lt 0 -or $q[2] -ge $N
                if ($outside -and $p[1] -le 1) { continue }
                if ((At $q[0] $q[1] $q[2]) -ne 0) { continue }
                $mask[$a, $b] = $c
            } }
            for ($a = 0; $a -lt $dims[$u]; $a++) { for ($b = 0; $b -lt $dims[$w]; $b++) {
                $c = $mask[$a, $b]; if ($c -eq 0) { continue }
                $wb = 1; while ($b + $wb -lt $dims[$w] -and $mask[$a, ($b + $wb)] -eq $c) { $wb++ }
                $ha = 1; $grow = $true
                while ($grow -and $a + $ha -lt $dims[$u]) {
                    for ($k = 0; $k -lt $wb; $k++) { if ($mask[($a + $ha), ($b + $k)] -ne $c) { $grow = $false; break } }
                    if ($grow) { $ha++ }
                }
                for ($i = 0; $i -lt $ha; $i++) { for ($k = 0; $k -lt $wb; $k++) { $mask[($a + $i), ($b + $k)] = 0 } }
                $plane = if ($sign -gt 0) { $s + 1 } else { $s }
                $corner = { param($da, $db) $pt = @(0, 0, 0); $pt[$axis] = $plane; $pt[$u] = $a + $da; $pt[$w] = $b + $db; return , $pt }
                $c00 = & $corner 0 0; $c10 = & $corner $ha 0; $c11 = & $corner $ha $wb; $c01 = & $corner 0 $wb
                # winding so the face points along +sign of the axis
                $pts = if ($sign -gt 0) { @($c00, $c10, $c11, $c01) } else { @($c00, $c01, $c11, $c10) }
                $quads.Add(@{ c = $c; p = $pts })
            } }
        }
    }
    return $quads
}

# ---------------------------------------------------------------- writers
$PaletteBlock = 16
function Write-Obj($name, $g) {
    $quads = Get-Quads $g
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Tiny Toy Heist voxel floor tile: $name. 24 x 24 studs, bottom y = -1, walk surface y = 0.")
    [void]$sb.AppendLine("mtllib floor-tiles.mtl")
    [void]$sb.AppendLine("o ${name}Tile")
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $uu = (($i + 0.5) / $Names.Count); [void]$sb.AppendLine(("vt {0} 0.5" -f $uu.ToString("0.######", $inv)))
    }
    [void]$sb.AppendLine("usemtl Palette")
    $vi = 0
    foreach ($q in $quads) {
        foreach ($pt in $q.p) {
            # voxel coords -> studs, centred on the tile; OBJ uses x right, y up, z toward the viewer
            $x = $pt[0] * $V - 12; $y = $pt[1] * $V + $Y0; $z = $pt[2] * $V - 12
            [void]$sb.AppendLine(("v {0} {1} {2}" -f $x.ToString("0.###", $inv), $y.ToString("0.###", $inv), $z.ToString("0.###", $inv)))
        }
        $t = $q.c
        # Two triangles. The mesher's winding is for a right-handed frame (counter-clockwise from outside).
        [void]$sb.AppendLine(("f {0}/{4} {1}/{4} {2}/{4}" -f ($vi + 1), ($vi + 2), ($vi + 3), 0, $t))
        [void]$sb.AppendLine(("f {0}/{3} {1}/{3} {2}/{3}" -f ($vi + 1), ($vi + 3), ($vi + 4), $t))
        $vi += 4
    }
    $path = Join-Path $OutDir "$name.obj"
    [System.IO.File]::WriteAllText($path, $sb.ToString())
    Write-Output ("{0}: {1} quads, {2} triangles" -f $name, $quads.Count, ($quads.Count * 2))
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($Names.Count * $PaletteBlock), $PaletteBlock
for ($i = 0; $i -lt $Names.Count; $i++) {
    $hex = $PaletteHex[$Names[$i]]
    $col = [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16))
    for ($x = 0; $x -lt $PaletteBlock; $x++) { for ($y = 0; $y -lt $PaletteBlock; $y++) { $bmp.SetPixel($i * $PaletteBlock + $x, $y, $col) } }
}
$bmp.Save((Join-Path $OutDir "floor-palette.png"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
[System.IO.File]::WriteAllText((Join-Path $OutDir "floor-tiles.mtl"), "newmtl Palette`nKd 1 1 1`nmap_Kd floor-palette.png`n")

Write-Obj "carpet" (Make-Carpet)
Write-Obj "wood" (Make-Boards "wood")
Write-Obj "creaky" (Make-Boards "creaky")
