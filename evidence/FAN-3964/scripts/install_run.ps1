param([string]$Label="install1")
$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
$W=$PSScriptRoot
$setup="$W\pkg\FantasyDisk-0.3.1-windows-setup.exe"
$target="$W\install_target\FantasyDisk"
"## $Label start $(T)"
"setup sha256 (immediately before run): $((Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()) bytes=$((Get-Item $setup).Length)"
"command: Start-Process -FilePath `"$setup`" -ArgumentList '/S','/D=$target' -Verb RunAs -Wait -PassThru"
$t0=Get-Date
$p=Start-Process -FilePath $setup -ArgumentList @('/S',"/D=$target") -Verb RunAs -Wait -PassThru
$t1=Get-Date
"installer pid=$($p.Id) exit_code=$($p.ExitCode) started=$($t0.ToUniversalTime().ToString('o')) ended=$($t1.ToUniversalTime().ToString('o')) duration_s=$([math]::Round(($t1-$t0).TotalSeconds,2))"
"### target contents"
Get-ChildItem $target -Recurse -Force -ErrorAction SilentlyContinue | % { "  $($_.FullName.Substring($W.Length)) bytes=$($_.Length) mtime=$($_.LastWriteTimeUtc.ToString('o')) sha256=$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower())" }
$exe="$target\FantasyDisk.exe"
if(Test-Path $exe){ $v=(Get-Item $exe).VersionInfo; "exe version: FileVersion=$($v.FileVersion) ProductVersion=$($v.ProductVersion) ProductName=$($v.ProductName) Company=$($v.CompanyName) Description=$($v.FileDescription)" }
"### registry"
& reg.exe query 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk'
"HKLM 64-bit view key present: $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk')"
"### shortcuts"
$sh=New-Object -ComObject WScript.Shell
$desk=[Environment]::GetFolderPath('Desktop'); $sm="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\FantasyDisk"
foreach($l in @("$sm\FantasyDisk.lnk","$sm\Uninstall.lnk","$desk\FantasyDisk.lnk","$env:ProgramData\Microsoft\Windows\Start Menu\Programs\FantasyDisk\FantasyDisk.lnk","<PublicProfile>\Desktop\FantasyDisk.lnk")){
  if(Test-Path $l){ $s=$sh.CreateShortcut($l); "  $($l.Replace($env:USERPROFILE,'%USERPROFILE%')) -> $($s.TargetPath) bytes=$((Get-Item $l).Length) mtime=$((Get-Item $l).LastWriteTimeUtc.ToString('o'))" } else { "  absent: $($l.Replace($env:USERPROFILE,'%USERPROFILE%'))" } }
"### protected state re-hash"
foreach($f in @("C:\Program Files\FantasyDisk\FantasyDisk.exe","C:\Program Files\FantasyDisk\Uninstall.exe")){ "$((Get-FileHash $f -Algorithm SHA256).Hash.ToLower())  $f" }
"C free=$([System.IO.DriveInfo]::new('C').AvailableFreeSpace)"
"## $Label end $(T)"
