# t186_install_openspeedy_desktop_r235.ps1 - round 235.
# Download game1024/OpenSpeedy portable release to Desktop and create one-click launchers.
# ASCII-only. No Antigravity/IDE actions.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s-replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s-replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Download-File([string]$Url,[string]$Out){
  try{
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
  }catch{}
  try{
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out -Headers @{'User-Agent'='Arena-OpenSpeedy-Setup'} -TimeoutSec 180
    return $true
  }catch{
    $msg=$_.Exception.Message
    try{
      $curl=Join-Path $env:SystemRoot 'System32\curl.exe'
      & $curl -L --retry 3 --connect-timeout 20 --max-time 240 -A 'Arena-OpenSpeedy-Setup' -o $Out $Url 2>&1 | Out-Null
      return (Test-Path -LiteralPath $Out)
    }catch{
      L ('download_error='+(San ($msg+' | '+$_.Exception.Message)))
      return $false
    }
  }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'OPENSPEEDY_DESKTOP_SETUP_R235.md'
L '# R235 OpenSpeedy desktop setup'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))
L 'repo=game1024/OpenSpeedy'

$desktop=[Environment]::GetFolderPath('Desktop')
if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$dest=Join-Path $desktop 'OpenSpeedy'
$tmp=Join-Path $dest '_download'
New-Item -ItemType Directory -Force -Path $dest,$tmp|Out-Null
L ('desktop='+(San $desktop))
L ('dest='+(San $dest))

# Discover latest release asset.
$api='https://api.github.com/repos/game1024/OpenSpeedy/releases/latest'
$rel=$null; $asset=$null; $assetUrl=''; $assetName=''; $tag=''
try{
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
  $rel=Invoke-RestMethod -UseBasicParsing -Headers @{'User-Agent'='Arena-OpenSpeedy-Setup'} -Uri $api -TimeoutSec 60
  $tag=[string]$rel.tag_name
  $assets=@($rel.assets)
  $asset=@($assets | Where-Object { $_.name -match '(?i)portable.*signed.*\.zip$' } | Select-Object -First 1)
  if(-not $asset){ $asset=@($assets | Where-Object { $_.name -match '(?i)portable.*\.zip$' } | Select-Object -First 1) }
  if(-not $asset){ $asset=@($assets | Where-Object { $_.name -match '(?i)win.*\.zip$|\.zip$' } | Select-Object -First 1) }
  if(-not $asset){ $asset=@($assets | Where-Object { $_.name -match '(?i)\.msi$|\.exe$' } | Select-Object -First 1) }
  if($asset){ $assetUrl=[string]$asset.browser_download_url; $assetName=[string]$asset.name }
}catch{ L ('github_api_error='+(San $_.Exception.Message)) }

# Fallback to a known naming scheme using the latest tag from website/search history if API had no usable asset.
if(-not $assetUrl -and $tag){
  $cleanTag=$tag.TrimStart('v')
  $assetName='OpenSpeedy-'+$cleanTag+'-portable-signed.zip'
  $assetUrl='https://github.com/game1024/OpenSpeedy/releases/download/'+$tag+'/'+$assetName
}
if(-not $assetUrl){
  $tag='3.3.8'
  $assetName='OpenSpeedy-3.3.8-portable-signed.zip'
  $assetUrl='https://github.com/game1024/OpenSpeedy/releases/download/3.3.8/'+$assetName
}
L ('release_tag='+(San $tag))
L ('asset_name='+(San $assetName))
L ('asset_url='+(San $assetUrl))

$downloadPath=Join-Path $tmp $assetName
if(Test-Path -LiteralPath $downloadPath){ Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue }
$downloadOk=Download-File $assetUrl $downloadPath
$downloadBytes=0; if(Test-Path -LiteralPath $downloadPath){ $downloadBytes=(Get-Item -LiteralPath $downloadPath).Length }
L ('download_ok='+$downloadOk+' bytes='+$downloadBytes+' path='+(San $downloadPath))

$extractRoot=Join-Path $dest 'app'
if(Test-Path -LiteralPath $extractRoot){ Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $extractRoot|Out-Null
$installKind='unknown'
if($downloadOk -and $assetName -match '(?i)\.zip$'){
  try{
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractRoot -Force
    $installKind='zip'
  }catch{ L ('expand_error='+(San $_.Exception.Message)) }
}elseif($downloadOk -and $assetName -match '(?i)\.exe$|\.msi$'){
  Copy-Item -LiteralPath $downloadPath -Destination (Join-Path $extractRoot $assetName) -Force
  $installKind='single-installer'
}
L ('install_kind='+$installKind)

# Find app exe. Avoid uninstallers/updaters.
$exe=$null
try{
  $exe=@(Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Include *.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '(?i)OpenSpeedy|Speedy' -and $_.Name -notmatch '(?i)unins|uninstall|update|setup' } |
    Sort-Object Length -Descending | Select-Object -First 1)
  if(-not $exe){ $exe=@(Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Include *.exe -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)unins|uninstall|update|setup' } | Sort-Object Length -Descending | Select-Object -First 1) }
}catch{}
$exePath=''; if($exe){ $exePath=$exe.FullName }
$exeBytes=0; if($exePath -and(Test-Path -LiteralPath $exePath)){ $exeBytes=(Get-Item -LiteralPath $exePath).Length }
L ('exe_path='+(San $exePath))
L ('exe_bytes='+$exeBytes)

# Create one-click launchers.
$runBat=Join-Path $dest 'Run-OpenSpeedy.bat'
$adminBat=Join-Path $dest 'Run-OpenSpeedy-as-Admin.bat'
$desktopBat=Join-Path $desktop 'OpenSpeedy.bat'
$desktopLnk=Join-Path $desktop 'OpenSpeedy.lnk'
if($exePath){
  W $runBat @('@echo off','cd /d "%~dp0"','start "OpenSpeedy" "'+$exePath+'"')
  W $adminBat @('@echo off','powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '''+$exePath+''' -Verb RunAs"')
  W $desktopBat @('@echo off','call "'+$runBat+'"')
  try{
    $ws=New-Object -ComObject WScript.Shell
    $sc=$ws.CreateShortcut($desktopLnk)
    $sc.TargetPath=$exePath
    $sc.WorkingDirectory=(Split-Path -Parent $exePath)
    $sc.IconLocation=$exePath
    $sc.Description='OpenSpeedy one-click launcher'
    $sc.Save()
  }catch{ L ('shortcut_error='+(San $_.Exception.Message)) }
}
L ('run_bat='+(San $runBat)+' exists='+(Test-Path -LiteralPath $runBat))
L ('desktop_bat='+(San $desktopBat)+' exists='+(Test-Path -LiteralPath $desktopBat))
L ('desktop_lnk='+(San $desktopLnk)+' exists='+(Test-Path -LiteralPath $desktopLnk))
L ('admin_bat='+(San $adminBat)+' exists='+(Test-Path -LiteralPath $adminBat))

$readme=Join-Path $dest 'README_ARENA.txt'
W $readme @(
'OpenSpeedy desktop package prepared by Arena.',
'',
'Run:',
'  Double-click Desktop\\OpenSpeedy.lnk or Desktop\\OpenSpeedy.bat',
'',
'Files:',
('  App folder: '+$extractRoot),
('  Main exe: '+$exePath),
('  Normal launcher: '+$runBat),
('  Admin launcher: '+$adminBat),
'',
'If OpenSpeedy cannot affect a target process, close it and use Run-OpenSpeedy-as-Admin.bat, then approve the UAC prompt.',
'Use only where allowed by the game/software rules.'
)

# Optional signature metadata only; do not fail on unsigned.
$sigStatus=''; $sigSigner=''
if($exePath){ try{ $sig=Get-AuthenticodeSignature -LiteralPath $exePath; $sigStatus=[string]$sig.Status; $sigSigner=[string]$sig.SignerCertificate.Subject }catch{} }
L ('signature_status='+(San $sigStatus))
L ('signature_signer='+(San $sigSigner))

$summaryJson=Join-Path $outDir 'openspeedy-desktop-setup-r235.json'
$summary=[pscustomobject]@{
  releaseTag=$tag; assetName=$assetName; assetUrl=$assetUrl; downloadOk=$downloadOk; downloadBytes=$downloadBytes; downloadPath=$downloadPath;
  desktop=$desktop; dest=$dest; extractRoot=$extractRoot; exePath=$exePath; exeBytes=$exeBytes; signatureStatus=$sigStatus; signatureSigner=$sigSigner;
  runBat=$runBat; adminBat=$adminBat; desktopBat=$desktopBat; desktopLnk=$desktopLnk; readme=$readme
}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
$status=if($downloadOk -and $exePath -and (Test-Path -LiteralPath $desktopLnk)){ 'OPENSPEEDY_DESKTOP_READY' }elseif($downloadOk -and $exePath){ 'OPENSPEEDY_EXE_READY_NO_SHORTCUT' }else{ 'OPENSPEEDY_SETUP_INCOMPLETE' }
L ('status='+$status)
L ('FINAL_R235: '+$status)
W $report $script:Lines
exit 0
