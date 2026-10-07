# Run in Administrator PowerShell.
# Makes the git-sync watcher run completely windowless (no flashing console).
param(
  [string]$Repo = "E:\0github\git-sync\git-pull-arena-01a0ff69"
)
$ErrorActionPreference = "Continue"
$watch = Join-Path $Repo "watch.ps1"
if (-not (Test-Path -LiteralPath $watch)) { throw "watch.ps1 not found: $watch" }

$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
  $a = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
  $a -match 'watch\.ps1'
}
if (-not $tasks) { Write-Host "no watcher scheduled task found" -ForegroundColor Yellow }

foreach ($t in $tasks) {
  $name = $t.TaskName
  $path = $t.TaskPath
  $inThisRepo = (($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ') -match [regex]::Escape($Repo)
  Write-Host ("task: {0}{1}  thisRepo={2}" -f $path, $name, $inThisRepo) -ForegroundColor Cyan

  if (-not $inThisRepo) {
    Stop-ScheduledTask    -TaskName $name -TaskPath $path -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  -> other repo: disabled" -ForegroundColor Yellow
    continue
  }

  # hidden, non-interactive action
  $act = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument ("-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`"" -f $watch) `
    -WorkingDirectory $Repo

  # S4U principal = runs whether logged on or not => never shows a window
  $prin = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

  $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::FromHours(12))
  $set.Hidden = $true
  $set.DisallowStartIfOnBatteries = $false

  Set-ScheduledTask -TaskName $name -TaskPath $path -Action $act -Principal $prin -Settings $set | Out-Null
  Write-Host "  -> set to hidden / S4U" -ForegroundColor Green

  Stop-ScheduledTask  -TaskName $name -TaskPath $path -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Start-ScheduledTask -TaskName $name -TaskPath $path
  Write-Host "  -> restarted" -ForegroundColor Green
}

# kill leftover visible watcher consoles from the old visible task
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object {
  $cl = [string]$_.CommandLine
  if ($cl -match 'watch\.ps1' -and $cl -notmatch 'WindowStyle Hidden' -and $_.ProcessId -ne $PID) {
    Write-Host ("kill visible watcher pid={0}" -f $_.ProcessId) -ForegroundColor Yellow
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "HIDE_OK=True" -ForegroundColor Cyan
