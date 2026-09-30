# t61_rot_fallback.ps1 - round 74 task: (1) patch run_cell_lct.ps1 (BOTH
# E:\cell_su7 source and installed ~/.codex/skills copy) adding a ROT
# fallback connector after the ProgID attempts; (2) live smoke test:
# launch Illustrator 2020, ROT-bind, DoJavaScript 1+1, documents.add(),
# report version; quit. ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t61: ROT fallback connector + smoke test ---'

# ---------------------------------------------------- 1. patch both copies
$rotFallback = @'
if (-not $illustrator) {
        # ROT fallback: bind the RUNNING Illustrator application object
        # (for installs with no COM registration, e.g. repacked AI 2020)
        $csSrc = 'using System;using System.Runtime.InteropServices;using System.Runtime.InteropServices.ComTypes;using System.Collections.Generic;public static class CsRot{[DllImport("ole32.dll")]public static extern int GetRunningObjectTable(int reserved,out IRunningObjectTable prot);public static object[] GetObjects(){List<object> objs=new List<object>();IRunningObjectTable rot;GetRunningObjectTable(0,out rot);IEnumMoniker em;rot.EnumRunning(out em);IMoniker[] mons=new IMoniker[1];IntPtr fetched=IntPtr.Zero;object obj;while(em.Next(1,mons,fetched)==0){try{if(rot.GetObject(mons[0],out obj)==0 && obj!=null){objs.Add(obj);}}catch{}}return objs.ToArray();}}'
        try { Add-Type -TypeDefinition $csSrc -ErrorAction Stop } catch { }
        if (-not ('CsRot' -as [type])) { throw 'Illustrator COM not available and ROT helper failed to load' }
        foreach ($csObj in [CsRot]::GetObjects()) {
            $csVer = ''
            try { $csVer = [string]$csObj.Version } catch { }
            if ($csVer -match '^2[4-9]\.') { $illustrator = $csObj; Write-Output "INFO|rot_bound|version=$csVer"; break }
        }
    }
    if (-not $illustrator) { throw 'Illustrator COM not available (no ProgID connected, no ROT object bound)' }
'@
$anchor = "    if (-not `$illustrator) { throw 'Illustrator COM not available (no ProgID connected; AI 2020 bridge needs registry/ROT fix)' }"
$newAnchor = $rotFallback + "`r`n" + "    if (-not `$illustrator) { throw 'Illustrator COM not available (no ProgID connected, no ROT object bound)' }"

$targets = @(
    'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct.ps1',
    (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts\run_cell_lct.ps1')
)
foreach ($f in $targets) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Output ('   [WARN] missing: ' + $f); continue }
    $raw = [System.IO.File]::ReadAllText($f)
    if ($raw -match 'CsRot') { Write-Output ('   already ROT-patched: ' + $f); continue }
    if ($raw.Contains($anchor)) {
        $raw2 = $raw.Replace($anchor, $newAnchor)
        [System.IO.File]::WriteAllText($f, $raw2, (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ('   ROT-PATCHED: ' + $f)
    } else {
        Write-Output ('   [WARN] anchor not found in ' + $f + ' - showing current connect block')
        $i = $raw.IndexOf('csProgid')
        if ($i -ge 0) { Write-Output ('   ctx: ' + (San ($raw.Substring([Math]::Max(0,$i-200), 700) -replace "`r?`n", ' | '))) }
    }
}

# ---------------------------------------------------- 2. smoke test
Write-Output '--- 2. live bridge smoke test ---'
$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { Write-Output '   [FAIL] no Illustrator.exe'; exit 2 }
if (-not (Get-Process -Name Illustrator -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $aiExe
    Write-Output '   launched Illustrator, waiting 35s ...'
    Start-Sleep -Seconds 35
}

$csSrc = 'using System;using System.Runtime.InteropServices;using System.Runtime.InteropServices.ComTypes;using System.Collections.Generic;public static class CsRot2{[DllImport("ole32.dll")]public static extern int GetRunningObjectTable(int reserved,out IRunningObjectTable prot);public static object[] GetObjects(){List<object> objs=new List<object>();IRunningObjectTable rot;GetRunningObjectTable(0,out rot);IEnumMoniker em;rot.EnumRunning(out em);IMoniker[] mons=new IMoniker[1];IntPtr fetched=IntPtr.Zero;object obj;while(em.Next(1,mons,fetched)==0){try{if(rot.GetObject(mons[0],out obj)==0 && obj!=null){objs.Add(obj);}}catch{}}return objs.ToArray();}}'
Add-Type -TypeDefinition $csSrc
$app = $null
foreach ($o in [CsRot2]::GetObjects()) {
    $v = ''
    try { $v = [string]$o.Version } catch { }
    if ($v -match '^2[4-9]\.') { $app = $o; break }
}
if ($app) {
    Write-Output ('   ROT-BOUND Illustrator version=' + (San ([string]$app.Version)))
    try { Write-Output ('   DoJavaScript 1+1 = ' + (San ([string]$app.DoJavaScript('1+1')))) } catch { Write-Output ('   [FAIL] DoJavaScript: ' + (San $_.Exception.Message)) }
    try {
        $r = [string]$app.DoJavaScript('app.documents.add(); app.activeDocument.name')
        Write-Output ('   documents.add -> ' + (San $r))
        $r2 = [string]$app.DoJavaScript('app.documents.length')
        Write-Output ('   documents count = ' + $r2)
        # close without saving, then quit
        $null = $app.DoJavaScript('app.activeDocument.close(SaveOptions.DONOTSAVECHANGES)')
        Write-Output '   test doc closed'
    } catch { Write-Output ('   [WARN] doc ops: ' + (San $_.Exception.Message)) }
    try { $app.Quit(); Write-Output '   Quit sent' } catch { }
    Start-Sleep -Seconds 4
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    Write-Output '   SMOKE TEST DONE'
} else {
    Write-Output '   [FAIL] no Illustrator object in ROT even while running'
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    exit 2
}
exit 0
