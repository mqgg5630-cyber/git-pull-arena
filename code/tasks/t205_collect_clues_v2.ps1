$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\user_amp"
$src  = Join-Path $repo "sources\user_amp"
New-Item -ItemType Directory -Force -Path $inv, $src | Out-Null
$desk = [Environment]::GetFolderPath("Desktop")
Write-Output "DESKTOP=$desk"

# A. small files from the user's own SCI suite
$suite = Join-Path $desk "AMP_Docking_Vina_R255_20261005_1552\SCI_Docking_Figure4_Suite"
foreach ($f in @("complexes_interaction_summary.csv","README.md")) {
    $p = Join-Path $suite $f
    if (Test-Path -LiteralPath $p) {
        Copy-Item -LiteralPath $p -Destination (Join-Path $src ("usersuite_" + $f)) -Force
        Write-Output "COPIED usersuite_$f"
    } else { Write-Output "MISSING $p" }
}

# B. whole Desktop result folder tree (names only)
$deskRes = Join-Path $desk "AMP_Docking_Vina_R255_20261005_1552"
if (Test-Path -LiteralPath $deskRes) {
    Get-ChildItem -LiteralPath $deskRes -Recurse -ErrorAction SilentlyContinue |
      ForEach-Object { "{0}`t{1}" -f $_.FullName.Substring($deskRes.Length), $(if ($_.PSIsContainer){"<DIR>"}else{$_.Length}) } |
      Set-Content -LiteralPath (Join-Path $inv "desktop_result_tree.txt") -Encoding UTF8
    Write-Output "DESKTOP_TREE_OK"
}

# C. machine-wide clue sweep (simple, robust)
$kw  = @('amp','antimicrob','peptide','algpred','allerg','toxinpred','hemolyt','dock','vina','ftsz','gyrb','sortase','crocodil','alligator','gut','jieguo','prediction_result','method','megahit','metawrap','kneaddata','checkm','getorf','sorf','mmseqs','pepfun','therapep','camp','axpep','bin.1','mag')
$exts = @('.py','.sh','.ipynb','.csv','.tsv','.txt','.md','.docx','.json','.pml','.fasta','.fa','.xlsx','.bat','.ps1','.yaml','.yml','.log')
$roots = @($desk, "E:\Users\$env:USERNAME\Downloads", "E:\Users\$env:USERNAME\Documents",
           "E:\0mcp-agv", "E:\0mcp-agv-arena-optimized", "E:\spider\work", "E:\amp", "E:\0github") |
         Where-Object { Test-Path -LiteralPath $_ }
Write-Output ("ROOTS=" + ($roots -join " ; "))

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("fullpath,name,ext,bytes,lastwrite,matched")
$n = 0
foreach ($r in $roots) {
    Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Length -lt 100MB -and ($exts -contains $_.Extension.ToLower())) {
            $low = $_.FullName.ToLower()
            $hit = @()
            foreach ($k in $kw) { if ($low.Contains($k)) { $hit += $k } }
            if ($hit.Count -gt 0) {
                $rows.Add(('"{0}","{1}","{2}",{3},"{4}","{5}"' -f $_.FullName,$_.Name,$_.Extension,$_.Length,$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'),($hit -join '|')))
                $n++
            }
        }
    }
}
Set-Content -LiteralPath (Join-Path $inv "clue_sweep.csv") -Value ($rows -join "`r`n") -Encoding UTF8
Write-Output "CLUE_SWEEP_ROWS=$n"

# D. WSL side (the AMP pipeline likely ran in WSL)
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wsl) {
    Write-Output "## WSL present"
    $cmd = "ls -d ~/* /mnt/*/amp* 2>/dev/null | head -60; echo ----; find ~ -maxdepth 4 -iname '*algpred*' -o -maxdepth 4 -iname '*toxinpred*' -o -maxdepth 4 -iname '*amp*' 2>/dev/null | head -80"
    $o = & wsl.exe bash -lc $cmd 2>&1
    $o | ForEach-Object { Write-Output ("WSL| " + $_) }
    $o | Set-Content -LiteralPath (Join-Path $inv "wsl_scan.txt") -Encoding UTF8
} else { Write-Output "## no WSL" }

# E. recycle bin hints for deleted project files
try {
  $sh = New-Object -ComObject Shell.Application
  $rb = $sh.Namespace(10)
  $cnt = 0
  $rows2 = New-Object System.Collections.Generic.List[string]
  $rows2.Add("name,original_path,deleted,size")
  foreach ($i in $rb.Items()) {
    $nm = $i.Name.ToLower()
    if ($nm -match 'amp|pep|dock|algpred|toxin|bin|mag|orf|croc|allig') {
      $rows2.Add(('"{0}","{1}","{2}","{3}"' -f $i.Name, $rb.GetDetailsOf($i,1), $rb.GetDetailsOf($i,2), $rb.GetDetailsOf($i,3)))
      $cnt++
    }
  }
  Set-Content -LiteralPath (Join-Path $inv "recyclebin_hits.csv") -Value ($rows2 -join "`r`n") -Encoding UTF8
  Write-Output "RECYCLEBIN_HITS=$cnt"
} catch { Write-Output ("RECYCLEBIN_ERR=" + $_.Exception.Message) }

Write-Output "COLLECT_205_OK=True"
