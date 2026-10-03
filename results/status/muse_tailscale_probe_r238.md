# Muse Tailscale probe - round 238

- Time: 2026-10-03 15:36:46 +08:00
- Host: LAPTOP-R77M5D6M
- User: 文少

- tailscale.exe: E:\Tailscale\tailscale.exe
- BackendState: Running
- This node: LAPTOP-R77M5D6M / laptop-r77m5d6m-1.tail42d047.ts.net. | ips=100.71.123.19, fd7a:115c:a1e0::eb3b:7b14

## Tailnet nodes seen by this laptop
- LAPTOP-R77M5D6M / laptop-r77m5d6m-1.tail42d047.ts.net. | ips=100.71.123.19, fd7a:115c:a1e0::eb3b:7b14 | online=True | os=windows
- muse / muse.tail42d047.ts.net. | ips=100.109.207.34, fd7a:115c:a1e0::943b:cf23 | online=True | os=
- Redmi Note 12 Turbo / redmi-note-12-turbo.tail42d047.ts.net. | ips=100.90.87.92, fd7a:115c:a1e0::b93b:575d | online=False | os=android
- DESKTOP-IEUDGS5 / desktop-ieudgs5.tail42d047.ts.net. | ips=100.84.137.117, fd7a:115c:a1e0::bb01:8994 | online=True | os=windows
- localhost / xiaomi-23049rad8c.tail42d047.ts.net. | ips=100.83.148.67, fd7a:115c:a1e0::b901:9490 | online=False | os=android
- Redmi Note 12 Turbo / redmi-note-12-turbo-1.tail42d047.ts.net. | ips=100.80.187.74, fd7a:115c:a1e0::63b:bb4c | online=False | os=android
- LAPTOP-R77M5D6M / laptop-r77m5d6m.tail42d047.ts.net. | ips=100.99.113.111, fd7a:115c:a1e0::ae01:7192 | online=False | os=windows

## Muse candidates
### muse / muse.tail42d047.ts.net.
- IPs: 100.109.207.34, fd7a:115c:a1e0::943b:cf23
- Probe target: 100.109.207.34
  - tcp/445: closed/filtered
  - tcp/22: closed/filtered
  - tcp/139: closed/filtered
  - tcp/3389: closed/filtered
  - tcp/80: closed/filtered
  - tcp/443: closed/filtered
  - tcp/8000: closed/filtered
  - tcp/8080: closed/filtered
  - tcp/5000: closed/filtered

## Access guidance
MUSE_REACHABLE_NO_FILE_SERVICE
- Muse is visible in Tailscale, but common file-service ports were not open. Ask Muse to expose SMB tcp/445 or SSH/SFTP tcp/22 on its Tailscale IP.
MUSE_TAILSCALE_PROBE_DONE
