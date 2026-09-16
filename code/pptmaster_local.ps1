# pptmaster_local.ps1 - install PPT Master on THIS Windows machine and prove it
# works here, then hand the result back to code/pptmaster_pipeline.py (which
# authors a deck from this repo, compiles it and verifies the pptx).
#
# Run by code/local_check.ps1 during a verification round, so the agent's
# self-loop covers the two questions a sandbox can never answer about this
# machine: "is PPT Master installed here" and "does it produce a good pptx
# here".
#
# What it does
#   1. git clone https://github.com/hugohe3/ppt-master.git  ->  <parent>\ppt-master
#      (shallow, network bounded; skipped when present, -Update shallow-pulls)
#   2. find a python 3.10+ (py -3 / python / conda / well-known paths) and prove
#      it with a real import test - never trust PATH alone
#   3. venv at <install>\.venv + pip install (core set first, then the full
#      requirements.txt best effort)
#   4. run code\pptmaster_pipeline.py: attribution_guard -> author the 12 SVG
#      pages from this repo -> svg_quality_checker -> svg_to_pptx -> structural
#      verification of the produced file
#   5. open that file read-only in the real PowerPoint and count its slides
#   6. write results\status\pptmaster_local.json / .txt (the receipt the watcher
#      pushes back) and <install>\make-deck.cmd (one-click local regeneration)
#
# ASCII-only on purpose (Windows PowerShell 5.1 decodes .ps1 as ANSI/GBK).
# Exit 0 = installed + verified, anything else = the round fails and the log
# above says why.

param(
    [switch]$Update,          # shallow-update an existing clone first
    [switch]$SkipInstall,     # verify + regenerate only (no clone/venv/pip)
    [switch]$SkipCom,         # do not open PowerPoint
    [string]$Root = '',       # install parent dir (default: the repo's parent)
    [string]$Repo = '',       # repo root (default: this script's parent)
    [string]$Project = 'arena-local-01a0aa00',
    [int]$ExpectSlides = 12
)

$ErrorActionPreference = 'Continue'
$fail = 0
$remote = 'https://github.com/hugohe3/ppt-master.git'
$corePkgs = @('PyYAML', 'python-pptx', 'XlsxWriter', 'skia-pathops', 'uharfbuzz',
              'Pillow', 'numpy')

function Say($msg) { Write-Output ('PPTMASTER: ' + $msg) }

# Run a native command and return both its output and its exit code, so the
# caller never has to reason about $LASTEXITCODE scope or array indexing.
function Run-Native {
    param([string]$Exe, [string[]]$ArgList)
    if (-not $ArgList) { $ArgList = @() }
    # [string] keeps $out a string even when the command prints nothing, so
    # callers can always call .Trim() on it
    $out = [string](& $Exe @ArgList 2>&1 | Out-String)
    return @{ out = $out; code = $LASTEXITCODE }
}

function Test-Py {
    param([string]$Exe, [string[]]$Pre)
    if (-not $Exe) { return '' }
    # a bare command name ("py", "python") resolves through PATH, so only check
    # Test-Path when we were handed an actual filesystem path
    if ($Exe -match '[\\/:]' -and -not (Test-Path -LiteralPath $Exe)) { return '' }
    $probe = 'import sys; print("%d.%d.%d" % sys.version_info[:3]); sys.exit(0 if sys.version_info>=(3,10) else 1)'
    $r = Run-Native $Exe (@($Pre) + @('-c', $probe))
    if ($r.code -eq 0) { return $r.out.Trim() }
    return ''
}

# ------------------------------------------------- 0. preliminary receipt
# If this run dies anywhere below, the repo must not keep a previous receipt
# pretending this machine verified the install. Write an honest "not installed
# (yet)" receipt first; the pipeline overwrites it on success.
if (-not $Repo) { $Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path }
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if (-not $Root) { $Root = Split-Path -Parent $Repo }
$Install = Join-Path $Root 'ppt-master'
$Scripts = Join-Path $Install 'skills\ppt-master\scripts'
$VenvDir = Join-Path $Install '.venv'
$VenvPy = Join-Path $VenvDir 'Scripts\python.exe'
$StatePath = Join-Path $Install '.git-sync-install.json'
$host_ = [string]$env:COMPUTERNAME
$recDir = Join-Path $Repo 'results\status'
$recJson = Join-Path $recDir 'pptmaster_local.json'
$recTxt = Join-Path $recDir 'pptmaster_local.txt'

if (Test-Path -LiteralPath $recDir) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $preTxt = 'pptmaster-FAIL environment=windows host=' + $host_ + "`n" +
              'deck_slides=None checker_blocking=None markers=FAIL powerpoint=na' + "`n" +
              'python=n/a deps_core=n/a deps_full=n/a slides_svg=0 export=n/a' + "`n" +
              'install_dir=' + $Install + "`n" +
              'note=run started at ' + $stamp + '; a completed run rewrites this file'
    $preJson = @{
        schema        = 'git-pull-arena.pptmaster-local.v1'
        environment   = 'windows'
        host          = $host_
        installed     = $false
        generated_utc = $stamp
        install_dir   = $Install
        note          = 'run started; rewritten when the pipeline finishes'
    } | ConvertTo-Json
    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($recTxt, $preTxt, $utf8)
        [System.IO.File]::WriteAllText($recJson, ($preJson + "`n"), $utf8)
    } catch {
        Say ('[WARN] could not write the preliminary receipt: ' + $_.Exception.Message)
    }
}

Say ('repo    : ' + $Repo)
Say ('install : ' + $Install)
Say ('host    : ' + $host_)

# ------------------------------------------------------------------ 1. clone
$gitExe = ''
$g = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
if ($g -and $g.Source) { $gitExe = [string]$g.Source }
else {
    $gitBases = @()
    if ($env:ProgramFiles) { $gitBases += $env:ProgramFiles }
    if (${env:ProgramFiles(x86)}) { $gitBases += ${env:ProgramFiles(x86)} }
    foreach ($baseDir in $gitBases) {
        $cand = Join-Path $baseDir 'Git\cmd\git.exe'
        if (Test-Path -LiteralPath $cand) { $gitExe = $cand; break }
    }
}
if ($gitExe) { Say ('git     : ' + $gitExe) } else { Say 'git     : NOT FOUND' }

$cloneMarker = Join-Path $Scripts 'svg_to_pptx.py'
if (-not (Test-Path -LiteralPath $cloneMarker)) {
    if ($SkipInstall) {
        Say '[FAIL] ppt-master is not installed yet (run again without -SkipInstall)'
        exit 1
    }
    if (-not $gitExe) {
        Say '[FAIL] git is required to install ppt-master'
        exit 1
    }
    if (Test-Path -LiteralPath $Install) {
        $junk = @(Get-ChildItem -LiteralPath $Install -Force -ErrorAction SilentlyContinue)
        if ($junk.Count -gt 0) {
            Say ('[FAIL] ' + $Install + ' exists but is not a usable clone - move it away first')
            exit 1
        }
    }
    Say 'cloning'
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GIT_ASKPASS = 'echo'
    # lowSpeed* bounds a stalled transfer, so a round can never hang on the network
    $r = Run-Native $gitExe @('-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=60',
                              'clone', '--depth', '1', $remote, $Install)
    if ($r.out.Trim()) { Say $r.out.TrimEnd() }
    if ($r.code -ne 0 -or -not (Test-Path -LiteralPath $cloneMarker)) {
        Say ('[FAIL] git clone failed (exit ' + $r.code + ')')
        if (-not (Test-Path -LiteralPath (Join-Path $Install '.git'))) {
            # only remove a directory this run created - never touch anything else
            Remove-Item -LiteralPath $Install -Recurse -Force -ErrorAction SilentlyContinue
            Say 'partial clone removed so the next round can start clean'
        }
        exit 1
    }
    Say 'clone done'
} else {
    Say 'already cloned'
    if ($Update -and $gitExe) {
        Say 'updating (shallow fetch + reset)'
        $env:GIT_TERMINAL_PROMPT = '0'
        $r1 = Run-Native $gitExe @('-C', $Install, 'fetch', '--depth', '1', 'origin', 'HEAD')
        $r2 = Run-Native $gitExe @('-C', $Install, 'reset', '--hard', 'FETCH_HEAD')
        if ($r1.out.Trim()) { Say $r1.out.TrimEnd() }
        if ($r2.out.Trim()) { Say $r2.out.TrimEnd() }
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $Install 'skills\ppt-master\SKILL.md'))) {
    Say '[FAIL] clone is incomplete: skills\ppt-master\SKILL.md is missing'
    exit 1
}

# --------------------------------------------------------------- 2. python
# The scheduled task does NOT inherit an activated conda shell, so a machine
# whose python only exists inside a conda env has no working python on PATH
# (round 26: "no python 3.10+ found" while E:\spider\python.exe was right
# there). Look in every place that can name one, in order of confidence:
#   explicit env var -> venv -> PATH -> conda base -> the repo's OWN hardware
#   report -> the Windows registry -> the well-known install dirs -> py launcher
$pyCands = New-Object System.Collections.ArrayList
function Add-Cand($cand) {
    if (-not $cand) { return }
    $c = [string]$cand
    if (-not $c) { return }
    if (-not $pyCands.Contains($c)) { [void]$pyCands.Add($c) }
}

if ($env:GIT_SYNC_PPTMASTER_PYTHON) { Add-Cand $env:GIT_SYNC_PPTMASTER_PYTHON }
foreach ($name in @('python', 'python.exe', 'python3', 'python3.exe')) {
    $c = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c -and $c.Source) { Add-Cand ([string]$c.Source) }
}
if ($env:CONDA_PREFIX) { Add-Cand (Join-Path $env:CONDA_PREFIX 'python.exe') }
$condaCmd = Get-Command conda -ErrorAction SilentlyContinue | Select-Object -First 1
if ($condaCmd -and $condaCmd.Source) {
    $base = (Run-Native ([string]$condaCmd.Source) @('info', '--base')).out.Trim()
    if ($base -and (Test-Path -LiteralPath $base)) { Add-Cand (Join-Path $base 'python.exe') }
}
$hwReport = Join-Path $Repo 'results\hardware\latest.json'
if (Test-Path -LiteralPath $hwReport) {
    try {
        $hwj = Get-Content -LiteralPath $hwReport -Raw -Encoding UTF8 | ConvertFrom-Json
        $globalPy = [string]$hwj.python.global_python
        if ($globalPy -and $globalPy -match '\(([^)]+)\)') { Add-Cand $Matches[1] }
        foreach ($e in @($hwj.python.envs)) {
            if ($e.path) { Add-Cand (Join-Path ([string]$e.path) 'python.exe') }
        }
    } catch {
        Say ('[WARN] could not read the hardware report for python paths: ' + $_.Exception.Message)
    }
}
foreach ($root in @('HKLM:\SOFTWARE\Python\PythonCore', 'HKCU:\SOFTWARE\Python\PythonCore',
                    'HKLM:\SOFTWARE\Python\ContinuumAnalytics')) {
    try {
        foreach ($key in @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $ip = Join-Path $key.PSPath 'InstallPath'
            if (-not (Test-Path -LiteralPath $ip)) { continue }
            $val = Get-ItemProperty -Path $ip -ErrorAction SilentlyContinue
            if ($val.ExecutablePath) { Add-Cand ([string]$val.ExecutablePath) }
            $def = $val.'(default)'
            if ($def) { Add-Cand (Join-Path ([string]$def) 'python.exe') }
        }
    } catch { }
}
foreach ($dir in @($env:ProgramData, $env:LOCALAPPDATA, $env:USERPROFILE)) {
    if (-not $dir) { continue }
    foreach ($name in @('miniconda3', 'anaconda3', 'Programs\Python\Python313',
                        'Programs\Python\Python312', 'Programs\Python\Python311',
                        'Programs\Python\Python310')) {
        Add-Cand (Join-Path (Join-Path $dir $name) 'python.exe')
    }
}
foreach ($p in @('E:\spider\python.exe', 'E:\spyder\python.exe', 'C:\Python313\python.exe',
                 'C:\Python312\python.exe', 'C:\Python311\python.exe', 'C:\Python310\python.exe')) {
    Add-Cand $p
}
if ($env:ProgramFiles) { Add-Cand (Join-Path $env:ProgramFiles 'Python313\python.exe') }

$basePy = ''
$basePre = @()
$baseVer = ''
if (Test-Path -LiteralPath $VenvPy) {
    $basePy = $VenvPy
    $baseVer = Test-Py -Exe $VenvPy -Pre @()
} else {
    foreach ($c in $pyCands) {
        $v = Test-Py -Exe $c -Pre @()
        if ($v) { $basePy = $c; $baseVer = $v; break }
    }
    if (-not $basePy) {
        foreach ($ver in @('-3', '-3.13', '-3.12', '-3.11', '-3.10')) {
            $v = Test-Py -Exe 'py' -Pre @($ver)
            if ($v) { $basePy = 'py'; $basePre = @($ver); $baseVer = $v; break }
        }
    }
}
if (-not $basePy -or -not $baseVer) {
    Say ('[FAIL] no python 3.10+ found; tried ' + $pyCands.Count + ' candidate(s):')
    foreach ($c in $pyCands) { Say ('        - ' + $c) }
    Say '        set GIT_SYNC_PPTMASTER_PYTHON to the python.exe to use'
    exit 1
}
Say ('python  : ' + $basePy + ' ' + $baseVer)

# ----------------------------------------------------------------- 3. venv
$pyExe = $basePy
$pyPre = $basePre
$pyMode = 'base'
if (Test-Path -LiteralPath $VenvPy) {
    $pyExe = $VenvPy
    $pyPre = @()
    $pyMode = 'venv'
    Say 'venv    : present'
} elseif ($SkipInstall) {
    Say '[FAIL] venv is missing and -SkipInstall was given'
    exit 1
} else {
    Say 'venv    : creating'
    $r = Run-Native $basePy (@($basePre) + @('-m', 'venv', $VenvDir))
    if ($r.out.Trim()) { Say $r.out.TrimEnd() }
    if (Test-Path -LiteralPath $VenvPy) {
        $pyExe = $VenvPy
        $pyPre = @()
        $pyMode = 'venv'
        Say 'venv    : created'
    } else {
        Say '[WARN] venv creation failed - falling back to the base interpreter with --user'
        $pyMode = 'user'
    }
}
$pyVer = Test-Py -Exe $pyExe -Pre $pyPre
if (-not $pyVer) {
    Say ('[FAIL] ' + $pyExe + ' cannot run python 3.10+ code')
    exit 1
}

# ------------------------------------------------------------- 4. deps pip
$pmCommit = ''
if ($gitExe) { $pmCommit = (Run-Native $gitExe @('-C', $Install, 'rev-parse', '--short', 'HEAD')).out.Trim() }
$state = $null
if (Test-Path -LiteralPath $StatePath) {
    try { $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}
$coreOk = $false
$fullOk = $false
if ($state -and $state.commit -eq $pmCommit -and $state.deps_core_ok -eq $true) {
    $coreOk = $true
    $fullOk = ($state.deps_full_ok -eq $true)
    Say ('deps    : already installed for ' + $pmCommit + ' (core ok, full ' + $fullOk + ')')
}

if (-not $coreOk) {
    if ($SkipInstall) {
        Say '[FAIL] dependencies are not installed for this commit and -SkipInstall was given'
        exit 1
    }
    Say 'deps    : pip install (core)'
    $pipBase = @('-m', 'pip', 'install', '--disable-pip-version-check', '--quiet',
                 '--timeout', '60', '--retries', '2')
    if ($pyMode -eq 'user') { $pipBase += '--user' }
    $r = Run-Native $pyExe (@($pyPre) + $pipBase + @('--only-binary', ':all:') + $corePkgs)
    if ($r.code -ne 0) {
        Say 'deps    : wheel-only install failed, retrying without --only-binary'
        $r = Run-Native $pyExe (@($pyPre) + $pipBase + $corePkgs)
    }
    if ($r.code -ne 0) {
        # ppt-master's own Windows guide suggests a mirror when PyPI is slow or
        # blocked; try it before giving up on the round
        Say 'deps    : retrying through the Tsinghua PyPI mirror'
        $mirror = @('-i', 'https://pypi.tuna.tsinghua.edu.cn/simple',
                    '--trusted-host', 'pypi.tuna.tsinghua.edu.cn')
        $r = Run-Native $pyExe (@($pyPre) + $pipBase + $mirror + $corePkgs)
    }
    if ($r.code -eq 0) {
        $coreOk = $true
        Say 'deps    : core ok'
    } else {
        Say '[FAIL] pip install of the core dependencies failed'
        if ($r.out.Trim()) { Say $r.out.TrimEnd() }
    }
}

if ($coreOk -and -not $fullOk -and -not $SkipInstall) {
    $req = Join-Path $Install 'requirements.txt'
    if (Test-Path -LiteralPath $req) {
        Say 'deps    : pip install -r requirements.txt (optional extras, best effort)'
        $fullBase = @('-m', 'pip', 'install', '--disable-pip-version-check', '--quiet',
                      '--timeout', '60', '--retries', '1')
        if ($pyMode -eq 'user') { $fullBase += '--user' }
        $r = Run-Native $pyExe (@($pyPre) + $fullBase + @('-r', $req))
        if ($r.code -eq 0) {
            $fullOk = $true
            Say 'deps    : full requirements ok'
        } else {
            Say '[WARN] optional extras did not all install - the deck pipeline only needs the core set'
        }
    }
}

# ------------------------------------------------ 5. pipeline + verification
$pipeScript = Join-Path $Repo 'code\pptmaster_pipeline.py'
if (-not (Test-Path -LiteralPath $pipeScript)) {
    Say '[FAIL] code\pptmaster_pipeline.py is missing from the repo'
    exit 1
}
$depsFullFlag = '-1'
if ($fullOk) { $depsFullFlag = '1' } elseif ($coreOk) { $depsFullFlag = '0' }
$r = Run-Native $pyExe (@($pyPre) + @($pipeScript, '--ppt-master', $Install, '--python', $pyExe,
                            '--repo', $Repo, '--project', $Project, '--environment', 'windows',
                            '--host', $host_, '--expect-slides', [string]$ExpectSlides,
                            '--python-mode', $pyMode, '--deps-full-ok', $depsFullFlag))
$pipeCode = $r.code
if ($r.out.Trim()) { Write-Output $r.out.TrimEnd() }

# ------------------------------------------------ 6. real PowerPoint opening
$deck = $null
$outDir = Join-Path $Install 'out'
if (Test-Path -LiteralPath $outDir) {
    $deck = Get-ChildItem -LiteralPath $outDir -Filter 'DECK_local_*.pptx' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1
}
$comResult = 'skip no deck to open'
if ($deck -and -not $SkipCom) {
    $progId = ''
    foreach ($cand in @('PowerPoint.Application', 'KWPP.Application', 'WPP.Application')) {
        if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + $cand)) { $progId = $cand; break }
    }
    if (-not $progId) {
        $comResult = 'skip no registered PowerPoint COM server'
    } elseif ([string]$env:GIT_SYNC_PPTMASTER_COM -eq '0') {
        $comResult = 'skip COM disabled by GIT_SYNC_PPTMASTER_COM'
    } else {
        $job = $null
        try {
            $job = Start-Job -ArgumentList $progId, $deck.FullName -ScriptBlock {
                param($srv, $path)
                $app = New-Object -ComObject $srv
                try {
                    $pres = $app.Presentations.Open($path, $true, $false, $false)
                    $n = [int]$pres.Slides.Count
                    $pres.Close()
                    return ('ok slides=' + $n)
                } finally {
                    try { $app.Quit() } catch { }
                }
            }
            $done = Wait-Job $job -Timeout 180
            if (-not $done) {
                $comResult = 'skip PowerPoint did not answer in 180s'
                Stop-Job $job -ErrorAction SilentlyContinue
            } elseif ($job.State -eq 'Completed') {
                $comResult = (((Receive-Job $job | Out-String) -replace '\s+$', ''))
            } else {
                $err = (((Receive-Job $job 2>&1 | Out-String) -replace '\s+$', ''))
                $comResult = 'fail ' + $err
            }
        } catch {
            $comResult = 'skip ' + $_.Exception.Message
        } finally {
            if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
        }
    }
}
Say ('powerpoint: ' + $comResult)

$r = Run-Native $pyExe (@($pyPre) + @($pipeScript, '--ppt-master', $Install, '--python', $pyExe,
                            '--repo', $Repo, '--patch-com', $comResult))
$patchCode = $r.code
if ($r.out.Trim()) { Write-Output $r.out.TrimEnd() }

# ------------------------------------------------- 7. the one-click launcher
# so the user can regenerate the deck locally without the agent
try {
    $cmdPath = Join-Path $Install 'make-deck.cmd'
    $cmdBody = @(
        '@echo off',
        'title PPT Master - regenerate the deck for this repo',
        'set "PM=' + $Install + '"',
        'set "PY=' + $pyExe + '"',
        'set "REPO=' + $Repo + '"',
        '"%PY%" "%REPO%\code\pptmaster_pipeline.py" --ppt-master "%PM%" --python "%PY%" --repo "%REPO%" --environment windows --host %COMPUTERNAME% --python-mode venv',
        'if errorlevel 1 (',
        '  echo.',
        '  echo The deck was NOT regenerated - see the messages above.',
        '  pause',
        '  exit /b 1',
        ')',
        'echo.',
        'echo Opening the deck PPT Master just built...',
        'for %%f in ("%PM%\out\DECK_local_*.pptx") do start "" "%%f"'
    ) -join "`r`n"
    $needsWrite = $true
    if (Test-Path -LiteralPath $cmdPath) {
        try {
            if (([System.IO.File]::ReadAllText($cmdPath)) -eq ($cmdBody + "`r`n")) { $needsWrite = $false }
        } catch { }
    }
    if ($needsWrite) {
        $ascii = New-Object System.Text.ASCIIEncoding
        [System.IO.File]::WriteAllText($cmdPath, ($cmdBody + "`r`n"), $ascii)
        Say ('launcher: ' + $cmdPath + ' (double-click to rebuild the deck here)')
    }
} catch {
    Say ('[WARN] could not write make-deck.cmd: ' + $_.Exception.Message)
}

# ---------------------------------------------------------------- 8. state
try {
    $stateOut = @{
        commit         = $pmCommit
        python         = $pyExe
        python_mode    = $pyMode
        python_version = $pyVer
        deps_core_ok   = [bool]$coreOk
        deps_full_ok   = [bool]$fullOk
        installed_at   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    } | ConvertTo-Json
    $stateOut | Set-Content -LiteralPath $StatePath -Encoding UTF8
} catch {
    Say ('[WARN] could not write .git-sync-install.json: ' + $_.Exception.Message)
}

if (-not $coreOk) { $fail = 1 }
if ($pipeCode -ne 0) { $fail = 1 }
if ($patchCode -ne 0) { $fail = 1 }
if ($comResult.StartsWith('fail')) { $fail = 1 }

if ($fail -eq 0) {
    Say 'local install verified: python + deps + guard + checker + export + PowerPoint open'
    Say ('run it by hand: ' + $pyExe + ' ' + (Join-Path $Scripts 'svg_to_pptx.py') + ' <project> --quick-generate')
    Say ('or double-click: ' + (Join-Path $Install 'make-deck.cmd'))
} else {
    Say '[FAIL] the local PPT Master install did not verify - see the lines above'
}
exit $fail
