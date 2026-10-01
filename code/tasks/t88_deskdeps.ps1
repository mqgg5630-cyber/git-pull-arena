# t88_deskdeps.ps1 - round 120 task: finish desktop python deps using the
# DIRECT python.exe path (py launcher location differs on this machine),
# then locate the real py launcher for the worker sessions.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t88: desktop deps via direct python.exe ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$py312 = 'C:\\Users\\BNI\\AppData\\Local\\Programs\\Python\\Python312\\python.exe'

function Invoke-SshCapped([string]$remoteCmd, [int]$capSec) {
    $job = Start-Job -ScriptBlock {
        param($o, $t, $c)
        & ssh @o ($t + '@' + $c[0]) $c[1] 2>&1 | Out-String
    } -ArgumentList $sshBase, $duser, @($desktop, $remoteCmd)
    if (Wait-Job $job -Timeout $capSec) {
        $out = (Receive-Job $job | Out-String).Trim()
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $out
    }
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return '__TIMEOUT__'
}
function Show([string]$tag, [string]$out) {
    if ($out -eq '__TIMEOUT__') { L ('   ' + $tag + ': __TIMEOUT__'); return }
    foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $tag + '| ' + $x) } }
}

# ------------------------------------------------ 1. offline pip via direct python.exe
L '1. offline pip install (300s cap)...'
$out = Invoke-SshCapped ($py312 + ' -m pip install --quiet --disable-pip-version-check --no-index --find-links F:\fig1_rebuild\stage\wheels fonttools shapely') 300
Show 'pip' $out
if ($out -eq '__TIMEOUT__') { L '   [FAIL] pip timed out'; exit 2 }

# ------------------------------------------------ 2. import check via direct python.exe
L '2. import check...'
$out = Invoke-SshCapped ($py312 + ' -c "import fontTools,shapely" && echo DESKTOP_DEPS_OK') 90
Show 'imp' $out
if ($out -notmatch 'DESKTOP_DEPS_OK') { L '   [FAIL] deps import failed'; exit 2 }
L '   DEPS OK (fontTools + shapely import from python 3.12)'

# ------------------------------------------------ 3. locate the py launcher
L '3. py launcher hunt...'
foreach ($cand in @(
    'C:\\Windows\\py.exe',
    'C:\\Users\\BNI\\AppData\\Local\\Programs\\Python\\Launcher\\py.exe',
    'py -3 --version'
)) {
    $out = Invoke-SshCapped ('if exist ' + $cand + ' (echo FOUND ' + $cand + ') else (echo missing ' + $cand + ')') 45
    Show 'cand' $out
}
# does the machine launcher resolve 3.12 now?
$out = Invoke-SshCapped 'C:\\Windows\\py.exe -3 --version' 45
Show 'py3-win' $out
# does the user PATH carry Python312 + launcher (what the worker refresh reads)?
$out = Invoke-SshCapped 'reg query HKCU\Environment /v Path' 45
Show 'userpath' $out

# ------------------------------------------------ 4. AI exe final check
$out = Invoke-SshCapped 'dir /b /s F:\\Adobe*Illustrator*\\Support Files\\Contents\\Windows\\Illustrator.exe 2>nul' 60
Show 'aiexe' $out
L '--- task t88 done ---'
exit 0
