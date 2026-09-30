# t32_wsl26_survey.ps1 - round 44 task: survey INSIDE the Ubuntu-26.04 WSL
# distro (whose vhdx is the 70.5 GB D:\WSL file) so the user can decide
# what to delete BEFORE we compact the disk. READ-ONLY.
#   - Windows side: map every WSL distro to its vhdx (Lxss registry)
#   - Inside: df, du of /home /root /var /opt, caches, files > 200 MB
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t32: WSL distro -> vhdx map + Ubuntu-26.04 inside survey (READ-ONLY) ---'

# ---------------------------------------------- Windows-side mapping
Write-Output '--- distro -> vhdx mapping (Lxss registry) ---'
try {
    foreach ($k in @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction Stop)) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
        if ($p.DistributionName) {
            $base = [string]$p.BasePath
            $vh = ''
            if ($base) {
                $base2 = $base.Replace('\\?\', '')
                $vhFile = Join-Path $base2 'ext4.vhdx'
                if (Test-Path -LiteralPath $vhFile) {
                    $sz = [math]::Round((Get-Item -LiteralPath $vhFile -Force).Length / 1GB, 1)
                    $vh = (' [vhdx ' + $sz + ' GB]')
                }
            }
            Write-Output ('   ' + (San ([string]$p.DistributionName)).PadRight(20) + ' ' + (San $base) + $vh)
        }
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# ---------------------------------------------- inside the distro
function Invoke-Wsl {
    param([string]$cmd, [int]$timeoutSec)
    $job = Start-Job -ScriptBlock {
        param($c)
        & wsl.exe -d Ubuntu-26.04 -- sh -c $c 2>&1 | Out-String
    } -ArgumentList $cmd
    if (Wait-Job $job -Timeout $timeoutSec) {
        $o = (Receive-Job $job | Out-String)
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $o
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return '__TIMEOUT__'
}

Write-Output '--- df inside Ubuntu-26.04 ---'
$r = Invoke-Wsl 'df -h / | tail -1' 30
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- /home breakdown (top 15) ---'
$r = Invoke-Wsl 'du -h -d 2 /home 2>/dev/null | sort -rh | head -15' 120
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- /root breakdown (top 8) ---'
$r = Invoke-Wsl 'du -h -d 1 /root 2>/dev/null | sort -rh | head -8' 60
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- /var breakdown (top 12) ---'
$r = Invoke-Wsl 'du -h -d 1 /var 2>/dev/null | sort -rh | head -12' 120
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- /opt + /usr/local + /tmp (top 8) ---'
$r = Invoke-Wsl 'du -h -d 1 /opt /usr/local /tmp 2>/dev/null | sort -rh | head -8' 120
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- user caches ---'
$r = Invoke-Wsl 'du -sh ~/.cache ~/.conda ~/miniconda3 ~/anaconda3 ~/.pip ~/.vscode-server 2>/dev/null' 120
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- biggest files anywhere (>= 200 MB, top 25) ---'
$r = Invoke-Wsl 'find / -xdev -type f -size +200M 2>/dev/null -exec du -h {} +' 240
$fl = @($r -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 25)
if ($fl.Count -eq 0 -and $r -eq '__TIMEOUT__') { Write-Output '   (find TIMEOUT - 240s cap)' }
foreach ($l in $fl) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- apt/docker cache sizes ---'
$r = Invoke-Wsl 'du -sh /var/cache/apt /var/lib/docker /var/lib/snapd 2>/dev/null; dpkg -l 2>/dev/null | wc -l' 120
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- notes ---'
Write-Output '   deleting inside WSL does NOT shrink the vhdx by itself: after cleanup run'
Write-Output '   wsl --manage Ubuntu-26.04 --set-sparse true  (or export/import) to give the space back to D:'
exit 0
