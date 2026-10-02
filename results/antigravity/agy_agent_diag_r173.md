# Antigravity agent-error desktop diagnostic r173
time: 2026-10-02 10:22:32
computer: DESKTOP-IEUDGS5 user: bni
## proxy persistence refresh
   HKCU/env proxy set: OK
   HKLM proxy set: OK
## Antigravity settings refresh
   settings OK: C:\Users\BNI\AppData\Roaming\Antigravity\User\settings.json
   settings OK: C:\Users\BNI\AppData\Roaming\Antigravity IDE\User\settings.json
## wrapper refresh
   wrapper OK: F:\fig1_rebuild\agy_proxy.cmd
## network probes
   local proxy port 10808: True
   curl proxy https://daily-cloudcode-pa.googleapis.com/ -> HTTP/1.1 404 Not Found
   curl proxy https://oauth2.googleapis.com/ -> HTTP/1.1 404 Not Found
   curl proxy https://jetski-webchannel.googleapis.com/ -> HTTP/1.1 404 Not Found
## state before
   processes: 0
   tcp: to_proxy=0 direct_443=0
   logs: C:\Users\BNI\AppData\Roaming\Antigravity\logs
      file main.log 10:18:19 210KB
      file language_server.log 10:17:29 140KB
   before main.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\main.log
      L2501 [2026-10-02 01:23:07.006] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 2)
      L2509 [2026-10-02 02:22:39.725] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2514 [2026-10-02 02:23:06.410] [error] Error: Error: net::ERR_CONNECTION_CLOSED
      L2517 [2026-10-02 02:23:06.410] [error] [AutoUpdater] Error: net::ERR_CONNECTION_CLOSED
      L2518 [2026-10-02 02:23:06.411] [error] (node:16292) UnhandledPromiseRejectionWarning: Error: net::ERR_CONNECTION_CLOSED
      L2521 [2026-10-02 02:23:06.412] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 4)
      L2529 [2026-10-02 03:22:39.030] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2572 [2026-10-02 10:18:19.898] [error]
   before language_server.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\language_server.log
      L659 ERROR: logging before google.Init: I1002 10:10:29.258213  137884 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels Trace: 0xe08e2fb2f139c953
      L660 ERROR: logging before google.Init: I1002 10:10:30.141705  137897 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist Trace: 0xc15516546605b6d9
      L661 ERROR: logging before google.Init: W1002 10:16:29.275758  138889 cache.go:135] Cache(loadCodeAssistResponse): Singleflight refresh failed: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L662 ERROR: logging before google.Init: E1002 10:16:29.275758  138889 errorreport.go:224] Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L663 ERROR: logging before google.Init: W1002 10:16:29.276296  138889 cache.go:163] Failed to refresh cache in background: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L664 ERROR: logging before google.Init: W1002 10:16:29.276318  138900 cache.go:163] Failed to refresh cache in background: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L665 ERROR: logging before google.Init: I1002 10:16:29.614191  138890 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels Trace: 0xf177aeb5030bba01
      L666 ERROR: logging before google.Init: I1002 10:17:29.575997  139065 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist Trace: 0x52f72df21f993c90
   logs missing: C:\Users\BNI\AppData\Roaming\Antigravity IDE\logs
## controlled relaunch
   relaunched through interactive scheduled task: agyrelaunch_git
## state after
   processes: 7
      pid=10944 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=22312 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=35092 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=37172 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=39016 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=40328 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\Antigravity.exe
      pid=39612 name=language_server.exe path=C:\Users\BNI\AppData\Local\Programs\Antigravity\resources\bin\language_server.exe
   tcp: to_proxy=13 direct_443=0
   logs: C:\Users\BNI\AppData\Roaming\Antigravity\logs
      file main.log 10:23:08 213KB
      file language_server.log 10:22:54 0KB
   after main.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\main.log
      L2514 [2026-10-02 02:23:06.410] [error] Error: Error: net::ERR_CONNECTION_CLOSED
      L2517 [2026-10-02 02:23:06.410] [error] [AutoUpdater] Error: net::ERR_CONNECTION_CLOSED
      L2518 [2026-10-02 02:23:06.411] [error] (node:16292) UnhandledPromiseRejectionWarning: Error: net::ERR_CONNECTION_CLOSED
      L2521 [2026-10-02 02:23:06.412] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 4)
      L2529 [2026-10-02 03:22:39.030] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2572 [2026-10-02 10:18:19.898] [error]
      L2580 Spawning: C:\Users\BNI\AppData\Local\Programs\Antigravity\resources\bin\language_server.exe --standalone --override_ide_name antigravity --subclient_type hub --override_ide_version 2.15.1 --override_user_agent_name antigravity --https_server_port 0 --csrf_token d80377e7-e09a-40ba-b9f5-2841a3ae6204 --app_data_dir antigravity --api_server_url https://generativelanguage.googleapis.com --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --enable_sidecars --host_bridge_url=http://127.0.0.1:61134 [REDACTED]
      L2586 [2026-10-02 10:22:55.152] [info]    LS Logs:     C:\Users\BNI\AppData\Roaming\Antigravity\logs\language_server.log
   after language_server.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\language_server.log
      L58 ERROR: logging before google.Init: E1002 10:23:00.369457     711 errorreport.go:224] GetProject: failed to read standalone project file: open C:/Users/BNI/.[REDACTED].json: The system cannot find the file specified.
      L59 ERROR: logging before google.Init: I1002 10:23:00.438981     636 encoder_embed.go:126] [CDP Discovery] Successfully discovered Electron WS URL: ws://127.0.0.1:[REDACTED]
      L60 ERROR: logging before google.Init: I1002 10:23:00.439569     636 encoder_embed.go:126] [CDP Discovery] Successfully discovered Electron WS URL: ws://127.0.0.1:[REDACTED]
      L61 ERROR: logging before google.Init: E1002 10:23:00.499129     171 browser_context.go:179] failed to install playwright: could not install driver: could not install driver: error: got non 200 status code: 404 (404 Not Found) from https://playwright.azureedge.net/builds/driver/playwright-1.57.0-win32_x64.zip
      L62 error: got non 200 status code: 404 (404 Not Found) from https://playwright-akamai.azureedge.net/builds/driver/playwright-1.57.0-win32_x64.zip
      L63 error: got non 200 status code: 404 (404 Not Found) from https://playwright-verizon.azureedge.net/builds/driver/playwright-1.57.0-win32_x64.zip
      L64 ERROR: logging before google.Init: I1002 10:23:00.629655     804 encoder_embed.go:126] [CDP Discovery] Successfully discovered Electron WS URL: ws://127.0.0.1:[REDACTED]
      L65 ERROR: logging before google.Init: I1002 10:23:00.632141     804 encoder_embed.go:126] [CDP Discovery] Successfully discovered Electron WS URL: ws://127.0.0.1:[REDACTED]
   logs missing: C:\Users\BNI\AppData\Roaming\Antigravity IDE\logs
fresh summary: ls_lines=63 good=7 bad=0 term=0 procs=7 to_proxy=13 direct443=0
FINAL: AGY_RELAUNCH_OK fresh session has no new network/termination errors.
