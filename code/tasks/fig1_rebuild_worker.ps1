# fig1_rebuild_worker.ps1 v3 - detached fig1 rebuild on the machine.
# v3: resume mode (reuse shibielujing1 job if all batches completed in
# playback.json), deps preflight for py -3, and relies on the v2 bridge
# patch (400ms spacing + 3x redelivery + dup-guard) applied by t68.
# ASCII-only.

$ErrorActionPreference = 'Continue'
$root = 'E:\fig1_rebuild'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function L([string]$m) { Write-Output $m }
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

try { Start-Transcript -Path (Join-Path $root 'rebuild.log') -Force | Out-Null } catch { }
try {
    L 'WORKER v3 START'
    # ------------------------------------------------ 0. PATH + python deps
    try {
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    } catch { L 'WARN: PATH refresh failed' }
    $pyOk = $false
    try {
        & py -3 -c "import fontTools, shapely" 2>$null
        if ($LASTEXITCODE -eq 0) { $pyOk = $true; L 'py -3 deps: already OK' }
    } catch { }
    if (-not $pyOk) {
        L 'py -3 missing deps - installing requirements.lock into py -3 ...'
        $lock = 'E:\cell_su7\requirements.lock'
        if (-not (Test-Path -LiteralPath $lock)) { throw ('requirements.lock missing: ' + $lock) }
        & py -3 -m pip install --quiet --disable-pip-version-check -r $lock 2>&1 | ForEach-Object { L ('   pip| ' + (San ([string]$_))) }
        & py -3 -c "import fontTools, shapely" 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'py -3 deps install failed (fontTools/shapely still missing)' }
        L 'py -3 deps installed OK'
    }

    # ------------------------------------------------ 1. locate Illustrator.exe
    $aiExe = $null
    foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
        $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
        if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
    }
    if (-not $aiExe) { throw 'Illustrator.exe not found under E:\' }
    L ('Illustrator.exe: ' + (San $aiExe))

    # ------------------------------------------------ 2. skill + patched runner
    $skillScripts = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts'
    $lct = Join-Path $skillScripts 'run_cell_lct.ps1'
    $alloc = Join-Path $skillScripts 'allocate_shibielujing_name.py'
    $valid = Join-Path $skillScripts 'validate_vector_svg.py'
    foreach ($req in @($lct, $alloc, $valid)) {
        if (-not (Test-Path -LiteralPath $req)) { throw ('missing skill file: ' + $req) }
    }
    if (-not (Select-String -LiteralPath $lct -Pattern 'Invoke-CsAiScript' -Quiet)) { throw 'run_cell_lct.ps1 is not bridge-patched' }
    if (-not (Select-String -LiteralPath $lct -Pattern 'BRIDGE_DUP_GUARD' -Quiet)) { throw 'run_cell_lct.ps1 lacks the v2 bridge patch (t68 must run first)' }
    L 'skill files + bridge v2 patch: OK'

    # ------------------------------------------------ 3. inputs
    $inSvg = Join-Path $root 'fig1_merged.svg'
    $inMan = Join-Path $root 'fig1_text_manifest.json'
    foreach ($req in @($inSvg, $inMan)) {
        if (-not (Test-Path -LiteralPath $req)) { throw ('missing input: ' + $req) }
    }
    L 'inputs present'

    # inline probe helper (mini-bridge for state checks)
    $dir_probe = Join-Path $root 'probe'
    function Probe-Bridge([string]$expr, [int]$seconds) {
        New-Item -ItemType Directory -Force -Path $dir_probe | Out-Null
        $id = [guid]::NewGuid().ToString('N')
        $sf = Join-Path $dir_probe ("p_$id.jsx")
        $rf = Join-Path $dir_probe ("p_$id.result")
        $rfJs = ($rf -replace '\\', '/')
        $jsx = 'var CELL_LCT_RET = String(' + $expr + ');' + "`r`n" + "(function(){try{var w=new File('$rfJs');w.encoding='UTF-8';w.open('w');w.write(String(CELL_LCT_RET));w.close();}catch(e){}})();"
        [IO.File]::WriteAllText($sf, $jsx, $utf8NoBom)
        Start-Process -FilePath $aiExe -ArgumentList @(('"' + $sf + '"'))
        $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
        while ([DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 400
            if (Test-Path -LiteralPath $rf) {
                Start-Sleep -Milliseconds 200
                $txt = [string]([IO.File]::ReadAllText($rf))
                Remove-Item -LiteralPath $rf, $sf -Force -ErrorAction SilentlyContinue
                return $txt
            }
        }
        return 'PROBE_TIMEOUT'
    }

    # ------------------------------------------------ 3.5 resume detection
    $resume = $false
    $base = $null
    $jobRoot = $null
    $resumeRoot = Join-Path $root 'shibielujing1'
    $resumePlayback = Join-Path $resumeRoot '.cell-lct-internal\live-cache\playback.json'
    if (Test-Path -LiteralPath $resumePlayback) {
        try {
            $rst = Get-Content -LiteralPath $resumePlayback -Raw -Encoding UTF8 | ConvertFrom-Json
            $rc = @($rst.batches | Where-Object { $_.completed }).Count
            $rt = @($rst.batches).Count
            if ($rt -gt 0 -and $rc -eq $rt) {
                $resume = $true
                $base = 'shibielujing1'
                $jobRoot = $resumeRoot
                L ('RESUME MODE: ' + $rc + '/' + $rt + ' batches already drawn - final phase only')
            } else { L ('resume check: ' + $rc + '/' + $rt + ' - starting fresh') }
        } catch { L ('resume check parse failed: ' + (San $_.Exception.Message)) }
    }

    if ($resume) {
        # ensure Illustrator running with the job document open
        $aiRunning = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count -gt 0
        $resumeAi = Join-Path $resumeRoot 'shibielujing1.ai'
        if (-not $aiRunning) {
            if (-not (Test-Path -LiteralPath $resumeAi)) { throw 'resume .ai checkpoint missing' }
            L 'Illustrator not running - opening saved .ai checkpoint'
            Start-Process -FilePath $aiExe -ArgumentList @(('"' + $resumeAi + '"'))
            Start-Sleep -Seconds 25
        }
        $docs = Probe-Bridge 'app.documents.length' 90
        L ('probe docs.length: ' + (San $docs))
        if ($docs -eq 'PROBE_TIMEOUT' -or $docs -eq '0') {
            L 'document not open - opening .ai checkpoint'
            Start-Process -FilePath $aiExe -ArgumentList @(('"' + $resumeAi + '"'))
            Start-Sleep -Seconds 25
            $docs = Probe-Bridge 'app.documents.length' 90
            L ('probe docs.length after open: ' + (San $docs))
            if ($docs -eq 'PROBE_TIMEOUT' -or $docs -eq '0') { throw 'could not open the resume document' }
        }
    }

    if (-not $resume) {
        # ------------------------------------------------ 4. clean Illustrator state
        try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Seconds 3

        # ------------------------------------------------ 5. cold launch + 1619x971 doc
        $mkdocResult = Join-Path $root 'mkdoc.result'
        Remove-Item -LiteralPath $mkdocResult -Force -ErrorAction SilentlyContinue
        $mkjsx = '(function(){try{app.documents.add(DocumentColorSpace.RGB,1619,971);var f=new File("E:/fig1_rebuild/mkdoc.result");f.encoding="UTF-8";f.open("w");f.write("OK|docs="+app.documents.length+"|name="+app.activeDocument.name);f.close();}catch(e){var g=new File("E:/fig1_rebuild/mkdoc.result");g.encoding="UTF-8";g.open("w");g.write("ERR|"+e.message);g.close();}})();'
        [IO.File]::WriteAllText((Join-Path $root 'mkdoc.jsx'), $mkjsx, $utf8NoBom)
        Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'mkdoc.jsx') + '"'))
        $deadline = [DateTime]::UtcNow.AddSeconds(150)
        $docInfo = $null
        while ([DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 700
            if (Test-Path -LiteralPath $mkdocResult) { $docInfo = [IO.File]::ReadAllText($mkdocResult); break }
        }
        if (-not $docInfo) { throw 'mkdoc jsx never ran (150s)' }
        L ('mkdoc: ' + (San $docInfo))
        if ($docInfo -notmatch 'OK\|docs=1') { throw ('document creation failed: ' + (San $docInfo)) }

        # ------------------------------------------------ 6. allocate job + layout
        $base = (& py -3 -X utf8 $alloc --root $root | Select-Object -Last 1)
        if (-not $base) { throw 'allocator returned nothing' }
        $base = ([string]$base).Trim()
        if ($base -notmatch '^shibielujing\d+$') { throw ('bad job name: ' + (San $base)) }
        $jobRoot = Join-Path $root $base
        New-Item -ItemType Directory -Force -Path $jobRoot | Out-Null
        Copy-Item -LiteralPath $inSvg -Destination (Join-Path $jobRoot ($base + '.svg')) -Force
        L ('job: ' + $base)

        # ------------------------------------------------ 7. validate svg
        & py -3 -X utf8 $valid --svg (Join-Path $jobRoot ($base + '.svg')) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'svg validation failed on machine' }
        L 'svg validated on machine'
    }

    $outputSvg = Join-Path $jobRoot ($base + '.svg')
    $outputAi = Join-Path $jobRoot ($base + '.ai')
    $outputPng = Join-Path $jobRoot ($base + '.png')
    $internalRoot = Join-Path $jobRoot '.cell-lct-internal\live-cache'
    Copy-Item -LiteralPath $inMan -Destination (Join-Path $jobRoot 'text-manifest.json') -Force

    # ------------------------------------------------ 8. run_cell_lct (child, resume retries)
    $attempt = 0
    $ok = $false
    while ($attempt -lt 3 -and -not $ok) {
        $attempt += 1
        L ('RUN attempt ' + $attempt)
        $runLog = Join-Path $root ('lct_run' + $attempt + '.log')
        $errLog = Join-Path $root ('lct_err' + $attempt + '.log')
        $argList = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $lct + '"'),
            '-InputSvg', ('"' + $outputSvg + '"'),
            '-WorkDir', ('"' + $internalRoot + '"'),
            '-OutputAi', ('"' + $outputAi + '"'),
            '-OutputPng', ('"' + $outputPng + '"'),
            '-Placement', 'center',
            '-MaxWidthFraction', '1.0',
            '-MaxHeightFraction', '1.0',
            '-DelayMs', '0',
            '-MinBatchSize', '20',
            '-MaxBatchSize', '50'
        )
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList ($argList -join ' ') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $runLog -RedirectStandardError $errLog
        $code = $proc.ExitCode
        L ('run_cell_lct exit code: ' + $code)
        if (Test-Path -LiteralPath $runLog) {
            $tail = @(Get-Content -LiteralPath $runLog -Tail 5 -ErrorAction SilentlyContinue)
            foreach ($t in $tail) { L ('   lct| ' + (San ([string]$t))) }
        }
        if ($code -eq 0) { $ok = $true; break }
        L 'retry preparation: checking Illustrator state'
        if (-not (Get-Process -Name Illustrator -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $outputAi) {
                L 'Illustrator gone - reopening the checkpoint .ai'
                Start-Process -FilePath $aiExe -ArgumentList @(('"' + $outputAi + '"'))
                Start-Sleep -Seconds 25
            } else {
                L 'Illustrator gone - relaunching with fresh doc'
                Remove-Item -LiteralPath (Join-Path $root 'mkdoc.result') -Force -ErrorAction SilentlyContinue
                Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'mkdoc.jsx') + '"'))
                $d2 = [DateTime]::UtcNow.AddSeconds(120)
                while ([DateTime]::UtcNow -lt $d2) {
                    Start-Sleep -Milliseconds 700
                    if (Test-Path -LiteralPath (Join-Path $root 'mkdoc.result')) { break }
                }
            }
        }
        Start-Sleep -Seconds 5
    }
    if (-not $ok) { throw ('run_cell_lct failed after ' + $attempt + ' attempts (see lct_run*.log)') }

    # ------------------------------------------------ 9. verify artifacts
    foreach ($p in @($outputAi, $outputPng)) {
        if (-not (Test-Path -LiteralPath $p)) { throw ('missing output: ' + $p) }
        $sz = (Get-Item -LiteralPath $p).Length
        if ($sz -lt 1024) { throw ('output too small: ' + $p + ' = ' + $sz + ' bytes') }
        L ('output OK: ' + $p + ' (' + [int]($sz / 1024) + ' KB)')
    }

    # ------------------------------------------------ 10. close + quit
    $closejsx = '(function(){try{app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);}catch(e){}var f=new File("E:/fig1_rebuild/closed.result");f.encoding="UTF-8";f.open("w");f.write("closed|docs="+app.documents.length);f.close();})();'
    [IO.File]::WriteAllText((Join-Path $root 'closedoc.jsx'), $closejsx, $utf8NoBom)
    Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'closedoc.jsx') + '"'))
    Start-Sleep -Seconds 8
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    L 'Illustrator closed'

    ('REBUILD_DONE|base=' + $base + '|ai=' + $outputAi + '|png=' + $outputPng) | Out-File -FilePath (Join-Path $root 'DONE.marker') -Encoding ascii
    L 'WORKER DONE'
    exit 0
}
catch {
    L ('FATAL: ' + (San ([string]$_.Exception.Message)))
    ('REBUILD_FAILED|' + (San ([string]$_.Exception.Message))) | Out-File -FilePath (Join-Path $root 'FAILED.marker') -Encoding ascii
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
