$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
Write-Output "HOST=$env:COMPUTERNAME"

$desk = $null
foreach ($d in @(("D:\" + [char]0x684C + [char]0x9762), [Environment]::GetFolderPath("Desktop"), (Join-Path $env:USERPROFILE "Desktop"))) {
    if ($d -and (Test-Path -LiteralPath $d)) { $desk = $d; break }
}
if (-not $desk) { Write-Output "NO_DESKTOP"; exit 1 }
Write-Output "DESKTOP=$desk"

$out = Join-Path $desk "Interop_And_Skills_20261007"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Write-Output "OUTDIR=$out"

$n = 0
function Grab($rel, $asName) {
    $src = Join-Path $repo $rel
    if (-not (Test-Path -LiteralPath $src)) { Write-Output ("SKIP_MISSING=" + $rel); return }
    $dst = Join-Path $out $asName
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Output ("COPIED {0} <- {1} ({2} B)" -f $asName, $rel, (Get-Item -LiteralPath $dst).Length)
    $script:n++
}

# 0. index first
Grab "results\skills\INTEROP_INDEX.md"            "00_INTEROP_INDEX.md"
Grab "results\skills\SKILLS_INTEROP_SUMMARY.md"   "01_SKILLS_INTEROP_SUMMARY.md"

# 1. skills
Grab "skills\README.md"                           "skills_README.md"
Grab "skills\cloud-interop\SKILL.md"              "skills_cloud-interop_SKILL.md"
Grab "skills\cloud-interop\README_CN.md"          "skills_cloud-interop_README_CN.md"
Grab "skills\computer-use\SKILL.md"               "skills_computer-use_SKILL.md"
Grab "skills\computer-use\README_CN.md"           "skills_computer-use_README_CN.md"
Grab "skills\git-sync\SKILL.md"                   "skills_git-sync_SKILL.md"
Grab "skills\git-sync\README.md"                  "skills_git-sync_README.md"
Grab "skills\harness-anything\README_CN.md"       "skills_harness-anything_README_CN.md"
Grab "skills\harness-anything\INSTALL.md"         "skills_harness-anything_INSTALL.md"
Grab "skills\harness-anything\WPS.md"             "skills_harness-anything_WPS.md"

# 2. git-sync templates (how to drive the loop)
$tpl = Join-Path $out "git-sync_templates"
New-Item -ItemType Directory -Force -Path $tpl | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repo "skills\git-sync\templates") -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $tpl $_.Name) -Force
    Write-Output ("COPIED templates\{0}" -f $_.Name); $script:n++
}

# 3. interop evidence
Grab "results\cloud_interop\GDRIVE_SETUP_R249.md"      "GDRIVE_SETUP_R249.md"
Grab "results\cloud_interop\INTEROP_HEALTH.md"         "INTEROP_HEALTH.md"
Grab "results\computer_use\COMPUTER_USE_LAPTOP_R249.md" "COMPUTER_USE_LAPTOP_R249.md"

# 4. muse protocol / records
$muse = Join-Path $out "muse"
New-Item -ItemType Directory -Force -Path $muse | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repo "results\muse") -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $muse $_.Name) -Force
    Write-Output ("COPIED muse\{0}" -f $_.Name); $script:n++
}

# 5. local restore / maintenance scripts the user may need again
$ops = Join-Path $out "ops_scripts"
New-Item -ItemType Directory -Force -Path $ops | Out-Null
foreach ($s in @("clean_flash_and_restore_watch.ps1","restore_watch_only_this.ps1","hide_watcher_windows.ps1","fix_git_slow_and_popups.ps1")) {
    $p = Join-Path $repo ("code\tasks\" + $s)
    if (Test-Path -LiteralPath $p) {
        Copy-Item -LiteralPath $p -Destination (Join-Path $ops $s) -Force
        Write-Output ("COPIED ops_scripts\{0}" -f $s); $script:n++
    }
}

Write-Output "FILES_COPIED=$n"
$total = @(Get-ChildItem -LiteralPath $out -Recurse -File).Count
Write-Output "FILES_IN_OUTDIR=$total"
if ($total -lt 15) { Write-Output "TOO_FEW_FILES"; exit 1 }

Get-ChildItem -LiteralPath $out -Recurse -File | ForEach-Object {
    Write-Output ("LIST {0}`t{1}" -f $_.FullName.Substring($out.Length + 1), $_.Length)
}

Write-Output "INTEROP_SKILLS_DESKTOP_DONE=True"
