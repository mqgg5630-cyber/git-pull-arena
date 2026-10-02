# Desktop fallback audit r218
time=2026-10-02 15:57:52
desktop_fallback_script_staged=OK
zip_ready=windows-computer-use exists=True
zip_ready=Windows-MCP exists=True
zip_ready=pywinauto-mcp exists=True
desktop| # Desktop computer-use capability audit r218
desktop| time=2026-10-02 15:58:00
desktop| computer=DESKTOP-IEUDGS5 user=bni
desktop| e_drive_available=False
desktop| f_drive_available=True
desktop| chosen_root=F:\0mcp-agv-arena-optimized
desktop| root_mode=F_FALLBACK_NO_E_DRIVE
desktop| project|windows-computer-use|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| project|Windows-MCP|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| project|pywinauto-mcp|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| antigravity_cli_candidates=1
desktop| ag_cli_version|path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32
desktop| ## Capability list
desktop| cap|DESKTOP-IEUDGS5|windows-computer-use|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| cap|DESKTOP-IEUDGS5|Windows-MCP|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| cap|DESKTOP-IEUDGS5|pywinauto-mcp|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| cap|DESKTOP-IEUDGS5|Windows GUI apps|windows-computer-use|UIA backend available|OK|backend exists|F:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1
desktop| cap|DESKTOP-IEUDGS5|Antigravity|Antigravity terminal CLI|open probe file/workspace|OK_ISSUED|version=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32|F:\0mcp-agv-arena-optimized\reports\antigravity-cli-probe-desktop-r218.txt
desktop| cap|DESKTOP-IEUDGS5|GreenVPN|app-specific status|check install/process/startup target|OK|exe=True;processes=4|F:\NsfocusVPN\NsfocusVPN.exe
desktop| cap|DESKTOP-IEUDGS5|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|
desktop| cap|DESKTOP-IEUDGS5|Adobe Illustrator|path/process probe|detect executable/process for future COM/UIA wrapper|OK|paths=F:\Adobe Illustrator 2020 ???\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe;F:\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe|
desktop| cap|DESKTOP-IEUDGS5|File Explorer|shell CLI|open chosen lab folder|OK_CAPABLE|explorer.exe can open local folders|F:\0mcp-agv-arena-optimized
desktop| cap|DESKTOP-IEUDGS5|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
desktop| json=F:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r218.json
desktop| ok_capability_count=12
desktop| partial_capability_count=0
desktop| [REDACTED]: COMPLETED
desktop| stage_copy=OK
desktop| # Desktop computer-use capability audit r218
desktop| time=2026-10-02 15:58:00
desktop| computer=DESKTOP-IEUDGS5 user=bni
desktop| e_drive_available=False
desktop| f_drive_available=True
desktop| chosen_root=F:\0mcp-agv-arena-optimized
desktop| root_mode=F_FALLBACK_NO_E_DRIVE
desktop| project|windows-computer-use|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| project|Windows-MCP|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| project|pywinauto-mcp|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| antigravity_cli_candidates=1
desktop| ag_cli_version|path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32
desktop| ## Capability list
desktop| cap|DESKTOP-IEUDGS5|windows-computer-use|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| cap|DESKTOP-IEUDGS5|Windows-MCP|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| cap|DESKTOP-IEUDGS5|pywinauto-mcp|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| cap|DESKTOP-IEUDGS5|Windows GUI apps|windows-computer-use|UIA backend available|OK|backend exists|F:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1
desktop| cap|DESKTOP-IEUDGS5|Antigravity|Antigravity terminal CLI|open probe file/workspace|OK_ISSUED|version=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32|F:\0mcp-agv-arena-optimized\reports\antigravity-cli-probe-desktop-r218.txt
desktop| cap|DESKTOP-IEUDGS5|GreenVPN|app-specific status|check install/process/startup target|OK|exe=True;processes=4|F:\NsfocusVPN\NsfocusVPN.exe
desktop| cap|DESKTOP-IEUDGS5|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|
desktop| cap|DESKTOP-IEUDGS5|Adobe Illustrator|path/process probe|detect executable/process for future COM/UIA wrapper|OK|paths=F:\Adobe Illustrator 2020 ???\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe;F:\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe|
desktop| cap|DESKTOP-IEUDGS5|File Explorer|shell CLI|open chosen lab folder|OK_CAPABLE|explorer.exe can open local folders|F:\0mcp-agv-arena-optimized
desktop| cap|DESKTOP-IEUDGS5|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
desktop| json=F:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r218.json
desktop| ok_capability_count=12
desktop| partial_capability_count=0
desktop| [REDACTED]: COMPLETED
desktop_report_collected=True
desktop_json_collected=True
final_checklist=E:\0github\git-sync\git-pull-arena-01a0fa39\results\mcp_agv_lab\[REDACTED].md
FINAL_R218: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY desktop_status=RAN
