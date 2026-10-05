# t219_retry_dynamic_wallpaper_r268.ps1 - retry the existing Lively dynamic-wallpaper path.
# Runs only on the user's Windows machine through the local watcher.
$ErrorActionPreference = 'Continue'
$inner = Join-Path $PSScriptRoot 't198_cute_dynamic_wallpaper_r247.ps1'
if (-not (Test-Path -LiteralPath $inner)) {
    Write-Output ('[FAIL] missing dynamic wallpaper task: ' + $inner)
    exit 2
}

$last = 1
for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Output ('== dynamic wallpaper attempt ' + $attempt + '/3')
    & $inner
    $last = $LASTEXITCODE
    if ($last -eq 0) {
        Write-Output '== dynamic wallpaper succeeded'
        exit 0
    }
    Write-Output ('== attempt failed with exit ' + $last + '; watcher will retry')
    Start-Sleep -Seconds 10
}
Write-Output '== dynamic wallpaper did not reach READY after 3 attempts'
exit $last
