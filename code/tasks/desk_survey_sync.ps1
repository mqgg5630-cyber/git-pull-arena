# desk_survey_sync.ps1 - runs ON THE DESKTOP. Read-only survey for the
# Antigravity IDE sync (task 1) and the harness-anything/WPS skill (task 2):
# python/pip/git, WPS installation + KWPP COM registration + guarded live
# COM test, Antigravity install state, disk free. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop survey (IDE sync + harness prep) ---'

# ---------------- 1. python / pip / git ----------------
$pcmd = Get-Command python -ErrorAction SilentlyContinue
if ($pcmd) { L ('   python: ' + (San ((& python --version 2>&1 | Out-String).Trim())) + ' @ ' + (San $pcmd.Source)) }
else { L '   python: NOT on PATH' }
$pyl = Get-Command py -ErrorAction SilentlyContinue
if ($pyl) { L ('   py launcher: ' + (San (((& py -0p 2>&1 | Out-String).Trim() -replace "`r?`n", ' | ')))) }
else { L '   py launcher: none' }
if ($pcmd) { L ('   pip: ' + (San ((& python -m pip --version 2>&1 | Out-String).Trim()))) }
$g = Get-Command git -ErrorAction SilentlyContinue
if ($g) { L ('   git: ' + (San ((& git --version 2>&1 | Out-String).Trim()))) }
else { L '   git: NOT on PATH' }

# ---------------- 2. WPS ----------------
$keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
$apps = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'WPS' })
if ($apps.Count -eq 0) { L '   WPS uninstall entry: none' }
foreach ($a in $apps) { L ('   WPS: ' + (San ([string]$a.DisplayName)) + ' v' + (San ([string]$a.DisplayVersion)) + ' at ' + (San ([string]$a.InstallLocation))) }
foreach ($p in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) {
    L ('   ProgID ' + $p + ': HKLM=' + (Test-Path ('HKLM:\SOFTWARE\Classes\' + $p)) + ' HKCU=' + (Test-Path ('HKCU:\SOFTWARE\Classes\' + $p)))
}
if ((Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application') -or ($apps.Count -gt 0)) {
    $cjob = Start-Job -ScriptBlock {
        try {
            $k = New-Object -ComObject KWPP.Application
            $k.Visible = $false
            $v = [string]$k.Version
            $k.Quit()
            'OK version=' + $v
        } catch { 'FAIL: ' + $_.Exception.Message }
    }
    if (Wait-Job $cjob -Timeout 90) { L ('   live COM KWPP: ' + (San ((Receive-Job $cjob | Out-String).Trim()))) }
    else { Stop-Job $cjob -Force -ErrorAction SilentlyContinue; L '   live COM KWPP: TIMEOUT (first-run dialog?)' }
    Remove-Job $cjob -Force -ErrorAction SilentlyContinue
} else { L '   live COM KWPP: skipped (WPS not detected)' }

# ---------------- 3. Antigravity ----------------
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if (Test-Path -LiteralPath $agExe) {
    L ('   Antigravity: v' + (San ([string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion)))
    $sz = (Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity') -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum)
    L ('   Antigravity install: files=' + $sz.Count + ' sizeMB=' + [math]::Round($sz.Sum/1MB))
} else { L '   Antigravity exe: missing' }
$n = @(Get-Process -Name Antigravity, language_server -ErrorAction SilentlyContinue)
L ('   Antigravity processes: ' + $n.Count)

# ---------------- 4. disk free ----------------
foreach ($d in @('C', 'F')) {
    try { $free = (Get-PSDrive $d -ErrorAction Stop).Free; L ('   disk ' + $d + ': freeGB=' + [math]::Round($free/1GB)) } catch { L ('   disk ' + $d + ': n/a') }
}
L '--- desktop survey done ---'
