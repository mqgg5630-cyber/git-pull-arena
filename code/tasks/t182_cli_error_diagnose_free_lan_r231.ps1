# t182_cli_error_diagnose_free_lan_r231.ps1 - round 231.
# Diagnose the Antigravity CLI/manual command error, do not install IDE, and
# keep the free same-WiFi LAN file share active. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$phoneRoot=Join-Path $lab 'phone-share'
New-Item -ItemType Directory -Force -Path $reports,$phoneRoot|Out-Null
$report=Join-Path $outDir 'CLI_ERROR_DIAGNOSE_FREE_LAN_R231.md'
L '# R231 CLI error diagnose + free LAN share'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))
L 'no_install_ide=True'

# Keep free same-WiFi HTTP share active.
$sharePort=18089
[IO.File]::WriteAllText((Join-Path $phoneRoot 'index.html'),'<title>Arena Free LAN Share R231</title><h1>Arena Free LAN Share R231</h1><p>No VPN required on same Wi-Fi. Type http://LAN-IP:18089/ exactly.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('lan_share_pid='+$p.Id) }catch{ L ('lan_share_start_ERR='+(San $_.Exception.Message)) } }
$fw=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
$ips=@()
try{ $ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.|100\.)' -and $_.IPAddress -ne '0.0.0.0' } | Select-Object -ExpandProperty IPAddress -Unique) }catch{}
$lanRows=@(); foreach($ip in $ips){ $u='http://'+$ip+':'+$sharePort+'/'; $ok=((Curl-Text $u 5) -match 'Arena Free LAN Share R231'); $lanRows += [pscustomobject]@{url=$u;ok=$ok}; L ('lan_url='+$u+' ok='+$ok) }

# Inspect the r230 Antigravity command artifacts. This tells whether the command
# was invoked and whether the failure was inside the runner.
$r230='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_cli_loop_r230'
$runner=Join-Path $r230 'run_illustrator_cli_loop_r230.ps1'
$invoke=Join-Path $r230 'agv_cli_loop_invoked_r230.txt'
$outAi=Join-Path $r230 'agv_cli_loop_figure_r230.ai'
$outPng=Join-Path $r230 'agv_cli_loop_figure_r230.png'
$outDone=Join-Path $r230 'agv_cli_loop_done_r230.txt'
$outLog=Join-Path $r230 'agv_cli_loop_runner_r230.log'
$before=[pscustomobject]@{runner=FInfo $runner;invoke=FInfo $invoke;ai=FInfo $outAi;png=FInfo $outPng;done=FInfo $outDone;log=FInfo $outLog}
L ('before runner_exists='+$before.runner.exists+' invoke='+$before.invoke.exists+' ai='+$before.ai.exists+'/'+$before.ai.bytes+' png='+$before.png.exists+'/'+$before.png.bytes+' done='+$before.done.exists+' log='+$before.log.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 80 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('r230_runner_log|'+(San $line)) } } }

# If the Antigravity/CLI invocation did not produce outputs, run the same runner
# once directly under the watcher to diagnose the script itself. This is NOT
# counted as Antigravity success; it is only a runner health check.
$directOut=Join-Path $reports 'r231_direct_runner_stdout.txt'
$directErr=Join-Path $reports 'r231_direct_runner_stderr.txt'
$directExit=$null
if((Test-Path -LiteralPath $runner) -and -not ((Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng))){
  try{
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner) -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $directOut -RedirectStandardError $directErr
    $directExit=$p.ExitCode
  }catch{ L ('direct_runner_start_ERR='+(San $_.Exception.Message)) }
}
$after=[pscustomobject]@{invoke=FInfo $invoke;ai=FInfo $outAi;png=FInfo $outPng;done=FInfo $outDone;log=FInfo $outLog;directExit=$directExit}
$directOk=$after.ai.exists -and $after.png.exists -and $after.done.exists -and ($after.ai.bytes -gt 1000) -and ($after.png.bytes -gt 1000)
L ('direct_runner_exit='+$directExit+' direct_runner_ok='+$directOk)
L ('after invoke='+$after.invoke.exists+' ai='+$after.ai.exists+'/'+$after.ai.bytes+' png='+$after.png.exists+'/'+$after.png.bytes+' done='+$after.done.exists+' log='+$after.log.exists)
if(Test-Path -LiteralPath $directOut){ foreach($line in (Get-Content -LiteralPath $directOut -Tail 60 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('direct_stdout|'+(San $line)) } } }
if(Test-Path -LiteralPath $directErr){ foreach($line in (Get-Content -LiteralPath $directErr -Tail 60 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('direct_stderr|'+(San $line)) } } }
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 80 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('after_runner_log|'+(San $line)) } } }

# Scan actual CLI commands in PATH and install dir. Do not invoke LLM actions here.
$cmdRows=@()
foreach($name in @('antigravity','antigravity.cmd','agv','agv.cmd','gemini','gemini.cmd')){
  $n=$name
  $where=Run-Cap { where.exe $using:n 2>&1|Out-String } 10
  foreach($line in ($where -split "`r?`n")){ if($line.Trim()){ $cmdRows += [pscustomobject]@{name=$name;path=$line.Trim()} } }
}
$cmdRows=@($cmdRows | Sort-Object name,path -Unique)
foreach($r in $cmdRows){ L ('path_command '+$r.name+' -> '+(San $r.path)) }
$cmdJson=Join-Path $reports 'antigravity-path-commands-r231.json'
[IO.File]::WriteAllText($cmdJson,($cmdRows|ConvertTo-Json -Depth 5)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $cmdJson -Destination (Join-Path $outDir 'antigravity-path-commands-r231.json') -Force }catch{}

$summaryJson=Join-Path $reports 'cli-error-diagnose-r231.json'
[IO.File]::WriteAllText($summaryJson,([pscustomobject]@{lan=$lanRows;before=$before;after=$after;directRunnerOk=$directOk;pathCommands=$cmdRows} | ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'cli-error-diagnose-r231.json') -Force }catch{}
$statusRunner=if($directOk){'RUNNER_HEALTH_OK_DIRECT_ONLY'}else{'RUNNER_HEALTH_FAILED_OR_UNKNOWN'}
$statusAgv=if($before.invoke.exists -and $before.ai.exists -and $before.png.exists){'ANTIGRAVITY_PREEXISTING_OUTPUTS_FOUND'}elseif($before.invoke.exists){'ANTIGRAVITY_INVOKED_BUT_OUTPUTS_MISSING'}else{'ANTIGRAVITY_INVOKE_MARKER_NOT_FOUND'}
$statusLan=if(($lanRows|Where-Object{$_.ok}).Count -gt 0){'FREE_LAN_SHARE_OK'}else{'FREE_LAN_SHARE_NOT_PROVEN'}
L ('status_antigravity='+$statusAgv)
L ('status_runner='+$statusRunner)
L ('status_lan='+$statusLan)
L ('FINAL_R231: '+$statusAgv+'_'+$statusRunner+'_'+$statusLan)
W $report $script:Lines
W (Join-Path $outDir 'cli-error-diagnose-free-lan-summary-r231.md') (@('# R231 summary','',('Antigravity/CLI invocation status: '+$statusAgv),('Runner direct health check: '+$statusRunner),'','R230 AI: '+$outAi,'R230 PNG: '+$outPng,'','Free same-WiFi phone share: '+$statusLan,'Open on phone while same Wi-Fi:') + ($lanRows|ForEach-Object{'- '+$_.url+' ok='+$_.ok}) + @('','Why assistant input differs: CDP automation writes/clicks the webview message box, which Antigravity treats as an agent request. Your manual/CLI path can use a trusted local agent/tool route. If the invoke marker exists but outputs do not, the command reached Windows and the failure is inside the runner/Illustrator step. If the invoke marker is absent, Antigravity accepted text but did not execute the command.'))
exit 0
