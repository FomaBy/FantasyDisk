$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
$W=$PSScriptRoot; $target="$W\install_target\FantasyDisk"; $PRE="$W\evidence\FAN-3964\preimage"
$desk=[Environment]::GetFolderPath('Desktop'); $sm="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\FantasyDisk"
$key='HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk'
"## uninstall start $(T)"
"processes named FantasyDisk before: $((Get-Process FantasyDisk -ErrorAction SilentlyContinue | Measure-Object).Count)"
"uninstaller sha256: $((Get-FileHash "$target\Uninstall.exe" -Algorithm SHA256).Hash.ToLower())"
"command: Start-Process `"$target\Uninstall.exe`" -ArgumentList '/S','_?=$target' -Verb RunAs -Wait -PassThru"
$t0=Get-Date
$p=Start-Process -FilePath "$target\Uninstall.exe" -ArgumentList @('/S',"_?=$target") -Verb RunAs -Wait -PassThru
$t1=Get-Date
"uninstaller pid=$($p.Id) exit_code=$($p.ExitCode) duration_s=$([math]::Round(($t1-$t0).TotalSeconds,2)) ended=$($t1.ToUniversalTime().ToString('o'))"
"### post-uninstall state"
"target dir exists: $(Test-Path $target)"
if(Test-Path $target){ Get-ChildItem $target -Force | % { "  remaining: $($_.Name) bytes=$($_.Length)" } }
"HKLM WOW6432 key exists: $(Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk")"
foreach($l in @("$sm\FantasyDisk.lnk","$sm\Uninstall.lnk","$desk\FantasyDisk.lnk")){ "  $($l.Replace($env:USERPROFILE,'%USERPROFILE%')) exists: $(Test-Path $l)" }
"start menu folder exists: $(Test-Path $sm)"
"## uninstall end $(T)"
"## rollback start $(T)"
"command: reg.exe import `"$PRE\hklm_wow6432_uninstall_FantasyDisk_before.reg`" (elevated)"
$r=Start-Process -FilePath reg.exe -ArgumentList @('import',"`"$PRE\hklm_wow6432_uninstall_FantasyDisk_before.reg`"") -Verb RunAs -Wait -PassThru
"reg import exit_code=$($r.ExitCode)"
& reg.exe query $key
New-Item -ItemType Directory -Force $sm | Out-Null
Copy-Item "$PRE\lnk\startmenu_FantasyDisk.lnk" "$sm\FantasyDisk.lnk" -Force
Copy-Item "$PRE\lnk\desktop_FantasyDisk.lnk" "$desk\FantasyDisk.lnk" -Force
"restored shortcuts; note: the pre-existing $sm\Uninstall.lnk (629 bytes, 0.3.0 uninstaller target) was deleted by the NSIS uninstaller and had no byte copy in the preimage; recreating it below from the recorded target"
$sh=New-Object -ComObject WScript.Shell
$s=$sh.CreateShortcut("$sm\Uninstall.lnk"); $s.TargetPath='C:\Program Files\FantasyDisk\Uninstall.exe'; $s.Save()
"### rollback verification"
$expect=@{}
Get-Content "$PRE\preimage_capture.txt" | ? { $_ -match '^([0-9a-f]{64})\s+(.+?)\s+bytes=' } | % { $expect[$Matches[2]]=$Matches[1] }
foreach($pair in @(@("$PRE\lnk\startmenu_FantasyDisk.lnk","$sm\FantasyDisk.lnk"),@("$PRE\lnk\desktop_FantasyDisk.lnk","$desk\FantasyDisk.lnk"))){
  $h=(Get-FileHash $pair[1] -Algorithm SHA256).Hash.ToLower(); $e=$expect[$pair[0]]
  "  $($pair[1].Replace($env:USERPROFILE,'%USERPROFILE%')) sha256=$h preimage=$e match=$($h -eq $e)" }
foreach($l in @("$sm\FantasyDisk.lnk","$sm\Uninstall.lnk","$desk\FantasyDisk.lnk")){ $x=$sh.CreateShortcut($l); "  $($l.Replace($env:USERPROFILE,'%USERPROFILE%')) -> $($x.TargetPath)" }
foreach($f in @("C:\Program Files\FantasyDisk\FantasyDisk.exe","C:\Program Files\FantasyDisk\Uninstall.exe")){ $h=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); "  $f sha256=$h match=$($h -eq $expect[$f])" }
$now=(Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk")
"  registry DisplayVersion=$($now.DisplayVersion) InstallLocation=$($now.InstallLocation) UninstallString=$($now.UninstallString)"
"  registry matches preimage: $($now.DisplayVersion -eq '0.3.0' -and $now.InstallLocation -eq 'C:\Program Files\FantasyDisk' -and $now.UninstallString -eq 'C:\Program Files\FantasyDisk\Uninstall.exe')"
"## rollback end $(T)"
