param([string]$Label="launchA",[string]$ExeDir="install_target\FantasyDisk",[string]$UserDirName="FantasyDisk-FAN3964-test",[string[]]$ExtraArgs=@(),[int]$DurationSec=60,[int]$IdleAfterRespondingSec=0,[string]$ShotsAt="10,30,55",[string]$KeySequence="",[switch]$NoClose)
$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
$W=$PSScriptRoot; $exe="$W\$ExeDir\FantasyDisk.exe"; $ev="$W\evidence\FAN-3964\launch"
$ud="$env:APPDATA\$UserDirName"; $realud="$env:APPDATA\Godot\app_userdata\FantasyDisk"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W32 { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h); [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; } }
"@
function Shot($proc,$name){
  $h=$proc.MainWindowHandle; if($h -eq 0){ $proc.Refresh(); $h=$proc.MainWindowHandle }
  $r=New-Object W32+RECT; $ok=[W32]::GetWindowRect($h,[ref]$r)
  if(-not $ok -or ($r.R-$r.L) -le 0){ "  screenshot ${name}: no window rect (hwnd=$h)"; return }
  $b=New-Object System.Drawing.Bitmap(($r.R-$r.L),($r.B-$r.T)); $g=[System.Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.L,$r.T,0,0,$b.Size); $p="$ev\$name"; $b.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose()
  "  screenshot $name rect=($($r.L),$($r.T))-($($r.R),$($r.B)) title='$($proc.MainWindowTitle)' visible=$([W32]::IsWindowVisible($h)) foreground=$([W32]::GetForegroundWindow() -eq $h) $(T)"
}
"## $Label start $(T)"
"exe sha256: $((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower())"
"exe: $ExeDir  override.cfg next to exe: $(Test-Path "$W\$ExeDir\override.cfg")  user dir: $ud"
"test userdata before: exists=$(Test-Path $ud) files=$(if(Test-Path $ud){(Get-ChildItem $ud -Recurse -File).Count}else{0})"
"args: $($ExtraArgs -join ' ')"
$out="$ev\$Label.stdout.txt"; $err="$ev\$Label.stderr.txt"
$t0=Get-Date
if($ExtraArgs.Count -gt 0){ $p=Start-Process -FilePath $exe -ArgumentList $ExtraArgs -WorkingDirectory "$W\$ExeDir" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru }
else { $p=Start-Process -FilePath $exe -WorkingDirectory "$W\$ExeDir" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru }
"pid=$($p.Id) started=$($t0.ToUniversalTime().ToString('o'))"
$peakWS=0; $elapsed=0; $keysDone=$false; $firstResp=-1; $firstOut=-1; $hdr=179; $shots=@($ShotsAt -split "," | % { [int]$_ })
while($elapsed -lt $DurationSec){
  Start-Sleep -Seconds 1; $elapsed++
  if($p.HasExited){ "process exited early at ${elapsed}s exit_code=$($p.ExitCode)"; break }
  $p.Refresh(); if($p.WorkingSet64 -gt $peakWS){ $peakWS=$p.WorkingSet64 }
  if($firstOut -lt 0 -and (Test-Path $out) -and (Get-Item $out).Length -gt $hdr){ $firstOut=$elapsed; "  first stdout growth beyond engine header at t=${elapsed}s $(T)" }
  if($firstResp -lt 0 -and $p.MainWindowHandle -ne 0 -and $p.Responding){ $firstResp=$elapsed; "  first responding main window at t=${elapsed}s cpu_s=$([math]::Round($p.TotalProcessorTime.TotalSeconds,1)) $(T)"; if($IdleAfterRespondingSec -gt 0){ $DurationSec=[math]::Min($DurationSec,$elapsed+$IdleAfterRespondingSec) } }
  if($elapsed % 10 -eq 0 -or $elapsed -eq 5){ "  t=${elapsed}s hwnd=$($p.MainWindowHandle) title='$($p.MainWindowTitle)' responding=$($p.Responding) cpu_s=$([math]::Round($p.TotalProcessorTime.TotalSeconds,1)) ws_MiB=$([math]::Round($p.WorkingSet64/1MB,1)) private_MiB=$([math]::Round($p.PrivateMemorySize64/1MB,1)) threads=$($p.Threads.Count) $(T)" }
  if($shots -contains $elapsed){ Shot $p "$Label`_$($elapsed)s.png" }
  if($KeySequence -ne "" -and -not $keysDone -and $firstResp -ge 0 -and $elapsed -ge ($firstResp+5)){
    $keysDone=$true; $wsh=New-Object -ComObject WScript.Shell; $act=$wsh.AppActivate($p.Id); "  keyboard smoke: AppActivate(pid)=$act $(T)"; Start-Sleep -Milliseconds 800
    $i=0; foreach($step in ($KeySequence -split ",")){ $i++; $parts=$step -split ":"; $k=$parts[0]; $wait=[int]$parts[1]
      $wsh.SendKeys("{$k}"); "  sent {$k} at $(T), waiting ${wait}s"; Start-Sleep -Seconds $wait; Shot $p "$Label`_key${i}_$k.png" }
  }
}
if(-not $p.HasExited){
  $p.Refresh(); "at ${elapsed}s: ws_MiB=$([math]::Round($p.WorkingSet64/1MB,1)) private_MiB=$([math]::Round($p.PrivateMemorySize64/1MB,1)) peak_ws_MiB=$([math]::Round($peakWS/1MB,1)) threads=$($p.Threads.Count) responding=$($p.Responding)"
  if(-not $NoClose){
    "closing main window (WM_CLOSE) $(T)"; $null=$p.CloseMainWindow()
    if(-not $p.WaitForExit(20000)){ "did not exit within 20s after WM_CLOSE; taking screenshot then Stop-Process -Id $($p.Id) (own child)"; Shot $p "$Label`_after_close.png"; Stop-Process -Id $p.Id -Force; $p.WaitForExit(10000) | Out-Null; "stopped $(T)" }
  }
}
$t1=Get-Date
"first_responding_s=$firstResp first_stdout_growth_s=$firstOut"
"exit_code=$($p.ExitCode) ended=$($t1.ToUniversalTime().ToString('o')) wall_s=$([math]::Round(($t1-$t0).TotalSeconds,2))"
"### stdout ($((Get-Item $out).Length) bytes) first 6 lines"; Get-Content $out -TotalCount 6
$fps=Get-Content $out | ? { $_ -match "Project FPS: (\d+)" } | % { [int]$Matches[1] }
if($fps.Count -gt 0){ $sorted=$fps | Sort-Object; $n1=[math]::Max(1,[math]::Floor($sorted.Count*0.01)); "fps_lines=$($fps.Count) avg=$([math]::Round(($fps | Measure-Object -Average).Average,1)) min=$($sorted[0]) max=$($sorted[-1]) low1pct=$($sorted[$n1-1]) median=$($sorted[[math]::Floor($sorted.Count/2)])" }
"### stderr ($((Get-Item $err).Length) bytes) first 40 lines"; Get-Content $err -TotalCount 40
"### test userdata after"
if(Test-Path $ud){ Get-ChildItem $ud -Recurse -File | % { "  $($_.FullName.Substring($ud.Length)) bytes=$($_.Length) mtime=$($_.LastWriteTimeUtc.ToString('o'))" } } else { "  test userdata dir NOT created" }
if(Test-Path "$ud\logs\godot.log"){ Copy-Item "$ud\logs\godot.log" "$ev\$Label.godot.log" -Force; "### godot.log ($((Get-Item "$ud\logs\godot.log").Length) bytes) first 60 lines"; Get-Content "$ud\logs\godot.log" -TotalCount 60 }
"### real userdata integrity"
$before=Get-Content "$W\evidence\FAN-3964\preimage\userdata_listing_before.txt" | ? { $_ -match 'sha256=' }
$changed=0; $now=0
Get-ChildItem $realud -Recurse -File | % { $now++; $rel=$_.FullName.Substring($realud.Length); $h=(Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); $line=$before | ? { $_ -like "  $rel bytes=*" } | Select-Object -First 1; if(-not $line -or $line -notmatch "sha256=$h"){ $changed++; "  CHANGED/NEW: $rel" } }
"real userdata files now=$now before=$($before.Count) changed_or_new=$changed"
"real userdata dir mtime: $((Get-Item $realud).LastWriteTimeUtc.ToString('o'))"
"## $Label end $(T)"
