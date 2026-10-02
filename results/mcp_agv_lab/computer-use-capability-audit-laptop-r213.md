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
