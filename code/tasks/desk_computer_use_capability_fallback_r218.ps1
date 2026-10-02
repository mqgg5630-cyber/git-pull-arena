# desk_computer_use_capability_fallback_r218.ps1 - runs ON THE DESKTOP via ssh.
# Desktop computer-use audit with E-drive detection and F-drive fallback when E:
# is not present/writable. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=]{32,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Out-Lines([string]$Path,[string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; Set-Content -LiteralPath $Path -Value $Lines -Encoding UTF8 }
function Add-Cap([string]$App,[string]$Backend,[string]$Task,[string]$Result,[string]$Evidence,[string]$Artifact) { $script:Caps += [pscustomobject]@{computer=$env:COMPUTERNAME; app=$App; backend=$Backend; task=$Task; result=$Result; evidence=(San $Evidence); artifact=(San $Artifact)} }
function Test-Port([int]$p) { try { $c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$p,$null,$null); if($iar.AsyncWaitHandle.WaitOne(500)){ $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }; return $false }
function Ensure-Project([string]$Name,[string]$Dest,[string]$ZipPath) {
    if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'present' }
    if(Test-Path -LiteralPath $ZipPath){
        try{
            New-Item -ItemType Directory -Force -Path $Dest | Out-Null
            $tmp=Join-Path $env:TEMP ('arena_proj_' + $Name + '_' + (Get-Date -Format 'HHmmss'))
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Force -Path $tmp | Out-Null
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $tmp -Force
            Copy-Item -Path (Join-Path $tmp '*') -Destination $Dest -Recurse -Force -ErrorAction Stop
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'unzipped-from-F' }
            return 'unzipped-but-no-git-dir'
        }catch{ return ('unzip-failed-' + (San $_.Exception.Message)) }
    }
    return 'zip-missing'
}
function Run-ExeCapture([string]$Path,[string[]]$Args,[int]$TimeoutMs) {
    try {
        $psi=New-Object Diagnostics.ProcessStartInfo
        if($Path -match '\.(cmd|bat)$'){
            $psi.FileName=(Join-Path $env:SystemRoot 'System32\cmd.exe')
            $argLine=($Args | ForEach-Object { if($_ -match '[ \t"]'){ '"' + ($_ -replace '"','\"') + '"' } else { $_ } }) -join ' '
            $psi.Arguments='/c ""' + $Path + '" ' + $argLine + '"'
        } else {
            $psi.FileName=$Path
            $psi.Arguments=($Args | ForEach-Object { if($_ -match '[ \t"]'){ '"' + ($_ -replace '"','\"') + '"' } else { $_ } }) -join ' '
        }
        $psi.UseShellExecute=$false; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
        $p=[Diagnostics.Process]::Start($psi)
        if(-not $p.WaitForExit($TimeoutMs)){ try{$p.Kill()}catch{}; return @{ok=$false;exit='TIMEOUT';out=''} }
        $out=($p.StandardOutput.ReadToEnd() + "`n" + $p.StandardError.ReadToEnd()).Trim()
        return @{ok=($p.ExitCode -eq 0 -or $out.Length -gt 0);exit=$p.ExitCode;out=(San (($out -split "`r?`n" | Select-Object -First 8) -join ' | '))}
    } catch { return @{ok=$false;exit='ERR';out=(San $_.Exception.Message)} }
}

$script:Lines=@(); $script:Caps=@()
$eAvail=Test-Path -LiteralPath 'E:\'
$fAvail=Test-Path -LiteralPath 'F:\'
if($eAvail){ $root='E:\0mcp-agv-arena-optimized'; $rootMode='E' }
elseif($fAvail){ $root='F:\0mcp-agv-arena-optimized'; $rootMode='F_FALLBACK_NO_E_DRIVE' }
else{ $root=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'; $rootMode='USERPROFILE_FALLBACK_NO_E_OR_F' }
$reports=Join-Path $root 'reports'
$github=Join-Path $root 'github'
$stage='F:\fig1_rebuild\cu_r214'
New-Item -ItemType Directory -Force -Path $reports,$github | Out-Null
$report=Join-Path $reports 'computer-use-capability-audit-desktop-r218.md'
$json=Join-Path $reports 'computer-use-capability-audit-desktop-r218.json'
$stageReport='F:\fig1_rebuild\computer-use-capability-audit-desktop-r218.md'
$stageJson='F:\fig1_rebuild\computer-use-capability-audit-desktop-r218.json'
L '# Desktop computer-use capability audit r218'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L ('e_drive_available=' + $eAvail)
L ('f_drive_available=' + $fAvail)
L ('chosen_root=' + $root)
L ('root_mode=' + $rootMode)

$projects=@('windows-computer-use','Windows-MCP','pywinauto-mcp')
foreach($name in $projects){
    $dest=Join-Path $github $name
    $zip=Join-Path $stage ($name + '.zip')
    $st=Ensure-Project $name $dest $zip
    L ('project|' + $name + '|status=' + (San $st) + '|path=' + (San $dest))
    Add-Cap $name ($rootMode + ' install') 'install/presence check' $(if($st -match 'present|unzipped'){'OK'}else{'CHECK_REPORT'}) $st $dest
}
$wcuBackend=Join-Path $github 'windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
if(Test-Path -LiteralPath $wcuBackend){ Add-Cap 'Windows GUI apps' 'windows-computer-use' 'UIA backend available' 'OK' 'backend exists' $wcuBackend } else { Add-Cap 'Windows GUI apps' 'windows-computer-use' 'UIA backend available' 'NOT_READY' 'backend missing' $wcuBackend }

$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cli=@()
foreach($p in @((Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\antigravity.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\antigravity-ide.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\code.cmd'),$agExe)){ if($p -and (Test-Path -LiteralPath $p)){ $cli += $p } }
$cli=@($cli | Select-Object -Unique)
L ('antigravity_cli_candidates=' + $cli.Count)
$cliOk=$false; $cliChoice=''; $cliEvidence=''
foreach($c in $cli){ $v=Run-ExeCapture $c @('--version') 8000; L ('ag_cli_version|path=' + (San $c) + '|ok=' + $v.ok + '|exit=' + $v.exit + '|out=' + (San $v.out)); if(-not $cliOk -and $v.ok){ $cliOk=$true; $cliChoice=$c; $cliEvidence=$v.out } }
if($cliOk){
    $probe=Join-Path $reports 'antigravity-cli-probe-desktop-r218.txt'
    Set-Content -LiteralPath $probe -Value ('ARENA_DESKTOP_AG_CLI_R218 ' + (Get-Date).ToString('s')) -Encoding UTF8
    try{ Start-Process -FilePath $cliChoice -ArgumentList @('--reuse-window',$probe) -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'open probe file/workspace' 'OK_ISSUED' ('version=' + $cliEvidence) $probe }catch{ Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'open probe file/workspace' 'CHECK_REPORT' $_.Exception.Message $probe }
} else { Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'version/help/open probe' 'NOT_FOUND_OR_TIMEOUT' ('candidates=' + $cli.Count) '' }

$agInstalled=Test-Path -LiteralPath $agExe
$agVersion=''; if($agInstalled){ try{$agVersion=[string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion}catch{} }
$agProc=@(Get-Process -Name Antigravity -ErrorAction SilentlyContinue).Count
$lsProc=@(Get-Process -Name language_server -ErrorAction SilentlyContinue).Count
$port18088=Test-Port 18088
Add-Cap 'Antigravity' 'app-specific status + bridge' 'installed/process/proxy check' $(if($agInstalled -and $port18088){'OK'}elseif($agInstalled){'PARTIAL'}else{'NOT_INSTALLED'}) ('version=' + $agVersion + ';proc=' + $agProc + ';ls=' + $lsProc + ';18088=' + $port18088) ''
$v2=@(Get-Process -Name v2rayN -ErrorAction SilentlyContinue).Count; $xray=@(Get-Process -Name xray -ErrorAction SilentlyContinue).Count
Add-Cap 'v2rayN/xray' 'process + port status' 'check bridge/network helper' $(if($port18088 -or $v2 -gt 0 -or $xray -gt 0){'OK'}else{'NOT_RUNNING'}) ('v2rayN=' + $v2 + ';xray=' + $xray + ';18088=' + $port18088) ''
$gvPaths=@('E:\NsfocusVPN\NsfocusVPN.exe','F:\NsfocusVPN\NsfocusVPN.exe','C:\NsfocusVPN\NsfocusVPN.exe')
$gvExe=($gvPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
$gv=@(Get-Process -Name NsfocusVPN -ErrorAction SilentlyContinue).Count
Add-Cap 'GreenVPN' 'app-specific status' 'check install/process/startup target' $(if($gvExe -or $gv -gt 0){'OK'}else{'NOT_FOUND'}) ('exe=' + [bool]$gvExe + ';processes=' + $gv) ([string]$gvExe)
$wps=@{}; foreach($pg in @('KWPS.Application','KET.Application','KWPP.Application')){ try{ $o=New-Object -ComObject $pg; $wps[$pg]='OK'; try{$o.Quit()}catch{} }catch{ $wps[$pg]='FAIL' } }
Add-Cap 'WPS Office' 'COM automation' 'instantiate Writer/Sheet/Presentation COM' $(if($wps.Values -contains 'OK'){'OK'}else{'NOT_READY'}) (($wps.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join ';') ''
$ai=@(); foreach($root2 in @('C:\Program Files','C:\Program Files (x86)','D:\','E:\','F:\')){ if(Test-Path $root2){ try{ $ai += @(Get-ChildItem -LiteralPath $root2 -Recurse -Depth 5 -Filter Illustrator.exe -File -ErrorAction SilentlyContinue | Select-Object -First 3 -ExpandProperty FullName) }catch{} } }
Add-Cap 'Adobe Illustrator' 'path/process probe' 'detect executable/process for future COM/UIA wrapper' $(if($ai.Count -gt 0 -or @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count -gt 0){'OK'}else{'NOT_FOUND'}) ('paths=' + (($ai|Select-Object -First 3) -join ';')) ''
Add-Cap 'File Explorer' 'shell CLI' 'open chosen lab folder' 'OK_CAPABLE' 'explorer.exe can open local folders' $root
try{ $np=(Get-Command notepad.exe -ErrorAction SilentlyContinue).Source; if($np){ Add-Cap 'Notepad' 'process/file CLI' 'open/edit text file by path' 'OK_CAPABLE' 'notepad.exe present' $np } }catch{}

$data=[ordered]@{computer=$env:COMPUTERNAME; user=$env:USERNAME; eDriveAvailable=$eAvail; rootMode=$rootMode; root=$root; capabilities=$script:Caps; time=(Get-Date).ToString('s')}
($data | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $json -Encoding UTF8
L ''
L '## Capability list'
foreach($c in $script:Caps){ L ('cap|' + $c.computer + '|' + $c.app + '|' + $c.backend + '|' + $c.task + '|' + $c.result + '|' + $c.evidence + '|' + $c.artifact) }
L ('json=' + (San $json))
L ('ok_capability_count=' + @($script:Caps | Where-Object { $_.result -match '^OK' }).Count)
L ('partial_capability_count=' + @($script:Caps | Where-Object { $_.result -match 'PARTIAL|CHECK' }).Count)
L 'FINAL_DESKTOP_COMPUTER_USE_AUDIT_R218: COMPLETED'
Out-Lines $report $script:Lines
try{ Copy-Item -LiteralPath $report -Destination $stageReport -Force; Copy-Item -LiteralPath $json -Destination $stageJson -Force; L 'stage_copy=OK' }catch{ L ('stage_copy_WARN=' + (San $_.Exception.Message)) }
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
