$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null

echo "=== 1. conda envs and their key packages ==="
for e in bitoxnet elfpatch dockingml acpype_env py36 camps-tf114 ; do
  P="$HOME/miniconda3/envs/$e"
  [ -d "$P" ] || continue
  echo "--- $e"
  ls "$P/bin" 2>/dev/null | grep -iE "toxin|tox|algpred|pepfun|thera|peptide|modlamp|propy" | head -10
  "$P/bin/python" -c "import pkgutil,sys; mods=[m.name for m in pkgutil.iter_modules()]; print([x for x in mods if any(k in x.lower() for k in ('tox','pepfun','modlamp','peptide','algpred','thera','rdkit','biopython','Bio'))][:20])" 2>/dev/null
done

echo
echo "=== 2. search the filesystem for the downstream tools ==="
for pat in toxinpred ToxinPred ToxIBTL bitoxnet algpred AlgPred pepfun PepFun therapepnet TheraPepNet ; do
  hits=$(timeout 60 find "$HOME" /mnt/e/0mcp-agv /mnt/e -maxdepth 4 -iname "*${pat}*" 2>/dev/null | head -4)
  if [ -n "$hits" ] ; then echo "== $pat" ; echo "$hits" | sed "s/^/   /" ; fi
done

echo
echo "=== 3. the allergen script the user already has ==="
find "$HOME" /mnt/e -maxdepth 5 -name "run_algpred2_allergen.sh" 2>/dev/null | head -3

echo
echo "=== 4. anything resembling a prior filtering pipeline ==="
timeout 90 find "$HOME" -maxdepth 4 \( -iname "*filter*.py" -o -iname "*screen*.py" -o -iname "*select*.py" \) 2>/dev/null | grep -viE "site-packages|/\.git/" | head -20

echo
echo "=== 5. history for the downstream steps ==="
grep -aiE "toxin|algpred|pepfun|thera|mmseqs|non.?toxic|allergen" "$HOME/.bash_history" 2>/dev/null | tail -40

echo
echo "=== 6. current stage files ==="
ls -la "$HOME/eyu_repro/stage2" 2>/dev/null | head
echo "reps=$(grep -c '^>' "$HOME/eyu_repro/stage2/clu100_rep_seq.fasta" 2>/dev/null)"
'@

$tmp = Join-Path $repo "surv.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("S| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "downstream_survey.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "DOWNSTREAM_SURVEY_DONE=True"
