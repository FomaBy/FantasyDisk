param([string]$Label="cold",[string]$ExeDir="install_target\FantasyDisk",[int]$Runs=5,[string]$EvRoot="evidence\FAN-3964\v0.3.2",[string[]]$ExtraArgs=@("--print-fps"),[int]$HoldSec=3)
# M4 cold start, perf-checklist P1: time from process start to the first "Project FPS" stdout line
# (same method as the independent 0.3.1 review, which reported "first FPS line minus 1 s"),
# polled every 100 ms; also the first moment the main window answers messages.
$ErrorActionPreference='Continue'
function T { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
$W=$PSScriptRoot; $exe="$W\$ExeDir\FantasyDisk.exe"; $ev="$W\$EvRoot\launch"
"## coldstart series $Label exe=$ExeDir runs=$Runs args=$($ExtraArgs -join ' ') start $(T)"
"exe sha256: $((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()) bytes=$((Get-Item $exe).Length)"
$fpsTimes=@(); $respTimes=@()
for($r=1; $r -le $Runs; $r++){
  $out="$ev\$Label`_run$r.stdout.txt"; $err="$ev\$Label`_run$r.stderr.txt"
  $sw=[Diagnostics.Stopwatch]::StartNew()
  $p=Start-Process -FilePath $exe -ArgumentList $ExtraArgs -WorkingDirectory "$W\$ExeDir" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
  $t0=$p.StartTime
  $fps=-1.0; $resp=-1.0
  while($sw.Elapsed.TotalSeconds -lt 300){
    Start-Sleep -Milliseconds 100
    if($p.HasExited){ break }
    if($resp -lt 0){ $p.Refresh(); if($p.MainWindowHandle -ne 0 -and $p.Responding){ $resp=[math]::Round($sw.Elapsed.TotalSeconds,1) } }
    if($fps -lt 0 -and (Test-Path $out)){ $txt=""; try { $fs=New-Object IO.FileStream($out,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite); $sr=New-Object IO.StreamReader($fs); $txt=$sr.ReadToEnd(); $sr.Close(); $fs.Close() } catch { $txt="" }; if($txt -match "Project FPS"){ $fps=[math]::Round($sw.Elapsed.TotalSeconds,1) } }
    if($fps -ge 0 -and $resp -ge 0){ break }
  }
  Start-Sleep -Seconds $HoldSec
  $p.Refresh(); $ws=[math]::Round($p.PeakWorkingSet64/1MB,1); $priv=[math]::Round($p.PrivateMemorySize64/1MB,1)
  $null=$p.CloseMainWindow(); if(-not $p.WaitForExit(20000)){ "  run ${r}: no exit after WM_CLOSE in 20 s, Stop-Process own pid $($p.Id)"; Stop-Process -Id $p.Id -Force; $p.WaitForExit(10000) | Out-Null }
  "  run ${r}: pid=$($p.Id) first_fps_line_s=$fps first_responding_s=$resp peak_ws_MiB=$ws private_MiB_at_hold=$priv exit_code=$($p.ExitCode) stderr_bytes=$((Get-Item $err).Length) $(T)"
  if($fps -ge 0){ $fpsTimes+=$fps }; if($resp -ge 0){ $respTimes+=$resp }
  Start-Sleep -Seconds 2
}
function Med($a){ if($a.Count -eq 0){ return 'n/a' }; $s=$a | Sort-Object; if($s.Count % 2 -eq 1){ return $s[[math]::Floor($s.Count/2)] } else { return [math]::Round(($s[$s.Count/2-1]+$s[$s.Count/2])/2,1) } }
"summary $Label`: first_fps_line_s=[$($fpsTimes -join ', ')] median=$(Med $fpsTimes); minus_1s_method_median=$(if($fpsTimes.Count){[math]::Round((Med $fpsTimes)-1,1)}else{'n/a'}); first_responding_s=[$($respTimes -join ', ')] median=$(Med $respTimes)"
"## coldstart series $Label end $(T)"
