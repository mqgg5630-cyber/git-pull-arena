# Desktop computer-use capability audit r218
time=2026-10-02 15:58:00
computer=DESKTOP-IEUDGS5 user=bni
e_drive_available=False
f_drive_available=True
chosen_root=F:\0mcp-agv-arena-optimized
root_mode=F_FALLBACK_NO_E_DRIVE
project|windows-computer-use|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\windows-computer-use
project|Windows-MCP|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\Windows-MCP
project|pywinauto-mcp|status=unzipped-but-no-git-dir|path=F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
antigravity_cli_candidates=1
ag_cli_version|path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32

## Capability list
cap|DESKTOP-IEUDGS5|windows-computer-use|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\windows-computer-use
cap|DESKTOP-IEUDGS5|Windows-MCP|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\Windows-MCP
cap|DESKTOP-IEUDGS5|pywinauto-mcp|F_FALLBACK_NO_E_DRIVE install|install/presence check|OK|unzipped-but-no-git-dir|F:\0mcp-agv-arena-optimized\github\pywinauto-mcp
cap|DESKTOP-IEUDGS5|Windows GUI apps|windows-computer-use|UIA backend available|OK|backend exists|F:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1
cap|DESKTOP-IEUDGS5|Antigravity|Antigravity terminal CLI|open probe file/workspace|OK_ISSUED|version=[33420:1002/155809.967:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32|F:\0mcp-agv-arena-optimized\reports\antigravity-cli-probe-desktop-r218.txt
cap|DESKTOP-IEUDGS5|Antigravity|app-specific status + bridge|installed/process/proxy check|OK|version=2.15.1.0;proc=6;ls=1;18088=True|
cap|DESKTOP-IEUDGS5|v2rayN/xray|process + port status|check bridge/network helper|OK|v2rayN=1;xray=2;18088=True|
cap|DESKTOP-IEUDGS5|GreenVPN|app-specific status|check install/process/startup target|OK|exe=True;processes=4|F:\NsfocusVPN\NsfocusVPN.exe
cap|DESKTOP-IEUDGS5|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|
cap|DESKTOP-IEUDGS5|Adobe Illustrator|path/process probe|detect executable/process for future COM/UIA wrapper|OK|paths=F:\Adobe Illustrator 2020 ???\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe;F:\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe|
cap|DESKTOP-IEUDGS5|File Explorer|shell CLI|open chosen lab folder|OK_CAPABLE|explorer.exe can open local folders|F:\0mcp-agv-arena-optimized
cap|DESKTOP-IEUDGS5|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
json=F:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r218.json
ok_capability_count=12
partial_capability_count=0
FINAL_DESKTOP_COMPUTER_USE_AUDIT_R218: COMPLETED
