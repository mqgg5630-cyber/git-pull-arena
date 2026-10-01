# t88_deskdeps.ps1 v2 - round 121 task: finish desktop verification using
# ONLY quote-free remote commands (the desktop sshd shell strips embedded
# quotes, which broke python -c). Dependency check runs a .py file staged
# via F$; every ssh call reports the remote exit code.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t88 v2: desktop deps (quote-free commands) ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$py312 = 'C:\Users\BNI\AppData\Local\Programs\Python\Python312\python.exe'

function Invoke-SshCapped([string]$remoteCmd, [int]$capSec) {
    $job = Start-Job -ScriptBlock {
        param($o, $t, $c)
        $x = (& ssh @o ($t + '@' + $c[0]) $c[1] 2>&1 | Out-String).Trim()
        $x + "`nREMOTE_EXIT=$LASTEXITCODE"
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

# ------------------------------------------------ 0. which remote shell?
$out = Invoke-SshCapped 'echo %PROCESSOR_ARCHITECTURE%' 45
Show 'shell' $out
L ('   (literal percent signs above => remote shell is PowerShell; expanded => cmd)')

# ------------------------------------------------ 1. stage depcheck.py via F$
$fshare = '\\' + $desktop + '\F$'
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
$dep = @'
import fontTools, shapely, sys
print('DEPS_IMPORT_OK py=' + sys.version.split()[0])
'@
[IO.File]::WriteAllText(($fshare + '\fig1_rebuild\depcheck.py'), ($dep -replace "`r?`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
& net use $fshare /delete 2>&1 | Out-Null
L '   depcheck.py staged'

# ------------------------------------------------ 2. offline pip (idempotent, quote-free)
$out = Invoke-SshCapped ($py312 + ' -m pip install --quiet --disable-pip-version-check --no-index --find-links F:\fig1_rebuild\stage\wheels fonttools shapely') 300
Show 'pip' $out

# ------------------------------------------------ 3. dependency import check via file
$out = Invoke-SshCapped ($py312 + ' F:\fig1_rebuild\depcheck.py') 90
Show 'dep' $out
if ($out -notmatch 'DEPS_IMPORT_OK') { L '   [FAIL] deps import failed'; exit 2 }
L '   DEPS OK'

# ------------------------------------------------ 4. py launcher hunt (quote-free)
$out = Invoke-SshCapped 'cmd /c where py' 45
Show 'where-py' $out
$out = Invoke-SshCapped 'C:\Windows\py.exe -3 --version' 45
Show 'py3-win' $out

# ------------------------------------------------ 5. user PATH (worker refresh source)
$out = Invoke-SshCapped 'reg query HKCU\Environment /v Path' 45
Show 'userpath' $out

# ------------------------------------------------ 6. AI exe on F: (quote-free PS)
$out = Invoke-SshCapped 'powershell -NoProfile -Command Get-ChildItem F:\ -Name -Filter *Illustrator*' 60
Show 'ai-dir' $out
$out = Invoke-SshCapped 'powershell -NoProfile -Command Test-Path F:\fig1_rebuild\desktop_worker.ps1' 45
Show 'worker-present' $out
L '--- task t88 v2 done ---'
exit 0
