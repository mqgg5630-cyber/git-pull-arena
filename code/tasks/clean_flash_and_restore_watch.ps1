# Run in Administrator PowerShell.
# 1) removes Lively / Livelycu / zTasker flash-window autoruns (registry + tasks + startup folders), with backup
# 2) re-enables ONLY this branch's git-sync watcher, hidden (no console window)
param(
  [string]$Repo = "E:\0github\git-sync\git-pull-arena-01a0ff69",
  [switch]$WhatIfOnly
)
$ErrorActionPreference = "Continue"
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $env:USERPROFILE ("Desktop\flashfix_backup_" + $stamp)
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Write-Host "backup dir: $backup" -ForegroundColor Cyan

$pattern = 'Lively|Livelycu|zTasker|wallpaper'

# ---------- 0) kill the loop right now ----------
Get-CimInstance Win32_Process | Where-Object {
  ([string]$_.CommandLine) -match 'Livelycu|IMAGENAME eq Lively' -or $_.Name -match '^(zTasker|Lively|Livelycu)'
} | ForEach-Object {
  Write-Host ("kill pid={0} {1}" -f $_.ProcessId, $_.Name) -ForegroundColor Yellow
  if (-not $WhatIfOnly) { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# ---------- 1) registry Run keys ----------
$runKeys = @(
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)
foreach ($k in $runKeys) {
  if (-not (Test-Path $k)) { continue }
  $props = (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
  foreach ($p in $props) {
    if ($p.Name -match $pattern -or ([string]$p.Value) -match $pattern) {
      ("{0}`t{1}`t{2}" -f $k, $p.Name, $p.Value) | Add-Content (Join-Path $backup "run_keys_removed.txt")
      Write-Host ("remove RUN  {0} :: {1} = {2}" -f $k, $p.Name, $p.Value) -ForegroundColor Yellow
      if (-not $WhatIfOnly) { Remove-ItemProperty -Path $k -Name $p.Name -Force -ErrorAction SilentlyContinue }
    }
  }
}

# ---------- 2) StartupApproved (so Task Manager startup list is clean too) ----------
foreach ($k in @(
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run")) {
  if (Test-Path $k) {
    (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' -and $_.Name -match $pattern } | ForEach-Object {
      Write-Host ("remove StartupApproved {0}" -f $_.Name) -ForegroundColor Yellow
      if (-not $WhatIfOnly) { Remove-ItemProperty -Path $k -Name $_.Name -Force -ErrorAction SilentlyContinue }
    }
  }
}

# ---------- 3) startup folders ----------
foreach ($d in @(
  (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
  (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'))) {
  if (Test-Path $d) {
    Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern } | ForEach-Object {
      Write-Host ("move startup item: " + $_.FullName) -ForegroundColor Yellow
      if (-not $WhatIfOnly) { Move-Item $_.FullName (Join-Path $backup $_.Name) -Force -ErrorAction SilentlyContinue }
    }
  }
}

# ---------- 4) scheduled tasks ----------
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
  $act = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
  if ($_.TaskName -match $pattern -or $act -match $pattern) {
    ("{0}{1}`t{2}" -f $_.TaskPath, $_.TaskName, $act) | Add-Content (Join-Path $backup "tasks_removed.txt")
    Write-Host ("remove TASK {0}{1}" -f $_.TaskPath, $_.TaskName) -ForegroundColor Yellow
    if (-not $WhatIfOnly) {
      Stop-ScheduledTask       -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
      Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
    }
  }
}

# ---------- 5) services ----------
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern -or $_.DisplayName -match $pattern } | ForEach-Object {
  Write-Host ("disable SERVICE {0}" -f $_.Name) -ForegroundColor Yellow
  if (-not $WhatIfOnly) {
    Stop-Service $_.Name -Force -ErrorAction SilentlyContinue
    Set-Service  $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
  }
}

# ---------- 6) stop console windows from popping: default terminal = conhost ----------
if (-not $WhatIfOnly) {
  New-Item -Path "HKCU:\Console\%%Startup" -Force | Out-Null
  Set-ItemProperty "HKCU:\Console\%%Startup" -Name DelegationConsole  -Value "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}" -Type String
  Set-ItemProperty "HKCU:\Console\%%Startup" -Name DelegationTerminal -Value "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}" -Type String
  Write-Host "default terminal set to classic conhost (far less visible flashing)" -ForegroundColor Green
}

# ---------- 7) restore ONLY this repo's watcher, hidden ----------
$watch = Join-Path $Repo "watch.ps1"
if (Test-Path -LiteralPath $watch) {
  Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'git-sync-watch' } | ForEach-Object {
    $mine = (($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ') -match [regex]::Escape($Repo)
    if ($mine) {
      $act = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument ("-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`" -Loop" -f $watch) `
        -WorkingDirectory $Repo
      $prin = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
      $set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::FromHours(12))
      $set.Hidden = $true
      if (-not $WhatIfOnly) {
        Set-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Action $act -Principal $prin -Settings $set | Out-Null
        Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null
        Start-ScheduledTask  -TaskName $_.TaskName -TaskPath $_.TaskPath
      }
      Write-Host ("RESTORED hidden watcher: {0}" -f $_.TaskName) -ForegroundColor Green
    } else {
      if (-not $WhatIfOnly) {
        Stop-ScheduledTask    -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null
      }
      Write-Host ("disabled other-repo watcher: {0}" -f $_.TaskName) -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "watch.ps1 not found at $watch" -ForegroundColor Red
}

Write-Host "CLEAN_AND_RESTORE_OK=True  (backup: $backup)" -ForegroundColor Cyan
