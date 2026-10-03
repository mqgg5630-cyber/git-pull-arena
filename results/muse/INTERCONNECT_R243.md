# Interconnect probe - round 243

- Time: 2026-10-03 16:16:35 +08:00
- Host: LAPTOP-R77M5D6M

## 1. Muse GitHub bridge contents
- deliverable/muse/.gitkeep
- results/muse/bridge_test_20261003.json
- results/muse/HANDOFF.md
- results/muse/INTERCONNECT_R242.json
- results/muse/INTERCONNECT_R242.md
- sources/muse/.gitkeep
MUSE_PUSH_SEEN: yes (3 non-placeholder file(s))

## 2. Tailscale nodes
- tailscale.exe: E:\Tailscale\tailscale.exe
- LAPTOP-R77M5D6M / laptop-r77m5d6m-1.tail42d047.ts.net. | ips=100.71.123.19, fd7a:115c:a1e0::eb3b:7b14 | online=True
- muse / muse.tail42d047.ts.net. | ips=100.109.207.34, fd7a:115c:a1e0::943b:cf23 | online=True
- Redmi Note 12 Turbo / redmi-note-12-turbo.tail42d047.ts.net. | ips=100.90.87.92, fd7a:115c:a1e0::b93b:575d | online=False
- DESKTOP-IEUDGS5 / desktop-ieudgs5.tail42d047.ts.net. | ips=100.84.137.117, fd7a:115c:a1e0::bb01:8994 | online=True
- localhost / xiaomi-23049rad8c.tail42d047.ts.net. | ips=100.83.148.67, fd7a:115c:a1e0::b901:9490 | online=False
- Redmi Note 12 Turbo / redmi-note-12-turbo-1.tail42d047.ts.net. | ips=100.80.187.74, fd7a:115c:a1e0::63b:bb4c | online=False
- LAPTOP-R77M5D6M / laptop-r77m5d6m.tail42d047.ts.net. | ips=100.99.113.111, fd7a:115c:a1e0::ae01:7192 | online=False

## 3. Laptop-side TCP reachability
- laptop -> desktop 100.84.137.117:22 = OPEN
- laptop -> desktop 100.84.137.117:3389 = OPEN
- laptop -> desktop 100.84.137.117:445 = OPEN
- laptop -> muse 100.109.207.34:22 = closed/filtered
- laptop -> muse 100.109.207.34:445 = closed/filtered
- laptop -> muse 100.109.207.34:80 = closed/filtered
- laptop -> muse 100.109.207.34:443 = closed/filtered
- laptop -> hpc 10.10.5.210:22 = OPEN

## 4. SSH and reverse probes
- ssh client: C:\WINDOWS\System32\OpenSSH\ssh.exe
- laptop -> desktop SSH: OK
  - desktop| DESKTOP_SSH_OK 
  - desktop| DESKTOP-IEUDGS5
  - desktop| True
  - desktop| False
- laptop -> HPC SSH: OK
  - hpc| HPC_SSH_OK
  - hpc| mu01
  - hpc| 25wenshaohua
  - hpc| /mnt/hpc/home/25menglei/25wenshaohua
  - hpc| HPC_TO_LAPTOP_22_NO

## 5. Summary
- Laptop IP: 100.71.123.19
- Desktop IP: 100.84.137.117
- Muse IP: 100.109.207.34 (outbound-only; inbound closed is expected)
- HPC IP: 10.10.5.210
- Report paths:
  - ./results/muse/INTERCONNECT_R243.md
  - ./results/muse/INTERCONNECT_R243.json
INTERCONNECT_PROBE_DONE
