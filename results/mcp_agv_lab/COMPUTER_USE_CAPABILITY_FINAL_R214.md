# Computer-use capability final checklist r214

All new computer-use project installs and reports are kept under E:\0mcp-agv-arena-optimized on each Windows machine.

## Key paths

- Laptop final/local report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.md
- Laptop final/local JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.json
- Laptop combined repo report: results/mcp_agv_lab/COMPUTER_USE_CAPABILITY_AUDIT_R213.md
- Desktop final report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.md
- Desktop final JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json
- Desktop repo copy: results/mcp_agv_lab/computer-use-capability-audit-desktop-r214.md

## Interpretation

- Antigravity CLI is useful for launching/opening files or workspaces from a terminal.
- Antigravity chat/agent dialog control is still better via CDP/Electron DOM; r212 proved real message insertion and submit.
- windows-computer-use gives reliable UIA find/invoke on ordinary Windows controls; r213 proved it again on an E-drive WinForms app.
- software-ops wrappers and COM are best for app-specific status/control such as WPS, v2rayN/xray, GreenVPN, and Illustrator detection.

## Laptop r213 summary

# Computer-use capability audit r213

Laptop E report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.md
Laptop E JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.json
Desktop status: RAN
Desktop E report expected: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r213.md
Desktop repo copy: E:\0github\git-sync\git-pull-arena-01a0fa39\results\mcp_agv_lab\computer-use-capability-audit-desktop-r213.md

## Complementary success case

- Antigravity terminal CLI: used to issue opening of an E-drive probe file/workspace.
- CDP/Electron DOM: proven in r212 to insert and submit an Antigravity message input; marker visible after submit.
- windows-computer-use MCP/UIA: fresh r213 E-drive WinForms button find+invoke test writes a marker file.
- software-ops wrappers and COM: app-specific status/control checks for Antigravity, v2rayN/xray, GreenVPN, WPS, and Illustrator.

## Laptop capabilities

| Computer | App | Backend | Tested task | Result | Evidence/artifact |
|---|---|---|---|---|---|
| LAPTOP-R77M5D6M | windows-computer-use | E-drive install | install/presence check | OK | present E:\[REDACTED]\github\[REDACTED] |
| LAPTOP-R77M5D6M | Windows-MCP | E-drive install | install/presence check | OK | present E:\[REDACTED]\github\Windows-MCP |
| LAPTOP-R77M5D6M | pywinauto-mcp | E-drive install | install/presence check | OK | cloned E:\[REDACTED]\github\pywinauto-mcp |
| LAPTOP-R77M5D6M | Antigravity | Antigravity terminal CLI | open E-drive probe file/workspace | OK_ISSUED | version= E:\[REDACTED]\reports\[REDACTED].txt |
| LAPTOP-R77M5D6M | Lab WinForms app | windows-computer-use MCP/UIA | find button and invoke it | OK | marker file created by invoked button E:\[REDACTED]\smoke\[REDACTED].txt |
| LAPTOP-R77M5D6M | antigravity | software-ops wrapper | run antigravity-status | OK | {??    "app":  "Antigravity",??    "installed":  true,??    "version":  "2.19.1.0",??    "processes":  6,??    "languageServer":  1,??    "proxy18088":  true,??    "mcpConfig":  true??} E:\[REDACTED]\software-ops\[REDACTED].ps1 |
| LAPTOP-R77M5D6M | v2rayn | software-ops wrapper | run v2rayn-status | OK | {??    "app":  "v2rayN",??    "v2rayN":  1,??    "xray":  2,??    "bridge18088":  true,??    "bridgeTask":  false??} E:\[REDACTED]\software-ops\[REDACTED].ps1 |
| LAPTOP-R77M5D6M | greenvpn | software-ops wrapper | run greenvpn-status | OK | {??    "app":  "GreenVPN",??    "exe":  true,??    "processes":  4,??    "startup":  true,??    "scheduledTask":  false??} E:\[REDACTED]\software-ops\[REDACTED].ps1 |
| LAPTOP-R77M5D6M | wps | software-ops wrapper | run wps-status | OK | {??    "app":  "WPS",??    "processes":  4,??    "com":  {??                "KWPS.Application":  "OK",??                "KET.Application":  "OK",??                "KWPP.Application":  "OK"??            }??} E:\[REDACTED]\software-ops\[REDACTED].ps1 |
| LAPTOP-R77M5D6M | illustrator | software-ops wrapper | run illustrator-status | OK | {??    "app":  "Illustrator",??    "processes":  0,??    "paths":  [??                  "E:\\Adobe Illustrator 2020 ?????\Support Files\\Contents\\Windows\\Illustrator.exe"??              ]??} E:\[REDACTED]\software-ops\[REDACTED].ps1 |
| LAPTOP-R77M5D6M | WPS Office | COM automation | instantiate Writer/Sheet/Presentation COM | OK | KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK [REDACTED].pptx |
| LAPTOP-R77M5D6M | Antigravity chat | CDP/Electron DOM | submit message input | OK_PROVEN_R212 | message input role=combobox aria=Message input; cdp-insertText; marker visible after submit E:\[REDACTED]\reports\[REDACTED].json |
| LAPTOP-R77M5D6M | File Explorer | shell CLI | open E-drive lab folder | OK_CAPABLE | explorer.exe can open local folders E:\[REDACTED] |
| LAPTOP-R77M5D6M | Notepad | process/file CLI | open/edit text file by path | OK_CAPABLE | notepad.exe present C:\WINDOWS\system32\notepad.exe |

Laptop OK capability count: 14
Final: completed laptop audit and desktop audit status=RAN

## Execution log

# Computer-use capability audit r213
time=2026-10-02 15:30:40
computer=LAPTOP-R77M5D6M user=文少
lab_root=E:\0mcp-agv-arena-optimized
project|windows-computer-use|status=present|path=E:\[REDACTED]\github\[REDACTED]
project|Windows-MCP|status=present|path=E:\[REDACTED]\github\Windows-MCP
project|pywinauto-mcp|status=cloned|path=E:\[REDACTED]\github\pywinauto-mcp
antigravity_cli_candidates=2
ag_cli_version|path=C:\Users\??\AppData\Local\Programs\Antigravity\Antigravity.exe|ok=True|exit=0|out=
ag_cli_version|path=E:\Antigravity\bin\antigravity-ide.cmd|ok=True|exit=0|out=
wcu_r213_health=True activate=True find=True button_id=uia:active.1 invoke=True marker=True
software_op|antigravity-status|{ |     "app":  "Antigravity", |     "installed":  true, |     "version":  "2.19.1.0", |     "processes":  6, |     "languageServer":  1, |     "proxy18088":  true, |     "mcpConfig":  true
software_op|v2rayn-status|{ |     "app":  "v2rayN", |     "v2rayN":  1, |     "xray":  2, |     "bridge18088":  true, |     "bridgeTask":  false | }
software_op|greenvpn-status|{ |     "app":  "GreenVPN", |     "exe":  true, |     "processes":  4, |     "startup":  true, |     "scheduledTask":  false | }
software_op|wps-status|{ |     "app":  "WPS", |     "processes":  4, |     "com":  { |                 "KWPS.Application":  "OK", |                 "KET.Application":  "OK", |                 "KWPP.Application":  "OK" |             }
software_op|illustrator-status|{ |     "app":  "Illustrator", |     "processes":  0, |     "paths":  [ |                   "E:\\Adobe Illustrator 2020 ?????\Support Files\\Contents\\Windows\\Illustrator.exe" |               ] | }
open_window_count=11
window|Antigravity|title=Reply exactly: ARENA_AGV_...
window|Antigravity IDE|title=0mcp-agv - Antigravity IDE - 1.md?
window|[REDACTED]|title=??
window|AweSun|title=???????
window|firefox|title=YouTube ? Mozilla Firefox
window|msedge|title=Arena | Benchmark & Compare the Best AI Models ??? 19 ??? - ?? - Microsoft? Edge
window|msedgewebview2|title=?????
window|SystemSettings|title=??
window|TextInputHost|title=Windows ????
window|v2rayN|title=v2rayN - V7.24.9 - X64 - ????????
window|WindowsTerminal|title=C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe

## Laptop capability list
cap|LAPTOP-R77M5D6M|windows-computer-use|E-drive install|install/presence check|OK|present|E:\[REDACTED]\github\[REDACTED]
cap|LAPTOP-R77M5D6M|Windows-MCP|E-drive install|install/presence check|OK|present|E:\[REDACTED]\github\Windows-MCP
cap|LAPTOP-R77M5D6M|pywinauto-mcp|E-drive install|install/presence check|OK|cloned|E:\[REDACTED]\github\pywinauto-mcp
cap|LAPTOP-R77M5D6M|Antigravity|Antigravity terminal CLI|open E-drive probe file/workspace|OK_ISSUED|version=|E:\[REDACTED]\reports\[REDACTED].txt
cap|LAPTOP-R77M5D6M|Lab WinForms app|windows-computer-use MCP/UIA|find button and invoke it|OK|marker file created by invoked button|E:\[REDACTED]\smoke\[REDACTED].txt
cap|LAPTOP-R77M5D6M|antigravity|software-ops wrapper|run antigravity-status|OK|{??    "app":  "Antigravity",??    "installed":  true,??    "version":  "2.19.1.0",??    "processes":  6,??    "languageServer":  1,??    "proxy18088":  true,??    "mcpConfig":  true??}|E:\[REDACTED]\software-ops\[REDACTED].ps1
cap|LAPTOP-R77M5D6M|v2rayn|software-ops wrapper|run v2rayn-status|OK|{??    "app":  "v2rayN",??    "v2rayN":  1,??    "xray":  2,??    "bridge18088":  true,??    "bridgeTask":  false??}|E:\[REDACTED]\software-ops\[REDACTED].ps1
cap|LAPTOP-R77M5D6M|greenvpn|software-ops wrapper|run greenvpn-status|OK|{??    "app":  "GreenVPN",??    "exe":  true,??    "processes":  4,??    "startup":  true,??    "scheduledTask":  false??}|E:\[REDACTED]\software-ops\[REDACTED].ps1
cap|LAPTOP-R77M5D6M|wps|software-ops wrapper|run wps-status|OK|{??    "app":  "WPS",??    "processes":  4,??    "com":  {??                "KWPS.Application":  "OK",??                "KET.Application":  "OK",??                "KWPP.Application":  "OK"??            }??}|E:\[REDACTED]\software-ops\[REDACTED].ps1
cap|LAPTOP-R77M5D6M|illustrator|software-ops wrapper|run illustrator-status|OK|{??    "app":  "Illustrator",??    "processes":  0,??    "paths":  [??                  "E:\\Adobe Illustrator 2020 ?????\Support Files\\Contents\\Windows\\Illustrator.exe"??              ]??}|E:\[REDACTED]\software-ops\[REDACTED].ps1
cap|LAPTOP-R77M5D6M|WPS Office|COM automation|instantiate Writer/Sheet/Presentation COM|OK|KWPP.Application=OK;KWPS.Application=OK;KET.Application=OK|[REDACTED].pptx
cap|LAPTOP-R77M5D6M|Antigravity chat|CDP/Electron DOM|submit message input|OK_PROVEN_R212|message input role=combobox aria=Message input; cdp-insertText; marker visible after submit|E:\[REDACTED]\reports\[REDACTED].json
cap|LAPTOP-R77M5D6M|File Explorer|shell CLI|open E-drive lab folder|OK_CAPABLE|explorer.exe can open local folders|E:\[REDACTED]
cap|LAPTOP-R77M5D6M|Notepad|process/file CLI|open/edit text file by path|OK_CAPABLE|notepad.exe present|C:\WINDOWS\system32\notepad.exe
local_json=E:\[REDACTED]\reports\[REDACTED].json
desktop_script_staged=OK
desktop| # Desktop computer-use capability audit r213
desktop| time=2026-10-02 15:33:22
desktop| [REDACTED] user=bni
desktop| lab_root=E:\[REDACTED]
desktop| [REDACTED]

## Desktop r214 summary

Desktop audit did not produce a collected report; status=RAN

Desktop status: RAN
FINAL_R214: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY
