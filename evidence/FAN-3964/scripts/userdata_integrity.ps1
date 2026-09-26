param([string]$Label="check")
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
$W=$PSScriptRoot; $real="$env:APPDATA\Godot\app_userdata\FantasyDisk"; $copy="$W\evidence\FAN-3964\preimage\userdata_copy"
"## real userdata integrity vs preimage copy ($Label) $(T)"
$cf=Get-ChildItem $copy -Recurse -File; $rf=Get-ChildItem $real -Recurse -File
$copyMap=@{}; foreach($f in $cf){ $copyMap[$f.FullName.Substring($copy.Length)]=$f }
$diff=0; $missing=0; $new=0
foreach($f in $rf){ $rel=$f.FullName.Substring($real.Length); if(-not $copyMap.ContainsKey($rel)){ $new++; "  NEW in real: $rel" ; continue }
  $c=$copyMap[$rel]; if($c.Length -ne $f.Length -or (Get-FileHash $c.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $f.FullName -Algorithm SHA256).Hash){ $diff++; "  DIFFERENT: $rel" } }
foreach($k in $copyMap.Keys){ if(-not (Test-Path (Join-Path $real $k))){ $missing++; "  MISSING in real: $k" } }
"real_files=$($rf.Count) copy_files=$($cf.Count) different=$diff new=$new missing=$missing"
"newest mtime in real: $(($rf | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc.ToString('o'))"
"result: $(if($diff -eq 0 -and $new -eq 0 -and $missing -eq 0){'IDENTICAL'}else{'CHANGED'})"
