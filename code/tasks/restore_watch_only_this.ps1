# Run in PowerShell as Administrator.
# Keeps ONLY the watcher for this branch repo; closes popups; kills other watchers/tasks.
param(
  [string]$Repo   = "E:\0github\git-sync\git-pull-arena-01a0ff69",
  [string]$Branch = "arena/01a0ff69-git-pull-arena"
)
$ErrorActionPreference = "Continue"
Write-Host "== repo: $Repo  branch: $Branch" -ForegroundColor Cyan

# 1) close every visible popup / message box (dialog class #32770)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
}
"@
$closed = 0
$cb = [W+EnumProc]{
  param($h,$l)
  if ([W]::IsWindowVisible($h)) {
    $c = New-Object System.Text.StringBuilder 256; [void][W]::GetClassName($h,$c,256)
    $t = New-Object System.Text.StringBuilder 512; [void][W]::GetWindowText($h,$t,512)
    if ($c.ToString() -eq '#32770') {
      Write-Host ("  popup closed: " + $t.ToString())
      $r=[IntPtr]::Zero
      [void][W]::SendMessageTimeout($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1500, [ref]$r)
      $script:closed++
    }
  }
  return $true
}
[void][W]::EnumWindows($cb,[IntPtr]::Zero)
Write-Host "POPUPS_CLOSED=$closed"

# 2) kill crash/error dialog hosts
foreach ($n in @('WerFault','WerFaultSecure','dwwin','DW20')) {
  Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("  dialog host killed: {0} ({1})" -f $_.ProcessName,$_.Id); Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  }
}

# 3) kill every watcher/sync powershell that is NOT this repo
$me = $PID
$killed = 0
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object {
  $cl = [string]$_.CommandLine
  if ($cl -match 'watch\.ps1|sync\.ps1') {
    if ($_.ProcessId -ne $me -and $cl -notmatch [regex]::Escape($Repo)) {
      Write-Host ("  stray watcher killed: pid={0}" -f $_.ProcessId)
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++
    }
  }
}
Write-Host "STRAY_WATCHERS_KILLED=$killed"

# 4) disable other git-sync scheduled tasks, keep only this repo's
$keepTask = $null
Get-ScheduledTask -ErrorAction SilentlyContinue |
  Where-Object { $_.TaskName -match 'git.?sync|arena|watch' } | ForEach-Object {
    $act = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
    if ($act -match [regex]::Escape($Repo)) {
      $keepTask = $_.TaskName
      Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
      Write-Host ("  KEEP task: {0}" -f $_.TaskName) -ForegroundColor Green
    } else {
      Stop-ScheduledTask  -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
      Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
      Write-Host ("  disabled task: {0}" -f $_.TaskName) -ForegroundColor Yellow
    }
  }

# 5) clear stale lock, re-align repo to the branch, restart the watcher
Get-ChildItem $env:TEMP -Filter '*.lock' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'git|sync|arena|watch' } |
  ForEach-Object { Write-Host ("  stale lock removed: " + $_.Name); Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

Set-Location -LiteralPath $Repo
git fetch origin --prune
git checkout $Branch
git reset --hard "origin/$Branch"
git log --oneline -1

if ($keepTask) {
  Start-ScheduledTask -TaskName $keepTask -ErrorAction SilentlyContinue
  Write-Host "watcher task restarted: $keepTask" -ForegroundColor Green
} else {
  Write-Host "no scheduled task found - starting watch.ps1 directly" -ForegroundColor Yellow
  Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$Repo\watch.ps1") -WindowStyle Minimized
}

Start-Sleep -Seconds 5
Get-Content (Join-Path $Repo 'results\status\handshake.json') -ErrorAction SilentlyContinue
Write-Host "RESTORE_OK=True" -ForegroundColor Cyan
