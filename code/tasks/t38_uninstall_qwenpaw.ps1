# t38_uninstall_qwenpaw.ps1 - round 49 task: uninstall QwenPaw Desktop
# (user-approved), clean its shortcuts and leftovers (to recycle bin),
# report freed space. Windows PowerShell 5.1, ASCII-only, Write-Output only.

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
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}
function ToBin {
    param([string]$p)
    if (Test-Path -LiteralPath $p) {
        try {
            if (Test-Path -LiteralPath $p -PathType Container) {
                $sz = [double]((Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, $ui, $rb)
            } else {
                $sz = [double](Get-Item -LiteralPath $p -Force).Length
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, $ui, $rb)
            }
            Write-Output ('   BIN  ' + (FmtB $sz) + '  ' + (San $p))
        } catch { Write-Output ('   [WARN] bin failed: ' + (San $p) + ' : ' + (San $_.Exception.Message)) }
    } else { Write-Output ('   skip (absent): ' + (San $p)) }
}

Write-Output '--- task t38: uninstall QwenPaw Desktop ---'

# locate the uninstall entry
$entry = $null
$entryKey = ''
foreach ($hive in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $hive -ErrorAction SilentlyContinue)) {
        if (([string]$it.DisplayName) -match 'QwenPaw') { $entry = $it; $entryKey = [string]$it.PSPath; break }
    }
    if ($entry) { break }
}
if (-not $entry) { Write-Output '   no QwenPaw uninstall entry found (already uninstalled?)' }

$eFree0 = [double]0
try { $eFree0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'").FreeSpace } catch { }

# size before
$dirSize = [double]0
if (Test-Path -LiteralPath 'E:\QwenPaw') {
    try { $dirSize = [double]((Get-ChildItem -LiteralPath 'E:\QwenPaw' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) } catch { }
}
Write-Output ('   E:\QwenPaw size before: ' + (FmtB $dirSize))
if ($entry) {
    Write-Output ('   registry: ' + (San ([string]$entry.DisplayName)) + ' ' + (San ([string]$entry.DisplayVersion)) + '  @ ' + (San ([string]$entry.InstallLocation)))
    Write-Output ('   uninstall cmd: ' + (San ([string]$entry.UninstallString)))
}

# kill running processes
try {
    $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'QwenPaw' })
    if ($procs.Count -gt 0) {
        foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        Write-Output ('   stopped ' + $procs.Count + ' running process(es)')
    } else { Write-Output '   not running' }
} catch { }

# run the uninstaller silently
if ($entry) {
    $us = [string]$entry.QuietUninstallString
    if (-not $us) { $us = [string]$entry.UninstallString }
    $exe = ''
    $args = ''
    if ($us -match '^"([^"]+\.exe)"(.*)$') { $exe = $Matches[1]; $args = $Matches[2].Trim() }
    elseif ($us -match '^([^"\s]+\.exe)(.*)$') { $exe = $Matches[1]; $args = $Matches[2].Trim() }
    if ($exe -and (Test-Path -LiteralPath $exe)) {
        if ($args -notmatch '/S') { $args = ($args + ' /S').Trim() }
        Write-Output ('   running silent: ' + (San $exe) + ' ' + $args)
        try {
            $p = Start-Process -FilePath $exe -ArgumentList $args -PassThru
            $null = Wait-Process -Id $p.Id -Timeout 150 -ErrorAction SilentlyContinue
            # NSIS often detaches; poll for the dir to disappear
            for ($i = 0; $i -lt 24; $i++) {
                if (-not (Test-Path -LiteralPath 'E:\QwenPaw')) { break }
                Start-Sleep -Seconds 5
            }
        } catch { Write-Output ('   [WARN] uninstaller: ' + (San $_.Exception.Message)) }
    } elseif ($us -match 'msiexec') {
        Write-Output '   msiexec-based uninstaller, running passive ...'
        try { $null = Start-Process -FilePath 'msiexec.exe' -ArgumentList (($us -replace '^.*msiexec\.exe\s*', '') + ' /passive') -Wait } catch { Write-Output ('   [WARN] msiexec: ' + (San $_.Exception.Message)) }
    } else {
        Write-Output ('   [FAIL] could not resolve uninstaller exe from: ' + (San $us))
    }
}

# leftovers
Start-Sleep -Seconds 3
if (Test-Path -LiteralPath 'E:\QwenPaw') {
    $left = [double]0
    try { $left = [double]((Get-ChildItem -LiteralPath 'E:\QwenPaw' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) } catch { }
    Write-Output ('   leftover E:\QwenPaw: ' + (FmtB $left) + ' -> sending to recycle bin')
    ToBin 'E:\QwenPaw'
} else { Write-Output '   E:\QwenPaw fully removed by uninstaller' }

# electron user data
foreach ($d in @(($env:APPDATA + '\qwenpaw'), ($env:LOCALAPPDATA + '\qwenpaw'))) {
    if (Test-Path -LiteralPath $d) {
        ToBin $d
    }
}

# shortcuts (desktop path is localized -> build from char codes)
$desk = [Environment]::GetFolderPath('Desktop')
ToBin (Join-Path $desk 'QwenPaw Desktop.lnk')
ToBin ($env:APPDATA + '\Microsoft\Windows\Start Menu\Programs\QwenPaw Desktop.lnk')
$pd = ($env:ProgramData + '\Microsoft\Windows\Start Menu\Programs\QwenPaw Desktop.lnk')
if (Test-Path -LiteralPath $pd) { ToBin $pd }

# registry key still there?
if ($entryKey) {
    $kp = $entryKey -replace 'Microsoft\.PowerShell\.Core\\Registry::', ''
    if (Test-Path -LiteralPath ('Registry::' + $kp)) { Write-Output '   [WARN] uninstall registry key still present' }
    else { Write-Output '   registry entry removed' }
}

# space
$eFree1 = [double]0
try { $eFree1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'").FreeSpace } catch { }
Write-Output ('   E: free: ' + (FmtB $eFree0) + ' -> ' + (FmtB $eFree1) + '  (delta ' + (FmtB ($eFree1 - $eFree0)) + ')')
Write-Output '   NOTE: freed space lands when the recycle bin is emptied (bin keeps it until then).'
exit 0
