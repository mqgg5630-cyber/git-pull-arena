# auth.ps1 - make git authentication on this machine NON-INTERACTIVE
#            (no popup window, no click) so an unattended push always works.
#
# Why this exists: the git-sync watcher (watch.ps1) pushes its verdict from a
# scheduled task. If git has to ASK for a credential there, the poll either
# hangs waiting for your click or dies - and the whole auto-verification loop
# looks broken. This script inspects / configures / PROVES the credential path:
#
#   * GitHub CLI (best)  'gh auth setup-git' keeps the token in gh's own config
#                        file and registers gh as git's credential helper.
#                        Nothing to unlock, works from a session-0 task too.
#   * GCM + DPAPI        Git Credential Manager (ships with Git for Windows)
#                        with credentialStore=dpapi. The DEFAULT store
#                        (wincredman / Windows Credential Manager) is NOT
#                        readable from a session-0 (S4U / "run whether logged
#                        on or not") task or an SSH session - DPAPI files are.
#   * a token            -Token / -TokenFile / -PromptToken seeds the store with
#                        no browser round-trip at all.
#
# Usage (inside the repo folder):
#     .\auth.ps1                      # report: how would a push authenticate NOW?
#     .\auth.ps1 -Setup               # configure (gh > GCM/DPAPI) and verify
#     .\auth.ps1 -Verify              # prove it: prompts OFF, ls-remote + push --dry-run
#     .\auth.ps1 -Verify -Quick       # only ls-remote (skip the push dry-run)
#     .\auth.ps1 -Setup -TokenFile C:\secrets\gh_pat.txt
#     .\auth.ps1 -Json -Verify        # machine readable (the agent reads this)
#     .\auth.ps1 -Unset               # undo what -Setup changed (keeps credentials)
#
# Nothing here ever prints the token. Exit codes: 0 ready / verified, 1 not ready.
# ASCII-only on purpose (Windows PowerShell 5.1 decodes .ps1 as ANSI/GBK).

param(
    [switch]$Setup,
    [switch]$Verify,
    [switch]$Quick,
    [switch]$Json,
    [switch]$Unset,
    [switch]$NoPromptAll,
    [switch]$KeepWinCredMan,
    [switch]$SkipVerify,
    [string]$Token = '',
    [string]$TokenFile = '',
    [switch]$PromptToken,
    [string]$Config = '',
    [string]$Remote = ''
)

$ErrorActionPreference = 'Continue'

# Prompts OFF for this whole script: it exists to find out whether git can get
# a credential WITHOUT asking, so every call it makes must be unable to ask.
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE     = 'never'
$env:GH_PROMPT_DISABLED  = '1'
$env:GIT_ASKPASS         = ''
$env:SSH_ASKPASS         = ''

# repo root = walk up from this script until .git appears, so the script also
# works when run straight from skills\git-sync\scripts\
$repo = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
while ($repo -and -not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
    $up = Split-Path -Parent $repo
    if (-not $up -or $up -eq $repo) { break }
    $repo = $up
}
Set-Location -LiteralPath $repo

function Say([string]$text, [string]$color = 'Gray') {
    if ($Json) { return }
    Write-Host $text -ForegroundColor $color
}
function Ok([string]$text)   { Say "  [ok]   $text" 'Green' }
function Warn([string]$text) { Say "  [warn] $text" 'Yellow' }
function Bad([string]$text)  { Say "  [FAIL] $text" 'Red' }
function Note([string]$text) { Say "  [info] $text" }
function Brief([string]$text, [int]$lines = 3) {
    return (($text -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -First $lines) -join ' | ')
}

$notes = New-Object System.Collections.ArrayList
$changed = New-Object System.Collections.ArrayList

# ------------------------------------------------------------------- config
if ($Config -and -not (Test-Path -LiteralPath $Config)) {
    Write-Host "[ERROR] config not found: $Config" -ForegroundColor Red
    exit 1
}
$cfgPath = @()
if ($Config) { $cfgPath += $Config }
if ($env:GIT_SYNC_PROFILE) {
    $prof = 'sync.config.' + $env:GIT_SYNC_PROFILE + '.json'
    $cfgPath += @(
        (Join-Path $repo ('skills\git-sync\' + $prof)),
        (Join-Path $repo $prof),
        (Join-Path $PSScriptRoot $prof)
    )
}
$cfgPath += @(
    (Join-Path $repo 'skills\git-sync\sync.config.json'),
    (Join-Path $PSScriptRoot 'sync.config.json')
)
$cfgPath = $cfgPath | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$Branch = ''
if ($cfgPath) {
    $cfg = Get-Content -LiteralPath $cfgPath -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($cfg.branch) { $Branch = [string]$cfg.branch }
    if (-not $Remote -and $cfg.remote) { $Remote = [string]$cfg.remote }
}
if (-not $Remote) { $Remote = 'origin' }

# --------------------------------------------------------------- primitives
# run any command and get {code,text} back; a missing exe is code 127, not an
# exception (PowerShell would otherwise spew a CommandNotFoundException)
function Run([string]$exe, [string[]]$exeArgs) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        return @{ code = 127; text = "(not found: $exe)" }
    }
    $out = & $exe @exeArgs 2>&1
    return @{ code = $LASTEXITCODE; text = (($out | Out-String).TrimEnd()) }
}
function CmdLine([string]$exe, [string[]]$exeArgs) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { return '' }
    $out = & $exe @exeArgs 2>$null
    return ((($out | Out-String).Trim()))
}
function CfgGet([string]$key) {
    $r = Run 'git' @('config', '--get', $key)
    if ($r.code -ne 0) { return '' }
    return $r.text.Trim()
}
function CfgSet([string]$key, [string]$value) {
    $r = Run 'git' @('config', '--global', $key, $value)
    return ($r.code -eq 0)
}
function CfgUnset([string]$key) {
    $r = Run 'git' @('config', '--global', '--unset', $key)
    return ($r.code -eq 0)
}
# every git call in this script runs with prompts DISABLED: a probe must never
# be able to pop a window - if it cannot get the credential silently, that IS
# the finding we are after
function GitNP([string[]]$gitArgs) {
    # the environment was locked down at the top of this script already; the -c
    # options make it explicit per call
    $all = @('-c', 'credential.interactive=false', '-c', 'core.askpass=') + $gitArgs
    $out = & git @all 2>&1
    return @{ code = $LASTEXITCODE; text = (($out | Out-String).TrimEnd()) }
}

if (-not $Branch) { $Branch = (CmdLine 'git' @('rev-parse', '--abbrev-ref', 'HEAD')) }

# ------------------------------------------------------------ remote + host
$remoteUrl = CmdLine 'git' @('remote', 'get-url', $Remote)
$hostName  = ''
if     ($remoteUrl -match '^https?://([^/]+)')  { $hostName = $Matches[1] }
elseif ($remoteUrl -match '^ssh://[^@]*@?([^/:]+)') { $hostName = $Matches[1] }
elseif ($remoteUrl -match '^[^@]+@([^:]+):')    { $hostName = $Matches[1] }
if (-not $hostName) { $hostName = 'github.com' }
$scheme = 'other'
if     ($remoteUrl -match '^https?://')        { $scheme = 'https' }
elseif ($remoteUrl -match '^(ssh://|git@)')    { $scheme = 'ssh' }

# ------------------------------------------------------------- environment
$gitVer   = CmdLine 'git' @('--version')
$psVer    = $PSVersionTable.PSVersion.ToString()
$helper   = CfgGet 'credential.helper'
$hostHelp = CfgGet ("credential.https://$hostName.helper")
$store    = CfgGet 'credential.credentialStore'
$inter    = CfgGet 'credential.interactive'
$gcmVer   = ''
$gcmRaw   = Run 'git' @('credential-manager', '--version')
if ($gcmRaw.code -eq 0) { $gcmVer = ($gcmRaw.text -split "`n")[0].Trim() }
if (-not $gcmVer) {
    $gcmRaw = Run 'git-credential-manager' @('--version')
    if ($gcmRaw.code -eq 0) { $gcmVer = ($gcmRaw.text -split "`n")[0].Trim() }
}
$ghVer = ''
$ghRaw = Run 'gh' @('--version')
if ($ghRaw.code -eq 0) { $ghVer = ($ghRaw.text -split "`n")[0].Trim() }
$ghUser = ''; $ghState = 'not installed'
if ($ghVer) {
    $st = Run 'gh' @('auth', 'status', '--hostname', $hostName)
    if ($st.code -eq 0) {
        $ghState = 'logged in'
        if     ($st.text -match '(?m)account\s+(\S+)') { $ghUser = $Matches[1] }
        elseif ($st.text -match '(?m)as\s+(\S+)')      { $ghUser = $Matches[1] }
    } else {
        $ghState = 'present, NOT logged in'
    }
}

# ------------------------------------------------------- credential probing
# The only honest question is "can git get a credential without asking?", so we
# ask it exactly the way the watcher will - prompts off, nothing can appear.
$credOk = $false; $credUser = ''; $credDetail = 'skipped (not an https remote)'
if ($scheme -eq 'https') {
    $probeIn = "protocol=https`nhost=$hostName`n`n"
    $probe = ($probeIn | & git -c credential.interactive=false -c core.askpass= credential fill 2>&1 | Out-String)
    if ($probe -match '(?m)^username=(.*)$') { $credUser = $Matches[1].Trim() }
    if ($probe -match '(?m)^password=(.*)$') {
        $secret = $Matches[1].Trim()
        if ($secret) { $credOk = $true }
    }
    if ($credOk) {
        $credDetail = "username=$credUser password=(hidden, $($secret.Length) chars)"
    } else {
        $msg = Brief $probe 3
        if (-not $msg) { $msg = '(the helper returned nothing)' }
        $credDetail = "no credential available - $msg"
    }
}

# ------------------------------------------------------------------ unsets
if ($Unset) {
    Say '== auth.ps1 -Unset : reverting what -Setup may have changed' 'Cyan'
    foreach ($k in @('credential.credentialStore', 'credential.interactive', ("credential.https://$hostName.helper"))) {
        if (CfgUnset $k) { Ok "unset git config key: $k" } else { Note "nothing to unset: $k" }
    }
    Note 'stored credentials were NOT deleted'
    Say ''
    exit 0
}

# ------------------------------------------------------------------- setup
if ($Setup) {
    Say "== auth.ps1 -Setup  (repo: $repo)" 'Cyan'
    Say "   remote : $Remote -> $remoteUrl"
    Say "   branch : $Branch"
    Say ''

    if ($scheme -eq 'ssh') {
        Note 'the remote uses SSH - no credential helper is involved; the private'
        Note 'key must be reachable without a passphrase prompt (ssh-agent).'
        $ssh = Run 'ssh' @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-T', "git@$hostName")
        if ($ssh.text -match 'successfully authenticated') {
            Ok "ssh key accepted by $hostName in batch mode (no prompt)"
            $null = $notes.Add('ssh key works in batch mode')
        } else {
            Warn "ssh batch-mode probe said: $(Brief $ssh.text 2)"
            Note "if an unattended push fails: enable ssh-agent or switch the remote to https"
            $null = $notes.Add('ssh key NOT proven in batch mode')
        }
        Say ''
        Say '== nothing else to do for SSH remotes.' 'Green'
        exit 0
    }

    # 1. a token was supplied -> seed it (never echoed anywhere)
    $seed = $Token
    if (-not $seed -and $TokenFile) {
        if (-not (Test-Path -LiteralPath $TokenFile)) { Bad "token file not found: $TokenFile"; exit 1 }
        $seed = (Get-Content -LiteralPath $TokenFile -Raw).Trim()
    }
    if (-not $seed -and $PromptToken) {
        $sec = Read-Host -AsSecureString 'paste the GitHub token (input hidden)'
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try   { $seed = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if ($seed) {
        if ($ghVer) {
            $seed | & gh auth login --hostname $hostName --git-protocol https --with-token 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Ok "token accepted by gh (kept in gh's own config, never in this repo)"
                $ghVer = (CmdLine 'gh' @('--version'))
                $ghState = 'logged in'
            } else {
                Warn 'gh refused the token - check its scopes (repo, and workflow if you push CI files)'
            }
        } else {
            $payload = "protocol=https`nhost=$hostName`nusername=x-access-token`npassword=$seed`n`n"
            $payload | & git -c credential.interactive=false credential approve 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok 'token stored in the configured credential store' }
            else { Warn 'could not store the token (no credential helper configured yet)' }
        }
        $seed = ''; $Token = ''
    }

    # 2. pick the helper: gh first, then Git Credential Manager
    if ($ghVer -and $ghState -eq 'logged in') {
        $r = Run 'gh' @('auth', 'setup-git', '--hostname', $hostName)
        if ($r.code -eq 0) {
            Ok "gh is now git's credential helper for $hostName (never prompts)"
            $null = $changed.Add("credential.https://$hostName.helper = gh")
        } else {
            Warn "gh auth setup-git failed: $(Brief $r.text 2)"
        }
    } elseif ($ghVer) {
        Note 'gh is installed but NOT logged in - run it once:  gh auth login'
        Note '   (that single browser step is the only click left; -TokenFile avoids it)'
        $null = $notes.Add('gh installed but not logged in')
    } else {
        Note 'gh CLI not installed (winget install GitHub.cli) - using Git Credential Manager'
    }

    if (-not ($ghVer -and $ghState -eq 'logged in')) {
        if ($gcmVer) {
            if (-not $helper) {
                if (CfgSet 'credential.helper' 'manager') {
                    Ok 'credential.helper = manager (Git Credential Manager)'
                    $null = $changed.Add('credential.helper = manager')
                }
            } else {
                Note "credential.helper already set: $helper (kept)"
            }
            if (-not $store) {
                if ($KeepWinCredMan) {
                    Warn 'keeping the default store (wincredman / Windows Credential Manager):'
                    Warn '   an unattended S4U or -Headless watcher push may fail - use a logged-on task'
                    $null = $notes.Add('credentialStore=default (wincredman): S4U/-Headless pushes may fail')
                } elseif (CfgSet 'credential.credentialStore' 'dpapi') {
                    Ok 'credential.credentialStore = dpapi (readable without an interactive desktop)'
                    $null = $changed.Add('credential.credentialStore = dpapi')
                }
            } elseif ($store -eq 'wincredman') {
                Warn 'credentialStore = wincredman: unreadable from a session-0 (S4U/-Headless) task or SSH'
                $null = $notes.Add('credentialStore=wincredman: S4U/-Headless pushes may fail')
            } else {
                Note "credentialStore already set: $store (kept)"
            }
        } else {
            Warn 'neither GitHub CLI nor Git Credential Manager found'
            Note 'install Git for Windows (ships GCM) or the GitHub CLI, then re-run -Setup'
            $null = $notes.Add('no credential helper available')
        }
    }

    # 3. optional: never prompt at all, machine-wide
    if ($NoPromptAll) {
        if (CfgSet 'credential.interactive' 'false') {
            Ok 'credential.interactive = false (git fails instead of prompting, everywhere)'
            $null = $changed.Add('credential.interactive = false')
        }
    }
    Say ''
}

# ------------------------------------------------------------------ verify
$lsState = ''; $lsText = ''
$pushState = ''; $pushText = ''
if ($Verify -or ($Setup -and -not $SkipVerify)) {
    Say '== verify (every probe runs with prompts DISABLED: no window can appear)' 'Cyan'
    if ($scheme -ne 'https') {
        Note "remote is not https ($scheme) - verify manually: git push $Remote $Branch"
    } else {
        $r1 = GitNP @('ls-remote', '--heads', $Remote)
        if ($r1.code -eq 0) {
            $lsState = 'passed'; Ok "git ls-remote $Remote : passed (read access, no prompt)"
        } else {
            $lsState = 'failed'; $lsText = Brief $r1.text 3
            Bad "git ls-remote $Remote : failed - $lsText"
        }

        if (-not $Quick) {
            $r2 = GitNP @('push', '--dry-run', $Remote, "HEAD:refs/heads/$Branch")
            if ($r2.code -eq 0) {
                $pushState = 'passed'; Ok "git push --dry-run $Remote HEAD:refs/heads/$Branch : passed (write access, no prompt)"
            } else {
                $pushState = 'failed'; $pushText = Brief $r2.text 3
                Bad "git push --dry-run : failed - $pushText"
            }
        } else {
            Note 'push dry-run skipped (-Quick)'
        }
    }
}

# ------------------------------------------------------------------ verdict
$ready = $credOk
if ($scheme -eq 'https') {
    if ($Verify -and -not $Quick) { $ready = ($lsState -eq 'passed' -and $pushState -eq 'passed') }
    elseif ($Verify)              { $ready = ($lsState -eq 'passed') }
    elseif ($Setup -and ($pushState -eq 'failed' -or $lsState -eq 'failed')) { $ready = $false }
} else {
    $ready = $true   # nothing to configure for ssh; the notes carry the caveat
}

if ($Json) {
    $skillVer = ''
    $verFile = Join-Path $repo 'skills\git-sync\VERSION'
    if (Test-Path -LiteralPath $verFile) { $skillVer = (Get-Content -LiteralPath $verFile -Raw).Trim() }
    $obj = [ordered]@{
        skill                  = $skillVer
        repo                   = $repo
        branch                 = $Branch
        remote                 = $Remote
        remote_url             = $remoteUrl
        scheme                 = $scheme
        host                   = $hostName
        git                    = $gitVer
        powershell             = $psVer
        credential_helper      = $helper
        host_helper            = $hostHelp
        credential_store       = $store
        credential_interactive = $inter
        gcm                    = $gcmVer
        gh                     = $ghVer
        gh_state               = $ghState
        gh_user                = $ghUser
        credential_available   = $credOk
        credential_detail      = $credDetail
        lsremote               = $lsState
        lsremote_detail        = $lsText
        push_dry_run           = $pushState
        push_dry_run_detail    = $pushText
        ready                  = [bool]$ready
        changed                = $changed.ToArray()
        notes                  = $notes.ToArray()
    }
    $obj | ConvertTo-Json -Depth 5 -Compress
    if ($ready) { exit 0 } else { exit 1 }
}

Say '== auth state' 'Cyan'
Say ("   repo    : {0}   branch: {1}   remote: {2} -> {3} [{4}]" -f $repo, $Branch, $Remote, $remoteUrl, $scheme)
Say ("   git     : {0}   PowerShell: {1}" -f $gitVer, $psVer)
$helperTxt = if ($helper) { $helper } else { '(none configured)' }
$storeTxt  = if ($store)  { $store }  else { '(default: wincredman / Windows Credential Manager)' }
$interTxt  = if ($inter)  { $inter }  else { '(unset)' }
$gcmTxt    = if ($gcmVer) { $gcmVer } else { '(not found)' }
$ghTxt     = if ($ghVer)  { "$ghVer [$ghState]$(if ($ghUser) { " user=$ghUser" })" } else { '(not installed)' }
Say ("   helper  : credential.helper = {0}" -f $helperTxt)
if ($hostHelp) { Say ("             credential.helper for {0} = {1}" -f $hostName, $hostHelp) }
Say ("             credential.credentialStore = {0}" -f $storeTxt)
Say ("             credential.interactive = {0}" -f $interTxt)
Say ("             Git Credential Manager = {0}" -f $gcmTxt)
Say ("             GitHub CLI = {0}" -f $ghTxt)
Say ''
$probeTxt = if ($credOk) { "OK - $credDetail" } else { "NOT AVAILABLE - $credDetail" }
Say ("   silent credential probe : {0}" -f $probeTxt)
if ($lsState)   { Say ("   git ls-remote          : {0}" -f $lsState.ToUpper()) }
if ($pushState) { Say ("   push --dry-run         : {0}" -f $pushState.ToUpper()) }
Say ''

if ($scheme -eq 'ssh') {
    Say '== verdict: SSH remote - no helper needed; see the notes from -Setup.' 'Green'
    exit 0
}
if ($ready) {
    Say '== verdict: READY - a push completes with no window and no click.' 'Green'
    Say '   the watcher (watch.ps1) can push its results unattended.' 'Gray'
    exit 0
}
Say '== verdict: NOT READY - a push would need a human (or hang forever).' 'Red'
Say '   do this once:' 'Yellow'
Say '     .\auth.ps1 -Setup              # gh > Git Credential Manager (dpapi)' 'Yellow'
Say '     .\auth.ps1 -Verify             # prove it, prompts disabled' 'Yellow'
Say '   if gh is installed but not logged in, ONE interactive login is needed:' 'Yellow'
Say '     gh auth login                  # browser/device code, once per machine' 'Yellow'
Say '   or seed a token with no browser at all:' 'Yellow'
Say '     .\auth.ps1 -Setup -PromptToken            (hidden input)' 'Yellow'
Say '     .\auth.ps1 -Setup -TokenFile C:\pat.txt   (the file stays outside git)' 'Yellow'
if ($credDetail) { Note "probe said: $credDetail" }
exit 1
