Add-Type @"
using System; using System.Runtime.InteropServices;
public class Idle { [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
 [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 public static double IdleSeconds(){ var l=new LASTINPUTINFO(); l.cbSize=(uint)Marshal.SizeOf(l); GetLastInputInfo(ref l); return (Environment.TickCount - (int)l.dwTime)/1000.0; }
 public static string Foreground(){ var h=GetForegroundWindow(); var sb=new System.Text.StringBuilder(256); GetWindowText(h,sb,256); uint pid; GetWindowThreadProcessId(h,out pid); return pid+"|"+sb.ToString(); } }
"@
$t=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); $fg=[Idle]::Foreground(); $pid2=[int]($fg.Split('|')[0]); $pn=(Get-Process -Id $pid2 -ErrorAction SilentlyContinue).ProcessName
"$t idle_seconds=$([math]::Round([Idle]::IdleSeconds(),1)) foreground_process=$pn (title redacted)"
"$t sessions: " + ((quser 2>$null | Out-String).Trim() -replace '\s+',' ')
"$t screen locked (LogonUI present): $((Get-Process LogonUI -ErrorAction SilentlyContinue) -ne $null)"
"$t user-facing apps running: " + ((Get-Process | ? { $_.ProcessName -match '^(Telegram|Discord|chrome|msedge|firefox|Code|Cursor|WINWORD|EXCEL|obs64|vlc)$' } | % { $_.ProcessName } | Sort-Object -Unique) -join ',')
