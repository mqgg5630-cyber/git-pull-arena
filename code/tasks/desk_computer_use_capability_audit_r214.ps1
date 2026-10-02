# desk_computer_use_capability_audit_r214.ps1 - runs ON THE DESKTOP via ssh.
# Fixed desktop audit: write UTF-8 correctly, install computer-use projects from
# staged zips on F: into E:, then probe controllable software. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=]{32,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; $enc=New-Object System.Text.UTF8Encoding -ArgumentList $false; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", $enc) }
function Write-Text([string]$p,[string]$text) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; $enc=New-Object System.Text.UTF8Encoding -ArgumentList $false; [IO.File]::WriteAllText($p, $text, $enc) }
function Add-Cap([string]$App,[string]$Backend,[string]$Task,[string]$Result,[string]$Evidence,[string]$Artifact) { $script:Caps += [pscustomobject]@{computer=$env:COMPUTERNAME; app=$App; backend=$Backend; task=$Task; result=$Result; evidence=(San $Evidence); artifact=(San $Artifact)} }
function Test-Port([int]$p) { try { $c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$p,$null,$null); if($iar.AsyncWaitHandle.WaitOne(500)){ $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }; return $false }
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) { $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{ok=$false;text='TIMEOUT';name=$Name} }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{ok=$true;text=$txt;name=$Name} }
function Ensure-Project([string]$Name,[string]$Url,[string]$Dest,[string]$ZipPath) {
    if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'present' }
    if(Test-Path -LiteralPath $ZipPath){
        try{
            New-Item -ItemType Directory -Force -Path $Dest | Out-Null
            $tmp=Join-Path $env:TEMP ('arena_proj_' + $Name + '_' + (Get-Date -Format 'HHmmss'))
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Force -Path $tmp | Out-Null
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $tmp -Force
            Copy-Item -LiteralPath (Join-Path $tmp '*') -Destination $Dest -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'unzipped-from-F' }
        }catch{ return ('unzip-failed-' + (San $_.Exception.Message)) }
    }
    if(Get-Command git -ErrorAction SilentlyContinue){
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
        $u=$Url; $d=$Dest; $r=Run-Capped ('clone_' + $Name) { git clone --depth 1 $using:u $using:d 2>&1 | Out-String } 240
        if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'cloned' }
        return ('clone-failed-' + (San $r.text))
    }
    return 'not-installed-git-missing-and-no-zip'
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
        return @{ok=($p.ExitCode -eq 0 -or $out.Length -gt 0);exit=$p.ExitCode;out=(San (($out -split "`r?`n" | Select-Object -First 12) -join ' | '))}
    } catch { return @{ok=$false;exit='ERR';out=(San $_.Exception.Message)} }
}

$script:Lines=@(); $script:Caps=@()
$root='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $root 'reports'
$github=Join-Path $root 'github'
$suite=Join-Path $root 'computer-use-suite'
$stage='F:\fig1_rebuild\cu_r214'
New-Item -ItemType Directory -Force -Path $reports,$github,$suite | Out-Null
$report=Join-Path $reports 'computer-use-capability-audit-desktop-r214.md'
$json=Join-Path $reports 'computer-use-capability-audit-desktop-r214.json'
$stageReport='F:\fig1_rebuild\computer-use-capability-audit-desktop-r214.md'
$stageJson='F:\fig1_rebuild\computer-use-capability-audit-desktop-r214.json'
L '# Desktop computer-use capability audit r214'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L ('lab_root=' + $root)
L ('stage_root=' + $stage)

$projects=@(
    @{name='windows-computer-use';url='https://github.com/cgissing/windows-computer-use.git';dest=(Join-Path $github 'windows-computer-use');zip=(Join-Path $stage 'windows-computer-use.zip')},
    @{name='Windows-MCP';url='https://github.com/CursorTouch/Windows-MCP.git';dest=(Join-Path $github 'Windows-MCP');zip=(Join-Path $stage 'Windows-MCP.zip')},
    @{name='pywinauto-mcp';url='https://github.com/sandraschi/pywinauto-mcp.git';dest=(Join-Path $github 'pywinauto-mcp');zip=(Join-Path $stage 'pywinauto-mcp.zip')}
)
foreach($p in $projects){ $st=Ensure-Project $p.name $p.url $p.dest $p.zip; L ('project|' + $p.name + '|status=' + (San $st) + '|path=' + (San $p.dest)); Add-Cap $p.name 'E-drive install' 'install/presence check' $(if($st -match 'present|cloned|unzipped'){'OK'}else{'CHECK_REPORT'}) $st $p.dest }
$wcuBackend=Join-Path $github 'windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
if(Test-Path -LiteralPath $wcuBackend){ Add-Cap 'Windows GUI apps' 'windows-computer-use' 'UIA backend available on E drive' 'OK' 'backend exists' $wcuBackend } else { Add-Cap 'Windows GUI apps' 'windows-computer-use' 'UIA backend available on E drive' 'NOT_READY' 'backend missing' $wcuBackend }

# Antigravity terminal CLI probe. Avoid installer candidates from Downloads.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cli=@()
foreach($p in @((Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\antigravity.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\antigravity-ide.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\code.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\resources\app\bin\code.cmd'),$agExe,'E:\Antigravity\bin\antigravity-ide.cmd')){ if($p -and (Test-Path -LiteralPath $p)){ $cli += $p } }
try{ $cmds=@(Get-Command antigravity*,code -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch 'Downloads|Antigravity-x64' } | Select-Object -ExpandProperty Source); foreach($c in $cmds){ if($c -and (Test-Path -LiteralPath $c)){ $cli += $c } } }catch{}
$cli=@($cli | Select-Object -Unique)
L ('antigravity_cli_candidates=' + $cli.Count)
$cliOk=$false; $cliChoice=''; $cliEvidence=''
foreach($c in $cli){ $v=Run-ExeCapture $c @('--version') 8000; L ('ag_cli_version|path=' + (San $c) + '|ok=' + $v.ok + '|exit=' + $v.exit + '|out=' + (San $v.out)); if(-not $cliOk -and $v.ok){ $cliOk=$true; $cliChoice=$c; $cliEvidence=$v.out } }
if($cliOk){
    $probe=Join-Path $reports 'antigravity-cli-probe-desktop-r214.txt'
    Write-Text $probe ('ARENA_DESKTOP_AG_CLI_R214 ' + (Get-Date).ToString('s'))
    try{ Start-Process -FilePath $cliChoice -ArgumentList @('--reuse-window',$probe) -ErrorAction SilentlyContinue; Start-Sleep -Seconds 4; Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'open E-drive probe file/workspace' 'OK_ISSUED' ('version=' + $cliEvidence) $probe }catch{ Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'open E-drive probe file/workspace' 'CHECK_REPORT' $_.Exception.Message $probe }
} else { Add-Cap 'Antigravity' 'Antigravity terminal CLI' 'version/help/open probe' 'NOT_FOUND_OR_TIMEOUT' ('candidates=' + $cli.Count) '' }

# App-specific status operations.
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
$wpsOk=($wps.Values -contains 'OK')
Add-Cap 'WPS Office' 'COM automation' 'instantiate Writer/Sheet/Presentation COM' $(if($wpsOk){'OK'}else{'NOT_READY'}) (($wps.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join ';') ''
$ai=@(); foreach($root2 in @('C:\Program Files','C:\Program Files (x86)','D:\','E:\','F:\')){ if(Test-Path $root2){ try{ $ai += @(Get-ChildItem -LiteralPath $root2 -Recurse -Depth 5 -Filter Illustrator.exe -File -ErrorAction SilentlyContinue | Select-Object -First 3 -ExpandProperty FullName) }catch{} } }
Add-Cap 'Adobe Illustrator' 'path/process probe' 'detect executable/process for future COM/UIA wrapper' $(if($ai.Count -gt 0 -or @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count -gt 0){'OK'}else{'NOT_FOUND'}) ('paths=' + (($ai|Select-Object -First 3) -join ';')) ''
Add-Cap 'File Explorer' 'shell CLI' 'open E-drive lab folder' 'OK_CAPABLE' 'explorer.exe can open local folders' $root
try{ $np=(Get-Command notepad.exe -ErrorAction SilentlyContinue).Source; if($np){ Add-Cap 'Notepad' 'process/file CLI' 'open/edit text file by path' 'OK_CAPABLE' 'notepad.exe present' $np } }catch{}
try{ $edge=(Get-Command msedge.exe -ErrorAction SilentlyContinue).Source; if($edge){ $ev=Run-ExeCapture $edge @('--version') 8000; Add-Cap 'Microsoft Edge' 'browser CLI' 'version/open URL/file capability' $(if($ev.ok){'OK'}else{'CHECK_REPORT'}) $ev.out $edge } }catch{}

$wins=@(Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object -First 40 ProcessName,Id,MainWindowTitle)
L ('open_window_count=' + $wins.Count)
foreach($w in ($wins | Select-Object -First 20)){ L ('window|' + (San $w.ProcessName) + '|title=' + (San $w.MainWindowTitle)) }
$data=[ordered]@{computer=$env:COMPUTERNAME; user=$env:USERNAME; labRoot=$root; capabilities=$script:Caps; windows=$wins; time=(Get-Date).ToString('s')}
$enc=New-Object System.Text.UTF8Encoding -ArgumentList $false
[IO.File]::WriteAllText($json, (($data | ConvertTo-Json -Depth 12) + "`r`n"), $enc)
L ''
L '## Capability list'
foreach($c in $script:Caps){ L ('cap|' + $c.computer + '|' + $c.app + '|' + $c.backend + '|' + $c.task + '|' + $c.result + '|' + $c.evidence + '|' + $c.artifact) }
L ('json=' + (San $json))
$okCount=@($script:Caps | Where-Object { $_.result -match '^OK' }).Count
$partialCount=@($script:Caps | Where-Object { $_.result -match 'PARTIAL|CHECK' }).Count
L ('ok_capability_count=' + $okCount)
L ('partial_capability_count=' + $partialCount)
L 'FINAL_DESKTOP_COMPUTER_USE_AUDIT_R214: COMPLETED'
W $report $script:Lines
try{ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stageReport) | Out-Null; Copy-Item -LiteralPath $report -Destination $stageReport -Force; Copy-Item -LiteralPath $json -Destination $stageJson -Force }catch{ Write-Output ('stage_copy_WARN=' + (San $_.Exception.Message)) }
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
