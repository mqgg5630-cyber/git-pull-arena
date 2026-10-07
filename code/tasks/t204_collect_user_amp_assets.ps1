$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$src  = Join-Path $repo "sources\user_amp"
$prev = Join-Path $repo "results\user_amp\figure_previews"
$inv  = Join-Path $repo "results\user_amp"
New-Item -ItemType Directory -Force -Path $src, $prev, $inv | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"
Write-Output "REPO=$repo"

function CopyIn($path, $label) {
    if (Test-Path -LiteralPath $path) {
        $leaf = Split-Path $path -Leaf
        $dst  = Join-Path $src $leaf
        Copy-Item -LiteralPath $path -Destination $dst -Force
        $h = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
        $sz = (Get-Item -LiteralPath $dst).Length
        Write-Output ("COPIED {0} <- {1} size={2} sha256={3}" -f $leaf, $path, $sz, $h)
    } else {
        Write-Output ("MISSING {0} :: {1}" -f $label, $path)
    }
}

Write-Output "## 1. requested source files"
$wanted = @(
  "E:\Users\$env:USERNAME\Downloads\method (1).docx",
  "E:\Users\$env:USERNAME\Downloads\Prediction_Result.csv",
  "E:\Users\$env:USERNAME\Downloads\Prediction_Result(1).csv",
  "E:\Users\$env:USERNAME\Downloads\run_algpred2_allergen.sh",
  "E:\Users\$env:USERNAME\Downloads\jieguo.csv",
  "E:\Users\$env:USERNAME\Downloads\crocodile_gut_amp_flow.svg"
)
foreach ($w in $wanted) { CopyIn $w "requested" }

# the SVG name is Chinese; find it by pattern instead
Get-ChildItem "E:\Users\$env:USERNAME\Downloads" -Filter "*.svg" -ErrorAction SilentlyContinue | ForEach-Object {
    $dst = Join-Path $src ("flow_" + ($_.BaseName -replace '[^\w\-]','_') + ".svg")
    Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    Write-Output ("COPIED_SVG {0} <- {1} size={2}" -f (Split-Path $dst -Leaf), $_.FullName, $_.Length)
}

Write-Output ""
Write-Output "## 2. user SCI figure suite"
$figDir = "D:\" + [char]0x684C + [char]0x9762 + "\AMP_Docking_Vina_R255_20261005_1552\SCI_Docking_Figure4_Suite\sci_composite_figures"
if (-not (Test-Path -LiteralPath $figDir)) {
    $deskRoot = [Environment]::GetFolderPath("Desktop")
    $figDir = Join-Path $deskRoot "AMP_Docking_Vina_R255_20261005_1552\SCI_Docking_Figure4_Suite\sci_composite_figures"
}
Write-Output "FIG_DIR=$figDir"
Write-Output "FIG_DIR_EXISTS=$(Test-Path -LiteralPath $figDir)"

$figList = Join-Path $inv "user_figures_inventory.csv"
"name,bytes,width,height,sha256,fullpath" | Set-Content -LiteralPath $figList -Encoding UTF8

$py = $null
foreach ($c in @("E:\spider\python.exe","python.exe")) {
    try { & $c -c "import PIL" 2>$null; if ($LASTEXITCODE -eq 0) { $py = $c; break } } catch {}
}
Write-Output "PYTHON_WITH_PIL=$py"

if (Test-Path -LiteralPath $figDir) {
    Get-ChildItem -LiteralPath $figDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        $h = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        Write-Output ("USERFIG {0} size={1}" -f $_.Name, $_.Length)
        $w = ""; $ht = ""
        if ($py -and $_.Extension -match '\.(png|jpg|jpeg|tif|tiff)$') {
            $outp = Join-Path $prev (($_.BaseName -replace '[^\w\-]','_') + "_preview.jpg")
            $code = "from PIL import Image;im=Image.open(r'" + $_.FullName + "');print(im.size[0],im.size[1]);im=im.convert('RGB');im.thumbnail((1400,1400));im.save(r'" + $outp + "',quality=72,optimize=True)"
            $dim = & $py -c $code 2>&1
            Write-Output ("  preview -> {0}  dim={1}" -f (Split-Path $outp -Leaf), $dim)
            $parts = ([string]$dim).Trim().Split(" ")
            if ($parts.Count -ge 2) { $w = $parts[0]; $ht = $parts[1] }
        }
        ('"{0}",{1},{2},{3},"{4}","{5}"' -f $_.Name, $_.Length, $w, $ht, $h, $_.FullName) | Add-Content -LiteralPath $figList -Encoding UTF8
    }
    # also capture the suite's parent folder tree
    $tree = Join-Path $inv "user_suite_tree.txt"
    Get-ChildItem -LiteralPath (Split-Path $figDir -Parent) -Recurse -ErrorAction SilentlyContinue |
      ForEach-Object { "{0}`t{1}" -f $_.FullName, $(if ($_.PSIsContainer) { "<DIR>" } else { $_.Length }) } |
      Set-Content -LiteralPath $tree -Encoding UTF8
    Write-Output "SUITE_TREE=$tree"
}

Write-Output ""
Write-Output "## 3. machine-wide clue sweep"
$roots = @("D:\" + [char]0x684C + [char]0x9762, "E:\Users\$env:USERNAME\Downloads", "E:\Users\$env:USERNAME\Documents",
           "E:\0mcp-agv", "E:\0mcp-agv-arena-optimized", "E:\0github", "E:\spider") | Where-Object { Test-Path -LiteralPath $_ }
$kw = 'amp|antimicrob|peptide|algpred|allerg|toxin|toxinpred|hemolyt|dock|vina|ftsz|gyrb|sortase|croc|crocodile|gut|jieguo|prediction_result|method'
$ext = '\.(py|sh|ipynb|csv|tsv|txt|md|docx|svg|json|pml|pdb|pdbqt|fasta|fa|xlsx|R|bat|ps1)$'
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("fullpath,name,ext,bytes,lastwrite")
$n = 0
foreach ($r in $roots) {
    Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Length -lt 200MB -and $_.Name -match $ext -and ($_.FullName -match $kw) } |
      ForEach-Object {
        $rows.Add(('"{0}","{1}","{2}",{3},"{4}"' -f $_.FullName, $_.Name, $_.Extension, $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))
        $n++
      }
}
$sweep = Join-Path $inv "clue_sweep.csv"
Set-Content -LiteralPath $sweep -Value ($rows -join "`r`n") -Encoding UTF8
Write-Output "CLUE_SWEEP=$sweep  rows=$n"

Write-Output ""
Write-Output "## 4. small text clues inlined"
foreach ($f in @("Prediction_Result.csv","Prediction_Result(1).csv","jieguo.csv","run_algpred2_allergen.sh")) {
    $p = Join-Path $src $f
    if (Test-Path -LiteralPath $p) {
        Write-Output ("---- head of {0} ----" -f $f)
        Get-Content -LiteralPath $p -TotalCount 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("| " + $_) }
        Write-Output ("---- lines={0} ----" -f (Get-Content -LiteralPath $p -ErrorAction SilentlyContinue).Count)
    }
}

Write-Output ""
Write-Output "COLLECT_204_OK=True"
