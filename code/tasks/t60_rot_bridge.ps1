# t60_rot_bridge.ps1 - round 73 task: (1) verify py launcher actually
# installed (file system check, refresh-free), (2) launch Illustrator 2020,
# enumerate the ROT (fixed C# - no compile bug this time), find the app
# object via Marshal.BindToMoniker, smoke-test DoJavaScript, (3) if a
# "!{GUID}" item moniker maps to the app, write HKCU COM registration
# (ProgID Illustrator.Application.24 -> CLSID -> LocalServer32) and test
# New-Object -ComObject in a fresh process.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t60: ROT bridge + manual COM registration for AI 2020 ---'

# ---------------------------------------------------- 1. py check
Write-Output '--- 1. py launcher check ---'
$pyPaths = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Launcher\py.exe'),
    'C:\Windows\py.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\py.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe')
)
$pyFound = $null
foreach ($p in $pyPaths) { if (Test-Path -LiteralPath $p) { Write-Output ('   FOUND: ' + $p); if (-not $pyFound -and $p -match 'py\.exe$') { $pyFound = $p } } }
if ($pyFound) {
    Write-Output ('   py -> ' + $pyFound)
    & $pyFound -3 -X utf8 -c "import sys; print('   py -3 ->', sys.version.split()[0])"
} else {
    Write-Output '   py.exe not on disk - installing python 3.12 silently ...'
    $inst = 'E:\python312_setup.exe'
    & curl.exe -sL --max-time 240 -o $inst 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe'
    if (Test-Path -LiteralPath $inst) {
        Start-Process -FilePath $inst -ArgumentList @('/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_launcher=1') -Wait
        Start-Sleep -Seconds 3
        foreach ($p in $pyPaths) { if (Test-Path -LiteralPath $p) { Write-Output ('   installed now: ' + $p); $pyFound = $p } }
    } else { Write-Output '   [WARN] python installer download failed' }
}

# ---------------------------------------------------- 2. ROT probe
Write-Output '--- 2. ROT enumeration (Illustrator) ---'
$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { Write-Output '   [FAIL] Illustrator.exe not found'; exit 2 }
$running = Get-Process -Name Illustrator -ErrorAction SilentlyContinue
if (-not $running) {
    Start-Process -FilePath $aiExe
    Write-Output '   launched Illustrator, waiting 35s ...'
    Start-Sleep -Seconds 35
} else { Write-Output '   Illustrator already running' }

$src = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Collections.Generic;
public static class RotEnum {
    [DllImport("ole32.dll")] public static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable prot);
    [DllImport("ole32.dll")] public static extern int CreateBindCtx(int reserved, out IBindCtx ppbc);
    public static List<string> ListAll() {
        List<string> names = new List<string>();
        IRunningObjectTable rot;
        GetRunningObjectTable(0, out rot);
        IEnumMoniker enumMon;
        rot.EnumRunning(out enumMon);
        IBindCtx ctx;
        CreateBindCtx(0, out ctx);
        IMoniker[] mons = new IMoniker[1];
        IntPtr fetched = IntPtr.Zero;
        while (enumMon.Next(1, mons, fetched) == 0) {
            string name = string.Empty;
            try { mons[0].GetDisplayName(ctx, null, out name); } catch { }
            if (!String.IsNullOrEmpty(name)) { names.Add(name); }
        }
        return names;
    }
}
'@
try { Add-Type -TypeDefinition $src } catch { Write-Output ('   [FAIL] Add-Type: ' + (San $_.Exception.Message)); exit 2 }

$names = @()
try { $names = [RotEnum]::ListAll() } catch { Write-Output ('   [FAIL] ListAll: ' + (San $_.Exception.Message)) }
Write-Output ('   ROT total monikers: ' + $names.Count)
$cand = @($names | Where-Object { $_ -match 'Illustrator|^!' } | Select-Object -First 25)
foreach ($c in $cand) { Write-Output ('   ROT: ' + (San ([string]$c))) }

# try to bind each candidate and identify the Illustrator app
$app = $null
$appMoniker = ''
foreach ($c in $cand) {
    try {
        $obj = [Runtime.InteropServices.Marshal]::BindToMoniker($c)
        $ver = ''
        try { $ver = [string]$obj.Version } catch { }
        if ($ver -match '^2[0-9]\.') {
            Write-Output ('   BOUND via moniker: ' + (San $c) + '  Illustrator version=' + $ver)
            $app = $obj
            $appMoniker = $c
            break
        } else {
            Write-Output ('   moniker not Illustrator (version=' + (San $ver) + '): ' + (San $c))
        }
    } catch { Write-Output ('   bind fail: ' + (San $c) + ' : ' + (San $_.Exception.Message)) }
}

if ($app) {
    try {
        $r = [string]$app.DoJavaScript('1+1')
        Write-Output ('   DoJavaScript smoke test: 1+1 = ' + $r)
    } catch { Write-Output ('   [WARN] DoJavaScript: ' + (San $_.Exception.Message)) }
    # extract GUID from moniker if present
    if ($appMoniker -match '\{[0-9A-Fa-f\-]{36}\}') {
        $clsid = $Matches[0]
        Write-Output ('   app CLSID from moniker: ' + $clsid)
        # ------------------------------------------------ 3. register HKCU COM
        Write-Output '--- 3. write HKCU COM registration ---'
        try {
            $progKey = 'HKCU:\Software\Classes\Illustrator.Application.24'
            $null = New-Item -Path $progKey -Force
            Set-ItemProperty -Path $progKey -Name '(default)' -Value 'Illustrator 2020 Application'
            $null = New-Item -Path (Join-Path $progKey 'CLSID') -Force
            Set-ItemProperty -Path (Join-Path $progKey 'CLSID') -Name '(default)' -Value $clsid
            $clsidKey = 'HKCU:\Software\Classes\CLSID\' + $clsid
            $null = New-Item -Path $clsidKey -Force
            Set-ItemProperty -Path $clsidKey -Name '(default)' -Value 'Illustrator 2020 Application'
            $null = New-Item -Path (Join-Path $clsidKey 'LocalServer32') -Force
            Set-ItemProperty -Path (Join-Path $clsidKey 'LocalServer32') -Name '(default)' -Value ('"' + $aiExe + '"')
            Write-Output ('   registered: ProgID Illustrator.Application.24 -> CLSID ' + $clsid + ' -> ' + $aiExe)
            # fresh-process test
            $t = Start-Job -ScriptBlock {
                try {
                    $a = New-Object -ComObject 'Illustrator.Application.24'
                    return ('COM-OK version=' + [string]$a.Version + ' docs=' + $a.Documents.Count)
                } catch { return ('COM-FAIL ' + $_.Exception.Message) }
            }
            if (Wait-Job $t -Timeout 60) { Write-Output ('   fresh-process test: ' + (San ([string](Receive-Job $t)))) }
            else { Write-Output '   fresh-process test: TIMEOUT' }
            Remove-Job $t -Force -ErrorAction SilentlyContinue
        } catch { Write-Output ('   [WARN] registration: ' + (San $_.Exception.Message)) }
    } else {
        Write-Output '   [WARN] no GUID in app moniker; cannot auto-register. Moniker was: ' + (San $appMoniker)
    }
    try { $app.Quit(); Write-Output '   app.Quit() sent' } catch { }
    Start-Sleep -Seconds 4
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
} else {
    Write-Output '   [FAIL] no Illustrator object found in ROT'
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue; Write-Output '   (Illustrator stopped)' } catch { }
}
exit 0
