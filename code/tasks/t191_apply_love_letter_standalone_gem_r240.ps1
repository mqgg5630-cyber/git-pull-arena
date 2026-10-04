# t191_apply_love_letter_standalone_gem_r240.ps1 - round 240.
# Apply the standalone love-letter/confession Gemini Gem patch into the separate
# goutoujunshi checkout on the user's laptop, push the new Gem folder to Google
# Drive, and push the goutoujunshi branch. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace 'ya29\.[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]'}catch{}; try{$s=$s-replace '1//[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]'}catch{}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{28,}','[REDACTED]'}catch{}; try{$s=$s-replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s-replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }; $txt=(Receive-Job $job 2>&1|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }; return @{code=$code;text=$txt} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'LOVE_LETTER_STANDALONE_GEM_R240.md'
$patch=Join-Path $repo 'deliverable\patches\goutoujunshi-standalone-love-letter-gem.patch'
$branch='arena/01a101bf-goutoujunshi'
$url='https://github.com/mqgg5630-cyber/goutoujunshi.git'
$targetRoot='E:\0github\git-sync'
$target=Join-Path $targetRoot 'goutoujunshi-01a101bf'

L '# R240 apply standalone love-letter Gemini Gem patch'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host='+$env:COMPUTERNAME)
L ('patch='+(San $patch)+' exists='+(Test-Path -LiteralPath $patch))
L ('target='+(San $target))

$git=''; try{ $c=Get-Command git.exe -ErrorAction SilentlyContinue; if(-not $c){$c=Get-Command git -ErrorAction SilentlyContinue}; if($c){$git=$c.Source} }catch{}
L ('git='+(San $git))
if(-not $git -or -not(Test-Path -LiteralPath $patch)){ L 'LOVE_LETTER_STANDALONE_GEM_READY=False'; W $report $script:Lines; exit 2 }

if(-not(Test-Path -LiteralPath (Join-Path $target '.git'))){
  New-Item -ItemType Directory -Force -Path $targetRoot|Out-Null
  if(Test-Path -LiteralPath $target){ Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
  $g=$git; $u=$url; $b=$branch; $t=$target
  $cl=Run-Cap { & $using:g clone -b $using:b $using:u $using:t 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 600
  L ('clone_exit='+$cl.code)
  L ('clone_tail='+(San (($cl.text -split "`r?`n"|Select-Object -Last 12)-join ' | ')))
}
if(-not(Test-Path -LiteralPath (Join-Path $target '.git'))){ L 'target_clone_missing=True'; L 'LOVE_LETTER_STANDALONE_GEM_READY=False'; W $report $script:Lines; exit 3 }

$g=$git; $t=$target; $b=$branch
$cfg=Run-Cap { & $using:g -C $using:t config user.name 'Arena Agent'; & $using:g -C $using:t config user.email 'arena-agent@users.noreply.github.com'; Write-Output '===EXITCODE:0' } 60
$fetch=Run-Cap { & $using:g -C $using:t fetch origin $using:b 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 240
L ('fetch_exit='+$fetch.code)
$co=Run-Cap { & $using:g -C $using:t checkout $using:b 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 120
L ('checkout_exit='+$co.code)
$pull=Run-Cap { & $using:g -C $using:t pull --ff-only origin $using:b 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 240
L ('pull_exit='+$pull.code)
$status0=Run-Cap { & $using:g -C $using:t status --porcelain 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 60
$dirty0=($status0.text.Trim().Length -gt 0)
L ('dirty_before='+$dirty0)
if($dirty0){ L ('dirty_before_lines='+(San (($status0.text -split "`r?`n"|Select-Object -First 20)-join ' | '))); L 'LOVE_LETTER_STANDALONE_GEM_READY=False'; W $report $script:Lines; exit 4 }

$marker=Join-Path $target 'deliverable\gem-love-letter\Gem????.md'
$gemDir=Join-Path $target 'deliverable\gem-love-letter'
$already=Test-Path -LiteralPath $gemDir
L ('already_applied='+$already)
if(-not $already){
  $p=$patch; $am=Run-Cap { & $using:g -C $using:t am --3way $using:p 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 300
  L ('git_am_exit='+$am.code)
  L ('git_am_tail='+(San (($am.text -split "`r?`n"|Select-Object -Last 20)-join ' | ')))
  if($am.code -ne 0){
    $ab=Run-Cap { & $using:g -C $using:t am --abort 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 60
    L 'LOVE_LETTER_STANDALONE_GEM_READY=False'
    W $report $script:Lines
    exit 5
  }
}

$py=''; foreach($n in @('python','py')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){$py=$c.Source; break} }catch{} }
L ('python='+(San $py))
if($py){
  $pyp=$py; $val=Run-Cap { & $using:pyp (Join-Path $using:t 'scripts\validate_skill.py') 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 180
  L ('validate_exit='+$val.code)
  L ('validate_tail='+(San (($val.text -split "`r?`n"|Select-Object -Last 12)-join ' | ')))
}

$t4=Join-Path $target 'code\tasks\t4_push_love_letter_gem_r4.ps1'
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$taskOk=$false
if(Test-Path -LiteralPath $t4){
  $run=Run-Cap { & $using:psExe -NoProfile -ExecutionPolicy Bypass -File $using:t4 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 2400
  L ('target_t4_exit='+$run.code)
  L ('target_t4_tail='+(San (($run.text -split "`r?`n"|Select-Object -Last 80)-join ' | ')))
  $taskOk=($run.code -eq 0)
}else{ L 'target_t4_missing=True' }

$add=Run-Cap { & $using:g -C $using:t add results/cloud_interop/LOVE_LETTER_GEM_GDRIVE_PUSH_R4.md 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 60
$diffCached=Run-Cap { & $using:g -C $using:t diff --cached --quiet 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 60
if($diffCached.code -ne 0){
  $cm=Run-Cap { & $using:g -C $using:t commit -m 'check: push standalone love letter gem r4' 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 120
  L ('report_commit_exit='+$cm.code)
  L ('report_commit_tail='+(San (($cm.text -split "`r?`n"|Select-Object -Last 20)-join ' | ')))
}else{ L 'report_commit_skipped_no_changes=True' }
$push=Run-Cap { & $using:g -C $using:t push origin $using:b 2>&1|Out-String; Write-Output ('===EXITCODE:'+$LASTEXITCODE) } 300
L ('target_push_exit='+$push.code)
L ('target_push_tail='+(San (($push.text -split "`r?`n"|Select-Object -Last 30)-join ' | ')))

$r4=Join-Path $target 'results\cloud_interop\LOVE_LETTER_GEM_GDRIVE_PUSH_R4.md'
$r4Ok=$false
if(Test-Path -LiteralPath $r4){ try{ $r4Ok=((Get-Content -LiteralPath $r4 -Raw -Encoding UTF8) -match 'LOVE_LETTER_GEM_PUSH_OK=True') }catch{} }
$finalOk=((Test-Path -LiteralPath $gemDir) -and $taskOk -and $r4Ok -and ($push.code -eq 0))
L ('standalone_gem_dir_exists='+(Test-Path -LiteralPath $gemDir))
L ('r4_report_ok='+$r4Ok)
L ('LOVE_LETTER_STANDALONE_GEM_READY='+$finalOk)
W $report $script:Lines
if(-not $finalOk){ exit 6 }
exit 0
