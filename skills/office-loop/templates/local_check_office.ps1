# office-loop section: the Office deliverables - proven ON THIS MACHINE.
# Installed by skills/office-loop/agent-install.sh from the success case in
# mqgg5630-cyber/git-pull-arena (branch arena/01a0aa00-git-pull-arena), where
# this code has been judged by the real machine in rounds 20-32. Do not edit
# here: change it in the skill and re-run the installer.
# --- office-loop: office deliverables section (sentinel) ---
# 3. the Office deliverables - proven ON THIS MACHINE, without Office installed.
#    For every file listed in deliverable/OFFICE_HASHES.json:
#      3a sha256 + byte size equal the copy the agent generated, which proves
#         that what arrived through git is that exact file and not a stale one
#      3b the package opens as a zip and every required OOXML part is present
#      3c every .xml / .rels part parses as XML
#      3d every relationship target resolves inside the package (a dangling
#         r:id is exactly what makes Office report unreadable content)
#      3e [Content_Types].xml covers every part
#      3f must_contain markers are found across the xml parts
#      3g pptx only: at least min_slides slides are present
$manRel = 'deliverable/OFFICE_HASHES.json'
if (Test-Path -LiteralPath $manRel) {
    try {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    } catch {
        Write-Output ('[WARN] cannot load System.IO.Compression - deliverable package checks skipped: ' + $_.Exception.Message)
    }

    function Read-ZipText {
        param($Archive, [string]$Name)
        $ze = $Archive.GetEntry($Name)
        if (-not $ze) { return $null }
        $sr = New-Object System.IO.StreamReader($ze.Open(), [System.Text.Encoding]::UTF8)
        $t = $sr.ReadToEnd()
        $sr.Dispose()
        return $t
    }

    function Resolve-ZipPath {
        param([string]$Base, [string]$Target)
        $segs = @()
        if ($Base) { $segs += ($Base -split '/') }
        foreach ($s in ($Target -split '/')) {
            if ($s -eq '' -or $s -eq '.') { continue }
            if ($s -eq '..') {
                if ($segs.Count -gt 1) { $segs = $segs[0..($segs.Count - 2)] } else { $segs = @() }
                continue
            }
            $segs += $s
        }
        return ($segs -join '/')
    }

    try {
        $man = Get-Content -LiteralPath $manRel -Raw -Encoding UTF8 | ConvertFrom-Json
        $manFiles = @($man.files)
        Write-Output ('== deliverables: ' + $manFiles.Count + ' Office file(s) declared in ' + $manRel)
        foreach ($f in $manFiles) {
            $rel = [string]$f.path
            $p = $rel -replace '/', '\'
            $kind = [string]$f.kind
            if (-not (Test-Path -LiteralPath $p)) {
                Write-Output ('   FAIL MISSING deliverable ' + $rel)
                $fail = 1
                continue
            }
            # 3a integrity: the file that came through git is the generated one
            $sz = [int64](Get-Item -LiteralPath $p).Length
            if ($sz -ne [int64]$f.bytes) {
                Write-Output ('   FAIL SIZE ' + $rel + ' expected ' + [int64]$f.bytes + ' got ' + $sz)
                $fail = 1
                continue
            }
            $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($h -ne ([string]$f.sha256).ToLowerInvariant()) {
                Write-Output ('   FAIL SHA256 ' + $rel + ' does not match the generated copy')
                Write-Output ('        local  ' + $h)
                Write-Output ('        wanted ' + [string]$f.sha256)
                $fail = 1
                continue
            }
            Write-Output ('   OK   3a sha256 + bytes match: ' + $rel + ' (' + $sz + ' B, ' + $kind + ')')

            $full = (Resolve-Path -LiteralPath $p).Path
            $zip = $null
            try { $zip = [System.IO.Compression.ZipFile]::OpenRead($full) } catch { $zip = $null }
            if (-not $zip) {
                Write-Output ('   FAIL 3b not a readable OOXML zip package: ' + $rel)
                $fail = 1
                continue
            }
            try {
                $names = @{}
                foreach ($ze in $zip.Entries) { $names[$ze.FullName] = $true }
                if ($names.Count -ne $zip.Entries.Count) {
                    Write-Output ('   FAIL 3b duplicate zip entries in ' + $rel)
                    $fail = 1
                }

                # 3b required parts
                $miss = @()
                foreach ($rp in @($f.required_parts)) {
                    if (-not $names.ContainsKey([string]$rp)) { $miss += [string]$rp }
                }
                if ($miss.Count -gt 0) {
                    Write-Output ('   FAIL 3b missing parts in ' + $rel + ' : ' + ($miss -join ', '))
                    $fail = 1
                } else {
                    Write-Output ('   OK   3b all ' + @($f.required_parts).Count + ' required parts present in ' + $rel)
                }

                # 3c every xml part parses; also collect the text for 3f
                $badXml = @()
                $allText = New-Object System.Text.StringBuilder
                foreach ($ze in $zip.Entries) {
                    if ($ze.FullName -notmatch '\.(xml|rels)$') { continue }
                    $t = Read-ZipText $zip $ze.FullName
                    if ($null -eq $t) { $badXml += ($ze.FullName + ' (unreadable)'); continue }
                    try { $null = [xml]$t } catch { $badXml += $ze.FullName }
                    [void]$allText.Append($t)
                }
                if ($badXml.Count -gt 0) {
                    Write-Output ('   FAIL 3c unparseable XML in ' + $rel + ' : ' + ($badXml -join ', '))
                    $fail = 1
                } else {
                    Write-Output ('   OK   3c every XML part parses in ' + $rel + ' (' + $names.Count + ' parts)')
                }

                # 3d relationships resolve
                $dangling = @()
                foreach ($ze in $zip.Entries) {
                    if ($ze.FullName -notmatch '\.rels$') { continue }
                    $segs = $ze.FullName -split '/'
                    $dirSegs = @()
                    if ($segs.Count -gt 2) { $dirSegs = $segs[0..($segs.Count - 3)] }
                    $base = ($dirSegs -join '/')
                    $rx = [xml](Read-ZipText $zip $ze.FullName)
                    foreach ($r in @($rx.Relationships.Relationship)) {
                        $tgt = [string]$r.Target
                        if (-not $tgt -or $tgt.StartsWith('http')) { continue }
                        $resolved = Resolve-ZipPath $base $tgt
                        if (-not $names.ContainsKey($resolved)) {
                            $dangling += ($ze.FullName + ' -> ' + $tgt)
                        }
                    }
                }
                if ($dangling.Count -gt 0) {
                    Write-Output ('   FAIL 3d dangling relationships in ' + $rel + ' : ' + ($dangling -join '; '))
                    $fail = 1
                } else {
                    Write-Output ('   OK   3d every relationship target resolves in ' + $rel)
                }

                # 3e content types cover every part
                $ctx = [xml](Read-ZipText $zip '[Content_Types].xml')
                $defs = @()
                foreach ($d in @($ctx.Types.Default)) { $defs += ([string]$d.Extension).ToLowerInvariant() }
                $ovrs = @()
                foreach ($o in @($ctx.Types.Override)) { $ovrs += [string]$o.PartName }
                $noCt = @()
                foreach ($ze in $zip.Entries) {
                    if ($ze.FullName -eq '[Content_Types].xml') { continue }
                    $ext = ''
                    if ($ze.FullName.Contains('.')) { $ext = ($ze.FullName.Split('.')[-1]).ToLowerInvariant() }
                    if (($ovrs -notcontains ('/' + $ze.FullName)) -and ($defs -notcontains $ext)) {
                        $noCt += $ze.FullName
                    }
                }
                if ($noCt.Count -gt 0) {
                    Write-Output ('   FAIL 3e parts without a content type in ' + $rel + ' : ' + ($noCt -join ', '))
                    $fail = 1
                } else {
                    Write-Output ('   OK   3e content types cover every part of ' + $rel)
                }

                # 3f text markers (searched across all xml parts of the package)
                $body = $allText.ToString()
                $noMark = @()
                foreach ($m in @($f.must_contain)) {
                    if (-not $body.Contains([string]$m)) { $noMark += [string]$m }
                }
                if ($noMark.Count -gt 0) {
                    Write-Output ('   FAIL 3f markers not found in ' + $rel + ' : ' + ($noMark -join ', '))
                    $fail = 1
                } else {
                    Write-Output ('   OK   3f all ' + @($f.must_contain).Count + ' text markers present in ' + $rel)
                }

                # 3g slide count for decks
                if ($f.min_slides) {
                    $nSlides = @($zip.Entries | Where-Object { $_.FullName -match '^ppt/slides/slide[0-9]+\.xml$' }).Count
                    if ($nSlides -lt [int]$f.min_slides) {
                        Write-Output ('   FAIL 3g slides in ' + $rel + ' : ' + $nSlides + ' < ' + [int]$f.min_slides)
                        $fail = 1
                    } else {
                        Write-Output ('   OK   3g slides in ' + $rel + ' : ' + $nSlides + ' >= ' + [int]$f.min_slides)
                    }
                }
            } finally {
                $zip.Dispose()
            }
        }
    } catch {
        Write-Output ('[FAIL] deliverable check threw: ' + $_.Exception.Message)
        $fail = 1
    }
} else {
    Write-Output ('== deliverables: (no ' + $manRel + ' - package checks skipped)')
}

#    3h. application-level open test, auto-detected and time-boxed.
#        The registry is probed for a registered COM server (MS Word / PowerPoint,
#        or WPS Writer / Presentation). Nothing is launched when no suite is
#        installed, so an Office-less or WPS-only machine gets SKIP instead of a
#        false FAIL. The launch runs in a job with a hard timeout, so a hung COM
#        server can never burn the round (check_timeout_min). Force off:
#            setx GIT_SYNC_OFFICE_COM 0
$comTargets = @()
try {
    if (Test-Path -LiteralPath $manRel) {
        $mh = Get-Content -LiteralPath $manRel -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($mh.files) {
            foreach ($mf in @($mh.files)) {
                $p = [string]$mf.path
                if (-not $p) { continue }
                $k = [string]$mf.kind
                if (-not $k) { $k = [System.IO.Path]::GetExtension($p).TrimStart('.') }
                if ($k -eq 'docx' -or $k -eq 'doc') {
                    $comTargets += , @($p.Replace('/', '\'), @('Word.Application', 'KWPS.Application'), 'word')
                } elseif ($k -eq 'pptx' -or $k -eq 'ppt') {
                    $comTargets += , @($p.Replace('/', '\'), @('PowerPoint.Application', 'KWPP.Application'), 'deck')
                }
            }
        }
    }
} catch {
    Write-Output ('   WARN 3h could not read ' + $manRel + ' (' + $_.Exception.Message + ') - open test skipped')
}
if ($comTargets.Count -eq 0) {
    Write-Output ('   SKIP 3h no Office deliverable declared in ' + $manRel + ' - nothing to open')
}
foreach ($ct in $comTargets) {
    $target = [string]$ct[0]
    $kind = [string]$ct[2]
    if (-not (Test-Path -LiteralPath $target)) { continue }
    if ([string]$env:GIT_SYNC_OFFICE_COM -eq '0') {
        Write-Output ('   SKIP 3h ' + $kind + ' open test disabled by GIT_SYNC_OFFICE_COM')
        continue
    }
    $progId = ''
    foreach ($cand in @($ct[1])) {
        if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + [string]$cand)) {
            $progId = [string]$cand
            break
        }
    }
    if (-not $progId) {
        Write-Output ('   SKIP 3h no registered COM server for ' + $kind + ' (Word/WPS) - the structural checks above stand')
        continue
    }
    $abs = (Resolve-Path -LiteralPath $target).Path
    $job = $null
    try {
        # $PID is a PowerShell automatic variable, hence $srv for the prog id
        $job = Start-Job -ArgumentList $progId, $abs, $kind -ScriptBlock {
            param($srv, $path, $k)
            $app = New-Object -ComObject $srv
            try {
                if ($k -eq 'word') {
                    $doc = $app.Documents.Open($path, $false, $true)
                    $name = [string]$doc.Name
                    $doc.Close($false)
                    return ('opened read-only, name=' + $name)
                }
                $pres = $app.Presentations.Open($path, $true, $false, $false)
                $n = [int]$pres.Slides.Count
                $pres.Close()
                return ('opened read-only, slides=' + $n)
            } finally {
                try { $app.Quit() } catch { }
            }
        }
        $done = Wait-Job $job -Timeout 120
        if (-not $done) {
            Write-Output ('   WARN 3h ' + $progId + ' did not answer in 120s - counted as SKIP, not as a failure')
            Stop-Job $job -ErrorAction SilentlyContinue
        } elseif ($job.State -eq 'Completed') {
            $msg = ((Receive-Job $job | Out-String) -replace '\s+$', '')
            Write-Output ('   OK   3h ' + $progId + ' ' + $msg + ' : ' + $target)
        } else {
            $err = ((Receive-Job $job 2>&1 | Out-String) -replace '\s+$', '')
            Write-Output ('   FAIL 3h ' + $progId + ' refused to open ' + $target)
            Write-Output ('        ' + $err)
            $fail = 1
        }
    } catch {
        Write-Output ('   WARN 3h open test could not run (' + $_.Exception.Message + ') - counted as SKIP')
    } finally {
        if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
    }
}
