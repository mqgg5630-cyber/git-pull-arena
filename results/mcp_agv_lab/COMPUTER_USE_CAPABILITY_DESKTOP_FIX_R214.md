# Desktop computer-use audit fix r214
time=2026-10-02 15:43:02
computer=LAPTOP-R77M5D6M user=文少
desktop_script_staged=OK
RUN_START=zip_windows-computer-use
zip_project=windows-computer-use ok=True exists=True
RUN_START=zip_Windows-MCP
zip_project=Windows-MCP ok=True exists=True
RUN_START=zip_pywinauto-mcp
zip_project=pywinauto-mcp ok=True exists=True
desktop| # Desktop computer-use capability audit r214
desktop| time=2026-10-02 15:44:27
desktop| computer=DESKTOP-IEUDGS5 user=bni
desktop| lab_root=E:\0mcp-agv-arena-optimized
desktop| stage_root=F:\fig1_rebuild\cu_r214
desktop| antigravity_cli_candidates=1
desktop| ag_cli_version|path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=[23812:1002/154443.956:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32
desktop| ssh : ???3???????WriteAllText??????:???????
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:9 ??: 190
desktop| open_window_count=0
desktop| ???3???????WriteAllText??????:???????
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:122 ??: 1
desktop| ## Capability list
desktop| cap|DESKTOP-IEUDGS5|Windows GUI apps|windows-computer-use|UIA backend available on E drive|NOT_READY|backend missing|E:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1
desktop| cap|DESKTOP-IEUDGS5|Antigravity|Antigravity terminal CLI|open E-drive probe file/workspace|OK_ISSUED|version=[23812:1002/154443.956:ERROR:chrome\browser\process_singleton_win.cc:457] Lock file can not be created! Error code: 32|E:\0mcp-agv-arena-optimized\reports\antigravity-cli-probe-desktop-r214.txt
desktop| cap|DESKTOP-IEUDGS5|GreenVPN|app-specific status|check install/process/startup target|OK|exe=True;processes=4|F:\NsfocusVPN\NsfocusVPN.exe
desktop| cap|DESKTOP-IEUDGS5|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|
desktop| cap|DESKTOP-IEUDGS5|Adobe Illustrator|path/process probe|detect executable/process for future COM/UIA wrapper|OK|paths=F:\Adobe Illustrator 2020 ???\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe;F:\Adobe Illustrator 2020 ???\Support Files\Contents\Windows\Illustrator.exe|
desktop| cap|DESKTOP-IEUDGS5|File Explorer|shell CLI|open E-drive lab folder|OK_CAPABLE|explorer.exe can open local folders|E:\0mcp-agv-arena-optimized
desktop| cap|DESKTOP-IEUDGS5|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
desktop| json=E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json
desktop| ok_capability_count=8
desktop| partial_capability_count=3
desktop| [REDACTED]: COMPLETED
desktop| ???3???????WriteAllText??????:???????
desktop| ?
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:8 ??: 184
desktop| Copy-Item : ??????E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.md???????
desktop| ????
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:133 ??: 94
desktop|    ption
desktop| Copy-Item : ??????E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json??????
desktop| ?????
desktop| ???? F:\fig1_rebuild\[REDACTED].ps1:133 ??: 159
desktop|    ption
desktop_report_collected=False
desktop_json_collected=False
final_checklist=E:\0github\git-sync\git-pull-arena-01a0fa39\results\mcp_agv_lab\[REDACTED].md
FINAL_R214: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY desktop_status=RAN
