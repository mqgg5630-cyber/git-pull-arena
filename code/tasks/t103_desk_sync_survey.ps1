# t103_desk_sync_survey.ps1 - round 139 task: dual-machine read-only survey
# for (1) syncing the laptop Antigravity IDE to the desktop and (2) the
# harness-anything WPS pptx skill install. Laptop probes run locally
# (version, User config, extensions, installer cache); desktop probes run
# via ssh (python/pip/git, WPS + COM, disk). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t103: dual-machine survey (IDE sync + harness-anything prep) ---'

# ================= laptop-local probes =================
L '--- laptop (IDE sync source) ---'
$pcmd = Get-Command python -ErrorAction SilentlyContinue
if ($pcmd) { L ('   python: ' + (San ((& python --version 2>&1 | Out-String).Trim())) + ' @ ' + (San $pcmd.Source)) }
else { L '   python: NOT on PATH' }
if ($pcmd) { L ('   pip: ' + (San ((& python -m pip --version 2>&1 | Out-String).Trim()))) }
$g = Get-Command git -ErrorAction SilentlyContinue
if ($g) { L ('   git: ' + (San ((& git --version 2>&1 | Out-String).Trim()))) }
else { L '   git: NOT on PATH' }

# WPS on laptop
$keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
$apps = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'WPS' })
if ($apps.Count -eq 0) { L '   WPS uninstall entry: none' }
foreach ($a in $apps) { L ('   WPS: ' + (San ([string]$a.DisplayName)) + ' v' + (San ([string]$a.DisplayVersion)) + ' at ' + (San ([string]$a.InstallLocation))) }
foreach ($p in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) {
    L ('   ProgID ' + $p + ': HKLM=' + (Test-Path ('HKLM:\SOFTWARE\Classes\' + $p)) + ' HKCU=' + (Test-Path ('HKCU:\SOFTWARE\Classes\' + $p)))
}
if ((Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application')) {
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
} else { L '   live COM KWPP: skipped (not registered)' }

# Antigravity on laptop (the sync source)
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if (Test-Path -LiteralPath $agExe) {
    L ('   Antigravity exe: v' + (San ([string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion)))
    $sz = (Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity') -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum)
    L ('   Antigravity install: files=' + $sz.Count + ' sizeMB=' + [math]::Round($sz.Sum/1MB))
} else { L '   Antigravity exe: MISSING - check install path' }

$userDir = Join-Path $env:APPDATA 'Antigravity\User'
if (Test-Path -LiteralPath $userDir) {
    L '   Roaming Antigravity User files (first 25):'
    foreach ($f in @(Get-ChildItem -LiteralPath $userDir -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 25)) {
        L ('      ' + (San $f.FullName.Substring($userDir.Length + 1)) + ' (' + [math]::Round($f.Length/1KB) + 'KB)')
    }
} else { L '   Roaming Antigravity User dir: none' }

$extDir = Join-Path $env:USERPROFILE '.antigravity\extensions'
if (Test-Path -LiteralPath $extDir) {
    $exts = @(Get-ChildItem -LiteralPath $extDir -Directory -ErrorAction SilentlyContinue)
    L ('   extensions: ' + $exts.Count)
    foreach ($d in @($exts | Select-Object -First 30)) { L ('      ' + (San $d.Name)) }
} else { L '   extensions dir: none' }

# installer search (bounded: antigravity-named dirs + Downloads)
L '   installer search:'
$found = 0
$cand = @()
$cand += @(Get-ChildItem $env:LOCALAPPDATA -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'antigravity' })
$cand += @(Get-ChildItem $env:APPDATA -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'antigravity' })
foreach ($c in $cand) {
    foreach ($f in @(Get-ChildItem $c.FullName -Recurse -Depth 3 -Filter '*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 5)) {
        L ('      ' + (San $f.FullName) + ' (' + [math]::Round($f.Length/1MB) + 'MB ' + $f.LastWriteTime.ToString('yyyy-MM-dd') + ')')
        $found++
    }
}
$dl = Join-Path $env:USERPROFILE 'Downloads'
if (Test-Path -LiteralPath $dl) {
    foreach ($f in @(Get-ChildItem $dl -Filter '*ntigravity*' -File -ErrorAction SilentlyContinue | Select-Object -First 5)) {
        L ('      ' + (San $f.FullName) + ' (' + [math]::Round($f.Length/1MB) + 'MB ' + $f.LastWriteTime.ToString('yyyy-MM-dd') + ')')
        $found++
    }
}
if ($found -eq 0) { L '      (no installer exe found - plan: zip the install dir)' }

# ================= desktop probes via ssh =================
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$survSrc = Join-Path $repoRoot 'code\tasks\desk_survey_sync.ps1'
if (-not (Test-Path -LiteralPath $survSrc)) { L '   [FAIL] survey script missing'; exit 2 }

$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($survSrc, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] desk survey parse errors: ' + $perrs.Count)
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\desksurvey.ps1'), ([IO.File]::ReadAllText($survSrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   desksurvey.ps1 staged'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desksurvey.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 240)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote survey timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t103 done ---'
exit 0
