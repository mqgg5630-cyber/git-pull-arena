# R320 diagnose the frozen WinFR processes
time=2026-10-06 21:26:50
snapshot1: {73524: ('WinFR.exe', '1,064 K'), 76396: ('WinFR.exe', '64,368 K'), 66588: ('WinFR.exe', '74,836 K')}
latest MONITOR lines:
  MONITOR v1 elapsed=1532s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=1802s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=1562s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=1832s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  key| VARIANT v1 filter=\0mcp-agv-arena-optimized\deskbox-v2\library\*
waiting 90s for a CPU-time comparison...
snapshot2: {73524: ('WinFR.exe', '1,064 K'), 76396: ('WinFR.exe', '71,368 K'), 66588: ('WinFR.exe', '83,236 K')}
cpu_frozen=False (equal snapshots => no progress)
waiting up to 15 min for helper v8 deadline / done marker...
  MONITOR v1 elapsed=1982s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2042s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2103s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2163s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2223s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2283s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2343s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
  MONITOR v1 elapsed=2403s alive=System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) System.Diagnostics.Process (WinFR) files=0
helper v8 done marker present
snapshot3 (after wait): {73524: ('WinFR.exe', '1,064 K'), 76396: ('WinFR.exe', '77,320 K'), 66588: ('WinFR.exe', '85,580 K')}
recovery_winfr_E: 0 files, 0MB
DIAGNOSIS: frozen=False helper_done=True winfr_left=3
PLAN: r321 = elevated cleanup (kill all WinFR) + single visible-window unredirected retry.
R320_DIAG_COMPLETE=True
