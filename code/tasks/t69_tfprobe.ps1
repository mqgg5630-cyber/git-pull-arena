# t69_tfprobe.ps1 - round 85 task: reopen shibielujing1.ai in Illustrator
# and dump every textFrame's contents/position/bounds/hidden/parent to find
# where the rotated 'RMSD (nm)' label landed. Closes without saving after.
# ASCII-only.

$ErrorActionPreference = 'Continue'
$root = 'E:\fig1_rebuild'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t69: textFrame probe of shibielujing1.ai ---'

$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { Write-Output '   [FAIL] no Illustrator.exe'; exit 2 }

$aiFile = Join-Path $root 'shibielujing1\shibielujing1.ai'
if (-not (Test-Path -LiteralPath $aiFile)) { Write-Output '   [FAIL] shibielujing1.ai missing'; exit 2 }

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

# launch (AI stopped after the rebuild)
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 2
Start-Process -FilePath $aiExe -ArgumentList @(('"' + $aiFile + '"'))
L '   launched with .ai, waiting 30s ...'
Start-Sleep -Seconds 30
$r = Probe-Bridge '(function(){return app.documents.length+"|"+(app.documents.length>0?app.activeDocument.name:"NONE");})()' 120
L ('   doc probe: ' + (San $r))
if ($r -notmatch '^\d+\|') { Write-Output '   [FAIL] document did not open'; try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }; exit 2 }

# full textFrame dump via script file
$tfResult = Join-Path $root 'tfprobe.result'
Remove-Item -LiteralPath $tfResult -Force -ErrorAction SilentlyContinue
$tfJsx = @'
(function(){
  var doc=app.activeDocument;
  var lines=[];
  for(var i=0;i<doc.textFrames.length;i++){
    var t=doc.textFrames[i];
    try{
      var gb=t.geometricBounds;
      lines.push(i+'|'+t.contents+'|pos='+Math.round(t.position[0])+','+Math.round(t.position[1])+'|gb='+Math.round(gb[0])+','+Math.round(gb[1])+','+Math.round(gb[2])+','+Math.round(gb[3])+'|hid='+t.hidden+'|op='+Math.round(t.opacity)+'|parent='+(t.parent&&t.parent.name?String(t.parent.name).substring(0,40):'?'));
    }catch(e){lines.push(i+'|ERR|'+e.message);}
  }
  var f=new File('E:/fig1_rebuild/tfprobe.result');
  f.encoding='UTF-8';f.open('w');f.write('count='+doc.textFrames.length+String.fromCharCode(10)+lines.join(String.fromCharCode(10)));f.close();
  return 'TF_PROBE_DONE|'+doc.textFrames.length;
})()
'@
[IO.File]::WriteAllText((Join-Path $root 'tfprobe.jsx'), $tfJsx, $utf8NoBom)
$r2 = Probe-Bridge '(function(){try{$.evalFile(new File("E:/fig1_rebuild/tfprobe.jsx"));}catch(e){return "ERR|"+e.message;}return "RAN";})()' 120
L ('   tfprobe run: ' + (San $r2))
Start-Sleep -Seconds 2

if (Test-Path -LiteralPath $tfResult) {
    $lines = @(Get-Content -LiteralPath $tfResult -ErrorAction SilentlyContinue)
    Write-Output ('   --- textFrames (' + $lines.Count + ' lines) ---')
    foreach ($t in $lines) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   tf| ' + $x) } }
    Copy-Item -LiteralPath $tfResult -Destination ((Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path + '\results\fig1_rebuild\out\tfprobe.result') -Force
    Write-Output '   copied tfprobe.result into repo results/fig1_rebuild/out/'
} else { Write-Output '   [FAIL] tfprobe.result not written' }

# also dump the artboard rect for coordinate reference
$r3 = Probe-Bridge '(function(){try{var a=app.activeDocument.artboards[app.activeDocument.artboards.getActiveArtboardIndex()].artboardRect;return "artboard="+Math.round(a[0])+","+Math.round(a[1])+","+Math.round(a[2])+","+Math.round(a[3]);}catch(e){return "ERR|"+e.message;}})()' 90
L ('   ' + (San $r3))

# close without saving + stop
$closejsx = '(function(){try{app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);}catch(e){}var f=new File("E:/fig1_rebuild/closed.result");f.encoding="UTF-8";f.open("w");f.write("closed");f.close();})();'
[IO.File]::WriteAllText((Join-Path $root 'closedoc.jsx'), $closejsx, $utf8NoBom)
Start-Process -FilePath $aiExe -ArgumentList @(('"' + (Join-Path $root 'closedoc.jsx') + '"'))
Start-Sleep -Seconds 8
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Write-Output '--- task t69 ok ---'
exit 0
