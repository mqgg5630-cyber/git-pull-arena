# Round 22 findings (from check_r22_20260929-113022.txt, machine LAPTOP-R77M5D6M)

## Task 1 - Antigravity (2.15.1) login failure: ROOT CAUSE FOUND

Evidence from `%APPDATA%\Antigravity IDE\logs\20260929T102401\ls-main.log`:

```
Get "https://www.googleapis.com/oauth2/v2/userinfo":
  Post "https://oauth2.googleapis.com/token": dial tcp 108.177.125.95:443: connectex ...
Post "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": Post "https://oauth2.goo ...
```

- The browser part of the login works through the SYSTEM PROXY (WinINET ProxyEnable=1,
  ProxyServer=127.0.0.1:10808 - v2rayN style): HTTPS via system proxy returns HTTP 204 / 302
  from google.com / accounts.google.com.
- Antigravity's own backend processes (the language server) dial Google APIs DIRECTLY,
  bypassing the proxy - and every direct TCP 443 to google hosts FAILS (GFW). So the user
  sees "authenticated" in the browser but the IDE never establishes a working session.
- Not the cause: clock skew (0 min), WSA (not installed), region errors (none in logs),
  url handler (registered), account eligibility (auth itself succeeded at 10:24:04).
- Chrome is NOT installed and default browser is Firefox, but the OAuth callback did work
  ("Auth succeeded, refreshing features"), so Chrome is not the blocker here.

Fix (round 23): patch Antigravity IDE settings.json with http.proxy + proxySupport + noProxy
(backup first), then the user relaunches Antigravity. If the language server still dials
direct, enable TUN mode in the proxy client (v2rayN) which force-proxies direct connections.

## Task 2 - Java: never installed at all

- java/javaw/javac NOT on PATH; JAVA_HOME unset (all scopes); no Java entries in the
  uninstall registry (HKLM 64/32 + HKCU); no MsiInstaller events (last 60d); nothing in
  winget; no installer logs in TEMP.
- `E:\java` exists but is EMPTY - an install attempt never landed.
- Windows Installer service: Stopped/Manual (normal). Watcher runs non-elevated.
- Fix (round 23): portable Temurin JDK 21 (LTS) zip from a China-friendly mirror,
  extracted to `E:\java\jdk-21.x.x`, JAVA_HOME + User PATH set without any admin rights.

## Task 3 - E: cleanup candidates (read-only scan, 289.7 of 481.1 GB scanned in 600s)

| item | size | verdict |
|---|---|---|
| E:\WSL\Ubuntu-24.04\ext4.vhdx | 145.1 GB | reclaimable via `wsl --manage Ubuntu-24.04 --set-sparse true` (or compact after cleaning inside WSL) |
| E:\pagefile.sys | 36.0 GB | page file on E:; capping it (e.g. 8-16 GB) frees ~20-28 GB, needs reboot |
| E:\Tencent Games (VALORANT) | 32.6 GB | ask user (uninstall if not played) |
| E:\Users\..\Downloads installers | ~5-6 GB | ask user: BIOVIA_DS2025Client (1).exe duplicate (455 MB), WSA_2407 leftover (~2 GB), RStudio 2 versions (604 MB), OmicOS/BaiduNetdisk/WorkBuddy/FlyingMouse/Positron etc. |
| E:\spider\pkgs (conda cache) | 6.7 GB | SAFE: `conda clean --all` (keeps all envs) |
| E:\xunlei + E:\Thunder | 3.7 GB | download leftovers, ask user |
| E:\Adobe Illustrator 2020 ???.zip | 431.6 MB | ask user |
| E:\????\WPSOffice_...2019...zip | 488.7 MB | ask user (installed WPS already at E:\WPSOffice) |
| node_modules hits | all < 100 MB | INSIDE apps (Tabby/Trae/vscode) - do NOT clean |

Remaining ~190 GB of top-level folders (alphabetically early, incl. E:\0github) were NOT
scanned before the 600s cap - round 23 task t3_edrive_scan2.ps1 finishes those.
NOTE: `E:\vit-pytorch-main\.conda\Lib\site-packages\pip` is pip-the-package, NOT a cache - excluded from cleanup.
