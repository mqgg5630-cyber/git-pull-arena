# Laptop computer-use / Windows MCP smoke r249
time=2026-10-03 20:36:29 +08:00
host=LAPTOP-R77M5D6M
lab_root=E:\0mcp-agv-arena-optimized
project|windows-computer-use|status=present|path=E:\0mcp-agv-arena-optimized\github\windows-computer-use
project|Windows-MCP|status=present|path=E:\0mcp-agv-arena-optimized\github\Windows-MCP
project|pywinauto-mcp|status=present|path=E:\0mcp-agv-arena-optimized\github\pywinauto-mcp
wcu_health=True activate=True find=True button_id=uia:active.1 invoke=True marker=True
antigravity_exe_present=True
wps_com|KWPS.Application=True
wps_com|KET.Application=True
wps_com|KWPP.Application=True
open_window_count=10
window|ApplicationFrameHost|title=??
window|Code|title=??.md - 0github - Visual Studio Code
window|firefox|title=YouTube ? Mozilla Firefox
window|msedge|title=Arena | Benchmark & Compare the Best AI Models ??? 20 ??? - ?? - Microsoft? Edge
window|Notepad|title=[REDACTED].txt - Notepad
window|SystemSettings|title=??
window|TextInputHost|title=Windows ????
window|v2rayN|title=v2rayN - V7.24.9 - X64 - ????????
window|WindowsTerminal|title=C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe
window|wpsoffice|title=English.docx - WPS Office

## Capability list
cap|LAPTOP-R77M5D6M|windows-computer-use|E-drive install|install/presence check|OK|present|E:\0mcp-agv-arena-optimized\github\windows-computer-use
cap|LAPTOP-R77M5D6M|Windows-MCP|E-drive install|install/presence check|OK|present|E:\0mcp-agv-arena-optimized\github\Windows-MCP
cap|LAPTOP-R77M5D6M|pywinauto-mcp|E-drive install|install/presence check|OK|present|E:\0mcp-agv-arena-optimized\github\pywinauto-mcp
cap|LAPTOP-R77M5D6M|Lab WinForms app|windows-computer-use MCP/UIA|find button and invoke it|OK|health=True;activate=True;find=True;invoke=True;marker=True|E:\0mcp-agv-arena-optimized\smoke\wcu_find_invoke_result_r249.txt
cap|LAPTOP-R77M5D6M|Antigravity|terminal/GUI surface|detect installed executable|OK|True|C:\Users\??\AppData\Local\Programs\Antigravity\Antigravity.exe
cap|LAPTOP-R77M5D6M|WPS Office|COM automation|instantiate KWPS.Application|OK|True|KWPS.Application
cap|LAPTOP-R77M5D6M|WPS Office|COM automation|instantiate KET.Application|OK|True|KET.Application
cap|LAPTOP-R77M5D6M|WPS Office|COM automation|instantiate KWPP.Application|OK|True|KWPP.Application
WCU_UIA_INVOKE_OK=True
COMPUTER_USE_LAPTOP_OK=True
