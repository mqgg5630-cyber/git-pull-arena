$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
Write-Output "HOST=$env:COMPUTERNAME"
Write-Output "REPO=$repo"

$py = $null
foreach ($c in @("E:\spider\python.exe","python.exe","python3.exe")) {
    try {
        $v = & $c -c "import sys;print(sys.version)" 2>$null
        if ($LASTEXITCODE -eq 0) { $py = $c; Write-Output "PY=$c :: $v"; break }
    } catch {}
}
if (-not $py) { Write-Output "NO_PYTHON"; exit 1 }

try { & $py -m pip install --user --quiet "python-docx" "pillow" 2>&1 | ForEach-Object { Write-Output ("pip| " + $_) } } catch { Write-Output ("pip-warn| " + $_.Exception.Message) }
& $py -c "import docx, PIL; print('DEPS_OK=True')" 2>&1 | ForEach-Object { Write-Output ("import| " + $_) }

$env:DESKTOP_DIR = [Environment]::GetFolderPath("Desktop")
Write-Output ("DESKTOP_DIR=" + $env:DESKTOP_DIR)
$script = Join-Path $repo "code\tasks\amp_method_supplement_build.py"
Write-Output "## running generator"
& $py $script 2>&1 | ForEach-Object { Write-Output ("run| " + $_) }
$rc = $LASTEXITCODE
Write-Output "GENERATOR_EXIT=$rc"
if ($rc -ne 0) { Write-Output "GENERATOR_FAILED"; exit 1 }

$folder = "AMP_Docking_Vina_R255_20261005_1552"
$res = $null
foreach ($d in @([Environment]::GetFolderPath("Desktop"), ("D:\" + [char]0x684C + [char]0x9762), (Join-Path $env:USERPROFILE "Desktop"))) {
    if ($d -and (Test-Path -LiteralPath (Join-Path $d $folder))) { $res = Join-Path $d $folder; break }
}
if (-not $res) { Write-Output "NO_RESULT_DIR"; exit 1 }
Write-Output "RESULT_DIR=$res"

$want = @("AMP_Pipeline_Reproduction_Method.md","AMP_Figure_Style_Review.md","AMP_Method_Supplement_manifest.json")
foreach ($w in $want) {
    $p = Join-Path $res $w
    Write-Output ("CHECK {0} exists={1} size={2}" -f $w, (Test-Path -LiteralPath $p), $(if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).Length } else { 0 }))
    if (-not (Test-Path -LiteralPath $p)) { Write-Output "MISSING_OUTPUT=$w"; exit 1 }
}

$sup = Get-ChildItem -LiteralPath $res -Filter "method_with_docking_*.docx" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $sup) { Write-Output "MISSING_SUPPLEMENT_DOCX"; exit 1 }
Write-Output ("SUPPLEMENT_DOCX={0} size={1}" -f $sup.Name, $sup.Length)
if ($sup.Length -lt 200000) { Write-Output "SUPPLEMENT_TOO_SMALL"; exit 1 }

# copy the three markdown/docx deliverables into the repo for the agent to review (md only, keep repo small)
$repoOut = Join-Path $repo "results\docking\method_supplement"
New-Item -ItemType Directory -Force -Path $repoOut | Out-Null
Copy-Item -LiteralPath (Join-Path $res "AMP_Pipeline_Reproduction_Method.md") -Destination $repoOut -Force
Copy-Item -LiteralPath (Join-Path $res "AMP_Figure_Style_Review.md") -Destination $repoOut -Force
Copy-Item -LiteralPath (Join-Path $res "AMP_Method_Supplement_manifest.json") -Destination $repoOut -Force
Write-Output "REPO_COPY_OK=True"

Write-Output "AMP_METHOD_SUPPLEMENT_DONE=True"
