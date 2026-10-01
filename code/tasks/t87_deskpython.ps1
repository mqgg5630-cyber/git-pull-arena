# t87_deskpython.ps1 - round 119 task: get Python 3.12 + deps onto the
# desktop WITHOUT trusting the desktop network:
#   1. ensure python-3.12.10-amd64.exe on the laptop (download via proxy)
#   2. pip download fonttools+shapely wheels (laptop) for offline install
#   3. copy installer + wheels to F:\fig1_rebuild\stage via F$
#   4. silent-install Python on the desktop (ssh, laptop-side 480s cap)
#   5. pip install offline (ssh, laptop-side 300s cap)
#   6. verify py -3 version + imports (full launcher path, no PATH needed)
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t87: desktop python 3.12 via offline kit ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$work = 'E:\fig1_rebuild\desk'
New-Item -ItemType Directory -Force -Path $work | Out-Null

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

# ------------------------------------------------ 1. python installer on laptop
$inst = 'E:\python312_setup.exe'
if (-not (Test-Path -LiteralPath $inst) -or ((Get-Item -LiteralPath $inst -ErrorAction SilentlyContinue).Length -lt 10MB)) {
    L '   downloading python 3.12.10 installer (via proxy)...'
    & curl.exe -sL -x http://127.0.0.1:10808 --max-time 300 -o $inst 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe' 2>&1 | Out-Null
}
if (Test-Path -LiteralPath $inst) {
    L ('   installer: ' + [int]((Get-Item -LiteralPath $inst).Length / 1MB) + ' MB')
} else { L '   [FAIL] installer unavailable'; exit 2 }

# ------------------------------------------------ 2. offline wheels (laptop)
$wheels = Join-Path $work 'wheels'
New-Item -ItemType Directory -Force -Path $wheels | Out-Null
& py -3 -m pip download --quiet --disable-pip-version-check --only-binary :all: -d $wheels fonttools shapely 2>&1 | Out-Null
$whl = @(Get-ChildItem -LiteralPath $wheels -Filter '*.whl' -ErrorAction SilentlyContinue)
$names = @($whl | ForEach-Object { $_.Name -replace '-(cp|py3|win_amd64).*', '' } | Select-Object -Unique)
L ('   wheels: ' + $whl.Count + ' files: ' + ($names -join ', '))
if ($whl.Count -lt 3) { L '   [FAIL] wheel download incomplete'; exit 2 }

# ------------------------------------------------ 3. copy kit to desktop
$fshare = '\\' + $desktop + '\F$'
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
$stage = $fshare + '\fig1_rebuild\stage'
$stageWhl = Join-Path $stage 'wheels'
New-Item -ItemType Directory -Force -Path $stageWhl | Out-Null
Copy-Item -LiteralPath $inst -Destination (Join-Path $stage 'python312.exe') -Force
foreach ($w in $whl) { Copy-Item -LiteralPath $w.FullName -Destination $stageWhl -Force }
& net use $fshare /delete 2>&1 | Out-Null
L '   kit staged on F:\fig1_rebuild\stage (installer + wheels)'

# ------------------------------------------------ 4. silent install on desktop
L '   installing python 3.12 silently on the desktop (480s cap)...'
$out = Invoke-SshCapped 'F:\fig1_rebuild\stage\python312.exe /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1' 480
if ($out -eq '__TIMEOUT__') { L '   [WARN] installer timed out - checking state anyway' }
elseif ($out) { foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   inst| ' + $x) } } }
Start-Sleep -Seconds 5

# ------------------------------------------------ 5. verify version (full launcher path)
$out = Invoke-SshCapped 'C:\Users\BNI\AppData\Local\Programs\Python\Launcher\py.exe -3 --version' 60
L ('   py -3 on desktop: ' + (San $out))
if ($out -notmatch '3\.1[12]') {
    # maybe launcher elsewhere - try plain python from user dir
    $out2 = Invoke-SshCapped 'C:\Users\BNI\AppData\Local\Programs\Python\Python312\python.exe --version' 60
    L ('   python.exe direct: ' + (San $out2))
}

# ------------------------------------------------ 6. offline pip install
L '   offline pip install fonttools+shapely (300s cap)...'
$out = Invoke-SshCapped 'C:\Users\BNI\AppData\Local\Programs\Python\Launcher\py.exe -3 -m pip install --quiet --disable-pip-version-check --no-index --find-links F:\fig1_rebuild\stage\wheels fonttools shapely' 300
if ($out -eq '__TIMEOUT__') { L '   [FAIL] pip install timed out'; exit 2 }
if ($out) { foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   pip| ' + $x) } } }

# ------------------------------------------------ 7. final verify (cmd-safe, no nested quotes)
$out = Invoke-SshCapped 'C:\Users\BNI\AppData\Local\Programs\Python\Launcher\py.exe -3 -c "import fontTools,shapely" && echo DESKTOP_DEPS_OK' 90
L ('   import check: ' + (San $out))
if ($out -match 'DESKTOP_DEPS_OK') { L '   >>> DESKTOP PYTHON READY (3.12 + fontTools + shapely)' }
else { L '   [WARN] import check did not pass - see output above' }
L '--- task t87 done ---'
exit 0
