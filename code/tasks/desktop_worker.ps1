# desktop_worker.ps1 - runs ON THE DESKTOP (BNI@desktop-ieudgs5) in the
# interactive session via the scheduled task 'fig1desk'. Reads
# F:\fig1_rebuild\JOB.marker ("fixture|cell-lct" / "fig1|cell-su7" style:
# MODE|SKILL), executes one full draw job with the selected skill through
# the Illustrator 2020 file bridge, writes DONE/FAILED markers + log.
# ASCII-only.

$ErrorActionPreference = 'Continue'
$root = 'F:\fig1_rebuild'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function L([string]$m) { Write-Output $m }
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

try { Start-Transcript -Path (Join-Path $root 'rebuild.log') -Force | Out-Null } catch { }
try {
    L 'DESKTOP WORKER START'
    $jobMarker = Join-Path $root 'JOB.marker'
    if (-not (Test-Path -LiteralPath $jobMarker)) { throw 'JOB.marker missing' }
    $job = ([string]([IO.File]::ReadAllText($jobMarker))).Trim()
    $parts = $job -split '\|'
    $mode = $parts[0]
    $skillName = if ($parts.Count -gt 1) { $parts[1] } else { 'cell-lct' }
    L ('job: ' + (San $job))

    # ------------------------------------------ 0. PATH + py deps
    try { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') } catch { }
    $pyOk = $false
    try { & py -3 -c "import fontTools, shapely" 2>$null; if ($LASTEXITCODE -eq 0) { $pyOk = $true } } catch { }
    if (-not $pyOk) {
        L 'installing py deps (fontTools, shapely) ...'
        & py -3 -m pip install --quiet --disable-pip-version-check fonttools shapely 2>&1 | ForEach-Object { L ('   pip| ' + (San ([string]$_))) }
        & py -3 -c "import fontTools, shapely" 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'py -3 deps unavailable on desktop' }
    }
    L 'py -3 deps OK'

    # ------------------------------------------ 1. locate Illustrator.exe (F: first, then E:)
    $aiExe = $null
    foreach ($drive in @('F:\', 'E:\')) {
        foreach ($d in @(Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
            $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
            if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
        }
        if ($aiExe) { break }
    }
    if (-not $aiExe) { throw 'Illustrator.exe not found on F:\ or E:\' }
    L ('Illustrator.exe: ' + (San $aiExe))

    # ------------------------------------------ 2. skill runner
    $skillScripts = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('.codex\skills\' + $skillName + '\scripts')
    $lct = Join-Path $skillScripts 'run_cell_lct.ps1'
    if (-not (Test-Path -LiteralPath $lct)) { throw ('skill runner missing: ' + $lct) }
    $runnerText = [string]([IO.File]::ReadAllText($lct))
    if ($runnerText -notmatch 'Invoke-CsAiScript' -or $runnerText -notmatch 'Get-CsIllustratorExe') { throw 'runner is not bridge-patched' }
    L ('skill: ' + (San $skillName))

    # ------------------------------------------ 3. inputs per mode
    if ($mode -eq 'fixture') {
        $inSvg = Join-Path $root 'test_fixture.svg'
        $jobRoot = Join-Path $root ('test-' + $skillName)
        if (Test-Path -LiteralPath $jobRoot) { Remove-Item -LiteralPath $jobRoot -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Force -Path $jobRoot | Out-Null
        $outAi = Join-Path $jobRoot ('test_' + $skillName + '.ai')
        $outPng = Join-Path $jobRoot ('test_' + $skillName + '.png')
        $maxW = '0.5'; $maxH = '0.5'; $minB = '5'
    }
    elseif ($mode -eq 'fig1') {
        $inSvg = Join-Path $root 'fig1_merged.svg'
        if (-not (Test-Path -LiteralPath (Join-Path $root 'fig1_text_manifest.json'))) { throw 'fig1 manifest missing' }
        $alloc = Join-Path $skillScripts 'allocate_shibielujing_name.py'
        $jobsRoot = Join-Path $root 'jobs'
        New-Item -ItemType Directory -Force -Path $jobsRoot | Out-Null
        $base = (& py -3 -X utf8 $alloc --root $jobsRoot | Select-Object -Last 1)
        $base = ([string]$base).Trim()
        if ($base -notmatch '^shibielujing\d+$') { throw ('bad job name: ' + (San $base)) }
        $jobRoot = Join-Path $jobsRoot $base
        New-Item -ItemType Directory -Force -Path $jobRoot | Out-Null
        Copy-Item -LiteralPath $inSvg -Destination (Join-Path $jobRoot ($base + '.svg')) -Force
        Copy-Item -LiteralPath (Join-Path $root 'fig1_text_manifest.json') -Destination (Join-Path $jobRoot 'text-manifest.json') -Force
        $inSvg = Join-Path $jobRoot ($base + '.svg')
        $outAi = Join-Path $jobRoot ($base + '.ai')
        $outPng = Join-Path $jobRoot ($base + '.png')
        $maxW = '1.0'; $maxH = '1.0'; $minB = '20'
        L ('job name: ' + $base)
    }
    else { throw ('unknown mode: ' + (San $mode)) }
    if (-not (Test-Path -LiteralPath $inSvg)) { throw ('input svg missing: ' + $inSvg) }
    $valid = Join-Path $skillScripts 'validate_vector_svg.py'
    & py -3 -X utf8 $valid --svg $inSvg | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'svg validation failed on desktop' }
    L 'svg validated'

    # ------------------------------------------ 4. fresh Illustrator + document
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    Start-Sleep -Seconds 3
    $mkdocResult = Join-Path $root 'mkdoc.result'
    $mkjsx = '(function(){try{app.documents.add(DocumentColorSpace.RGB,1619,971);var f=new File("F:/fig1_rebuild/mkdoc.result");f.encoding="UTF-8";f.open("w");f.write("OK|docs="+app.documents.length);f.close();}catch(e){var g=new File("F:/fig1_rebuild/mkdoc.result");g.encoding="UTF-8";g.open("w");g.write("ERR|"+e.message);g.close();}})();'
    [IO.File]::WriteAllText((Join-Path $root 'mkdoc.jsx'), $mkjsx, $utf8NoBom)
    $docInfo = $null
    for ($try = 1; $try -le 2 -and -not $docInfo; $try++) {
        Remove-Item -LiteralPath $mkdocResult -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'mkdoc.jsx') + '"'))
        $deadline = [DateTime]::UtcNow.AddSeconds(150)
        while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $mkdocResult)) { Start-Sleep -Milliseconds 700 }
        if (Test-Path -LiteralPath $mkdocResult) { $docInfo = [IO.File]::ReadAllText($mkdocResult) }
        if (-not $docInfo) { L ('mkdoc attempt ' + $try + ' timed out'); Start-Sleep -Seconds 3 }
    }
    if (-not $docInfo) { throw 'mkdoc jsx never ran' }
    L ('mkdoc: ' + (San $docInfo))
    if ($docInfo -notmatch 'OK\|docs=1') { throw ('doc creation failed: ' + (San $docInfo)) }

    # ------------------------------------------ 5. run the skill runner
    $runLog = Join-Path $root 'lct_run.log'
    $errLog = Join-Path $root 'lct_err.log'
    $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $lct + '"'),
        '-InputSvg', ('"' + $inSvg + '"'),
        '-WorkDir', ('"' + (Join-Path $jobRoot 'live-cache') + '"'),
        '-OutputAi', ('"' + $outAi + '"'),
        '-OutputPng', ('"' + $outPng + '"'),
        '-Placement', 'center',
        '-MaxWidthFraction', $maxW,
        '-MaxHeightFraction', $maxH,
        '-DelayMs', '0',
        '-MinBatchSize', $minB,
        '-MaxBatchSize', '50'
    )
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList ($argList -join ' ') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $runLog -RedirectStandardError $errLog
    L ('runner exit code: ' + $proc.ExitCode)
    if (Test-Path -LiteralPath $runLog) {
        foreach ($t in @(Get-Content -LiteralPath $runLog -Tail 5 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   lct| ' + $x) } }
    }
    if ($proc.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $errLog) { foreach ($t in @(Get-Content -LiteralPath $errLog -Tail 6 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   err| ' + $x) } } }
        throw ('runner failed, exit ' + $proc.ExitCode)
    }

    # ------------------------------------------ 6. verify + probe (fixture)
    foreach ($p in @($outAi, $outPng)) {
        if (-not (Test-Path -LiteralPath $p)) { throw ('missing output: ' + $p) }
        L ('output OK: ' + $p + ' (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)')
    }
    if ($mode -eq 'fixture') {
        $probeFile = Join-Path $root 'probe.result'
        $probeJsx = '(function(){try{var d=app.activeDocument;var s="tf="+d.textFrames.length+"|pi="+d.pathItems.length;var f=new File("F:/fig1_rebuild/probe.result");f.encoding="UTF-8";f.open("w");f.write(s);f.close();}catch(e){var g=new File("F:/fig1_rebuild/probe.result");g.encoding="UTF-8";g.open("w");g.write("ERR|"+e.message);g.close();}})();'
        [IO.File]::WriteAllText((Join-Path $root 'probe.jsx'), $probeJsx, $utf8NoBom)
        Remove-Item -LiteralPath $probeFile -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'probe.jsx') + '"'))
        $deadline = [DateTime]::UtcNow.AddSeconds(90)
        while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $probeFile)) { Start-Sleep -Milliseconds 400 }
        if (Test-Path -LiteralPath $probeFile) { L ('object probe: ' + (San ([string]([IO.File]::ReadAllText($probeFile))))) }
        else { L 'object probe: TIMEOUT' }
    }

    # ------------------------------------------ 7. close + quit
    $closejsx = '(function(){try{app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);}catch(e){}var f=new File("F:/fig1_rebuild/closed.result");f.encoding="UTF-8";f.open("w");f.write("closed");f.close();})();'
    [IO.File]::WriteAllText((Join-Path $root 'closedoc.jsx'), $closejsx, $utf8NoBom)
    Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'closedoc.jsx') + '"'))
    Start-Sleep -Seconds 8
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }

    ('DESKTOP_DONE|mode=' + $mode + '|skill=' + $skillName + '|ai=' + $outAi + '|png=' + $outPng) | Out-File -FilePath (Join-Path $root 'DONE.marker') -Encoding ascii
    Remove-Item -LiteralPath $jobMarker -Force -ErrorAction SilentlyContinue
    L 'DESKTOP WORKER DONE'
    exit 0
}
catch {
    L ('FATAL: ' + (San ([string]$_.Exception.Message)))
    ('DESKTOP_FAILED|' + (San ([string]$_.Exception.Message))) | Out-File -FilePath (Join-Path $root 'FAILED.marker') -Encoding ascii
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
