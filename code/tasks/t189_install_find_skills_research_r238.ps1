# t189_install_find_skills_research_r238.ps1 - round 238.
# Install find-skills and write love-record/video skills + GitHub report to desktop.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s-replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s-replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WUtf8([string]$p,[string]$content){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$content,(New-Object Text.UTF8Encoding($false))) }
function WLines([string]$p,[string[]]$lines){ WUtf8 $p (($lines -join "`r`n")+"`r`n") }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job 2>&1|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Copy-Dir([string]$src,[string]$dst){ if(Test-Path -LiteralPath $src){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null; if(Test-Path -LiteralPath $dst){ Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue }; Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force; return $true }; return $false }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$runReport=Join-Path $outDir 'FIND_SKILLS_LOVE_VIDEO_R238.md'
L '# R238 install find-skills and write research report'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('repo='+(San $repo))

$lab='E:\0mcp-agv-arena-optimized'
$skillsRoot=Join-Path $lab 'skills'
$eSkillDir=Join-Path $skillsRoot 'find-skills'
$sourceRoot=Join-Path $skillsRoot '_sources\vercel-labs-skills'
New-Item -ItemType Directory -Force -Path $skillsRoot|Out-Null

$desktop=[Environment]::GetFolderPath('Desktop')
if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
if(-not(Test-Path -LiteralPath $desktop)){ New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$desktopReport=Join-Path $desktop 'love-record-video-skills-github-report.md'
$projectSkillDir=Join-Path $repo '.agents\skills\find-skills'
$projectSkillMd=Join-Path $projectSkillDir 'SKILL.md'
$agentSkillDir=Join-Path $repo 'agent\skills\find-skills'
$agentSkillMd=Join-Path $agentSkillDir 'SKILL.md'

$node=''; try{ $c=Get-Command node.exe -ErrorAction SilentlyContinue; if($c){ $node=$c.Source } }catch{}
$npx=''; try{ $c=Get-Command npx.cmd -ErrorAction SilentlyContinue; if(-not $c){ $c=Get-Command npx -ErrorAction SilentlyContinue }; if($c){ $npx=$c.Source } }catch{}
L ('node='+(San $node))
L ('npx='+(San $npx))

$installOut=''
$installStatus='not_run'
if($npx){
  $repo2=$repo; $npx2=$npx
  $installOut=Run-Cap { Set-Location -LiteralPath $using:repo2; & $using:npx2 --yes skills add https://github.com/vercel-labs/skills --skill find-skills --copy --json -y 2>&1 | Out-String } 600
  L ('npx_install_head='+(San (($installOut -split "`r?`n"|Select-Object -First 18)-join ' | ')))
  if(Test-Path -LiteralPath $projectSkillMd){ $installStatus='installed_by_npx' }else{ $installStatus='npx_ran_but_skill_missing' }
}else{
  L 'npx_not_found=True'
  $installStatus='npx_not_found'
}

# Fallback: clone vercel-labs/skills and copy find-skills into project and E:.
$cloneOut=''
if(-not(Test-Path -LiteralPath $projectSkillMd)){
  $git=''; try{ $c=Get-Command git.exe -ErrorAction SilentlyContinue; if(-not $c){ $c=Get-Command git -ErrorAction SilentlyContinue }; if($c){ $git=$c.Source } }catch{}
  L ('git='+(San $git))
  if($git){
    if(Test-Path -LiteralPath (Join-Path $sourceRoot '.git')){
      $git2=$git; $sr=$sourceRoot
      $cloneOut=Run-Cap { & $using:git2 -C $using:sr pull --ff-only 2>&1 | Out-String } 240
    }else{
      if(Test-Path -LiteralPath $sourceRoot){ Remove-Item -LiteralPath $sourceRoot -Recurse -Force -ErrorAction SilentlyContinue }
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourceRoot)|Out-Null
      $git2=$git; $sr=$sourceRoot
      $cloneOut=Run-Cap { & $using:git2 clone --depth 1 https://github.com/vercel-labs/skills.git $using:sr 2>&1 | Out-String } 420
    }
    L ('fallback_clone_head='+(San (($cloneOut -split "`r?`n"|Select-Object -First 12)-join ' | ')))
    $srcSkill=Join-Path $sourceRoot 'skills\find-skills'
    if(Test-Path -LiteralPath (Join-Path $srcSkill 'SKILL.md')){
      [void](Copy-Dir $srcSkill $projectSkillDir)
      [void](Copy-Dir $srcSkill $agentSkillDir)
      if(Test-Path -LiteralPath $projectSkillMd){ $installStatus='installed_by_git_fallback' }
    }
  }
}

$copySource=''
if(Test-Path -LiteralPath $projectSkillMd){ $copySource=$projectSkillDir }
elseif(Test-Path -LiteralPath (Join-Path $sourceRoot 'skills\find-skills\SKILL.md')){ $copySource=Join-Path $sourceRoot 'skills\find-skills' }
$copiedE=$false
if($copySource){ $copiedE=Copy-Dir $copySource $eSkillDir }
L ('project_skill='+(San $projectSkillMd)+' exists='+(Test-Path -LiteralPath $projectSkillMd))
L ('agent_skill='+(San $agentSkillMd)+' exists='+(Test-Path -LiteralPath $agentSkillMd))
L ('e_skill_dir='+(San $eSkillDir)+' exists='+(Test-Path -LiteralPath (Join-Path $eSkillDir 'SKILL.md')))
L ('install_status='+$installStatus)

$templateB64=@'
IyBmaW5kLXNraWxscyDlronoo4XkuI7jgIzmg4XkvqPmgYvniLHorrDlvZUgKyDop4bpopHjgI1T
a2lsbHMvR2l0SHViIOmrmOaYn+S7k+W6k+iwg+eglAoK55Sf5oiQ5pe26Ze077yaX19USU1FX18K
CuahjOmdouaKpeWRiuaWh+S7tu+8mmBfX0RFU0tUT1BfUkVQT1JUX19gCgotLS0KCiMjIDEuIGZp
bmQtc2tpbGxzIOWuieijhee7k+aenAoKLSDlronoo4XnirbmgIHvvJoqKl9fSU5TVEFMTF9TVEFU
VVNfXyoqCi0g6aG555uu57qn5oqA6IO955uu5b2V77yaYF9fUFJPSkVDVF9TS0lMTF9ESVJfX2AK
LSBFIOebmOWkh+S7veebruW9le+8mmBfX0VfU0tJTExfRElSX19gCi0gTm9kZe+8mmBfX05PREVf
X2AKLSBucHjvvJpgX19OUFhfX2AKLSDlronoo4Xlkb3ku6TvvJoKCmBgYGJhc2gKbnB4IC0teWVz
IHNraWxscyBhZGQgaHR0cHM6Ly9naXRodWIuY29tL3ZlcmNlbC1sYWJzL3NraWxscyAtLXNraWxs
IGZpbmQtc2tpbGxzIC0tY29weSAtLWpzb24gLXkKYGBgCgpgZmluZC1za2lsbHNgIOadpeiHqiBg
dmVyY2VsLWxhYnMvc2tpbGxzYO+8jOeUqOmAlOaYr+W4ruWKqeWPkeeOsOOAgemqjOivgeWSjOWu
ieijheW8gOaUviBBZ2VudCBTa2lsbHPjgILku6XlkI7lj6/ku6XnlKjvvJoKCmBgYGJhc2gKbnB4
IHNraWxscyBmaW5kIHZpZGVvCm5weCBza2lsbHMgZmluZCByZWxhdGlvbnNoaXAKbnB4IHNraWxs
cyBhZGQgPG93bmVyL3JlcG8+IC0tc2tpbGwgPHNraWxsLW5hbWU+CmBgYAoK5pys5qyh5a6J6KOF
6L6T5Ye65pGY6KaB77yaCgpgYGB0ZXh0Cl9fSU5TVEFMTF9IRUFEX18KYGBgCgotLS0KCiMjIDIu
IOW/q+mAn+e7k+iuugoKIyMjIOaDheS+oy/mgYvniLHorrDlvZXmlrnlkJEKCui/meS4quaWueWQ
keeahCAqKkFnZW50IFNraWxsKiog55Sf5oCB6L+Y5LiN566X5oiQ54af77ya5rKh5pyJ5om+5Yiw
5b6I5aSa5LiT6Zeo5YGa4oCc5oOF5L6j5oGL54ix6K6w5b2VL+e6quW/teaXpeebuOWGjC/niLHm
g4Xml7bpl7Tnur/igJ3nmoTpq5jmmJ8gQWdlbnQgU2tpbGzjgILmm7TnjrDlrp7nmoTmlrnmoYjm
mK/vvJoKCjEuIOeUqOS4i+mdoueahOW8gOa6kOaDheS+o+epuumXtC/mgYvniLHorrDlvZXku5Pl
upPlgZrmlbDmja7kuI7nlYzpnaLvvJsKMi4g55So5YWz57O75YiG5p6QL+aBi+eIseaWh+ahiOex
uyBza2lsbCDovoXliqnlhpnmlofmoYjvvJsKMy4g55So6KeG6aKR57G7IHNraWxsIOaIluWJquaY
oCBza2lsbCDmiornhafniYfjgIHnuqrlv7Xml6XjgIHlnLDngrnovajov7njgIHogYrlpKnmopfl
gZrmiJDnuqrlv7Xnn63niYfjgIIKCiMjIyDop4bpopHmlrnlkJEKCuinhumikeaWueWQkeeahCBT
a2lsbCDlkowgR2l0SHViIOS7k+W6k+aYjuaYvuabtOaIkOeGn+OAguW7uuiuruS8mOWFiOWFs+az
qO+8mgoKLSBgamlhbnlpbmctZWRpdG9yYO+8mumAguWQiOiHquWKqOWMluWJquaYoC9DYXBDdXQg
5Lit5paH54mI77yb5L2g55S16ISR5LiK5LmL5YmN5bey57uP5a6J6KOF6L+H44CCCi0gYHplbnN0
b3J5LWFpL2RyYW1hLXNraWxsc2DvvJrnn63liacv5YiG6ZWcL+inhumikeaPkOekuuivjS/lrqHm
n6XvvIzpgILlkIjliafmg4XljJbmg4XkvqPnuqrlv7Xnn63niYfjgIIKLSBgbmFycmF0b3ItYWkt
Y2xpLXNraWxsYO+8mumAguWQiCBBSSDop6Por7TjgIHml4Hnmb3jgIHlj6Pmkq3ohJrmnKzliLDo
p4bpopHjgIIKLSBgbWF4YXp1cmUvdmlkZW8tZWRpdGluZy1za2lsbGDvvJrlgY/oh6rliqjliaro
vpHjgIHlrZfluZXjgIHlj6Pmkq0v6K6/6LCI6KeG6aKR44CCCi0gYGJsaXR6cmVlbHMvYWdlbnQt
c2tpbGxzYO+8muWBj+efreinhumikeOAgeWIh+eJh+OAgeWtl+W5leS4u+mimOOAgeWKqOaViOOA
ggoKLS0tCgojIyAzLiDnm7jlhbMgQWdlbnQgU2tpbGxzIOaOqOiNkAoKIyMjIDMuMSDmg4XkvqMv
5oGL54ixL+WFs+ezu+ebuOWFsyBTa2lsbHMKCnwg5o6o6I2Q5bqmIHwgU2tpbGwgLyDku5PlupMg
fCDlronoo4Xph48gLyDmmJ/moIcgfCDpgILlkIjnlKjpgJQgfCDlronoo4Xlkb3ku6QgfAp8LS0t
fC0tLTp8LS0tOnwtLS18LS0tfAp8IOKYheKYheKYheKYheKYhiB8IGBsaWppZ2FuZy9samctc2tp
bGxzYCAvIGBsamctcmVsYXRpb25zaGlwYCB8IDYuMksgaW5zdGFsbHPvvIznuqYgNy40SyBzdGFy
cyB8IOWFs+ezu+e7k+aehOWIhuaekOOAgeayn+mAmuWkjeebmOOAgeaBi+eIseiusOW9leaAu+e7
k++8jOS4jeaYr+aXpeiusCBBcHDvvIzkvYbpgILlkIjnlJ/miJDigJzlhbPns7vmtJ7lr58v5aSN
55uY5paH5qGI4oCdIHwgYG5weCBza2lsbHMgYWRkIGh0dHBzOi8vZ2l0aHViLmNvbS9saWppZ2Fu
Zy9samctc2tpbGxzIC0tc2tpbGwgbGpnLXJlbGF0aW9uc2hpcGAgfAp8IOKYheKYheKYheKYhuKY
hiB8IGByZWFzb24tbWFjaGluZXMvdHJlbmRpbmctc2tpbGxzYCAvIGB0b25nLWppbmNoZW5nLXJl
bGF0aW9uc2hpcC1za2lsbGAgfCA2MzYgaW5zdGFsbHPvvIznuqYgODMgc3RhcnMgfCDmgYvniLEv
5YWz57O76Zeu6aKY5YiG5p6Q77yM6aOO5qC85pu055u055m977yM6YCC5ZCI5YGa5oOF5oSf57G7
5Y+j5pKt5YaF5a655Y+C6ICDIHwgYG5weCBza2lsbHMgYWRkIGh0dHBzOi8vZ2l0aHViLmNvbS9y
ZWFzb24tbWFjaGluZXMvdHJlbmRpbmctc2tpbGxzIC0tc2tpbGwgdG9uZy1qaW5jaGVuZy1yZWxh
dGlvbnNoaXAtc2tpbGxgIHwKfCDimIXimIXimIbimIbimIYgfCBgZ2Vla3MtYWNjZWxlcmF0b3Iv
aW4tYmVkLWFpYCB8IDE4OCB0b3RhbCBpbnN0YWxsc++8jOe6piAyNSBzdGFycyB8IGRhdGluZy9s
b3ZlL3NvY2lhbC9mbGlydGluZyDnrYnkupLliqjnsbsgc2tpbGzvvJvlgY/nuqbkvJov56S+5Lqk
77yM5LiN5piv5oGL54ix6K6w5b2VIHwgYG5weCBza2lsbHMgYWRkIGdlZWtzLWFjY2VsZXJhdG9y
L2luLWJlZC1haWAgfAoKPiDlu7rorq7vvJrlpoLmnpzkvaDnmoTnm67moIfmmK/igJzmg4XkvqPm
gYvniLHorrDlvZXkuqflk4HigJ3vvIzkuI3opoHlj6rmib4gU2tpbGzvvJvlupTkvJjlhYjnnIvn
rKwgNCDoioLnmoTlvIDmupDku5PlupPvvIzlho3nu5PlkIjkuIrpnaLnmoQgcmVsYXRpb25zaGlw
L2xvdmUgc2tpbGwg5YGa5paH5qGI5LiO5oC757uT44CCCgojIyMgMy4yIOinhumikeebuOWFsyBT
a2lsbHMKCnwg5o6o6I2Q5bqmIHwgU2tpbGwgLyDku5PlupMgfCDlronoo4Xph48gLyDmmJ/moIcg
fCDpgILlkIjnlKjpgJQgfCDlronoo4Xlkb3ku6QgfAp8LS0tfC0tLTp8LS0tOnwtLS18LS0tfAp8
IOKYheKYheKYheKYheKYhSB8IGBsdW9sdW9sdW8yMi9qaWFueWluZy1lZGl0b3Itc2tpbGxgIC8g
YGppYW55aW5nLWVkaXRvcmAgfCAyLjBLIGluc3RhbGxz77yM57qmIDMuN0sgc3RhcnMgfCDoh6rl
iqjljJbliarmmKAvQ2FwQ3V0IOS4reaWh+eJiOOAgee0oOadkOWvvOWFpeOAgeWtl+W5leOAgemF
jemfs+OAgeWvvOWHuu+8m+acgOmAguWQiOS4reaWh+WJqui+kemTvui3ryB8IGBucHggc2tpbGxz
IGFkZCBsdW9sdW9sdW8yMi9qaWFueWluZy1lZGl0b3Itc2tpbGxgIHwKfCDimIXimIXimIXimIXi
mIUgfCBgemVuc3RvcnktYWkvZHJhbWEtc2tpbGxzYCB8IDcuNksgdG90YWwgaW5zdGFsbHPvvIzn
uqYgMi41SyBzdGFycyB8IOefreWJp+iEmuacrOOAgeinkuiJsui1hOS6p+OAgeWIhumVnOOAgeWb
vueJhy/op4bpopHmj5DnpLror43jgIHnn63liafnlJ/kuqfkuI7lrqHmn6UgfCBgbnB4IHNraWxs
cyBhZGQgemVuc3RvcnktYWkvZHJhbWEtc2tpbGxzYCB8Cnwg4piF4piF4piF4piF4piGIHwgYGVj
bGlwdGljLWFpL3NraWxsc2AgLyBgYmVhdC1zeW5jLXZpZGVvLWVkaXRpbmdgIHwgNzA1IHRvdGFs
IGluc3RhbGxz77ybYmVhdC1zeW5jIDY4OCBpbnN0YWxscyB8IOmfs+S5kOiKguaLjeWQjOatpeWJ
qui+keOAgW1vbnRhZ2UgfCBgbnB4IHNraWxscyBhZGQgZWNsaXB0aWMtYWkvc2tpbGxzYCB8Cnwg
4piF4piF4piF4piF4piGIHwgYGJsaXR6cmVlbHMvYWdlbnQtc2tpbGxzYCB8IDEuMEsgdG90YWwg
aW5zdGFsbHPvvJt2aWRlby1lZGl0aW5nIDUxOCBpbnN0YWxscyB8IOefreinhumikeWJqui+keOA
geWIh+eJh+OAgeWtl+W5leS4u+mimOOAgeWKqOaViOOAgeaXoOmcsuiEuOinhumikSB8IGBucHgg
c2tpbGxzIGFkZCBibGl0enJlZWxzL2FnZW50LXNraWxsc2AgfAp8IOKYheKYheKYheKYheKYhiB8
IGBtYXhhenVyZS92aWRlby1lZGl0aW5nLXNraWxsYCAvIGB2aWRlby1lZGl0aW5nYCB8IDM1NiBp
bnN0YWxsc++8jOe6piAxOTMgc3RhcnMgfCDlj6Pmkq0v6K6/6LCI6KeG6aKR6Ieq5Yqo5Ymq6L6R
44CB5a2X5bmV54On5b2V44CB54mH5q615ZCI5bm2IHwgYG5weCBza2lsbHMgYWRkIG1heGF6dXJl
L3ZpZGVvLWVkaXRpbmctc2tpbGxgIHwKfCDimIXimIXimIXimIXimIYgfCBgbmFycmF0b3JhaS1z
dHVkaW8vbmFycmF0b3ItYWktY2xpLXNraWxsYCB8IDM1MSBpbnN0YWxsc++8jOe6piAzLjBLIHN0
YXJzIHwgQUkg6Kej6K+0L+aXgeeZveexu+W3peS9nOa1ge+8jOmAguWQiOaDheaEn+aVheS6i+OA
geaDheS+o+WbnuW/huWPo+aSrSB8IGBucHggc2tpbGxzIGFkZCBuYXJyYXRvcmFpLXN0dWRpby9u
YXJyYXRvci1haS1jbGktc2tpbGxgIHwKfCDimIXimIXimIXimIbimIYgfCBgZ29sZGxlZ2VuZHc4
MC9sbG0tdmlkZW8tbWFrZXJgIHwgMjk5IHRvdGFsIGluc3RhbGxzIHwg5LiA5LiqIHByb21wdCDl
iLAgTVA077yM5ZCr5peB55m944CB5a2X5bmV44CB6Z+z5LmQ44CB55yf5a6e57Sg5p2QIHwgYG5w
eCBza2lsbHMgYWRkIGdvbGRsZWdlbmR3ODAvbGxtLXZpZGVvLW1ha2VyYCB8Cnwg4piF4piF4piF
4piG4piGIHwgYGF3ZXNvbWUtZ2VubWVkaWEvc2tpbGxzYCB8IDQyNiB0b3RhbCBpbnN0YWxscyB8
IOinhumikeeUn+aIkOOAgeinhumikee8lui+keOAgeiDjOaZr+enu+mZpOOAgVRUU+OAgeWjsOmf
s+eUn+aIkOetieWkmuWqkuS9kyBza2lsbCDljIUgfCBgbnB4IHNraWxscyBhZGQgYXdlc29tZS1n
ZW5tZWRpYS9za2lsbHNgIHwKCi0tLQoKIyMgNC4gR2l0SHViIOmrmOaYn+S7k+W6k++8muaDheS+
oy/mgYvniLHorrDlvZXmlrnlkJEKCj4g6K+05piO77ya5oOF5L6j5oGL54ix6K6w5b2V5bGe5LqO
5bCP5LyX6LWb6YGT77yM5omA5Lul4oCc6auY5pif4oCd5piv55u45a+55pys6LWb6YGT6ICM6KiA
44CC5pif5qCH5Li6IDIwMjYtMTAtMDQg5pCc57Si5pe255qE6L+R5Ly85YC844CCCgp8IOaYn+ag
hyB8IOS7k+W6kyB8IOaWueWQkSB8IOmAguWQiOS9oOaAjuS5iOeUqCB8CnwtLS06fC0tLXwtLS18
LS0tfAp8IDIzMCB8IGh0dHBzOi8vZ2l0aHViLmNvbS9rZWVsZXljZW5jL2NjLW91ci1zdG9yeSB8
IOiHquaJmOeuoeaDheS+o+epuumXtO+8jOiusOW9leW9vOatpOeCuea7tOS4juaVheS6iyB8IOac
gOaOpei/keKAnOaDheS+o+aBi+eIseiusOW9leezu+e7n+KAneeahOaWueWQke+8jOWPr+WPguiA
g+aVsOaNrue7k+aehOWSjOmhtemdoue7hOe7hyB8CnwgMTMxIHwgaHR0cHM6Ly9naXRodWIuY29t
L2JiYmxhY2tjbGFyay8xMDI0aG91c2UgfCDmnKzlnLDnp4HmnInmg4XkvqMv5a625bqt56m66Ze0
77yM56S86LSm5pys44CB57qq5b+15pel44CB5a6d5a6d5oiQ6ZW/44CB5pel5bi45pS25pSvIHwg
5aaC5p6c5oOz5YGa56eB5pyJ5YyW5oOF5L6jL+WutuW6reepuumXtO+8jOi/meS4quW+iOWAvOW+
l+eciyB8CnwgMTA2IHwgaHR0cHM6Ly9naXRodWIuY29tL3RlY2gta2V2L1NoYXJlZE1vbWVudHMg
fCBDb3VwbGVzIHNwZWNpYWwgbW9tZW50cyAvIG1lbW9yaWVzIHdlYnNpdGUgfCDpgILlkIjlgZrn
hafniYflm57lv4bjgIHnibnmrorml7bliLvorrDlvZXnvZHnq5kgfAp8IDcxIHwgaHR0cHM6Ly9n
aXRodWIuY29tL1lpemFjay9tYXBwZWRsb3ZlIHwg5Zyw5Zu+5qCH6K6w5oOF5L6j5LiA6LW35Y67
6L+H55qE5Zyw5pa544CB5LiK5Lyg54Wn54mHIHwg5b6I6YCC5ZCI5YGa4oCc5oiR5Lus55qE6Laz
6L+55Zyw5Zu+4oCd5qih5Z2XIHwKfCA2NSB8IGh0dHBzOi8vZ2l0aHViLmNvbS9xaWFlcnUvY291
cGxlY2FyZHMgfCDmg4XkvqPmir3mtLvliqjljaHniYfvvIzmiZPnoLTml6XluLggfCDkuI3mmK/o
rrDlvZXvvIzkvYbpgILlkIjlgZrkupLliqjnjqnms5XmqKHlnZcgfAp8IDY0IHwgaHR0cHM6Ly9n
aXRodWIuY29tL2Nhcmxhc3NtYW5uL3RpbGx5IHwgUmVsYXRpb25zaGlwIGpvdXJuYWzvvIznprvn
ur8gUFdB77yM5bimIEFJIGFnZW50IHwg6YCC5ZCI5Y+C6ICD56a757q/5YWz57O75pel6K6w5L2T
6aqMIHwKfCA2MyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9ob290aGluL1FpbmdMdiB8IOaDheS+o+mj
nuihjOaji+S6kuWKqOWwj+a4uOaIjyB8IOWPr+S9nOS4uuaDheS+o+iusOW9lSBBcHAg55qE5bCP
5ri45oiPL+S6kuWKqOaooeWdlyB8CnwgMjMgfCBodHRwczovL2dpdGh1Yi5jb20vRW5kZXJqdWEv
dmFsZW50aW5lLW1vYmlsZS1hcHAgfCBGbHV0dGVyIOaDheS+oy/kvLTkvqPnp7vliqjlupTnlKgg
fCDpgILlkIjnp7vliqjnq68gVUkv5Lqk5LqS5Y+C6ICDIHwKfCAxNiB8IGh0dHBzOi8vZ2l0aHVi
LmNvbS9YVEgtTE9WRS9Mb3ZlLSB8IENvdXBsZVNwYWNl77ya55u45YaM44CB5pe25YWJ6L2044CB
5oKE5oKE6K+d44CB57qq5b+15pel44CBQUkg5pel6K6w44CB5Zyw5Zu+562JIHwg5Yqf6IO95pa5
5ZCR6Z2e5bi46LS06L+R77yM5L2G5pif5pWw6L6D5L2O77yM6YCC5ZCI5Y+C6ICD5Lqn5ZOB5qih
5Z2XIHwKfCAxMCB8IGh0dHBzOi8vZ2l0aHViLmNvbS9pYm51c2FiL215bG92ZSB8IOengeS6uuaV
sOWtlyBsb3ZlIGRpYXJ577yM5pe26Ze057q/44CB55u45YaM44CB6Z+z5LmQ44CB5YCS6K6h5pe2
44CB5oOF5LmmIHwg6YCC5ZCI5Y+C6ICD4oCc5oGL54ix5pel6K6wL+e6quW/teaXpeKAnei9u+mH
j+WMluWunueOsCB8CnwgOSB8IGh0dHBzOi8vZ2l0aHViLmNvbS9hbmRyZWxjYWxhZG8vbm9zc2Fz
LWxlbWJyYW5jYXMgfCBDb3VwbGUgdGltZWxpbmUgZ2VuZXJhdG9yIHwg6YCC5ZCI5Y+C6ICD5pe2
6Ze057q/55Sf5oiQ5ZmoIHwKCi0tLQoKIyMgNS4gR2l0SHViIOmrmOaYn+S7k+W6k++8muinhumi
kS/liarovpEv55Sf5oiQ5pa55ZCRCgp8IOaYn+aghyB8IOS7k+W6kyB8IOaWueWQkSB8IOmAguWQ
iOS9oOaAjuS5iOeUqCB8CnwtLS06fC0tLXwtLS18LS0tfAp8IDEyOEsrIHwgaHR0cHM6Ly9naXRo
dWIuY29tL2hhcnJ5MDcwMy9Nb25leVByaW50ZXJUdXJibyB8IEFJIOiHquWKqOefreinhumikeW3
peS9nOa1ge+8jOS4u+mimC/lhbPplK7or43liLDpq5jmuIXop4bpopEgfCDnoJTnqbbnn63op4bp
opHoh6rliqjljJbnlJ/kuqflhajmtYHnqIsgfAp8IDY0SysgfCBodHRwczovL2dpdGh1Yi5jb20v
RkZtcGVnL0ZGbXBlZyB8IOmfs+inhumikeW6leWxguWkhOeQhuW3peWFtyB8IOaJgOacieiHquWK
qOWJqui+keOAgei9rOeggeOAgeWQiOaIkOeahOWfuuehgOW3peWFtyB8CnwgNjJLKyB8IGh0dHBz
Oi8vZ2l0aHViLmNvbS9jYWxlc3RoaW8vT3Blbk1vbnRhZ2UgfCDlvIDmupAgYWdlbnRpYyB2aWRl
byBwcm9kdWN0aW9uIHN5c3Rlbe+8jOWQq+Wkp+mHj+W3peWFty/mioDog73mlofku7YgfCDmnIDl
gLzlvpfnoJTnqbbnmoQgQWdlbnQg6KeG6aKR55Sf5Lqn57O757uf5LmL5LiAIHwKfCA1NksrIHwg
aHR0cHM6Ly9naXRodWIuY29tL2hleWdlbi1jb20vaHlwZXJmcmFtZXMgfCBXcml0ZSBIVE1MLCBy
ZW5kZXIgdmlkZW/vvIzpnaLlkJEgYWdlbnRzIHwg6YCC5ZCI55SoIFdlYi9IVE1MIOWKqOeUu+eU
n+aIkOinhumikee0oOadkCB8CnwgNDRLKyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9taWZpL2xvc3Ns
ZXNzLWN1dCB8IOaXoOaNn+inhumikS/pn7PpopHliarliIcgfCDmnKzlnLDlv6vpgJ/liarliIfn
tKDmnZAgfAp8IDE5SysgfCBodHRwczovL2dpdGh1Yi5jb20vS2xpbmdBSVJlc2VhcmNoL0xpdmVQ
b3J0cmFpdCB8IOiuqeWktOWDjy/kurrlg4/liqjotbfmnaUgfCDlgZrmg4XkvqPnhafniYcv5aS0
5YOP5Yqo5pWI6KeG6aKR5b6I5ZCI6YCCIHwKfCAxOUsrIHwgaHR0cHM6Ly9naXRodWIuY29tL2h5
cGl0LWFpL2h5cGl0IHwgQUkgYWdlbnRzIOWFi+mahi/mibnph4/mlLnpgKDnn63op4bpopHlt6Xk
vZzmtYEgfCDpgILlkIjnoJTnqbbmibnph4/nn63op4bpopHlj5jkvZPnlJ/kuqcgfAp8IDE1Sysg
fCBodHRwczovL2dpdGh1Yi5jb20vWnVsa28vbW92aWVweSB8IFB5dGhvbiDop4bpopHnvJbovpHl
upMgfCDnvJbnqIvlvI/liarovpHjgIHlrZfluZXjgIHmi7zmjqXjgIHovazlnLogfAp8IDE0Sysg
fCBodHRwczovL2dpdGh1Yi5jb20vRnVqaXdhcmFDaG9raS9Nb25leVByaW50ZXIgfCBNb3ZpZVB5
IOiHquWKqOeUn+aIkCBZb3VUdWJlIFNob3J0cyB8IOiHquWKqOefreinhumikeiEmuacrOWPguiA
gyB8CnwgMTJLKyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9rcmlsbGluYWkvT3BlbkNyZWF0b3IgfCBB
SSDliJvkvZzogIXlt6XkvZzljLrvvIzop4bpopEv5Zu+54mHL+ivremfsy/lpLTlg48v57+76K+R
L+e8lui+kSB8IOe7vOWQiOWei+WIm+S9nOW5s+WPsOWPguiAgyB8CnwgMTFLKyB8IGh0dHBzOi8v
Z2l0aHViLmNvbS9saW55cWgvTmFycmF0b0FJIHwgQUkg6Kej6K+05bm25Ymq6L6R6KeG6aKRIHwg
6YCC5ZCI5Y+j5pKt44CB6Kej6K+044CB5Ymn5oOF6KeG6aKRIHwKfCA5LjVLKyB8IGh0dHBzOi8v
Z2l0aHViLmNvbS9ZYW9GQU5HVUsvdmlkZW8tc3VidGl0bGUtZXh0cmFjdG9yIHwg6KeG6aKR56Gs
5a2X5bmV5o+Q5Y+W55Sf5oiQIFNSVCB8IOmAguWQiOS7juW3suacieinhumikeaPkOWPluWtl+W5
lSB8CnwgNi42SysgfCBodHRwczovL2dpdGh1Yi5jb20vT3BlblNob3Qvb3BlbnNob3QtcXQgfCDl
vIDmupDmoYzpnaLop4bpopHnvJbovpHlmaggfCBHVUkg5Ymq6L6R6L2v5Lu25Y+C6ICDIHwKfCA2
LjRLKyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9tb2RlbHNjb3BlL0Z1bkNsaXAgfCDovazlhpnjgIHl
rZfluZXjgIFMTE0g6L6F5Yqp5YiH54mHIHwg6ZW/6KeG6aKR5YiH55+t6KeG6aKR44CB5a2X5bmV
55Sf5oiQIHwKfCA1LjVLKyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9taWZpL2VkaXRseSB8IERlY2xh
cmF0aXZlIGNvbW1hbmQtbGluZSB2aWRlbyBlZGl0aW5nL0FQSSB8IOeUqCBKU09OL+S7o+eggeaP
j+i/sOinhumikeWQiOaIkCB8CnwgMy43SysgfCBodHRwczovL2dpdGh1Yi5jb20vbHVvbHVvbHVv
MjIvamlhbnlpbmctZWRpdG9yLXNraWxsIHwg6Ieq5Yqo5YyW5Ymq5pigL0NhcEN1dCDkuK3mlofn
iYjnmoQgQWdlbnQgU2tpbGwgfCDkuK3mlofliarovpHlt6XkvZzmtYHpppbpgInkuYvkuIDvvIzk
vaDlt7Loo4Xov4cgfAp8IDMuMEsrIHwgaHR0cHM6Ly9naXRodWIuY29tL05hcnJhdG9yQUktU3R1
ZGlvL25hcnJhdG9yLWFpLWNsaS1za2lsbCB8IEFJIOino+ivtOWkp+W4iCBBZ2VudCBTa2lsbCB8
IOmAguWQiOKAnOaBi+eIseaVheS6i+ino+ivtC/nuqrlv7Xml6Xlj6Pmkq3igJ0gfAp8IDIuMUsr
IHwgaHR0cHM6Ly9naXRodWIuY29tLzB4c2xpbmUvT3BlbkNoYXRDdXQgfCDmnKzlnLDkvJjlhYjj
gIHlr7nor53lvI8gQUkg6KeG6aKR57yW6L6R5Zmo77yM5ZCrIEFnZW50IFNraWxscy9NQ1AgfCDp
gILlkIjnoJTnqbbkuqTkupLlvI/op4bpopHnvJbovpHkuqflk4EgfAoKLS0tCgojIyA2LiDmiJHl
u7rorq7nmoTnu4TlkIjmlrnmoYgKCiMjIyDmlrnmoYggQe+8muWBmuKAnOaDheS+o+aBi+eIseiu
sOW9lee9keermS/lsI/lupTnlKjigJ0KCuS8mOWFiOWPguiAg++8mgoKMS4gYGNjLW91ci1zdG9y
eWAKMi4gYDEwMjRob3VzZWAKMy4gYFNoYXJlZE1vbWVudHNgCjQuIGBtYXBwZWRsb3ZlYAo1LiBg
bXlsb3ZlYAoK5qih5Z2X5bu66K6u77yaCgotIOe6quW/teaXpeWAkuiuoeaXtgotIOaXtuWFiei9
tC/ml6XorrAKLSDnm7jlhowv6KeG6aKR57Sg5p2Q5bqTCi0g6Laz6L+55Zyw5Zu+Ci0g5oKE5oKE
6K+dL+aDheS5pgotIOaDhee7quaIluWFs+ezu+WkjeebmAotIOS4gOmUrueUn+aIkOe6quW/teef
reinhumikQoKIyMjIOaWueahiCBC77ya5YGa4oCc5oOF5L6j57qq5b+15pel6Ieq5Yqo55+t6KeG
6aKR4oCdCgrlu7rorq7pk77ot6/vvJoKCjEuIOaBi+eIseiusOW9leaVsOaNru+8mueFp+eJh+OA
geaXpeacn+OAgeWcsOeCueOAgeeJh+auteaWh+Wtl++8mwoyLiDmlofmoYjvvJpgbGpnLXJlbGF0
aW9uc2hpcGAg5YGa5YWz57O75aSN55uY77yM5oiW55So5pmu6YCaIExMTSDlhpnnlJwv5pCe56yR
5Y+j5pKt77ybCjMuIOinhumike+8mmBqaWFueWluZy1lZGl0b3Jg44CBYGxsbS12aWRlby1tYWtl
cmDjgIFgbmFycmF0b3ItYWktY2xpLXNraWxsYOOAgWB6ZW5zdG9yeS1haS9kcmFtYS1za2lsbHNg
77ybCjQuIOWQjuacn++8mkZGbXBlZy9Nb3ZpZVB5L0Z1bkNsaXAg5aSE55CG5a2X5bmV44CB5ou8
5o6l44CB6L2s5Zy644CCCgojIyMg5pa55qGIIEPvvJrnu6fnu63msr/nlKjkvaDnlLXohJHlt7Lm
nInnmoTliarmmKDoh6rliqjljJbpk77ot68KCuS9oOS5i+WJjeeUteiEkeS4iuW3suacie+8mgoK
YGBgdGV4dApFOlwwbWNwLWFndi1hcmVuYS1vcHRpbWl6ZWRcc2tpbGxzXGppYW55aW5nLWVkaXRv
cgpgYGAKCuWPr+S7peWcqOi/meS4quWfuuehgOS4iue7p+e7reWBmu+8muaDheS+o+e0oOadkOaW
h+S7tuWkuSAtPiDoh6rliqjlhpnmlofmoYggLT4g6Ieq5Yqo6YWN6Z+zIC0+IOiHquWKqOWtl+W5
lSAtPiDoh6rliqjliarmmKAvTVA0IOaIkOeJh+OAggoKLS0tCgojIyA3LiDkvJjlhYjlronoo4Xl
u7rorq4KCuWmguaenOWPquaDs+WwkeijheWHoOS4qu+8jOaIkeW7uuiuruWQjue7reaMiei/meS4
qumhuuW6j++8mgoKMS4gYGxpamlnYW5nL2xqZy1za2lsbHMgLS1za2lsbCBsamctcmVsYXRpb25z
aGlwYO+8muWBmuaBi+eIseiusOW9leaAu+e7ky/lhbPns7vlpI3nm5jmlofmoYjjgIIKMi4gYHpl
bnN0b3J5LWFpL2RyYW1hLXNraWxsc2DvvJrlgZrliafmg4XjgIHliIbplZzjgIHop4bpopHmj5Dn
pLror43jgIIKMy4gYG5hcnJhdG9yYWktc3R1ZGlvL25hcnJhdG9yLWFpLWNsaS1za2lsbGDvvJrl
gZrop6Por7Qv5Y+j5pKt57G75YaF5a6544CCCjQuIGBtYXhhenVyZS92aWRlby1lZGl0aW5nLXNr
aWxsYCDmiJYgYGJsaXR6cmVlbHMvYWdlbnQtc2tpbGxzYO+8muWBmuiHquWKqOWJqui+keOAgeWt
l+W5leOAgeWIh+eJh+OAggo1LiDlt7LmnInnmoQgYGppYW55aW5nLWVkaXRvcmAg57un57ut5L+d
55WZ77yM5pyA6YCC5ZCI5Lit5paH5Ymq5pig6JC95Zyw44CCCgotLS0KCiMjIDguIOacrOaKpeWR
iuS4u+imgeadpea6kAoKLSBodHRwczovL2dpdGh1Yi5jb20vdmVyY2VsLWxhYnMvc2tpbGxzCi0g
aHR0cHM6Ly93d3cuc2tpbGxzLnNoLwotIGh0dHBzOi8vd3d3LnNraWxscy5zaC9sdW9sdW9sdW8y
Mi9qaWFueWluZy1lZGl0b3Itc2tpbGwKLSBodHRwczovL3d3dy5za2lsbHMuc2gvbGlqaWdhbmcv
bGpnLXNraWxscy9samctcmVsYXRpb25zaGlwCi0gaHR0cHM6Ly93d3cuc2tpbGxzLnNoL3plbnN0
b3J5LWFpL2RyYW1hLXNraWxscwotIGh0dHBzOi8vd3d3LnNraWxscy5zaC9uYXJyYXRvcmFpLXN0
dWRpby9uYXJyYXRvci1haS1jbGktc2tpbGwKLSBodHRwczovL3d3dy5za2lsbHMuc2gvbWF4YXp1
cmUvdmlkZW8tZWRpdGluZy1za2lsbAotIGh0dHBzOi8vd3d3LnNraWxscy5zaC9ibGl0enJlZWxz
L2FnZW50LXNraWxscwotIGh0dHBzOi8vd3d3LnNraWxscy5zaC9lY2xpcHRpYy1haS9za2lsbHMK
LSBHaXRIdWIgcmVwb3NpdG9yeSBzZWFyY2ggYnkgdG9waWNzOiBjb3VwbGUsIGNvdXBsZXMsIGxv
dmUtYXBwLCByZWxhdGlvbnNoaXAtYXBwLCB2aWRlby1lZGl0aW5nLCB2aWRlby1nZW5lcmF0aW9u
LCBzdWJ0aXRsZXMsIGZmbXBlZywgcmVtb3Rpb24K
'@
$templateBytes=[Convert]::FromBase64String(($templateB64 -replace '\s',''))
$md=[Text.Encoding]::UTF8.GetString($templateBytes)
$head=(San (($installOut -split "`r?`n"|Select-Object -First 28)-join "`r`n"))
if(-not $head){ $head='npx install output empty or npx unavailable; fallback copy may have been used.' }
$md=$md.Replace('__TIME__',(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$md=$md.Replace('__DESKTOP_REPORT__',$desktopReport)
$md=$md.Replace('__INSTALL_STATUS__',$installStatus)
$md=$md.Replace('__PROJECT_SKILL_DIR__',$projectSkillDir)
$md=$md.Replace('__E_SKILL_DIR__',$eSkillDir)
$md=$md.Replace('__NODE__',$node)
$md=$md.Replace('__NPX__',$npx)
$md=$md.Replace('__INSTALL_HEAD__',$head)
WUtf8 $desktopReport $md
$repoMd=Join-Path $outDir 'FIND_SKILLS_LOVE_VIDEO_REPORT_R238.md'
WUtf8 $repoMd $md

$desktopExists=Test-Path -LiteralPath $desktopReport
$skillExists=(Test-Path -LiteralPath $projectSkillMd) -or (Test-Path -LiteralPath (Join-Path $eSkillDir 'SKILL.md'))
$status=if($desktopExists -and $skillExists){'FIND_SKILLS_REPORT_READY'}else{'FIND_SKILLS_REPORT_INCOMPLETE'}
$summary=[pscustomobject]@{
  status=$status
  installStatus=$installStatus
  desktopReport=$desktopReport
  repoReport=$repoMd
  projectSkillDir=$projectSkillDir
  projectSkillExists=(Test-Path -LiteralPath $projectSkillMd)
  agentSkillDir=$agentSkillDir
  agentSkillExists=(Test-Path -LiteralPath $agentSkillMd)
  eSkillDir=$eSkillDir
  eSkillExists=(Test-Path -LiteralPath (Join-Path $eSkillDir 'SKILL.md'))
  node=$node
  npx=$npx
  copiedE=$copiedE
}
$jsonPath=Join-Path $outDir 'find-skills-love-video-r238.json'
WUtf8 $jsonPath (($summary|ConvertTo-Json -Depth 6)+"`r`n")
L ('desktop_report='+(San $desktopReport)+' exists='+$desktopExists)
L ('repo_report='+(San $repoMd)+' exists='+(Test-Path -LiteralPath $repoMd))
L ('status='+$status)
L ('FINAL_R238: '+$status)
WLines $runReport $script:Lines
if($status -eq 'FIND_SKILLS_REPORT_READY'){ exit 0 }else{ exit 1 }
