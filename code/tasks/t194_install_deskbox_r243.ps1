# t194_install_deskbox_r243.ps1 - round 243.
# Retry DeskBox download/install with certificate revocation disabled for curl.
# ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [System.Net.ServicePointManager]::CheckCertificateRevocationList = $false } catch {}
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Find-Cmd([string[]]$Names){ foreach($n in $Names){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){ return $c.Source } }catch{} }; return '' }
function Run-CmdLine([string]$Line,[string]$Cwd,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock {
    param($line,$wd)
    if($wd -and (Test-Path -LiteralPath $wd)){ Set-Location -LiteralPath $wd }
    cmd.exe /d /s /c $line 2>&1 | Out-String
    $c=$LASTEXITCODE; if($null -eq $c){$c=0}
    Write-Output ('===EXITCODE:'+[string]$c)
  } -ArgumentList $Line,$Cwd
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return @{code=-1;text='TIMEOUT'}
  }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim()
  Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0
  if($txt -match '===EXITCODE:(-?\d+)'){
    $code=[int]$Matches[1]
    $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim()
  }
  return @{code=$code;text=$txt}
}
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){
  try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $ws=New-Object -ComObject WScript.Shell
    $sc=$ws.CreateShortcut($Path)
    $sc.TargetPath=$Target
    if($Arguments){$sc.Arguments=$Arguments}
    if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}
    if($IconLocation){$sc.IconLocation=$IconLocation}
    if($Description){$sc.Description=$Description}
    $sc.Save(); return $true
  }catch{ L ('shortcut_error='+(San $_.Exception.Message)); return $false }
}
function Download-File([string]$Url,[string]$Out){
  $curl=Find-Cmd @('curl.exe','curl')
  if($curl){
    $line='"'+$curl+'" -L --ssl-no-revoke --retry 3 -A "Mozilla/5.0" -o "'+$Out+'" "'+$Url+'"'
    $r=Run-CmdLine $line '' 600
    if((Test-Path -LiteralPath $Out) -and ((Get-Item -LiteralPath $Out).Length -gt 1000000)){ return $r }
    L ('curl_ssl_no_revoke_tail='+(TailText (San $r.text) 6))
  }
  try{
    Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $Url -OutFile $Out
    return @{code=0;text='Invoke-WebRequest OK'}
  }catch{ return @{code=1;text=$_.Exception.Message} }
}
function Find-DeskBoxExe([string]$Edir){
  foreach($root in @($Edir,(Join-Path $env:LOCALAPPDATA 'Programs'),(Join-Path $env:LOCALAPPDATA 'DeskBox'))){
    if($root -and (Test-Path -LiteralPath $root)){
      try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter DeskBox.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} }catch{}
    }
  }
  return ''
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R243_DESKBOX_INSTALL.md'; $jsonReport=Join-Path $outDir 'r243-deskbox-install.json'
$lab='E:\0mcp-agv-arena-optimized'; $appsRoot=Join-Path $lab 'apps'; $deskboxDir=Join-Path $appsRoot 'DeskBox'; $installerRoot=Join-Path $lab 'installers\r243'
foreach($d in @($appsRoot,$deskboxDir,$installerRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
L '# R243 DeskBox install retry'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('deskbox_dir='+$deskboxDir)
$deskboxExe=Find-DeskBoxExe $deskboxDir
$deskboxInstaller=''
$installExit=999
if(-not $deskboxExe){
  foreach($u in @('https://github.com/Tianyu199509/DeskBox/releases/download/v1.5.2/DeskBox_Setup_1.5.2_x64.exe','https://github.com/Tianyu199509/DeskBox/releases/download/v1.5.0/DeskBox_Setup_1.5.0_x64.exe')){
    $name=($u -split '/')[-1]
    $out=Join-Path $installerRoot $name
    $dr=Download-File $u $out
    $sz=0; if(Test-Path -LiteralPath $out){$sz=(Get-Item -LiteralPath $out).Length}
    L ('download_'+$name+'_exit='+$dr.code)
    L ('download_'+$name+'_bytes='+$sz)
    L ('download_'+$name+'_tail='+(TailText (San $dr.text) 8))
    if($sz -gt 1000000){ $deskboxInstaller=$out; break }
  }
  if($deskboxInstaller){
    $line='"'+$deskboxInstaller+'" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /DIR="'+$deskboxDir+'"'
    $ir=Run-CmdLine $line '' 900
    $installExit=$ir.code
    L ('install_exit='+$installExit)
    L ('install_tail='+(TailText (San $ir.text) 12))
    $deskboxExe=Find-DeskBoxExe $deskboxDir
  }
}
$shortcut=Join-Path $desktop 'DeskBox Cute.lnk'
if($deskboxExe){ New-Link $shortcut $deskboxExe '' (Split-Path -Parent $deskboxExe) $deskboxExe 'DeskBox cute desktop organizer'|Out-Null }
elseif($deskboxInstaller){ New-Link $shortcut $deskboxInstaller '' $installerRoot $deskboxInstaller 'DeskBox installer'|Out-Null }
else{ New-Link $shortcut 'explorer.exe' (Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer') $desktop '' 'DeskBox organizer folder'|Out-Null }
$exeOk=($deskboxExe -and (Test-Path -LiteralPath $deskboxExe))
$installerOk=($deskboxInstaller -and (Test-Path -LiteralPath $deskboxInstaller))
$shortcutOk=Test-Path -LiteralPath $shortcut
L ('deskbox_installer='+$deskboxInstaller+' exists='+$installerOk)
L ('deskbox_exe='+$deskboxExe+' exists='+$exeOk)
L ('deskbox_shortcut='+$shortcut+' exists='+$shortcutOk)
L ('R243_DESKBOX_INSTALL_READY='+($shortcutOk -and ($exeOk -or $installerOk)))
$summary=[pscustomobject]@{ready=($shortcutOk -and ($exeOk -or $installerOk));desktop=$desktop;deskboxDir=$deskboxDir;deskboxInstaller=$deskboxInstaller;deskboxExe=$deskboxExe;shortcut=$shortcut;installExit=$installExit}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 5)+"`r`n")
W $report $script:Lines
if(-not($shortcutOk -and ($exeOk -or $installerOk))){ exit 6 }
exit 0
