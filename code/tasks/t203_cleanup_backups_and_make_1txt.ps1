$ErrorActionPreference = "Continue"
$desk = [Environment]::GetFolderPath("Desktop")
Write-Output "HOST=$env:COMPUTERNAME"
Write-Output "DESKTOP=$desk"

# 1) delete every flashfix backup folder on the Desktop
$removed = 0
Get-ChildItem -LiteralPath $desk -Directory -Filter 'flashfix_backup_*' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output ("REMOVING_BACKUP={0}" -f $_.FullName)
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $_.FullName)) { $removed++ }
}
Write-Output "BACKUP_FOLDERS_REMOVED=$removed"
$left = @(Get-ChildItem -LiteralPath $desk -Directory -Filter 'flashfix_backup_*' -ErrorAction SilentlyContinue).Count
Write-Output "BACKUP_FOLDERS_LEFT=$left"

# 2) create Desktop\1.txt
$f = Join-Path $desk "1.txt"
$body = @(
  "created by git-sync watcher",
  "host   : $env:COMPUTERNAME",
  "user   : $env:USERNAME",
  "time   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  "branch : arena/01a0ff69-git-pull-arena",
  "round  : 264",
  "status : watcher <-> arena link verified"
) -join "`r`n"
Set-Content -LiteralPath $f -Value $body -Encoding UTF8
Write-Output "FILE_PATH=$f"
Write-Output "FILE_EXISTS=$(Test-Path -LiteralPath $f)"
Write-Output ("FILE_SIZE={0}" -f (Get-Item -LiteralPath $f).Length)
Write-Output "---- content ----"
Get-Content -LiteralPath $f | ForEach-Object { Write-Output ("| " + $_) }

if ($left -eq 0 -and (Test-Path -LiteralPath $f)) {
    Write-Output "TASK_203_OK=True"
} else {
    Write-Output "TASK_203_OK=False"
    exit 1
}
