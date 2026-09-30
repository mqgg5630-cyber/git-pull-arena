# t45_r_versions_cleanup.ps1 - round 55 task: enumerate R versions under
# E:\R, DELETE old version dirs (user-approved, to recycle bin) keeping the
# newest, verify R still runs, survey E:\RStudio + user libraries, and patch
# the R section of the Desktop report. Windows PowerShell 5.1, ASCII-only.

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName Microsoft.VisualBasic
$ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
$rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function FmtB {
    param([double]$b)
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    return ('{0:N1} KB' -f ($b / 1KB))
}

Write-Output '--- task t45: R versions under E:\R - delete old, keep newest ---'
$rRoot = 'E:\R'
if (-not (Test-Path -LiteralPath $rRoot)) { Write-Output '   [FAIL] E:\R not found'; exit 2 }

# all top-level entries (version dirs + anything else)
$entries = @(Get-ChildItem -LiteralPath $rRoot -ErrorAction SilentlyContinue)
Write-Output ('   E:\R top-level entries: ' + $entries.Count)
$vers = @($entries | Where-Object { $_.PSIsContainer -and $_.Name -match '^R-\d+(\.\d+)+$' } | Sort-Object -Property @{Expression = { [version]($_.Name.Substring(2)) }})
$other = @($entries | Where-Object { -not ($_.PSIsContainer -and $_.Name -match '^R-\d+(\.\d+)+$') })
foreach ($o in $other) { Write-Output ('   OTHER  ' + (San ([string]$o.Name)) + $(if (-not $o.PSIsContainer) { ' (file)' })) }

if ($vers.Count -eq 0) { Write-Output '   no R-x.y.z version dirs inside E:\R' }

# sizes
$szOf = @{}
foreach ($v in $vers) {
    $s = [double]0
    try {
        $m = Get-ChildItem -LiteralPath $v.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
        $s = [double]$m.Sum
    } catch { }
    $szOf[$v.FullName] = $s
    Write-Output ('   R VER  ' + (FmtB $s).PadLeft(10) + '  ' + $v.Name)
}

# delete old, keep newest
$deleted = @()
if ($vers.Count -ge 2) {
    $keep = $vers[-1]
    foreach ($v in @($vers | Where-Object { $_.FullName -ne $keep.FullName })) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($v.FullName, $ui, $rb)
            $deleted += $v.Name
            Write-Output ('   BIN    ' + $v.Name + '  (' + (FmtB ([double]$szOf[$v.FullName])) + ')')
        } catch { Write-Output ('   [WARN] ' + (San $v.Name) + ' : ' + (San $_.Exception.Message)) }
    }
    Write-Output ('   KEPT   ' + $keep.Name)
    # verify newest still runs
    $rExe = Join-Path $keep.FullName 'bin\R.exe'
    if (Test-Path -LiteralPath $rExe) {
        try {
            $j = Start-Job -ScriptBlock { param($e) & $e --version 2>&1 | Select-Object -First 1 | Out-String } -ArgumentList $rExe
            if (Wait-Job $j -Timeout 30) { Write-Output ('   verify: ' + (San ((Receive-Job $j | Out-String).Trim()))) }
            else { Write-Output '   verify: timeout' }
            Remove-Job $j -Force -ErrorAction SilentlyContinue
        } catch { Write-Output ('   [WARN] verify: ' + (San $_.Exception.Message)) }
    } else { Write-Output '   [WARN] newest has no bin\R.exe (portable layout?)' }
} elseif ($vers.Count -eq 1) {
    Write-Output ('   only one version present (' + $vers[0].Name + ') - nothing to delete')
}

# RStudio survey (report only)
Write-Output '--- E:\RStudio (report only) ---'
try {
    foreach ($d in @(Get-ChildItem -LiteralPath 'E:\RStudio' -Directory -ErrorAction SilentlyContinue | Select-Object -First 12)) {
        Write-Output ('   RSTUDIO-DIR  ' + (San ([string]$d.Name)))
    }
    foreach ($f in @(Get-ChildItem -LiteralPath 'E:\RStudio' -File -ErrorAction SilentlyContinue | Select-Object -First 8)) {
        Write-Output ('   RSTUDIO-FILE ' + (San ([string]$f.Name)) + '  ' + (FmtB ([double]$f.Length)))
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# user libraries (report only)
Write-Output '--- user package libraries (report only) ---'
foreach ($lib in @((Join-Path $rRoot 'win-library'), (([Environment]::GetFolderPath('MyDocuments')) + '\R'))) {
    if (Test-Path -LiteralPath $lib) {
        try {
            foreach ($v in @(Get-ChildItem -LiteralPath $lib -Directory -ErrorAction SilentlyContinue | Select-Object -First 10)) {
                Write-Output ('   LIB  ' + (San ([string]$v.FullName)))
            }
        } catch { }
    }
}

# patch the Desktop report R section
$desk = [Environment]::GetFolderPath('Desktop')
$name = [string]([char]0x4EFB + [char]0x52A1 + [char]0x573A + [char]0x666F + [char]0x4E0E + [char]0x5927 + [char]0x6587 + [char]0x4EF6 + [char]0x6E05 + [char]0x5355 + '_2026-09-30.md')
$deskFile = Join-Path $desk $name
if (Test-Path -LiteralPath $deskFile) {
    try {
        $raw = [System.IO.File]::ReadAllText($deskFile, [System.Text.Encoding]::UTF8)
        $m0 = $raw.IndexOf('- Windows R version dirs: 0')
        $m1 = $raw.IndexOf('- R inside WSL is reported only')
        if ($m0 -ge 0 -and $m1 -gt $m0) {
            $newR = '- Windows R: FOUND at E:\R (' + $vers.Count + ' version dirs) + E:\RStudio (IDE).'
            if ($deleted.Count -gt 0) {
                $del = ($deleted -join ', ')
                $newR = $newR + "`r`n" + '- DELETED old versions (recycle bin): ' + $del
            } else {
                $newR = $newR + "`r`n" + '- Old versions: none deleted (single version only).'
            }
            $newR = $newR + "`r`n" + '- WSL: no R in Ubuntu-24.04 (clean probe) or 26.04.'
            $new = $raw.Substring(0, $m0) + $newR + $raw.Substring($m1)
            [System.IO.File]::WriteAllText($deskFile, $new, (New-Object System.Text.UTF8Encoding($true)))
            Write-Output '   desktop report: R section updated'
        } else { Write-Output '   desktop report: R section markers not found (already updated?)' }
    } catch { Write-Output ('   [WARN] desktop patch: ' + (San $_.Exception.Message)) }
} else { Write-Output '   [WARN] desktop report not found' }

# space
try {
    $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'"
    Write-Output ('   E: free now: ' + ([math]::Round($dk.FreeSpace / 1GB, 1)) + ' GB (freed space lands after bin empty)')
} catch { }
exit 0
