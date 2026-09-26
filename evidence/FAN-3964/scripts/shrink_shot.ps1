param([string]$In,[string]$Out,[int]$CropBottom=70,[int]$Scale=2)
Add-Type -AssemblyName System.Drawing
$src=[System.Drawing.Image]::FromFile($In)
$h=$src.Height-$CropBottom; $w=$src.Width
$dst=New-Object System.Drawing.Bitmap([int]($w/$Scale),[int]($h/$Scale)); $g=[System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($src,(New-Object System.Drawing.Rectangle(0,0,$dst.Width,$dst.Height)),(New-Object System.Drawing.Rectangle(0,0,$w,$h)),[System.Drawing.GraphicsUnit]::Pixel)
$dst.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $dst.Dispose(); $src.Dispose()
"$Out $($dst.Width)x$($dst.Height) bytes=$((Get-Item $Out).Length)"
