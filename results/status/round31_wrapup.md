# Wrap-up - rounds 22-31 (2026-09-29)

## Task 1 - Antigravity login: FIXED (user confirmed)
Root cause: the IDE's auth/language-server processes dialed Google APIs
directly, bypassing the system proxy; direct TCP 443 to Google is blocked.
Fixes applied: http.proxy in both settings.json (r23) + USER-level proxy env
vars HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/NO_PROXY (r27). User reports login works.

## Task 2 - Java: DONE
- Microsoft OpenJDK 21.0.12.1 LTS portable at E:\java\jdk-21.0.12.1+1 (r23),
  JAVA_HOME + User PATH set, PATH backup at E:\java\PATH-backup-*.txt
- java env proven end-to-end: javac compile + jar pack + Swing GUI window
  "JavaOK-E-drive" (r31/t11), E:\java\selftest\HelloSwing.jar
- LigPlot+ upgraded: old expired v2.2.9 (all 3 copies same sha256 8e97c34d...)
  removed to the recycle bin (r29 E:\1result, r31 E:\LigPlus); NEW v2.3.2
  (build 2026-06-30) tested in place and installed at E:\LigPlus\LigPlus -
  window title "LigPlot+ v.2.3.2" verified. WeChat copy untouched (chat history).

## Task 3 - E: cleanup: DONE (user-approved parts)
- freed on disk: 233.98 -> ~244 GB free (+ recycle bin ~6.1 GB: old installers,
  expired LigPlus jars, old E:\LigPlus install)
- conda clean --all, npm caches x2, E:\.cache, uv cache (~2.9 GB of 4.7 GB;
  1.78 GB left - locked by running uv/MCP processes)
- NOT touched (user decision): E:\Docker, VALORANT, WSL Ubuntu-24.04 (145 GB),
  E:\xwechat_files LigPlus copy
- Docker report (engine running): images 16.04 GB (4.45 GB reclaimable),
  build cache 10 GB (0.66+ GB reclaimable), n8n container RUNNING,
  autofigure-edit container stopped (its image is 9.34 GB), 0 volumes.
  Safe next step if wanted: docker system prune (~5.1 GB, keeps n8n + all images
  in use; no volumes exist, so no data risk).
