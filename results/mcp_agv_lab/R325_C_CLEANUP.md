# R325 recovery abandoned - stop scan, audit C:, clean caches
time=2026-10-06 22:53:45
C: free before: 38571MB / total 102399MB
  vss_final| MON2 elapsed=2401s alive=True files=0
  vss_final| MON2 elapsed=2461s alive=True files=0
  vss_final| MON2 elapsed=2521s alive=True files=0
  vss_final| MON2 elapsed=2581s alive=False files=0
  vss_final| WINFR_ZERO (winfr exited with no files recovered)
  vss_final| == helper v10 done 10/06/2026 22:43:14
winfr_count=0
winfr_alive_after=False
## audit (read-only sizes, MB)
  recovery_winfr_E: 0 files, 0MB
  user_temp: 47 files, 1MB
  crashdumps: 4 files, 2MB
  c_windows_temp: 0 files, 0MB
  wu_download: 5 files, 1MB
  c_recyclebin: 1 files, 0MB
  programdata_wer: 4 files, 0MB
  search_index: (missing/inaccessible)
  pip_cache: 697 files, 395MB
  delivery_opt: (missing/inaccessible)
  C:\hiberfil.sys: 6516MB
  C:\swapfile.sys: 256MB
  -- LOCALAPPDATA top 15 --
  LA/Lively Wallpaper: 6679MB
  LA/ms-playwright: 1356MB
  LA/Google: 1166MB
  LA/Microsoft: 962MB
  LA/Programs: 923MB
  LA/Packages: 612MB
  LA/pip: 395MB
  LA/antigravity-updater: 312MB
  LA/go-build: 245MB
  LA/agy: 175MB
  LA/ArenaTools: 122MB
  LA/keymouse-studio-updater: 121MB
  LA/antigravity: 97MB
  LA/com.ccswitch.desktop: 96MB
  LA/freellmapi-desktop-updater: 88MB
## cleanup (user-level only)
  user_temp: freed -126MB (leftover 127MB)
  crashdumps: freed 2MB (leftover 0MB)
  pip_cache: freed 395MB (leftover 0MB)
  edge-Default-Cache: freed 31MB (leftover 0MB)
  edge-Default-Code Cache: freed 27MB (leftover 0MB)
  edge-Default-GPUCache: freed 1MB (leftover 0MB)
  chrome-Default-Cache: freed 0MB (leftover 0MB)
  chrome-Default-Code Cache: freed 0MB (leftover 0MB)
  chrome-Default-GPUCache: freed 4MB (leftover 0MB)
  recovery_winfr_E: freed 0MB (leftover 0MB)
  dbox/vss_helper.ps1: removed
  dbox/vss_launch_v10.ps1: removed
  dbox/vss_out.txt: removed
  dbox/uac_err.txt: removed
desktop=D:\??
  desktop/RECOVERY-recover-data.bat: removed
## summary
freed_estimate=337MB
C: free after: 38971MB (delta 400MB)
admin_only (user can clean via Settings > System > Storage): wu_download, delivery_opt, search_index, hiberfil, pagefile
recycle_bin_left_untouched=yes (may hold user files)
R325_CLEANUP_COMPLETE=True
