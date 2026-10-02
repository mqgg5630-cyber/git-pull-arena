# Desktop computer-use audit fix r214
time=2026-10-02 15:53:02
computer=LAPTOP-R77M5D6M user=文少
desktop_script_staged=OK
RUN_START=zip_windows-computer-use
zip_project=windows-computer-use ok=True exists=True
RUN_START=zip_Windows-MCP
zip_project=Windows-MCP ok=True exists=True
RUN_START=zip_pywinauto-mcp
zip_project=pywinauto-mcp ok=True exists=True
desktop| # Desktop computer-use capability audit r214
desktop| time=2026-10-02 15:54:48
desktop| computer=DESKTOP-IEUDGS5 user=bni
desktop| lab_root=E:\0mcp-agv-arena-optimized
desktop| stage_root=F:\fig1_rebuild\cu_r214
desktop| project|windows-computer-use|status=unzip-failed-????????|path=E:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| project|Windows-MCP|status=unzip-failed-????????|path=E:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| project|pywinauto-mcp|status=unzip-failed-????????|path=E:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| antigravity_cli_candidates=1
desktop| ag_cli_version|path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=[29920:1002/155505.774:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32
desktop| ssh : ???2???????WriteAllText??????:???????
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:9 ??: 127
desktop| open_window_count=0
desktop| ???2???????WriteAllText??????:???????
desktop| ## Capability list
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:121 ??: 1
desktop| cap|DESKTOP-IEUDGS5|windows-computer-use|E-drive install|install/presence check|CHECK_REPORT|unzip-failed-????????|E:\0mcp-agv-arena-optimized\github\windows-computer-use
desktop| cap|DESKTOP-IEUDGS5|Windows-MCP|E-drive install|install/presence check|CHECK_REPORT|unzip-failed-????????|E:\0mcp-agv-arena-optimized\github\Windows-MCP
desktop| cap|DESKTOP-IEUDGS5|pywinauto-mcp|E-drive install|install/presence check|CHECK_REPORT|unzip-failed-????????|E:\0mcp-agv-arena-optimized\github\pywinauto-mcp
desktop| cap|DESKTOP-IEUDGS5|Windows GUI apps|windows-computer-use|UIA backend available on E drive|NOT_READY|backend missing|E:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1
desktop| cap|DESKTOP-IEUDGS5|Antigravity|Antigravity terminal CLI|open E-drive probe file/workspace|OK_ISSUED|version=[29920:1002/155505.774:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32|E:\0mcp-agv-arena-optimized\reports\antigravity-cli-probe-desktop-r214.txt
desktop| cap|DESKTOP-IEUDGS5|GreenVPN|app-specific status|check install/process/startup target|OK|exe=True;processes=4|F:\NsfocusVPN\NsfocusVPN.exe
desktop| cap|DESKTOP-IEUDGS5|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|
desktop| cap|DESKTOP-IEUDGS5|Adobe Illustrator|path/process probe|detect executable/process for future COM/UIA wrapper|OK|paths=F:\Adobe Illustrator 2020 ???\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe;F:\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe|
desktop| cap|DESKTOP-IEUDGS5|File Explorer|shell CLI|open E-drive lab folder|OK_CAPABLE|explorer.exe can open local folders|E:\0mcp-agv-arena-optimized
desktop| cap|DESKTOP-IEUDGS5|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
desktop| json=E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json
desktop| ok_capability_count=8
desktop| partial_capability_count=3
desktop| [REDACTED]: COMPLETED
desktop| ???2???????WriteAllText??????:???????
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:8 ??: 121
desktop| Copy-Item : ??????E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.md???????
desktop| ????
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:132 ??: 94
desktop|    ption
desktop| Copy-Item : ??????E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json??????
desktop| ?????
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:132 ??: 159
desktop|    ption
desktop_report_collected=False
desktop_json_collected=False
final_checklist=E:\0github\git-sync\git-pull-arena-01a0fa39\results\mcp_agv_lab\[REDACTED].md
FINAL_R214: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY desktop_status=RAN
