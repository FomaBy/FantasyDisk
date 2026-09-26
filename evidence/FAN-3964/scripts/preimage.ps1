$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
$P="$PSScriptRoot\evidence\FAN-3964\preimage"
New-Item -ItemType Directory -Force "$P\lnk","$P\userdata_copy" | Out-Null
"## preimage capture start $(T)"
& reg.exe export 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk' "$P\hklm_wow6432_uninstall_FantasyDisk_before.reg" /y | Out-Null
"reg export exit=$LASTEXITCODE"
& reg.exe query 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk'
"HKLM 64-bit view key present: $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk')"
$desk=[Environment]::GetFolderPath('Desktop')
$sm="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\FantasyDisk"
"desktop folder is OneDrive-redirected: $($desk -like '*OneDrive*')"
Copy-Item "$sm\FantasyDisk.lnk" "$P\lnk\startmenu_FantasyDisk.lnk" -Force
Copy-Item "$desk\FantasyDisk.lnk" "$P\lnk\desktop_FantasyDisk.lnk" -Force
"startmenu Uninstall.lnk present: $(Test-Path "$sm\Uninstall.lnk")"
Get-ChildItem $sm | % { "  SM: $($_.Name) bytes=$($_.Length)" }
$ud="$env:APPDATA\Godot\app_userdata\FantasyDisk"
Copy-Item "$ud\*" "$P\userdata_copy\" -Recurse -Force
"userdata files copied: $((Get-ChildItem "$P\userdata_copy" -Recurse -File).Count) of $((Get-ChildItem $ud -Recurse -File).Count)"
"### hashes"
foreach($f in @("$P\lnk\startmenu_FantasyDisk.lnk","$P\lnk\desktop_FantasyDisk.lnk","C:\Program Files\FantasyDisk\FantasyDisk.exe","C:\Program Files\FantasyDisk\Uninstall.exe")){ $h=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); "$h  $f  bytes=$((Get-Item $f).Length)" }
"exe version: $((Get-Item 'C:\Program Files\FantasyDisk\FantasyDisk.exe').VersionInfo | Select-Object FileVersion,ProductVersion,ProductName,CompanyName | Out-String)"
"## preimage capture end $(T)"
