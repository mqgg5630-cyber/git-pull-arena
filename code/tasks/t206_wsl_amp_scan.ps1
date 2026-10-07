$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\user_amp"
$src  = Join-Path $repo "sources\user_amp\wsl"
New-Item -ItemType Directory -Force -Path $inv, $src | Out-Null

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) { Write-Output "NO_WSL=True"; exit 0 }

$bash = @'
set +e
echo "=== HOME TREE (depth2) ==="
find ~ -maxdepth 2 -not -path "*/.git/*" -not -path "*/miniconda3/*" -not -path "*/.nvm/*" -not -path "*/.cache/*" | head -120
echo
echo "=== c_AMPs-prediction-master ==="
find ~/c_AMPs-prediction-master -maxdepth 3 -not -path "*/.git/*" | head -120
echo
echo "=== projects ==="
find ~/projects -maxdepth 3 -not -path "*/.git/*" 2>/dev/null | head -120
echo
echo "=== AMP-related files anywhere in home (name match) ==="
find ~ -maxdepth 6 \( -path "*/miniconda3/*" -o -path "*/.nvm/*" -o -path "*/.cache/*" -o -path "*/.git/*" -o -path "*/site-packages/*" \) -prune -o -type f \
  \( -iname "*amp*" -o -iname "*sorf*" -o -iname "*orf*" -o -iname "*pep*" -o -iname "*bin.1*" -o -iname "*toxin*" -o -iname "*algpred*" -o -iname "*mmseqs*" -o -iname "*candidate*" -o -iname "*final*" \) \
  -printf "%T@ %10s %p\n" 2>/dev/null | sort -rn | head -120
echo
echo "=== FASTA/CSV/TSV with sizes ==="
find ~ -maxdepth 6 \( -path "*/miniconda3/*" -o -path "*/.cache/*" -o -path "*/.git/*" -o -path "*/site-packages/*" \) -prune -o -type f \
  \( -name "*.fa" -o -name "*.fasta" -o -name "*.csv" -o -name "*.tsv" \) -printf "%T@ %10s %p\n" 2>/dev/null | sort -rn | head -100
echo
echo "=== shell history grep ==="
grep -hiE "getorf|megahit|metawrap|kneaddata|checkm|gtdbtk|mmseqs|toxinpred|algpred|c_AMPs|bin\.1|fastp|bowtie2" ~/.bash_history 2>/dev/null | tail -80
echo
echo "=== conda envs ==="
~/miniconda3/bin/conda env list 2>/dev/null
'@

$tmp = Join-Path $env:TEMP "wslscan.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath = (& wsl.exe wslpath -a ($tmp -replace '\\','/')) 2>$null
$out = & wsl.exe bash $wslPath 2>&1
$outFile = Join-Path $inv "wsl_amp_scan.txt"
$out | Set-Content -LiteralPath $outFile -Encoding UTF8
$out | ForEach-Object { Write-Output ("W| " + $_) }
Write-Output "WSL_SCAN_FILE=$outFile"
Write-Output "SCAN_206_OK=True"
