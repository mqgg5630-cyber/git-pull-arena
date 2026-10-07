$ErrorActionPreference = "Continue"
$out = Join-Path (Get-Location) "results\status\flash_window_diag.md"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
function L($s) { $lines.Add($s); Write-Output $s }

L "# Flash window diagnostic"
L "HOST=$env:COMPUTERNAME  TIME=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

L ""
L "## A. scheduled tasks firing frequently"
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
  $i = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
  if ($i -and $i.LastRunTime -and $i.LastRunTime -gt (Get-Date).AddMinutes(-30)) {
    $act = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | '
    L ("TASK {0}{1} last={2} next={3} hidden={4} act={5}" -f $_.TaskPath,$_.TaskName,$i.LastRunTime,$i.NextRunTime,$_.Settings.Hidden,($act -replace '\s+',' '))
  }
}

L ""
L "## B. new short-lived processes over 60s"
$end = (Get-Date).AddSeconds(60)
$seen = @{}
Get-CimInstance Win32_Process | ForEach-Object { $seen[$_.ProcessId] = $true }
$hits = @{}
while ((Get-Date) -lt $end) {
  Get-CimInstance Win32_Process | ForEach-Object {
    if (-not $seen.ContainsKey($_.ProcessId)) {
      $seen[$_.ProcessId] = $true
      $key = "{0} :: {1}" -f $_.Name, ((([string]$_.CommandLine) -replace '\s+',' '))
      if ($hits.ContainsKey($key)) { $hits[$key]++ } else { $hits[$key] = 1 }
    }
  }
  Start-Sleep -Milliseconds 400
}
$hits.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40 | ForEach-Object {
  L ("NEWPROC x{0}  {1}" -f $_.Value, $_.Key)
}

L ""
L "## C. console-host / window-owning processes right now"
Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object {
  L ("WINDOW pid={0} name={1} title={2}" -f $_.Id,$_.ProcessName,$_.MainWindowTitle)
}
Get-Process conhost,WindowsTerminal,cmd,wscript,cscript,mshta -ErrorAction SilentlyContinue | ForEach-Object {
  L ("HOSTPROC pid={0} name={1} start={2}" -f $_.Id,$_.ProcessName,$_.StartTime)
}

L ""
L "## D. autoruns likely to pop consoles"
foreach ($k in @(
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
  if (Test-Path $k) {
    (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
      L ("RUN {0} = {1}" -f $_.Name, $_.Value)
    }
  }
}

L ""
L "## E. recent task-scheduler starts (event log)"
try {
  Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; Id=129,200; StartTime=(Get-Date).AddMinutes(-30)} -MaxEvents 40 -ErrorAction Stop |
    ForEach-Object { L ("EVT {0} {1} {2}" -f $_.TimeCreated, $_.Id, (($_.Message -replace '\s+',' ')).Substring(0,[Math]::Min(160,$_.Message.Length))) }
} catch { L "EVT unavailable: $($_.Exception.Message)" }

L ""
L "FLASH_DIAG_OK=True"
Set-Content -LiteralPath $out -Value ($lines -join "`r`n") -Encoding UTF8
Write-Output "REPORT=$out"
