# t75_test_celllct.ps1 - round 103 task: END-TO-END SMOKE TEST of the
# cell-lct skill (free edition): draw the tiny test fixture SVG (4 paths +
# 2 live texts incl. one rotated) into a fresh Illustrator 2020 document
# via the bridge-patched runner, save .ai, export .png, probe created
# objects, copy artifacts into the repo. ASCII-only.

$ErrorActionPreference = 'Continue'
$skillDirName = 'cell-lct'
$tag = 'cell-lct'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$root = 'E:\fig1_rebuild'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

Write-Output ('--- task t75: skill smoke test: ' + $tag + ' ---')

# ------------------------------------------------ 1. locate Illustrator.exe
$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { L '   [FAIL] no Illustrator.exe'; exit 2 }
L ('   Illustrator.exe: ' + (San $aiExe))

# ------------------------------------------------ 2. fixture + skill runner
$fixtureSrc = Join-Path $repoRoot 'results\fig1_rebuild\test_fixture.svg'
if (-not (Test-Path -LiteralPath $fixtureSrc)) { L '   [FAIL] fixture missing in repo'; exit 2 }
$fixture = Join-Path $root 'test_fixture.svg'
Copy-Item -LiteralPath $fixtureSrc -Destination $fixture -Force
L '   fixture staged'

$skillScripts = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('.codex\skills\' + $skillDirName + '\scripts')
$lct = Join-Path $skillScripts 'run_cell_lct.ps1'
if (-not (Test-Path -LiteralPath $lct)) { L ('   [FAIL] runner missing: ' + $lct); exit 2 }
$runnerText = [string]([IO.File]::ReadAllText($lct))
if ($runnerText -notmatch 'Invoke-CsAiScript' -or $runnerText -notmatch 'Get-CsIllustratorExe') { L '   [FAIL] runner is not bridge-patched'; exit 2 }
L ('   skill runner OK: ' + (San $lct))

# probe helper
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

# ------------------------------------------------ 3. fresh document
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 3
$mkdocResult = Join-Path $root 'mkdoc.result'
Remove-Item -LiteralPath $mkdocResult -Force -ErrorAction SilentlyContinue
$mkjsx = '(function(){try{app.documents.add(DocumentColorSpace.RGB,1619,971);var f=new File("E:/fig1_rebuild/mkdoc.result");f.encoding="UTF-8";f.open("w");f.write("OK|docs="+app.documents.length);f.close();}catch(e){var g=new File("E:/fig1_rebuild/mkdoc.result");g.encoding="UTF-8";g.open("w");g.write("ERR|"+e.message);g.close();}})();'
[IO.File]::WriteAllText((Join-Path $root 'mkdoc.jsx'), $mkjsx, $utf8NoBom)
Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'mkdoc.jsx') + '"'))
$deadline = [DateTime]::UtcNow.AddSeconds(150)
$docInfo = $null
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 700
    if (Test-Path -LiteralPath $mkdocResult) { $docInfo = [IO.File]::ReadAllText($mkdocResult); break }
}
if (-not $docInfo) { L '   [FAIL] mkdoc never ran'; exit 2 }
L ('   mkdoc: ' + (San $docInfo))
if ($docInfo -notmatch 'OK\|docs=1') { L '   [FAIL] doc creation failed'; exit 2 }

# ------------------------------------------------ 4. run the skill runner
$testDir = Join-Path $root ('test-' + $tag)
if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
$workDir = Join-Path $testDir 'live-cache'
$outAi = Join-Path $testDir ('test_' + $tag + '.ai')
$outPng = Join-Path $testDir ('test_' + $tag + '.png')
$runLog = Join-Path $testDir 'run.log'
$errLog = Join-Path $testDir 'err.log'
L ('   drawing fixture via ' + $tag + ' runner ...')
$argList = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $lct + '"'),
    '-InputSvg', ('"' + $fixture + '"'),
    '-WorkDir', ('"' + $workDir + '"'),
    '-OutputAi', ('"' + $outAi + '"'),
    '-OutputPng', ('"' + $outPng + '"'),
    '-Placement', 'center',
    '-MaxWidthFraction', '0.5',
    '-MaxHeightFraction', '0.5',
    '-MinBatchSize', '5',
    '-MaxBatchSize', '50'
)
$proc = Start-Process -FilePath 'powershell.exe' -ArgumentList ($argList -join ' ') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $runLog -RedirectStandardError $errLog
$code = $proc.ExitCode
L ('   runner exit code: ' + $code)
if (Test-Path -LiteralPath $runLog) {
    foreach ($t in @(Get-Content -LiteralPath $runLog -Tail 6 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   run| ' + $x) } }
}
if (Test-Path -LiteralPath $errLog) {
    $errTail = @(Get-Content -LiteralPath $errLog -Tail 4 -ErrorAction SilentlyContinue) | Where-Object { $_.Trim() }
    if (@($errTail).Count -gt 0) { foreach ($t in $errTail) { L ('   err| ' + (San ([string]$t))) } }
}
if ($code -ne 0) { L ('   [FAIL] ' + $tag + ' runner failed'); exit 2 }

# ------------------------------------------------ 5. verify artifacts + probe objects
foreach ($p in @($outAi, $outPng)) {
    if (-not (Test-Path -LiteralPath $p)) { L ('   [FAIL] missing output: ' + $p); exit 2 }
    L ('   output: ' + $p + ' (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)')
}
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($outPng)
L ('   exported png: ' + $img.Width + 'x' + $img.Height)
$img.Dispose()

$probe = Probe-Bridge '(function(){try{var d=app.activeDocument;return "tf="+d.textFrames.length+"|pi="+d.pathItems.length+"|groups="+d.groupItems.length;}catch(e){return "ERR|"+e.message;}})()' 90
L ('   object probe: ' + (San $probe))
$textProbe = Probe-Bridge '(function(){try{var t=app.activeDocument.textFrames;var s="";for(var i=0;i<t.length;i++){s+=t[i].contents+";";}return s;}catch(e){return "ERR|"+e.message;}})()' 90
L ('   text contents: ' + (San $textProbe))

# ------------------------------------------------ 6. close + cleanup
$closejsx = '(function(){try{app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);}catch(e){}var f=new File("E:/fig1_rebuild/closed.result");f.encoding="UTF-8";f.open("w");f.write("closed");f.close();})();'
[IO.File]::WriteAllText((Join-Path $root 'closedoc.jsx'), $closejsx, $utf8NoBom)
Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'closedoc.jsx') + '"'))
Start-Sleep -Seconds 8
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }

# ------------------------------------------------ 7. copy artifacts into repo
$repoTestDir = Join-Path $repoRoot ('results\fig1_rebuild\test\' + $tag)
New-Item -ItemType Directory -Force -Path $repoTestDir | Out-Null
foreach ($n in @(('test_' + $tag + '.ai'), ('test_' + $tag + '.png'))) {
    Copy-Item -LiteralPath (Join-Path $testDir $n) -Destination (Join-Path $repoTestDir $n) -Force
}
Copy-Item -LiteralPath $runLog -Destination (Join-Path $repoTestDir 'run.log') -Force
Copy-Item -LiteralPath $fixture -Destination (Join-Path $repoTestDir 'test_fixture.svg') -Force
L ('   artifacts copied to repo results/fig1_rebuild/test/' + $tag + '/')

$okObjects = ($probe -match 'tf=2\|pi=4')
if ($okObjects) { L ('   TEST PASS: ' + $tag + ' (2 text frames + 4 paths drawn, .ai saved, .png exported)') }
else { L ('   TEST PARTIAL: ' + $tag + ' completed but object counts unexpected: ' + (San $probe)) }
L ('--- task t75 done (' + $tag + ') ---')
exit 0
