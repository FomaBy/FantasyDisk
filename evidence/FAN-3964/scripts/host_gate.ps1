$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
"## host gate start $(T)"
"### identity"
"whoami: $(whoami)"
$id=[Security.Principal.WindowsIdentity]::GetCurrent(); $p=New-Object Security.Principal.WindowsPrincipal($id)
"is_admin_elevated: $($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
"session_id: $((Get-Process -Id $PID).SessionId) user_interactive: $([Environment]::UserInteractive)"
"uac_enabled(EnableLUA): $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA) ConsentPromptBehaviorAdmin: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').ConsentPromptBehaviorAdmin)"
"admin_group_member(token groups): $(([Security.Principal.WindowsIdentity]::GetCurrent().Groups | % { $_.Value }) -contains 'S-1-5-32-544')"
"os: $([Environment]::OSVersion.VersionString) machine: $env:COMPUTERNAME"
"### disks $(T)"
foreach($d in 'C','D'){ try { $di=[System.IO.DriveInfo]::new($d); "$d`: fmt=$($di.DriveFormat) free=$($di.AvailableFreeSpace) total=$($di.TotalSize) ready=$($di.IsReady)" } catch { "$d`: $_" } }
"workdir: $PWD"
"### godot $(T)"
$g=Get-Item '%USERPROFILE%\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' -ErrorAction SilentlyContinue
if($g){ "godot: $($g.FullName) bytes=$($g.Length) product=$($g.VersionInfo.ProductVersion) file=$($g.VersionInfo.FileVersion)" } else { "godot: not found at preflight path" }
Get-Command godot* -ErrorAction SilentlyContinue | % { "godot on PATH: $($_.Source)" }
"### processes $(T)"
$procs=Get-Process | Sort-Object ProcessName
"process_count: $($procs.Count)"
$interest=$procs | ? { $_.ProcessName -match 'godot|fantasy|msiexec|makensis|setup|git|7z|nsis|uninst|steam|multica|claude|codex' }
$interest | % { "  pid=$($_.Id) name=$($_.ProcessName) path=$(try{$_.Path}catch{'?'})" }
"### existing install $(T)"
$inst='C:\Program Files\FantasyDisk'
if(Test-Path $inst){ Get-ChildItem $inst -Recurse -Force | % { "  $($_.FullName) bytes=$($_.Length) mtime=$($_.LastWriteTimeUtc.ToString('o'))" } } else { "no existing $inst" }
"### godot user data $(T)"
foreach($base in @($env:APPDATA, $env:LOCALAPPDATA)){ Get-ChildItem $base -Directory -Force -ErrorAction SilentlyContinue | ? { $_.Name -match 'fantasy|godot' } | % { "  $($_.FullName)"; Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | ? { -not $_.PSIsContainer } | % { "     $($_.FullName) bytes=$($_.Length) mtime=$($_.LastWriteTimeUtc.ToString('o'))" } } }
"### registry $(T)"
foreach($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'){ Get-ChildItem $k -ErrorAction SilentlyContinue | ? { $_.PSChildName -match 'fantasy' -or ($_.GetValue('DisplayName') -match 'fantasy') } | % { "  $($_.Name)"; $_.GetValueNames() | % { "     $_ = $($_ | % { $null }) " } ; $_.Property | % { "     $_=$($_ )" } } }
foreach($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk','HKLM:\SOFTWARE\FantasyDisk','HKCU:\SOFTWARE\FantasyDisk'){ if(Test-Path $k){ "  present: $k"; (Get-ItemProperty $k | Out-String) } else { "  absent: $k" } }
"### shortcuts $(T)"
foreach($d in @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs","$env:APPDATA\Microsoft\Windows\Start Menu\Programs",[Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('CommonDesktopDirectory'))){ Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | ? { $_.Name -match 'fantasy' } | % { "  $($_.FullName) bytes=$($_.Length)" } }
"### handle tools $(T)"
foreach($h in 'handle.exe','handle64.exe','openfiles.exe','signtool.exe'){ $c=Get-Command $h -ErrorAction SilentlyContinue; if($c){"  $h => $($c.Source)"} else {"  $h => absent on PATH"} }
"### exclusive-open lock probe on existing install $(T)"
if(Test-Path $inst){ Get-ChildItem $inst -Recurse -Force | ? { -not $_.PSIsContainer } | % { try { $fs=[System.IO.File]::Open($_.FullName,'Open','Read','None'); $fs.Close(); "  free: $($_.FullName)" } catch { "  LOCKED/denied: $($_.FullName) :: $($_.Exception.Message)" } } }
"## host gate end $(T)"
