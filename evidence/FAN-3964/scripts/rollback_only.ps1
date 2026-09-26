$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
$W=$PSScriptRoot; $PRE="$W\evidence\FAN-3964\preimage"
$desk=[Environment]::GetFolderPath('Desktop'); $sm="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\FantasyDisk"
$key='HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk'
"## rollback (rerun after variable-collision bug in first attempt) start $(T)"
"state before: key exists=$(Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk') sm FantasyDisk.lnk=$(Test-Path "$sm\FantasyDisk.lnk") sm Uninstall.lnk=$(Test-Path "$sm\Uninstall.lnk") desktop lnk=$(Test-Path "$desk\FantasyDisk.lnk")"
"command: reg.exe import <preimage .reg> (elevated)"
$r=Start-Process -FilePath reg.exe -ArgumentList @('import',"`"$PRE\hklm_wow6432_uninstall_FantasyDisk_before.reg`"") -Verb RunAs -Wait -PassThru
"reg import exit_code=$($r.ExitCode)"
& reg.exe query $key
New-Item -ItemType Directory -Force $sm | Out-Null
Copy-Item "$PRE\lnk\startmenu_FantasyDisk.lnk" "$sm\FantasyDisk.lnk" -Force
Copy-Item "$PRE\lnk\desktop_FantasyDisk.lnk" "$desk\FantasyDisk.lnk" -Force
"note: the pre-existing Start Menu Uninstall.lnk (629 bytes, target C:\Program Files\FantasyDisk\Uninstall.exe) had no byte copy in the preimage; it was recreated with the same target in the first attempt"
"### rollback verification"
$expect=@{}
Get-Content "$PRE\preimage_capture.txt" | ? { $_ -match '^([0-9a-f]{64})\s+(.+?)\s+bytes=' } | % { $expect[$Matches[2]]=$Matches[1] }
"expected hashes loaded: $($expect.Count)"
$sh=New-Object -ComObject WScript.Shell
foreach($pair in @(@("$PRE\lnk\startmenu_FantasyDisk.lnk","$sm\FantasyDisk.lnk"),@("$PRE\lnk\desktop_FantasyDisk.lnk","$desk\FantasyDisk.lnk"))){
  $h=(Get-FileHash $pair[1] -Algorithm SHA256).Hash.ToLower(); $e=$expect[$pair[0]]
  "  $($pair[1].Replace($env:USERPROFILE,'%USERPROFILE%')) sha256=$h preimage=$e match=$($h -eq $e)" }
foreach($l in @("$sm\FantasyDisk.lnk","$sm\Uninstall.lnk","$desk\FantasyDisk.lnk")){ $x=$sh.CreateShortcut($l); "  $($l.Replace($env:USERPROFILE,'%USERPROFILE%')) -> $($x.TargetPath) bytes=$((Get-Item $l).Length)" }
foreach($f in @("C:\Program Files\FantasyDisk\FantasyDisk.exe","C:\Program Files\FantasyDisk\Uninstall.exe")){ $h=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); "  $f sha256=$h match=$($h -eq $expect[$f])" }
$now=(Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk")
"  registry DisplayVersion=$($now.DisplayVersion) InstallLocation=$($now.InstallLocation) UninstallString=$($now.UninstallString)"
"  registry matches preimage: $($now.DisplayVersion -eq '0.3.0' -and $now.InstallLocation -eq 'C:\Program Files\FantasyDisk' -and $now.UninstallString -eq 'C:\Program Files\FantasyDisk\Uninstall.exe' -and $now.DisplayName -eq 'FantasyDisk' -and $now.Publisher -eq 'FantasyDisk')"
"  HKLM 64-bit view key present (must stay absent as before): $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk')"
"## rollback end $(T)"
