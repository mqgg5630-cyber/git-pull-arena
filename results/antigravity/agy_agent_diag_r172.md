# Antigravity agent-error desktop diagnostic r172
time: 2026-10-02 10:17:58
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
   processes: 7
      pid=980 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=16292 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=17604 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=34320 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=36636 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=47204 name=Antigravity.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\Antigravity.exe
      pid=46248 name=language_server.exe path=C:\Users\BNI\AppData\Local\Programs\antigravity\resources\bin\language_server.exe
   tcp: to_proxy=5 direct_443=0
   logs: C:\Users\BNI\AppData\Roaming\Antigravity\logs
      file main.log 09:22:39 210KB
      file language_server.log 20:22:33 11KB
   before main.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\main.log
      L2497 [2026-10-02 01:23:07.005] [error] (node:16292) UnhandledPromiseRejectionWarning: Error: net::ERR_CONNECTION_CLOSED
      L2501 [2026-10-02 01:23:07.006] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 2)
      L2509 [2026-10-02 02:22:39.725] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2514 [2026-10-02 02:23:06.410] [error] Error: Error: net::ERR_CONNECTION_CLOSED
      L2517 [2026-10-02 02:23:06.410] [error] [AutoUpdater] Error: net::ERR_CONNECTION_CLOSED
      L2518 [2026-10-02 02:23:06.411] [error] (node:16292) UnhandledPromiseRejectionWarning: Error: net::ERR_CONNECTION_CLOSED
      L2521 [2026-10-02 02:23:06.412] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 4)
      L2529 [2026-10-02 03:22:39.030] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
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
   relaunched through wrapper
## state after
   processes: 0
   tcp: to_proxy=0 direct_443=0
   logs: C:\Users\BNI\AppData\Roaming\Antigravity\logs
      file main.log 10:18:19 210KB
      file language_server.log 10:17:29 140KB
   after main.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\main.log
      L2501 [2026-10-02 01:23:07.006] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 2)
      L2509 [2026-10-02 02:22:39.725] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2514 [2026-10-02 02:23:06.410] [error] Error: Error: net::ERR_CONNECTION_CLOSED
      L2517 [2026-10-02 02:23:06.410] [error] [AutoUpdater] Error: net::ERR_CONNECTION_CLOSED
      L2518 [2026-10-02 02:23:06.411] [error] (node:16292) UnhandledPromiseRejectionWarning: Error: net::ERR_CONNECTION_CLOSED
      L2521 [2026-10-02 02:23:06.412] [error] (node:16292) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 4)
      L2529 [2026-10-02 03:22:39.030] [error] Cannot download differentially, fallback to full download: Error: Cannot download "https://storage.googleapis.[REDACTED].19.[REDACTED].exe.blockmap", status 404:
      L2572 [2026-10-02 10:18:19.898] [error]
   after language_server.log: hits=20 file=C:\Users\BNI\AppData\Roaming\Antigravity\logs\language_server.log
      L659 ERROR: logging before google.Init: I1002 10:10:29.258213  137884 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels Trace: 0xe08e2fb2f139c953
      L660 ERROR: logging before google.Init: I1002 10:10:30.141705  137897 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist Trace: 0xc15516546605b6d9
      L661 ERROR: logging before google.Init: W1002 10:16:29.275758  138889 cache.go:135] Cache(loadCodeAssistResponse): Singleflight refresh failed: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L662 ERROR: logging before google.Init: E1002 10:16:29.275758  138889 errorreport.go:224] Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L663 ERROR: logging before google.Init: W1002 10:16:29.276296  138889 cache.go:163] Failed to refresh cache in background: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L664 ERROR: logging before google.Init: W1002 10:16:29.276318  138900 cache.go:163] Failed to refresh cache in background: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist": tls: received record with version 15 when expecting version 303
      L665 ERROR: logging before google.Init: I1002 10:16:29.614191  138890 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels Trace: 0xf177aeb5030bba01
      L666 ERROR: logging before google.Init: I1002 10:17:29.575997  139065 http_helpers.go:299] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist Trace: 0x52f72df21f993c90
   logs missing: C:\Users\BNI\AppData\Roaming\Antigravity IDE\logs
FINAL: AGY_NETWORK_LAYER_STILL_BAD direct dial/tls errors remain.
FINAL_DETAIL: no exact termination marker found in scanned logs.
